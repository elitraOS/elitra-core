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

    // Oracle state
    IBalanceUpdateHook public balanceUpdateHook;
    uint256 public aggregatedUnderlyingBalances;
    uint256 public lastBlockUpdated;
    uint256 public lastPricePerShare;

    // Redemption state
    IRedemptionHook public redemptionHook;
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;
    uint256 public totalPendingAssets;

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
        lastBlockUpdated = block.number;

        emit PPSUpdated(block.timestamp, lastPricePerShare, newPPS);
    }

    function updateBalance(uint256 newAggregatedBalance) external requiresAuth {
        _updateBalance(newAggregatedBalance);
    }

    /// @inheritdoc IElitraVault
    function setBalanceUpdateHook(IBalanceUpdateHook newAdapter) external requiresAuth {
        require(address(newAdapter) != address(0), Errors.ZeroAddress());
        emit BalanceUpdateHookUpdated(address(balanceUpdateHook), address(newAdapter));
        balanceUpdateHook = newAdapter;
    }

    // ========================================= REDEMPTION INTEGRATION =========================================

    /// @inheritdoc IElitraVault
    function requestRedeem(uint256 shares, address receiver, address owner) public whenNotPaused returns (uint256) {
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        uint256 assets = previewRedeem(shares);

        // Ask strategy how to handle this redemption
        (RedemptionMode mode, uint256 actualAssets) = redemptionHook.beforeRedeem(this, shares, assets, owner, receiver);

        if (mode == RedemptionMode.INSTANT) {
            _withdraw(owner, receiver, owner, actualAssets, shares);
            emit RedeemRequest(receiver, owner, actualAssets, shares, true);
            return actualAssets;
        } else if (mode == RedemptionMode.QUEUED) {
            // Queue the redemption
            _transfer(owner, address(this), shares);
            totalPendingAssets += actualAssets;

            PendingRedeem storage pending = _pendingRedeem[receiver];
            pending.shares += shares;
            pending.assets += actualAssets;

            emit RedeemRequest(receiver, owner, actualAssets, shares, false);
            return REQUEST_ID;
        } else {
            revert Errors.InvalidRedemptionMode();
        }
    }

    /// @inheritdoc IElitraVault
    function fulfillRedeem(address receiver, uint256 shares, uint256 assets) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestFulfilled(receiver, shares, assets);
        _withdraw(address(this), receiver, address(this), assets, shares);
    }

    /// @inheritdoc IElitraVault
    function cancelRedeem(address receiver, uint256 shares, uint256 assets) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestCancelled(receiver, shares, assets);
        _transfer(address(this), receiver, shares);
    }

    /// @inheritdoc IElitraVault
    function setRedemptionHook(IRedemptionHook newStrategy) external requiresAuth {
        require(address(newStrategy) != address(0), Errors.ZeroAddress());
        emit RedemptionHookUpdated(address(redemptionHook), address(newStrategy));
        redemptionHook = newStrategy;
    }

    /// @inheritdoc IElitraVault
    function getAvailableBalance() public view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }

    /// @inheritdoc IElitraVault
    function pendingRedeemRequest(address user) public view returns (uint256 assets, uint256 pendingShares) {
        return (_pendingRedeem[user].assets, _pendingRedeem[user].shares);
    }

    function manageBatch(Call[] calldata calls) public payable override(VaultBase, IVaultBase) requiresAuth {
        // Get asset balance before execution
        uint256 beforeBalance = IERC20(asset()).balanceOf(address(this));

        // Execute batch operations
        super.manageBatch(calls);

        // Update aggregated balance based on vault asset balance change
        uint256 afterBalance = IERC20(asset()).balanceOf(address(this));
        if (afterBalance != beforeBalance) {
            uint256 balanceChange =
                afterBalance > beforeBalance ? afterBalance - beforeBalance : beforeBalance - afterBalance;

            uint256 newAggregatedUnderlyingBalances = afterBalance > beforeBalance
                ? aggregatedUnderlyingBalances - balanceChange  // funds came In, -> extenal balances when down
                : aggregatedUnderlyingBalances + balanceChange; // funds went out, -> extenal balances when up

            _updateBalance(newAggregatedUnderlyingBalances);
        }
    }

    // ========================================= ERC4626 OVERRIDES =========================================

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626Upgradeable) returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + aggregatedUnderlyingBalances;
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
        whenNotPaused
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

    /// @inheritdoc IVaultBase
    function pause() public override(VaultBase, IVaultBase) requiresAuth {
        _pause();
    }

    /// @inheritdoc IVaultBase
    function unpause() public override(VaultBase, IVaultBase) requiresAuth {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override requiresAuth {}
}
