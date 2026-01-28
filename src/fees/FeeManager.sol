// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";
import { Errors } from "../libraries/Errors.sol";

/// @title IFeeManager
/// @notice Minimal interface for fee-related view functions
interface IFeeManager {
    function feeOnDeposit() external view returns (uint256);
    function feeOnWithdraw() external view returns (uint256);
    function feeOnQueuedRedeem() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function pendingFees() external view returns (uint256);
}

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
abstract contract FeeManager is ERC4626Upgradeable, IFeeManager {
    using MathUpgradeable for uint256;
    using SafeERC20 for IERC20;

    uint256 internal constant ONE_YEAR = 365 days;
    uint256 internal constant BPS_DIVIDER = 10_000; // 100%
    uint256 internal constant DENOMINATOR = 1e18; // 100%

    uint16 public constant MAX_MANAGEMENT_RATE = 1000; // 10%
    uint16 public constant MAX_PERFORMANCE_RATE = 5000; // 50%
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%
    uint256 internal constant MAX_FEE = 1e16; // 1%

    error AboveMaxRate(uint256 max);
    error ZeroAddress();

    event HighWaterMarkUpdated(uint256 oldHighWaterMark, uint256 newHighWaterMark);
    event RatesUpdated(Rates oldRates, Rates newRates, uint256 applyTimestamp);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event FeeRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event FeesTaken(uint256 managerShares, uint256 protocolShares);

    struct Rates {
        uint16 managementRate; // bps
        uint16 performanceRate; // bps
    }

    /// @custom:storage-definition erc7201:elitra.storage.feeManager
    struct FeeManagerStorage {
        address feeReceiver;
        // Deprecated: kept for storage compatibility.
        address protocolFeeReceiver;
        uint16 protocolRateBps;

        uint256 newRatesTimestamp;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        uint256 cooldown;

        Rates rates;
        Rates oldRates;

        address feeRegistry;
        uint256 feeOnDeposit;
        uint256 feeOnWithdraw;
        uint256 feeOnQueuedRedeem;
        address feeRecipient;
        uint256 pendingFees;
        uint256 pendingProtocolFees;
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
        address _feeRegistry,
        uint16 _managementRate,
        uint16 _performanceRate,
        uint256 _cooldown
    ) internal onlyInitializing {
        if (_feeReceiver == address(0) || _feeRegistry == address(0)) revert ZeroAddress();
        if (_managementRate > MAX_MANAGEMENT_RATE) revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        if (_performanceRate > MAX_PERFORMANCE_RATE) revert AboveMaxRate(MAX_PERFORMANCE_RATE);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.feeReceiver = _feeReceiver;
        $.feeRegistry = _feeRegistry;
        $.feeRecipient = _feeReceiver;

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
        return ($.feeReceiver, _protocolFeeReceiver());
    }

    function feeOnDeposit() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnDeposit;
    }

    function feeOnWithdraw() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnWithdraw;
    }

    function feeOnQueuedRedeem() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnQueuedRedeem;
    }

    function feeRecipient() public virtual view returns (address) {
        return _getFeeManagerStorage().feeRecipient;
    }

    function pendingFees() public virtual view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.pendingFees + $.pendingProtocolFees;
    }

    function pendingProtocolFees() public view returns (uint256) {
        return _getFeeManagerStorage().pendingProtocolFees;
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

    function _setFeeReceiver(address newFeeReceiver) internal {
        if (newFeeReceiver == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        address old = $.feeReceiver;
        $.feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated(old, newFeeReceiver);
    }

    function _setDepositFee(uint256 newFee) internal returns (uint256 oldFee) {
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnDeposit;
        $.feeOnDeposit = newFee;
    }

    function _setWithdrawFee(uint256 newFee) internal returns (uint256 oldFee) {
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnWithdraw;
        $.feeOnWithdraw = newFee;
    }

    function _setQueuedRedeemFee(uint256 newFee) internal returns (uint256 oldFee) {
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnQueuedRedeem;
        $.feeOnQueuedRedeem = newFee;
    }

    function _setFeeRecipient(address newRecipient) internal returns (address oldRecipient) {
        if (newRecipient == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldRecipient = $.feeRecipient;
        $.feeRecipient = newRecipient;
    }

    function _addPendingFees(uint256 amount) internal {
        if (amount == 0) return;
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 protocolCut = amount.mulDiv(uint256(_protocolRate()), BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        $.pendingProtocolFees += protocolCut;
        $.pendingFees += amount - protocolCut;
    }

    function _clearPendingFees() internal returns (uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        fees = $.pendingFees;
        $.pendingFees = 0;
    }

    function _claimManagerFees() internal returns (address recipient, uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        fees = $.pendingFees;
        if (fees == 0) revert Errors.InvalidAssetsAmount();

        recipient = $.feeRecipient;
        if (recipient == address(0)) revert ZeroAddress();

        $.pendingFees = 0;
        IERC20(asset()).safeTransfer(recipient, fees);
    }

    function _claimProtocolFees() internal returns (address recipient, uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        fees = $.pendingProtocolFees;
        if (fees == 0) revert Errors.InvalidAssetsAmount();

        recipient = _protocolFeeReceiver();
        if (recipient == address(0)) revert ZeroAddress();

        $.pendingProtocolFees = 0;
        IERC20(asset()).safeTransfer(recipient, fees);
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
                _mint(_protocolFeeReceiver(), protocolShares);
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

        // Solve for x: x / (totalSupply + x) = totalFeesAssets / assetsUnderMgmt.
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
        if ($.feeRegistry == address(0)) revert ZeroAddress();
        uint16 registryRate = IFeeRegistry($.feeRegistry).protocolFeeRateBps(address(this));
        return registryRate > MAX_PROTOCOL_RATE ? MAX_PROTOCOL_RATE : registryRate;
    }

    function _protocolFeeReceiver() internal view returns (address) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if ($.feeRegistry == address(0)) revert ZeroAddress();
        return IFeeRegistry($.feeRegistry).protocolFeeReceiver();
    }

    function _feeOnRaw(uint256 assets, uint256 feeRate) internal pure returns (uint256) {
        return assets.mulDiv(feeRate, DENOMINATOR, MathUpgradeable.Rounding.Up);
    }

    function _feeOnTotal(uint256 assets, uint256 feeRate) internal pure returns (uint256) {
        return assets.mulDiv(feeRate, feeRate + DENOMINATOR, MathUpgradeable.Rounding.Up);
    }

    function _feeConfig() internal view returns (uint256 depositFee, uint256 withdrawFee, uint256 queuedRedeemFee, uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return ($.feeOnDeposit, $.feeOnWithdraw, $.feeOnQueuedRedeem, 0);
    }

}
