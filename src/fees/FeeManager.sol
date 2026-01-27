// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";

/**
 * @title FeeManager (Lagoon-inspired)
 * @notice Fee accrual module inspired by hopperlabsxyz/lagoon-v0 FeeManager.
 *         Designed to be mixed into an ERC4626Upgradeable vault.
 *
 * Key features:
 * - Management fee (time-based) and performance fee (high-water mark)
 * - Cooldown for rate updates (old rates active until timestamp)
 * - Optional protocol fee cut (bps) and separate fee receivers
 * - ERC-7201 style namespaced storage slot to avoid upgradeable storage collisions
 */
abstract contract FeeManager is ERC4626Upgradeable {
    using MathUpgradeable for uint256;

    uint256 internal constant ONE_YEAR = 365 days;
    uint256 internal constant BPS_DIVIDER = 10_000; // 100%

    uint16 public constant MAX_MANAGEMENT_RATE = 1000; // 10%
    uint16 public constant MAX_PERFORMANCE_RATE = 5000; // 50%
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    error AboveMaxRate(uint256 max);
    error ZeroAddress();

    event HighWaterMarkUpdated(uint256 oldHighWaterMark, uint256 newHighWaterMark);
    event RatesUpdated(Rates oldRates, Rates newRates, uint256 applyTimestamp);
    event FeeReceiversUpdated(address feeReceiver, address protocolFeeReceiver);
    event ProtocolRateUpdated(uint256 oldRateBps, uint256 newRateBps);
    event FeeRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event FeesTaken(uint256 managerShares, uint256 protocolShares);

    struct Rates {
        uint16 managementRate; // bps
        uint16 performanceRate; // bps
    }

    /// @custom:storage-definition erc7201:elitra.storage.feeManager
    struct FeeManagerStorage {
        address feeReceiver;
        address protocolFeeReceiver;
        uint16 protocolRateBps;

        uint256 newRatesTimestamp;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        uint256 cooldown;

        Rates rates;
        Rates oldRates;

        address feeRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("elitra.storage.feeManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FEE_MANAGER_STORAGE_LOCATION =
        0x62ee6c87655b03a0f244c5dd6cdaff99ad0ffcf29771b56c4a7e6dc71f3c1c00;

    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := FEE_MANAGER_STORAGE_LOCATION
        }
    }

    // solhint-disable-next-line func-name-mixedcase
    function __FeeManager_init(
        address _feeReceiver,
        address _protocolFeeReceiver,
        address _feeRegistry,
        uint16 _protocolRateBps,
        uint16 _managementRate,
        uint16 _performanceRate,
        uint256 _cooldown
    ) internal onlyInitializing {
        if (_feeReceiver == address(0) || _protocolFeeReceiver == address(0)) revert ZeroAddress();
        if (_managementRate > MAX_MANAGEMENT_RATE) revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        if (_performanceRate > MAX_PERFORMANCE_RATE) revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        if (_protocolRateBps > MAX_PROTOCOL_RATE) revert AboveMaxRate(MAX_PROTOCOL_RATE);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.feeReceiver = _feeReceiver;
        $.protocolFeeReceiver = _protocolFeeReceiver;
        $.protocolRateBps = _protocolRateBps;
        $.feeRegistry = _feeRegistry;

        $.cooldown = _cooldown;
        $.newRatesTimestamp = block.timestamp;
        $.lastFeeTime = block.timestamp;

        // Initialize high-water mark to 1 share worth of assets at share decimals.
        // Lagoon sets it to 10**decimals (share units); we keep same semantics.
        $.highWaterMark = 10 ** decimals();

        $.rates = Rates({ managementRate: _managementRate, performanceRate: _performanceRate });
        $.oldRates = $.rates;
    }

    /// @notice Current fee rates (old rates during cooldown)
    function feeRates() public view returns (Rates memory) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.newRatesTimestamp <= block.timestamp ? $.rates : $.oldRates;
    }

    function feeReceivers() public view returns (address feeReceiver, address protocolFeeReceiver) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return ($.feeReceiver, $.protocolFeeReceiver);
    }

    function protocolRateBps() public view returns (uint16) {
        return _protocolRate();
    }

    function highWaterMark() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.highWaterMark;
    }

    function lastFeeTime() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.lastFeeTime;
    }

    function cooldown() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.cooldown;
    }

    function feeRegistry() public view returns (address) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.feeRegistry;
    }

    /// @notice Update fee rates (applied after cooldown)
    function _updateRates(Rates memory newRates) internal {
        if (newRates.managementRate > MAX_MANAGEMENT_RATE) revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE) revert AboveMaxRate(MAX_PERFORMANCE_RATE);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 applyTs = block.timestamp + $.cooldown;
        Rates memory current = $.rates;

        $.newRatesTimestamp = applyTs;
        $.oldRates = current;
        $.rates = newRates;

        emit RatesUpdated(current, newRates, applyTs);
    }

    function _setFeeReceivers(address _feeReceiver, address _protocolFeeReceiver) internal {
        if (_feeReceiver == address(0) || _protocolFeeReceiver == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.feeReceiver = _feeReceiver;
        $.protocolFeeReceiver = _protocolFeeReceiver;
        emit FeeReceiversUpdated(_feeReceiver, _protocolFeeReceiver);
    }

    function _setProtocolRateBps(uint16 newRateBps) internal {
        if (newRateBps > MAX_PROTOCOL_RATE) revert AboveMaxRate(MAX_PROTOCOL_RATE);
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 old = $.protocolRateBps;
        $.protocolRateBps = newRateBps;
        emit ProtocolRateUpdated(old, newRateBps);
    }

    function _setFeeRegistry(address newRegistry) internal {
        if (newRegistry == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        address old = $.feeRegistry;
        $.feeRegistry = newRegistry;
        emit FeeRegistryUpdated(old, newRegistry);
    }

    function _setHighWaterMark(uint256 newHwm) internal {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 oldHwm = $.highWaterMark;
        if (newHwm > oldHwm) {
            $.highWaterMark = newHwm;
            emit HighWaterMarkUpdated(oldHwm, newHwm);
        }
    }

    /// @notice Mint fee shares to fee receivers based on current rates.
    /// @dev This is Lagoon-style "mint shares without adding assets".
    function _takeFees() internal {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        (uint256 managerShares, uint256 protocolShares) = _calculateFees();

        if (managerShares > 0) {
            _mint($.feeReceiver, managerShares);
            if (protocolShares > 0) {
                _mint($.protocolFeeReceiver, protocolShares);
            }
        }

        // Update HWM using current price per share (assets per 1 share unit)
        uint256 pps = _convertToAssets(10 ** decimals(), MathUpgradeable.Rounding.Down);
        _setHighWaterMark(pps);

        $.lastFeeTime = block.timestamp;

        emit FeesTaken(managerShares, protocolShares);
    }

    function _calculateFees() internal view returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        Rates memory r = feeRates();

        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        uint256 assetsUnderMgmt = totalAssets();

        // Management fee in assets
        uint256 managementFees = _calculateManagementFee(assetsUnderMgmt, r.managementRate, timeElapsed);

        // Price-per-share after accounting for management fees (dilution-aware)
        uint256 pricePerShare = (10 ** decimals()).mulDiv(
            assetsUnderMgmt + 1 - managementFees,
            totalSupply() + 10 ** _decimalsOffset(),
            MathUpgradeable.Rounding.Up
        );

        // Performance fee in assets (based on HWM)
        uint256 performanceFees = _calculatePerformanceFee(
            r.performanceRate,
            totalSupply(),
            pricePerShare,
            $.highWaterMark,
            decimals()
        );

        uint256 totalFeesAssets = managementFees + performanceFees;
        if (totalFeesAssets == 0) return (0, 0);

        // Convert fee assets to shares to mint (dilution compensation)
        uint256 totalSharesToMint = totalFeesAssets.mulDiv(
            totalSupply() + 10 ** _decimalsOffset(),
            (assetsUnderMgmt - totalFeesAssets) + 1,
            MathUpgradeable.Rounding.Up
        );

        protocolShares = totalSharesToMint.mulDiv(uint256(_protocolRate()), BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        managerShares = totalSharesToMint - protocolShares;
    }

    function _calculateManagementFee(
        uint256 assets,
        uint256 annualRateBps,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (annualRateBps == 0 || assets == 0 || timeElapsed == 0) return 0;
        uint256 annualFee = assets.mulDiv(annualRateBps, BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        return annualFee.mulDiv(timeElapsed, ONE_YEAR, MathUpgradeable.Rounding.Up);
    }

    function _calculatePerformanceFee(
        uint256 rateBps,
        uint256 totalSupplyShares,
        uint256 pricePerShare,
        uint256 hwm,
        uint256 shareDecimals
    ) internal pure returns (uint256) {
        if (rateBps == 0) return 0;
        if (pricePerShare <= hwm) return 0;

        uint256 profitPerShare;
        unchecked {
            profitPerShare = pricePerShare - hwm;
        }

        uint256 profitAssets = profitPerShare.mulDiv(totalSupplyShares, 10 ** shareDecimals, MathUpgradeable.Rounding.Up);
        return profitAssets.mulDiv(rateBps, BPS_DIVIDER, MathUpgradeable.Rounding.Up);
    }

    function _protocolRate() internal view returns (uint16) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if ($.feeRegistry == address(0)) return $.protocolRateBps;
        uint16 registryRate = IFeeRegistry($.feeRegistry).protocolFeeRateBps();
        return registryRate > MAX_PROTOCOL_RATE ? MAX_PROTOCOL_RATE : registryRate;
    }
}
