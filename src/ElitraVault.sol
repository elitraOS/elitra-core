// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IElitraVault, Call } from "./interfaces/IElitraVault.sol";
import { IVaultBase } from "./interfaces/IVaultBase.sol";
import { ITransactionGuard } from "./interfaces/ITransactionGuard.sol";
import { IBalanceUpdateHook } from "./interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook, RedemptionMode } from "./interfaces/IRedemptionHook.sol";

import { VaultBase } from "./vault/VaultBase.sol";
import { FeeManager } from "./fees/FeeManager.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";

/// @title ElitraVault - Vault with pluggable oracle and redemption adapters
/// @notice ERC-4626 vault that delegates validation logic to adapters
contract ElitraVault is ERC4626Upgradeable, VaultBase, FeeManager, IElitraVault {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev Redemption request ID (always 0 for non-fungible requests)
    uint256 internal constant REQUEST_ID = 0;

    // Oracle state
    IBalanceUpdateHook public balanceUpdateHook;
    uint256 public aggregatedUnderlyingBalances;
    uint256 public lastBlockUpdated;
    uint256 public lastPricePerShare;

    // NAV freshness state
    uint256 public navFreshnessThreshold; // Maximum allowed time (in seconds) since last NAV update
    uint256 public lastTimestampUpdated;  // Timestamp of last NAV update

    // Redemption state
    IRedemptionHook public redemptionHook;
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;
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
        __Context_init();
        __ERC20_init(_name, _symbol);
        __ERC4626_init(IERC20Upgradeable(address(_asset)));
        __VaultBase_init(_owner, _upgradeAdmin);

        // FeeManager (Lagoon-inspired): initialize with safe defaults (0 fees) and receivers set to owner.
        __FeeManager_init(_owner, _feeRegistry, 0, 0, 0);

        require(address(_balanceUpdateHook) != address(0), Errors.ZeroAddress());
        require(address(_redemptionHook) != address(0), Errors.ZeroAddress());

        balanceUpdateHook = _balanceUpdateHook;
        redemptionHook = _redemptionHook;
    }

    // ========================================= ORACLE INTEGRATION =========================================

    /// @notice Internal function to update vault balance and price per share
    /// @param newAggregatedBalance The new aggregated balance from external protocols
    function _updateBalance(uint256 newAggregatedBalance) internal {
        // 1. Pull validation from balance update hook (read-only)
        (bool shouldContinue, uint256 newPPS) = balanceUpdateHook.beforeBalanceUpdate(
            lastPricePerShare, totalSupply(), _netTotalAssets(newAggregatedBalance)
        );

        // 2. Check if should pause
        if (!shouldContinue) {
            _pause();
            emit VaultPausedDueToThreshold(block.timestamp, lastPricePerShare, newPPS);
            return;
        }

        // Emit the changes
        emit UnderlyingBalanceUpdated(block.timestamp, aggregatedUnderlyingBalances, newAggregatedBalance);

        // Update own state
        aggregatedUnderlyingBalances = newAggregatedBalance;
        lastPricePerShare = newPPS;

        emit PPSUpdated(block.timestamp, lastPricePerShare, newPPS);
    }

    function updateBalance(uint256 newAggregatedBalance) external requiresAuth {
        // Validate not already updated this block
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        _updateBalance(newAggregatedBalance);

        // Update last block updated and timestamp updated
        lastBlockUpdated = block.number;  // Only external syncs reset NAV freshness
        lastTimestampUpdated = block.timestamp;
    }

    function _netTotalAssets(uint256 newAggregatedBalance) internal view returns (uint256) {
        uint256 idleAssets = IERC20(asset()).balanceOf(address(this));
        uint256 totalAssetsAfter = idleAssets + newAggregatedBalance;
        uint256 excluded = totalPendingAssets + pendingFees();
        return totalAssetsAfter > excluded ? totalAssetsAfter - excluded : 0;
    }

    /// @inheritdoc IElitraVault
    function setBalanceUpdateHook(IBalanceUpdateHook newAdapter) external requiresAuth {
        require(address(newAdapter) != address(0), Errors.ZeroAddress());
        emit BalanceUpdateHookUpdated(address(balanceUpdateHook), address(newAdapter));
        balanceUpdateHook = newAdapter;
    }

    /// @notice Set the NAV freshness threshold
    /// @param newThreshold Maximum allowed time (in seconds) since last NAV update. Set to 0 to disable check.
    function setNavFreshnessThreshold(uint256 newThreshold) external requiresAuth {
        emit NavFreshnessThresholdUpdated(navFreshnessThreshold, newThreshold);
        navFreshnessThreshold = newThreshold;
    }

    // ========================================= FEES (Lagoon-inspired) =========================================

    /// @notice Take management/performance fees by minting shares to fee receivers.
    /// @dev Manual hook for now (does not auto-accrue on deposit/withdraw/updateBalance).
    function takeFees() external requiresAuth {
        _takeFees();
    }

    /// @notice Update fee rates (applied after cooldown)
    function updateFeeRates(uint16 managementRateBps, uint16 performanceRateBps) external requiresAuth {
        _updateRates(Rates({ managementRate: managementRateBps, performanceRate: performanceRateBps }));
    }

    /// @notice Set the manager fee receiver
    function setFeeReceiver(address feeReceiver) external requiresAuth {
        _setFeeReceiver(feeReceiver);
    }

    /// @notice Set the fee registry used for protocol fee rate lookup
    function setFeeRegistry(address newRegistry) external requiresAuth {
        _setFeeRegistry(newRegistry);
    }

    /// @notice Check if NAV is fresh (updated within threshold)
    /// @dev Reverts if navFreshnessThreshold > 0 and NAV is stale
    function _requireFreshNav() internal view {
        if (navFreshnessThreshold > 0 && block.timestamp > lastTimestampUpdated + navFreshnessThreshold) {
            revert Errors.StaleNav();
        }
    }

    // ========================================= REDEMPTION INTEGRATION =========================================

    /// @inheritdoc IElitraVault
    function requestRedeem(uint256 shares, address receiver, address owner) public whenNotPaused returns (uint256) {
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(receiver != address(0), Errors.ZeroAddress());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());
        
        _takeFees();  // Take fees before redeeming

        uint256 assets = previewRedeem(shares);

        // Ask strategy how to handle this redemption
        (RedemptionMode mode, uint256 actualAssets) = redemptionHook.beforeRedeem(this, shares, assets, owner, receiver);

        if (mode == RedemptionMode.INSTANT) {
            _requireFreshNav(); // Instant redemptions require fresh NAV
            _withdraw(owner, receiver, owner, actualAssets, shares);
            emit RedeemRequest(receiver, owner, actualAssets, shares, true);
            return actualAssets;
        } else if (mode == RedemptionMode.QUEUED) {
            // Queue the redemption: burn shares and virtually remove assets from totalAssets
            _requireFreshNav();
            _burn(owner, shares);
            
            // Calculate and accumulate queued redeem fee
            (, , uint256 queuedFee, ) = _feeConfig();
            uint256 feeAmount = _feeOnTotal(actualAssets, queuedFee);
            uint256 assetsAfterFee = actualAssets - feeAmount;
            _addPendingFees(feeAmount);
            
            totalPendingAssets += assetsAfterFee;

            PendingRedeem storage pending = _pendingRedeem[receiver];
            pending.assets += assetsAfterFee;

            emit RedeemRequest(receiver, owner, assetsAfterFee, shares, false);
            return REQUEST_ID;
        } else {
            revert Errors.InvalidRedemptionMode();
        }
    }

    /// @inheritdoc IElitraVault
    function fulfillRedeem(address receiver, uint256 assets) external requiresAuth {
        // Take fees on every withdrawal (queued redemption fulfillment transfers assets out)
        _takeFees();

        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestFulfilled(receiver, assets);
        // Shares already burned at request time, just transfer assets
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    /// @inheritdoc IElitraVault
    function cancelRedeem(address receiver, uint256 assets) external requiresAuth {
        _takeFees(); // Take fees before canceling redeem

        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        // Mint shares based on current price to avoid price distortion
        // Use super.previewDeposit to bypass fee - cancel should not charge fee
        uint256 sharesToMint = super.previewDeposit(assets);

        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestCancelled(receiver, assets, sharesToMint);
        _mint(receiver, sharesToMint);
    }

    /// @inheritdoc IElitraVault
    function setRedemptionHook(IRedemptionHook newStrategy) external requiresAuth {
        require(address(newStrategy) != address(0), Errors.ZeroAddress());
        emit RedemptionHookUpdated(address(redemptionHook), address(newStrategy));
        redemptionHook = newStrategy;
    }

    // ========================================= FEE MANAGEMENT =========================================

    /// @inheritdoc IElitraVault
    function setDepositFee(uint256 newFee) external requiresAuth {
        uint256 oldFee = _setDepositFee(newFee);
        emit DepositFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setWithdrawFee(uint256 newFee) external requiresAuth {
        uint256 oldFee = _setWithdrawFee(newFee);
        emit WithdrawFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setQueuedRedeemFee(uint256 newFee) external requiresAuth {
        uint256 oldFee = _setQueuedRedeemFee(newFee);
        emit QueuedRedeemFeeUpdated(oldFee, newFee);
    }

    /// @inheritdoc IElitraVault
    function setFeeRecipient(address newRecipient) external requiresAuth {
        address oldRecipient = _setFeeRecipient(newRecipient);
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /// @inheritdoc IElitraVault
    function claimFees() external requiresAuth {
        (address recipient, uint256 fees) = _claimManagerFees();
        emit FeesClaimed(recipient, fees);
    }

    function claimProtocolFees() external requiresAuth {
        (address recipient, uint256 fees) = _claimProtocolFees();
        emit FeesClaimed(recipient, fees);
    }

    /// @inheritdoc IElitraVault
    function getAvailableBalance() public view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }

    /// @inheritdoc IElitraVault
    function pendingRedeemRequest(address user) public view returns (uint256 assets) {
        return _pendingRedeem[user].assets;
    }

    function manageBatch(Call[] calldata calls) public payable override(VaultBase, IVaultBase) {
        revert Errors.UseManageBatchWithDelta();
    }

    function manageBatchWithDelta(
        Call[] calldata calls,
        int256 externalDelta
    )
        public
        payable
        requiresAuth
    {
        // Execute batch operations
        super.manageBatch(calls);

        // Apply explicit external balance delta
        uint256 newAggregatedUnderlyingBalances;
        if (externalDelta >= 0) {
            newAggregatedUnderlyingBalances = aggregatedUnderlyingBalances + uint256(externalDelta);
        } else {
            uint256 absDelta = uint256(-externalDelta);
            require(absDelta <= aggregatedUnderlyingBalances, "External delta exceeds balances");
            newAggregatedUnderlyingBalances = aggregatedUnderlyingBalances - absDelta;
        }

        _updateBalance(newAggregatedUnderlyingBalances);
    }

    // ========================================= ERC4626 OVERRIDES =========================================

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        return _netTotalAssets(aggregatedUnderlyingBalances);
    }

    function netTotalAssets() external view returns (uint256) {
        return _netTotalAssets(aggregatedUnderlyingBalances);
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        whenNotPaused
        returns (uint256)
    {
        _requireFreshNav();
        _takeFees();
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        whenNotPaused
        returns (uint256)
    {
        _requireFreshNav();
        _takeFees();
        return super.mint(shares, receiver);
    }

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
        revert Errors.UseRequestRedeem();
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        return requestRedeem(shares, receiver, owner);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function maxDeposit(address receiver)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        if (paused()) return 0;
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
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
        uint256 assets = super.previewRedeem(shares);
        (, uint256 withdrawFee, , ) = _feeConfig();
        return assets - _feeOnTotal(assets, withdrawFee);
    }

    /// @inheritdoc IVaultBase
    function pause() public override(VaultBase, IVaultBase) requiresAuth {
        _pause();
    }

    /// @inheritdoc IVaultBase
    function unpause() public override(VaultBase, IVaultBase) requiresAuth {
        _unpause();
    }

    // ========================================= FEE INTERNAL FUNCTIONS =========================================

    /// @dev Override to handle fee on deposit
    /// @notice Fee is accumulated in pendingFees and excluded from totalAssets
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        (uint256 depositFee, , , ) = _feeConfig();
        uint256 feeAmount = _feeOnTotal(assets, depositFee);
        
        super._deposit(caller, receiver, assets, shares);

        // Accumulate fee (will be excluded from totalAssets via pendingFees)
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
        // Take management/performance fees before charging exit fee (globalized)
        (, uint256 withdrawFee, , ) = _feeConfig();
        uint256 feeAmount = _feeOnTotal(assets, withdrawFee);
        uint256 assetsAfterFee = assets - feeAmount;
        
        super._withdraw(caller, receiver, owner, assetsAfterFee, shares);
        
        // Accumulate fee (will be excluded from totalAssets via pendingFees)
        _addPendingFees(feeAmount);
    }

}
