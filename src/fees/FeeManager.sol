// SPDX-License-Identifier: UNLICENSED
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

    // Time base for annualized management fee accrual.
    uint256 internal constant ONE_YEAR = 365 days;
    // Basis points denominator for rate math (100% = 10_000 bps).
    uint256 internal constant BPS_DIVIDER = 10_000; // 100%
    // 1e18 fixed-point denominator for deposit/withdraw fees.
    uint256 internal constant DENOMINATOR = 1e18; // 100%

    // Hard caps to prevent misconfiguration.
    uint16 public constant MAX_MANAGEMENT_RATE = 1000; // 10%
    uint16 public constant MAX_PERFORMANCE_RATE = 5000; // 50%
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%
    // Entry/exit fee cap (1%).
    uint256 internal constant MAX_FEE = 1e16; // 1%

    error AboveMaxRate(uint256 max);
    error ZeroAddress();

    event HighWaterMarkUpdated(uint256 oldHighWaterMark, uint256 newHighWaterMark);
    event RatesUpdated(Rates oldRates, Rates newRates, uint256 applyTimestamp);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event FeeRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event FeesTaken(uint256 managerShares, uint256 protocolShares);

    struct Rates {
        // Annualized fee on AUM (in bps).
        uint16 managementRate;
        // Performance fee on profits above HWM (in bps).
        uint16 performanceRate;
    }

    /// @custom:storage-definition erc7201:elitra.storage.feeManager
    struct FeeManagerStorage {
        // Recipient for manager fees (shares minted to this address).
        address feeReceiver;
        // Deprecated: kept for storage compatibility.
        address protocolFeeReceiver;
        // Deprecated: kept for storage compatibility.
        uint16 protocolRateBps;

        // Timestamp after which new rates are effective.
        uint256 newRatesTimestamp;
        // Last time fees were accrued.
        uint256 lastFeeTime;
        // High-water mark in asset units per share.
        uint256 highWaterMark;
        // Cooldown duration before new rates apply.
        uint256 cooldown;

        // Active rates and previous rates (used during cooldown).
        Rates rates;
        Rates oldRates;

        // Registry that provides protocol fee rate/receiver.
        address feeRegistry;
        // Flat fee rates (1e18 denominator) for entry/exit paths.
        uint256 feeOnDeposit;
        uint256 feeOnWithdraw;
        uint256 feeOnQueuedRedeem;
        // Recipient for manager fees paid in assets (claim path).
        address feeRecipient;
        // Accumulated manager fees in assets.
        uint256 pendingFees;
        // Accumulated protocol fees in assets.
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
        // Guard against unusable config at initialization.
        if (_feeReceiver == address(0) || _feeRegistry == address(0)) revert ZeroAddress();
        if (_managementRate > MAX_MANAGEMENT_RATE) revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        if (_performanceRate > MAX_PERFORMANCE_RATE) revert AboveMaxRate(MAX_PERFORMANCE_RATE);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        // Default to the owner as the initial fee receiver/recipient.
        $.feeReceiver = _feeReceiver;
        $.feeRegistry = _feeRegistry;
        $.feeRecipient = _feeReceiver;

        // Apply rates immediately on init (cooldown counts from now).
        $.cooldown = _cooldown;
        $.newRatesTimestamp = block.timestamp;
        $.lastFeeTime = block.timestamp;

        // Initialize high-water mark to 1 share worth of assets at share decimals.
        // Lagoon sets it to 10**decimals (share units); we keep same semantics.
        // Initialize HWM to 1 share unit (in assets) at share decimals.
        $.highWaterMark = 10 ** decimals();

        // Seed both current and "old" rates to avoid cooldown ambiguity.
        $.rates = Rates({ managementRate: _managementRate, performanceRate: _performanceRate });
        $.oldRates = $.rates;
    }

    /// @notice Get current fee rates (uses old rates during cooldown period)
    /// @return Fee rates struct containing managementRate and performanceRate in bps
    /// @dev Returns old rates if cooldown period hasn't elapsed, otherwise returns new rates
    function feeRates() public view returns (Rates memory) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // During cooldown, old rates stay active to avoid mid-epoch jumps.
        return $.newRatesTimestamp <= block.timestamp ? $.rates : $.oldRates;
    }

    /// @notice Get fee receiver addresses
    /// @return feeReceiver Manager fee receiver address
    /// @return protocolFeeReceiver Protocol fee receiver address
    function feeReceivers() public view returns (address feeReceiver, address protocolFeeReceiver) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Protocol receiver is resolved lazily from the registry.
        return ($.feeReceiver, _protocolFeeReceiver());
    }

    /// @notice Get the deposit fee rate (in 1e18 denominator)
    /// @return Deposit fee rate
    /// @inheritdoc IFeeManager
    function feeOnDeposit() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnDeposit;
    }

    /// @notice Get the withdraw fee rate (in 1e18 denominator)
    /// @return Withdraw fee rate
    /// @inheritdoc IFeeManager
    function feeOnWithdraw() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnWithdraw;
    }

    /// @notice Get the queued redeem fee rate (in 1e18 denominator)
    /// @return Queued redeem fee rate
    /// @inheritdoc IFeeManager
    function feeOnQueuedRedeem() public virtual view returns (uint256) {
        return _getFeeManagerStorage().feeOnQueuedRedeem;
    }

    /// @notice Get the fee recipient address
    /// @return Fee recipient address
    /// @inheritdoc IFeeManager
    function feeRecipient() public virtual view returns (address) {
        return _getFeeManagerStorage().feeRecipient;
    }

    /// @notice Get total pending fees (manager + protocol)
    /// @return Total pending fees in asset tokens
    /// @inheritdoc IFeeManager
    function pendingFees() public virtual view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Sum both fee buckets for total outstanding liabilities.
        return $.pendingFees + $.pendingProtocolFees;
    }

    /// @notice Get pending protocol fees
    /// @return Pending protocol fees in asset tokens
    function pendingProtocolFees() public view returns (uint256) {
        return _getFeeManagerStorage().pendingProtocolFees;
    }

    /// @notice Get the protocol fee rate in basis points
    /// @return Protocol fee rate in bps (capped at MAX_PROTOCOL_RATE)
    function protocolRateBps() public view returns (uint16) {
        // Pull current protocol rate from registry (capped).
        return _protocolRate();
    }

    /// @notice Get the high-water mark for performance fee calculation
    /// @return High-water mark in asset units per share
    /// @dev Performance fees are only charged when price per share exceeds this value
    function highWaterMark() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // HWM is used to gate performance fees.
        return $.highWaterMark;
    }

    /// @notice Get the timestamp of the last fee calculation
    /// @return Timestamp of last fee calculation
    function lastFeeTime() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Used to compute elapsed time for management fees.
        return $.lastFeeTime;
    }

    /// @notice Get the cooldown period for rate updates
    /// @return Cooldown period in seconds
    /// @dev New fee rates take effect after this cooldown period
    function cooldown() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Cooldown delays rate changes to give users time to react.
        return $.cooldown;
    }

    /// @notice Get the fee registry contract address
    /// @return Fee registry address
    function feeRegistry() public view returns (address) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Registry is the source of protocol fee policy.
        return $.feeRegistry;
    }

    /// @notice Update fee rates (applied after cooldown)
    function _updateRates(Rates memory newRates) internal {
        // Enforce max caps to avoid abusive fees.
        if (newRates.managementRate > MAX_MANAGEMENT_RATE) revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE) revert AboveMaxRate(MAX_PERFORMANCE_RATE);

        // Checkpoint fees under the currently active rates before changing rate state
        _takeFees();

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        // Schedule new rates to activate after cooldown.
        uint256 applyTs = block.timestamp + $.cooldown;
        // Snapshot current rates for the cooldown window.
        Rates memory current = feeRates();

        $.newRatesTimestamp = applyTs;
        $.oldRates = current;
        $.rates = newRates;

        emit RatesUpdated(current, newRates, applyTs);
    }

    function _setFeeReceiver(address newFeeReceiver) internal {
        // Fee receiver must be a valid address.
        if (newFeeReceiver == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        address old = $.feeReceiver;
        $.feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated(old, newFeeReceiver);
    }

    function _setDepositFee(uint256 newFee) internal returns (uint256 oldFee) {
        // Cap to protect users from excessive entry fees.
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnDeposit;
        $.feeOnDeposit = newFee;
    }

    function _setWithdrawFee(uint256 newFee) internal returns (uint256 oldFee) {
        // Cap to protect users from excessive exit fees.
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnWithdraw;
        $.feeOnWithdraw = newFee;
    }

    function _setQueuedRedeemFee(uint256 newFee) internal returns (uint256 oldFee) {
        // Cap to protect users from excessive queued redeem fees.
        if (newFee > MAX_FEE) revert Errors.InvalidFee();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldFee = $.feeOnQueuedRedeem;
        $.feeOnQueuedRedeem = newFee;
    }

    function _setFeeRecipient(address newRecipient) internal returns (address oldRecipient) {
        // Fee recipient must be valid to avoid fee blackholes.
        if (newRecipient == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        oldRecipient = $.feeRecipient;
        $.feeRecipient = newRecipient;
    }

    function _addPendingFees(uint256 amount) internal {
        // No-op for zero to save gas and avoid noise.
        if (amount == 0) return;
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Split fees into protocol cut and manager remainder.
        uint256 protocolCut = amount.mulDiv(uint256(_protocolRate()), BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        $.pendingProtocolFees += protocolCut;
        $.pendingFees += amount - protocolCut;
    }

    function _clearPendingFees() internal returns (uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Clear manager fees so they can't be double-claimed.
        fees = $.pendingFees;
        $.pendingFees = 0;
    }

    function _claimManagerFees() internal returns (address recipient, uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Transfer manager fees in underlying assets.
        fees = $.pendingFees;
        if (fees == 0) revert Errors.InvalidAssetsAmount();

        // Resolve recipient for manager fees.
        recipient = $.feeRecipient;
        if (recipient == address(0)) revert ZeroAddress();

        $.pendingFees = 0;
        IERC20(asset()).safeTransfer(recipient, fees);
    }

    function _claimProtocolFees() internal returns (address recipient, uint256 fees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Transfer protocol fees in underlying assets.
        fees = $.pendingProtocolFees;
        if (fees == 0) revert Errors.InvalidAssetsAmount();

        // Resolve protocol fee receiver from registry.
        recipient = _protocolFeeReceiver();
        if (recipient == address(0)) revert ZeroAddress();

        $.pendingProtocolFees = 0;
        IERC20(asset()).safeTransfer(recipient, fees);
    }

    function _setFeeRegistry(address newRegistry) internal {
        // Registry must be valid for protocol fee lookups.
        if (newRegistry == address(0)) revert ZeroAddress();
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        address old = $.feeRegistry;
        $.feeRegistry = newRegistry;
        emit FeeRegistryUpdated(old, newRegistry);
    }

    function _setHighWaterMark(uint256 newHwm) internal {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 oldHwm = $.highWaterMark;
        // Only increase HWM to preserve "high-water" semantics.
        if (newHwm > oldHwm) {
            $.highWaterMark = newHwm;
            emit HighWaterMarkUpdated(oldHwm, newHwm);
        }
    }

    /// @notice Mint fee shares to fee receivers based on current rates.
    /// @dev This is Lagoon-style "mint shares without adding assets".
    function _takeFees() internal {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        // Compute fee shares based on current rates and AUM.
        (uint256 managerShares, uint256 protocolShares) = _calculateFees();

        // Only mint if there are fees to take.
        if (managerShares > 0) {
            _mint($.feeReceiver, managerShares);
            if (protocolShares > 0) {
                _mint(_protocolFeeReceiver(), protocolShares);
            }
        }

        // Update HWM using current price per share (assets per 1 share unit)
        // Update HWM using current PPS (assets per 1 share unit).
        uint256 pps = _convertToAssets(10 ** decimals(), MathUpgradeable.Rounding.Down);
        _setHighWaterMark(pps);

        // Advance fee clock for management fee accrual.
        $.lastFeeTime = block.timestamp;

        emit FeesTaken(managerShares, protocolShares);
    }

    function _calculateFees() internal view returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        // Resolve active rates (respects cooldown).
        Rates memory r = feeRates();

        // Time-based fee uses elapsed time since last accrual.
        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        // AUM excludes pending fees (totalAssets handles that).
        uint256 assetsUnderMgmt = totalAssets();

        // Management fee in assets
        // Management fee in asset units.
        uint256 managementFees = _calculateManagementFee(assetsUnderMgmt, r.managementRate, timeElapsed);

        // Price-per-share after accounting for management fees (dilution-aware)
        // PPS after deducting management fees (dilution-aware).
        uint256 assetsAfterMgmt = assetsUnderMgmt > managementFees ? assetsUnderMgmt - managementFees : 0;
        uint256 pricePerShare = (10 ** decimals()).mulDiv(
            assetsAfterMgmt,
            totalSupply() + 10 ** _decimalsOffset(),
            MathUpgradeable.Rounding.Up
        );

        // Performance fee in assets (based on HWM)
        // Performance fee is charged only on gains above HWM.
        uint256 performanceFees = _calculatePerformanceFee(
            r.performanceRate,
            totalSupply(),
            pricePerShare,
            $.highWaterMark,
            decimals()
        );

        // Aggregate fees in asset units.
        uint256 totalFeesAssets = managementFees + performanceFees;
        if (totalFeesAssets == 0) return (0, 0);

        // Solve for share mint amount x:
        // x / (totalSupply + x) = totalFeesAssets / assetsUnderMgmt
        // => x = totalFeesAssets * (totalSupply + 10**offset) / (assetsUnderMgmt - totalFeesAssets)
        uint256 assetsAfterFees = assetsUnderMgmt - totalFeesAssets;
        uint256 totalSharesToMint = totalFeesAssets.mulDiv(
            totalSupply() + 10 ** _decimalsOffset(),
            assetsAfterFees + 1,
            MathUpgradeable.Rounding.Up
        );

        // Split minted shares between protocol and manager.
        protocolShares = totalSharesToMint.mulDiv(uint256(_protocolRate()), BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        managerShares = totalSharesToMint - protocolShares;
    }

    function _calculateManagementFee(
        uint256 assets,
        uint256 annualRateBps,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        // Short-circuit if nothing to charge.
        if (annualRateBps == 0 || assets == 0 || timeElapsed == 0) return 0;
        // Annual fee = assets * rate.
        uint256 annualFee = assets.mulDiv(annualRateBps, BPS_DIVIDER, MathUpgradeable.Rounding.Up);
        // Pro-rate by elapsed time.
        return annualFee.mulDiv(timeElapsed, ONE_YEAR, MathUpgradeable.Rounding.Up);
    }

    function _calculatePerformanceFee(
        uint256 rateBps,
        uint256 totalSupplyShares,
        uint256 pricePerShare,
        uint256 hwm,
        uint256 shareDecimals
    ) internal pure returns (uint256) {
        // No perf fee if rate is zero or PPS hasn't exceeded HWM.
        if (rateBps == 0) return 0;
        if (pricePerShare <= hwm) return 0;

        uint256 profitPerShare;
        // Safe because pricePerShare > hwm is enforced above.
        unchecked {
            profitPerShare = pricePerShare - hwm;
        }

        // Convert per-share profit to total assets.
        uint256 profitAssets = profitPerShare.mulDiv(totalSupplyShares, 10 ** shareDecimals, MathUpgradeable.Rounding.Up);
        // Apply performance rate to total profit.
        return profitAssets.mulDiv(rateBps, BPS_DIVIDER, MathUpgradeable.Rounding.Up);
    }

    function _protocolRate() internal view returns (uint16) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Pull rate from registry and cap it defensively.
        if ($.feeRegistry == address(0)) revert ZeroAddress();
        uint16 registryRate = IFeeRegistry($.feeRegistry).protocolFeeRateBps(address(this));
        return registryRate > MAX_PROTOCOL_RATE ? MAX_PROTOCOL_RATE : registryRate;
    }

    function _protocolFeeReceiver() internal view returns (address) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Resolve receiver from registry (must be configured).
        if ($.feeRegistry == address(0)) revert ZeroAddress();
        return IFeeRegistry($.feeRegistry).protocolFeeReceiver();
    }

    function _feeOnRaw(uint256 assets, uint256 feeRate) internal pure returns (uint256) {
        // Fee applied on "raw" assets (fee is additive).
        return assets.mulDiv(feeRate, DENOMINATOR, MathUpgradeable.Rounding.Up);
    }

    function _feeOnTotal(uint256 assets, uint256 feeRate) internal pure returns (uint256) {
        // Fee applied on "total" assets (fee is inclusive).
        return assets.mulDiv(feeRate, feeRate + DENOMINATOR, MathUpgradeable.Rounding.Up);
    }

    function _feeConfig() internal view returns (uint256 depositFee, uint256 withdrawFee, uint256 queuedRedeemFee, uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        // Return configured fees; trailing value reserved for future use.
        return ($.feeOnDeposit, $.feeOnWithdraw, $.feeOnQueuedRedeem, 0);
    }

}
