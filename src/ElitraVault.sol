// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IElitraVault, Call } from "./interfaces/IElitraVault.sol";
import { IVaultBase } from "./interfaces/IVaultBase.sol";
import { ITransactionGuard } from "./interfaces/ITransactionGuard.sol";
import { IBalanceUpdateHook } from "./interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook, RedemptionMode } from "./interfaces/IRedemptionHook.sol";

import { VaultBase } from "./vault/VaultBase.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";

/// @title ElitraVault - Vault with pluggable oracle and redemption adapters
/// @notice ERC-4626 vault that delegates validation logic to adapters
contract ElitraVault is ERC4626Upgradeable, VaultBase, IElitraVault {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev The denominator used for precision calculations
    uint256 internal constant DENOMINATOR = 1e18;
    /// @dev Redemption request ID (always 0 for non-fungible requests)
    uint256 internal constant REQUEST_ID = 0;
    /// @dev The maximum fee that can be set for the vault operations. 1e16 = 1%
    uint256 internal constant MAX_FEE = 1e16;

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

    // Fee state
    uint256 public feeOnDeposit;
    uint256 public feeOnWithdraw; // only apply on instant withdrawals
    address public feeRecipient;
    uint256 public pendingFees; // Accumulated fees waiting to be claimed

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault with adapters
    function initialize(
        IERC20 _asset,
        address _owner,
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
        __VaultBase_init(_owner);

        require(address(_balanceUpdateHook) != address(0), Errors.ZeroAddress());
        require(address(_redemptionHook) != address(0), Errors.ZeroAddress());

        balanceUpdateHook = _balanceUpdateHook;
        redemptionHook = _redemptionHook;
    }

    // ========================================= ORACLE INTEGRATION =========================================

    /// @notice Internal function to update vault balance and price per share
    /// @param newAggregatedBalance The new aggregated balance from external protocols
    function _updateBalance(uint256 newAggregatedBalance) internal {
        // 1. Validate not already updated this block
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        // 2. Pull validation from balance update hook (read-only)
        (bool shouldContinue, uint256 newPPS) = balanceUpdateHook.beforeBalanceUpdate(
            lastPricePerShare, totalSupply(), IERC20(asset()).balanceOf(address(this)), newAggregatedBalance
        );

        // 3. Check if should pause
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
        _updateBalance(newAggregatedBalance);
        lastBlockUpdated = block.number;  // Only external syncs reset NAV freshness
        lastTimestampUpdated = block.timestamp;
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
            _burn(owner, shares);
            totalPendingAssets += actualAssets;

            PendingRedeem storage pending = _pendingRedeem[receiver];
            pending.assets += actualAssets;

            emit RedeemRequest(receiver, owner, actualAssets, shares, false);
            return REQUEST_ID;
        } else {
            revert Errors.InvalidRedemptionMode();
        }
    }

    /// @inheritdoc IElitraVault
    function fulfillRedeem(address receiver, uint256 assets) external requiresAuth {
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
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.assets -= assets;
        totalPendingAssets -= assets;

        // Mint shares based on current price to avoid price distortion
        uint256 sharesToMint = previewDeposit(assets);

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
        require(newFee <= MAX_FEE, Errors.InvalidFee());
        emit DepositFeeUpdated(feeOnDeposit, newFee);
        feeOnDeposit = newFee;
    }

    /// @inheritdoc IElitraVault
    function setWithdrawFee(uint256 newFee) external requiresAuth {
        require(newFee <= MAX_FEE, Errors.InvalidFee());
        emit WithdrawFeeUpdated(feeOnWithdraw, newFee);
        feeOnWithdraw = newFee;
    }

    /// @inheritdoc IElitraVault
    function setFeeRecipient(address newRecipient) external requiresAuth {
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    /// @inheritdoc IElitraVault
    function claimFees() external requiresAuth {
        uint256 fees = pendingFees;
        require(fees > 0, Errors.InvalidAssetsAmount());
        
        address recipient = feeRecipient;
        require(recipient != address(0), Errors.ZeroAddress());
        
        pendingFees = 0;
        
        emit FeesClaimed(recipient, fees);
        IERC20(asset()).safeTransfer(recipient, fees);
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
        // Get asset balance before execution
        uint256 beforeBalance = IERC20(asset()).balanceOf(address(this));

        // Execute batch operations
        super.manageBatch(calls);

        // Update aggregated balance based on vault asset balance change
        uint256 afterBalance = IERC20(asset()).balanceOf(address(this));
        if (afterBalance != beforeBalance) {
            uint256 balanceChange =
                afterBalance > beforeBalance ? afterBalance - beforeBalance : beforeBalance - afterBalance;

            // Prevent underflow when funds come in
            if (afterBalance > beforeBalance) {
                require(balanceChange <= aggregatedUnderlyingBalances, "Balance change exceeds external balances");
            }

            uint256 newAggregatedUnderlyingBalances = afterBalance > beforeBalance
                ? aggregatedUnderlyingBalances - balanceChange  // funds came In, -> extenal balances when down
                : aggregatedUnderlyingBalances + balanceChange; // funds went out, -> extenal balances when up

            _updateBalance(newAggregatedUnderlyingBalances);
        }
    }

    // ========================================= ERC4626 OVERRIDES =========================================

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        uint256 vaultBalance = IERC20(asset()).balanceOf(address(this));
        uint256 total = vaultBalance + aggregatedUnderlyingBalances;
        // Exclude both:
        // 1. totalPendingAssets - assets reserved for queued redemptions (belong to redeemers)
        // 2. pendingFees - accumulated fees (belong to fee recipient)
        uint256 excluded = totalPendingAssets + pendingFees;
        return total > excluded ? total - excluded : 0;
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
        uint256 fee = _feeOnTotal(assets, feeOnDeposit);
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
        return assets + _feeOnRaw(assets, feeOnDeposit);
    }

    /// @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
    function previewWithdraw(uint256 assets)
        public
        view
        override(ERC4626Upgradeable, IERC4626Upgradeable)
        returns (uint256)
    {
        uint256 fee = _feeOnRaw(assets, feeOnWithdraw);
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
        return assets - _feeOnTotal(assets, feeOnWithdraw);
    }

    /// @inheritdoc IVaultBase
    function pause() public override(VaultBase, IVaultBase) requiresAuth {
        _pause();
    }

    /// @inheritdoc IVaultBase
    function unpause() public override(VaultBase, IVaultBase) requiresAuth {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override requiresAuth {}

    // ========================================= FEE INTERNAL FUNCTIONS =========================================

    /// @dev Override to handle fee on deposit
    /// @notice Fee is accumulated in pendingFees and excluded from totalAssets
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        uint256 feeAmount = _feeOnTotal(assets, feeOnDeposit);
        
        super._deposit(caller, receiver, assets, shares);

        // Accumulate fee (will be excluded from totalAssets via pendingFees)
        if (feeAmount > 0) {
            pendingFees += feeAmount;
        }
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
        uint256 feeAmount = _feeOnTotal(assets, feeOnWithdraw);
        uint256 assetsAfterFee = assets - feeAmount;
        
        super._withdraw(caller, receiver, owner, assetsAfterFee, shares);
        
        // Accumulate fee (will be excluded from totalAssets via pendingFees)
        if (feeAmount > 0) {
            pendingFees += feeAmount;
        }
    }

    /// @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
    /// Used in {IERC4626-mint} and {IERC4626-withdraw} operations.
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, DENOMINATOR, Math.Rounding.Up);
    }

    /// @dev Calculates the fee part of an amount `assets` that already includes fees.
    /// Used in {IERC4626-deposit} and {IERC4626-redeem} operations.
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) internal pure returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + DENOMINATOR, Math.Rounding.Up);
    }
}
