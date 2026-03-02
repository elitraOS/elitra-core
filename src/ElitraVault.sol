// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IElitraVault, Call } from "./interfaces/IElitraVault.sol";
import { IVaultBase } from "./interfaces/IVaultBase.sol";
import { IBalanceUpdateHook } from "./interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook, RedemptionMode } from "./interfaces/IRedemptionHook.sol";

import { VaultBase } from "./vault/VaultBase.sol";
import { FeeManager } from "./fees/FeeManager.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title ElitraVault - Vault with pluggable oracle and redemption adapters
/// @notice ERC-4626 vault that delegates validation logic to adapters
contract ElitraVault is ERC4626Upgradeable, VaultBase, FeeManager, ReentrancyGuardUpgradeable, IElitraVault {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev Redemption request ID (always 0 for non-fungible requests)
    uint256 internal constant REQUEST_ID = 0;

    // Oracle state
    // Hook that validates balance updates (e.g., PPS threshold checks).
    IBalanceUpdateHook public balanceUpdateHook;
    // Aggregated balances reported from external strategies.
    uint256 public aggregatedUnderlyingBalances;
    // Guard to prevent multiple updates in the same block.
    uint256 public lastBlockUpdated;
    // Cached price per share from the last update.
    uint256 public lastPricePerShare;

    // NAV freshness state
    // Maximum allowed time (in seconds) since last NAV update.
    uint256 public navFreshnessThreshold;
    // Timestamp of last NAV update.
    uint256 public lastTimestampUpdated;

    // Redemption state
    // Hook that decides redemption mode and amount.
    IRedemptionHook public redemptionHook;
    // Owner => pending queued assets.
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;
    // Total assets reserved for queued redemptions.
    uint256 public totalPendingAssets;

    // Fee state (moved to FeeManager storage)

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault with adapters
    function initialize(
        IERC20 _asset,
        address _owner,
        address _upgradeAdmin,
        address _feeRegistry,
        IBalanceUpdateHook _balanceUpdateHook,
        IRedemptionHook _redemptionHook,
        string memory _name,
        string memory _symbol
    )
        public
        initializer
    {
        // Initialize upgradeable mixins and ERC4626 plumbing.
        __Context_init();
        __ERC20_init(_name, _symbol);
        __ERC4626_init(IERC20Upgradeable(address(_asset)));
        __VaultBase_init(_owner, _upgradeAdmin);
        __ReentrancyGuard_init();

        // FeeManager (Lagoon-inspired): initialize with safe defaults (0 fees) and receivers set to owner.
        // Initialize FeeManager with safe defaults (0 fees, no cooldown).
        __FeeManager_init(_owner, _feeRegistry, 0, 0, 0);

        // Require non-zero adapters to avoid unusable vault.
        require(address(_balanceUpdateHook) != address(0), Errors.ZeroAddress());
        require(address(_redemptionHook) != address(0), Errors.ZeroAddress());

        balanceUpdateHook = _balanceUpdateHook;
        redemptionHook = _redemptionHook;
    }

    // ========================================= ORACLE INTEGRATION =========================================

    /// @notice Internal function to update vault balance and price per share
    /// @param newAggregatedBalance The new aggregated balance from external protocols
    function _updateBalance(uint256 newAggregatedBalance) internal {
        uint256 newPPS = _calculatePPS(totalSupply(), _netTotalAssets(newAggregatedBalance));

        // 1. Pull validation from balance update hook (read-only).
        bool shouldContinue = balanceUpdateHook.beforeBalanceUpdate(lastPricePerShare, newPPS);

        // 2. If hook signals out-of-bounds, pause the vault.
        if (!shouldContinue) {
            _pause();
            emit VaultPausedDueToThreshold(block.timestamp, lastPricePerShare, newPPS);
            return;
        }

        // Emit the changes for off-chain indexers.
        emit UnderlyingBalanceUpdated(block.timestamp, aggregatedUnderlyingBalances, newAggregatedBalance);

        // Update cached balances and PPS.
        uint256 oldPPS = lastPricePerShare;
        aggregatedUnderlyingBalances = newAggregatedBalance;
        lastPricePerShare = newPPS;

        emit PPSUpdated(block.timestamp, oldPPS, newPPS);
    }

    /// @notice Update the vault's aggregated underlying balance and price per share
    /// @param newAggregatedBalance The new aggregated balance from external protocols
    /// @dev Validates that balance hasn't been updated in the current block and calls the balance update hook
    function updateBalance(uint256 newAggregatedBalance) external requiresAuth nonReentrant {
        // Guard against multiple external syncs within the same block.
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        _updateBalance(newAggregatedBalance);

        // Update freshness trackers (external syncs reset NAV freshness).
        lastBlockUpdated = block.number;
        lastTimestampUpdated = block.timestamp;
    }

    function _netTotalAssets(uint256 newAggregatedBalance) internal view returns (uint256) {
        // Idle assets live on the vault contract.
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        // Total assets = idle + aggregated external balances.
        uint256 totalAssetsAfter = idleAssets + newAggregatedBalance;
        // Exclude queued redemptions and pending fees from NAV.
        uint256 excluded = totalPendingAssets + pendingFees();
        // Prevent underflow if excluded > total.
        return totalAssetsAfter > excluded ? totalAssetsAfter - excluded : 0;
    }

    /// @notice Set the balance update hook used for validating balance updates
    /// @param newAdapter Address of the new balance update hook (cannot be zero)
    /// @inheritdoc IElitraVault
    function setBalanceUpdateHook(IBalanceUpdateHook newAdapter) external requiresAuth {
        // Adapter must be valid.
        require(address(newAdapter) != address(0), Errors.ZeroAddress());
        emit BalanceUpdateHookUpdated(address(balanceUpdateHook), address(newAdapter));
        balanceUpdateHook = newAdapter;
    }

    /// @notice Set the NAV freshness threshold
    /// @param newThreshold Maximum allowed time (in seconds) since last NAV update. Set to 0 to disable check.
    function setNavFreshnessThreshold(uint256 newThreshold) external requiresAuth {
        // Emit before update to preserve old/new values.
        emit NavFreshnessThresholdUpdated(navFreshnessThreshold, newThreshold);
        navFreshnessThreshold = newThreshold;
    }

    // ========================================= FEES (Lagoon-inspired) =========================================

    /// @notice Take management/performance fees by minting shares to fee receivers.
    /// @dev Manual hook for now (does not auto-accrue on deposit/withdraw/updateBalance).
    function takeFees() external requiresAuth {
        // Manual accrual; does not auto-run on other state changes.
        _takeFeesAndSyncPPS();
    }

    /// @notice Update fee rates (applied after cooldown)
    function updateFeeRates(uint16 managementRateBps, uint16 performanceRateBps) external requiresAuth {
        // Schedule new rates (subject to cooldown in FeeManager).
        _updateRates(Rates({ managementRate: managementRateBps, performanceRate: performanceRateBps }));
        _syncLastPricePerShare();
    }

    /// @notice Set the manager fee receiver
    function setFeeReceiver(address feeReceiver) external requiresAuth {
        // Set manager fee receiver.
        _setFeeReceiver(feeReceiver);
    }

    /// @notice Set the fee registry used for protocol fee rate lookup
    function setFeeRegistry(address newRegistry) external requiresAuth {
        // Update registry for protocol fee policy.
        _setFeeRegistry(newRegistry);
    }

    /// @notice Check if NAV is fresh (updated within threshold)
    /// @dev Reverts if navFreshnessThreshold > 0 and NAV is stale
    function _requireFreshNav() internal view {
        // Enforce freshness only when threshold is enabled (>0).
        if (navFreshnessThreshold > 0 && block.timestamp > lastTimestampUpdated + navFreshnessThreshold) {
            revert Errors.StaleNav();
        }
    }

    // ========================================= REDEMPTION INTEGRATION =========================================

    /// @inheritdoc IElitraVault
    function requestRedeem(uint256 shares, address owner) public whenNotPaused nonReentrant returns (uint256) {
        // Validate inputs and ownership.
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        // Accrue management/performance fees before computing redemption value.
        _takeFeesAndSyncPPS();

        // Gross assets before any exit fee.
        uint256 grossAssets = super.previewRedeem(shares);

        // Ask the strategy/hook to choose redemption mode.
        (RedemptionMode mode, uint256 actualGrossAssets) =
            redemptionHook.beforeRedeem(this, shares, grossAssets, owner);

        if (mode == RedemptionMode.INSTANT) {
            // Instant redemptions require fresh NAV.
            _requireFreshNav();
            // _withdraw internally deducts withdrawFee from actualGrossAssets
            // and sends the net amount to the owner. Fee fires exactly once.
            _withdraw(owner, owner, owner, actualGrossAssets, shares);
            (, uint256 withdrawFee, , ) = _feeConfig();
            uint256 assetsToUser = actualGrossAssets - _feeOnTotal(actualGrossAssets, withdrawFee);
            emit RedeemRequest(owner, assetsToUser, shares, true);
            return assetsToUser;
        } else if (mode == RedemptionMode.QUEUED) {
            // Queue the redemption: burn shares now, transfer assets later.
            _requireFreshNav();
            _burn(owner, shares);
            
            // Track reserved assets to exclude from NAV.
            totalPendingAssets += actualGrossAssets;

            PendingRedeem storage pending = _pendingRedeem[owner];
            pending.assets += actualGrossAssets;

            emit RedeemRequest(owner, actualGrossAssets, shares, false);
            return REQUEST_ID;
        } else {
            revert Errors.InvalidRedemptionMode();
        }
    }

    /// @inheritdoc IElitraVault
    function fulfillRedeem(address owner, uint256 assets) external requiresAuth nonReentrant {
        // Take fees on every withdrawal (queued redemption fulfillment transfers assets out)
        // Accrue fees before transferring assets out.
        _takeFeesAndSyncPPS();

        PendingRedeem storage pending = _pendingRedeem[owner];
        // Ensure enough queued assets are available.
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.assets -= assets;
        totalPendingAssets -= assets;

        // Calculate and accumulate queued redeem fee on the fulfilled amount.
        (, , uint256 queuedFee, ) = _feeConfig();
        uint256 feeAmount = _feeOnTotal(assets, queuedFee);
        uint256 assetsAfterFee = assets - feeAmount;

        _addPendingFees(feeAmount);

        emit RequestFulfilled(owner, assets);
        
        // Shares already burned at request time; transfer assets minus fee.
        IERC20(asset()).safeTransfer(owner, assetsAfterFee);
    }

    /// @inheritdoc IElitraVault
    function cancelRedeem(address owner, uint256 assets) external requiresAuth nonReentrant {
        // Accrue fees before minting back shares.
        _takeFeesAndSyncPPS();

        PendingRedeem storage pending = _pendingRedeem[owner];
        // Ensure cancel amount is valid.
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        // Mint shares based on current price to avoid distortion.
        // Use super.previewDeposit to bypass fee; cancel should not charge fee.
        uint256 sharesToMint = super.previewDeposit(assets);

        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestCancelled(owner, assets, sharesToMint);
        _mint(owner, sharesToMint);
    }

    /// @inheritdoc IElitraVault
    function setRedemptionHook(IRedemptionHook newStrategy) external requiresAuth {
        // Strategy must be valid.
        require(address(newStrategy) != address(0), Errors.ZeroAddress());
        emit RedemptionHookUpdated(address(redemptionHook), address(newStrategy));
        redemptionHook = newStrategy;
    }

    // ========================================= FEE MANAGEMENT =========================================

    /// @inheritdoc IElitraVault
    function setDepositFee(uint256 newFee) external requiresAuth {
        // Update deposit fee (inclusive).
        uint256 oldFee = _setDepositFee(newFee);
        emit DepositFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setWithdrawFee(uint256 newFee) external requiresAuth {
        // Update withdraw fee (inclusive).
        uint256 oldFee = _setWithdrawFee(newFee);
        emit WithdrawFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setQueuedRedeemFee(uint256 newFee) external requiresAuth {
        // Update queued redeem fee (inclusive).
        uint256 oldFee = _setQueuedRedeemFee(newFee);
        emit QueuedRedeemFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setFeeRecipient(address newRecipient) external requiresAuth {
        // Update recipient for manager fee claims.
        address oldRecipient = _setFeeRecipient(newRecipient);
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /// @inheritdoc IElitraVault
    function claimFees() external requiresAuth {
        // Transfer pending manager fees in assets.
        (address recipient, uint256 fees) = _claimManagerFees();
        emit FeesClaimed(recipient, fees);
    }

    /// @notice Claim accumulated protocol fees and transfer to protocol fee recipient
    /// @dev Protocol fees are determined by the fee registry
    function claimProtocolFees() external requiresAuth {
        // Transfer pending protocol fees in assets.
        (address recipient, uint256 fees) = _claimProtocolFees();
        emit FeesClaimed(recipient, fees);
    }

    /// @inheritdoc IElitraVault
    function getAvailableBalance() public view returns (uint256) {
        // Available = idle assets minus queued redemptions and pending fees.
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        uint256 reserved = totalPendingAssets + pendingFees();
        return balance > reserved ? balance - reserved : 0;
    }

    /// @inheritdoc IElitraVault
    function pendingRedeemRequest(address user) public view returns (uint256 assets) {
        return _pendingRedeem[user].assets;
    }

    /// @notice Batch management is disabled - use manageBatchWithDelta instead
    /// @dev This function always reverts to prevent accidental use of the base manageBatch function
    function manageBatch(Call[] calldata) public payable override(VaultBase, IVaultBase) {
        // Disallow base batch to ensure externalDelta is always provided.
        revert Errors.UseManageBatchWithDelta();
    }

    /// @notice Execute batch operations and update balance with explicit external delta
    /// @param calls Array of calls to execute
    /// @param externalDelta Explicit balance delta to apply (can be positive or negative)
    /// @dev This function executes the batch calls and then updates the aggregated balance with the provided delta
    function manageBatchWithDelta(
        Call[] calldata calls,
        int256 externalDelta
    )
        public
        payable
        requiresAuth
        nonReentrant
    {
        // Preserve one-update-per-block invariant for operator-driven balance syncs too.
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        // Execute batch operations first (may change external balances).
        super.manageBatch(calls);

        // Apply explicit external balance delta (positive or negative).
        uint256 newAggregatedUnderlyingBalances;
        if (externalDelta >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            newAggregatedUnderlyingBalances = aggregatedUnderlyingBalances + uint256(externalDelta);
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            uint256 absDelta = uint256(-externalDelta);
            require(absDelta <= aggregatedUnderlyingBalances, "External delta exceeds balances");
            newAggregatedUnderlyingBalances = aggregatedUnderlyingBalances - absDelta;
        }

        // Recompute PPS and apply hook checks.
        _updateBalance(newAggregatedUnderlyingBalances);

        // Operator syncs refresh block/timestamp guards exactly like oracle syncs.
        lastBlockUpdated = block.number;
        lastTimestampUpdated = block.timestamp;
    }

    // ========================================= ERC4626 OVERRIDES =========================================

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        // ERC4626 totalAssets excludes pending fees and queued redemptions.
        return _netTotalAssets(aggregatedUnderlyingBalances);
    }

    /// @notice Get the net total assets (excluding pending assets and fees)
    /// @return Net total assets available in the vault
    function netTotalAssets() external view returns (uint256) {
        // Expose net assets for off-chain visibility.
        return _netTotalAssets(aggregatedUnderlyingBalances);
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        // Disallow stale NAV and accrue fees before minting shares.
        _requireFreshNav();
        _takeFeesAndSyncPPS();
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        // Disallow stale NAV and accrue fees before minting shares.
        _requireFreshNav();
        _takeFeesAndSyncPPS();
        return super.mint(shares, receiver);
    }

    /// @dev Accrue fees and then sync the cached PPS used by oracle threshold checks.
    function _takeFeesAndSyncPPS() internal {
        _takeFees();
        _syncLastPricePerShare();
    }

    /// @dev Keep `lastPricePerShare` aligned with current supply/assets after non-oracle state changes.
    function _syncLastPricePerShare() internal {
        lastPricePerShare = _calculatePPS(totalSupply(), totalAssets());
    }

    function _calculatePPS(uint256 supply, uint256 assets) internal pure returns (uint256) {
        if (supply == 0) return 1e18;
        return Math.mulDiv(assets, 1e18, supply, Math.Rounding.Down);
    }

    /// @notice Withdraw is disabled - use requestRedeem instead
    /// @dev Cannot be view: must match IERC4626Upgradeable interface signature
    /// @custom:warning 2018 - Function intentionally not view to match interface
    function withdraw(
        uint256,
        address,
        address
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        whenNotPaused
        returns (uint256)
    {
        // Redirect users to the queued/instant redeem flow.
        revert Errors.UseRequestRedeem();
    }

    /// @notice Redeem shares by calling requestRedeem
    /// @param shares Amount of shares to redeem
    /// @param owner Address that owns the shares
    /// @return Assets amount redeemed (or REQUEST_ID if queued)
    /// @dev ERC4626 compatibility wrapper. Receiver arg is ignored; assets always go to owner.
    function redeem(
        uint256 shares,
        address, /* receiver — ignored, assets always go to owner */
        address owner
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // Ignore receiver; always redeem to owner to prevent miscredit.
        return requestRedeem(shares, owner);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        // Respect pause guard for transfers as well.
        super._beforeTokenTransfer(from, to, amount);
    }

    function maxDeposit(address receiver)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // When paused, disable deposits.
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        // When paused, disable mints.
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // When paused, disable withdrawals (even though withdraw is disabled).
        if (paused()) return 0;
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        // When paused, disable redemptions.
        if (paused()) return 0;
        return super.maxRedeem(owner);
    }

    /// @dev Preview taking an entry fee on deposit. See {IERC4626-previewDeposit}.
    function previewDeposit(uint256 assets)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // Entry fee is inclusive; compute fee and reduce assets accordingly.
        (uint256 depositFee, , , ) = _feeConfig();
        uint256 fee = _feeOnTotal(assets, depositFee);
        return super.previewDeposit(assets - fee);
    }

    /// @dev Preview adding an entry fee on mint. See {IERC4626-previewMint}.
    function previewMint(uint256 shares)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // Preview assets needed for shares, then add entry fee (exclusive).
        uint256 assets = super.previewMint(shares);
        (uint256 depositFee, , , ) = _feeConfig();
        return assets + _feeOnRaw(assets, depositFee);
    }

    /// @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // Exit fee is exclusive for previewWithdraw.
        (, uint256 withdrawFee, , ) = _feeConfig();
        uint256 fee = _feeOnRaw(assets, withdrawFee);
        return super.previewWithdraw(assets + fee);
    }

    /// @dev Preview taking an exit fee on redeem. See {IERC4626-previewRedeem}.
    function previewRedeem(uint256 shares)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        // Exit fee is inclusive for previewRedeem.
        uint256 assets = super.previewRedeem(shares);
        (, uint256 withdrawFee, , ) = _feeConfig();
        return assets - _feeOnTotal(assets, withdrawFee);
    }

    /// @inheritdoc IVaultBase
    function pause() public override(VaultBase, IVaultBase) requiresAuth {
        // Admin pause (disables deposits/redemptions).
        _pause();
    }

    /// @inheritdoc IVaultBase
    function unpause() public override(VaultBase, IVaultBase) requiresAuth {
        // Admin unpause.
        _unpause();
    }

    // ========================================= FEE INTERNAL FUNCTIONS =========================================

    /// @dev Override to handle fee on deposit
    /// @notice Fee is accumulated in pendingFees and excluded from totalAssets
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // Compute inclusive deposit fee.
        (uint256 depositFee, , , ) = _feeConfig();
        uint256 feeAmount = _feeOnTotal(assets, depositFee);

        // Deposit full assets to keep ERC4626 accounting consistent.
        super._deposit(caller, receiver, assets, shares);

        // Accumulate fee (excluded from totalAssets via pendingFees).
        _addPendingFees(feeAmount);
    }

    /// @dev Override to handle fee on withdraw (instant redemptions only)
    /// @notice Fee is accumulated in pendingFees
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        // Compute inclusive exit fee.
        (, uint256 withdrawFee, , ) = _feeConfig();
        uint256 feeAmount = _feeOnTotal(assets, withdrawFee);
        uint256 assetsAfterFee = assets - feeAmount;

        // Withdraw net assets to receiver.
        super._withdraw(caller, receiver, owner, assetsAfterFee, shares);

        // Accumulate fee (excluded from totalAssets via pendingFees).
        _addPendingFees(feeAmount);
    }

}
