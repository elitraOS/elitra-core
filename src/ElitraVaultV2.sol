// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IElitraVaultV2 } from "./interfaces/IElitraVaultV2.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";
import { IRedemptionStrategy, RedemptionMode } from "./interfaces/IRedemptionStrategy.sol";

import { Compatible } from "./base/Compatible.sol";
import { AuthUpgradeable, Authority } from "./base/AuthUpgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title ElitraVaultV2 - Vault with pluggable oracle and redemption adapters
/// @notice ERC-4626 vault that delegates validation logic to adapters
contract ElitraVaultV2 is ERC4626Upgradeable, Compatible, IElitraVaultV2, AuthUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    /// @dev The denominator used for precision calculations
    uint256 internal constant DENOMINATOR = 1e18;
    /// @dev Redemption request ID (always 0 for non-fungible requests)
    uint256 internal constant REQUEST_ID = 0;

    // Oracle state
    IOracleAdapter public oracleAdapter;
    uint256 public aggregatedUnderlyingBalances;
    uint256 public lastBlockUpdated;
    uint256 public lastPricePerShare;

    // Redemption state
    IRedemptionStrategy public redemptionStrategy;
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
        IOracleAdapter _oracleAdapter,
        IRedemptionStrategy _redemptionStrategy,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __Context_init();
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();

        require(address(_oracleAdapter) != address(0), Errors.ZeroAddress());
        require(address(_redemptionStrategy) != address(0), Errors.ZeroAddress());

        oracleAdapter = _oracleAdapter;
        redemptionStrategy = _redemptionStrategy;
    }

    // ========================================= ORACLE INTEGRATION =========================================

    /// @inheritdoc IElitraVaultV2
    function setAggregatedBalance(uint256 newBalance, uint256 newPPS) external {
        require(msg.sender == address(oracleAdapter), Errors.OnlyOracleAdapter());

        emit UnderlyingBalanceUpdated(aggregatedUnderlyingBalances, newBalance);

        aggregatedUnderlyingBalances = newBalance;
        lastPricePerShare = newPPS;
        lastBlockUpdated = block.number;
    }

    /// @inheritdoc IElitraVaultV2
    function setOracleAdapter(IOracleAdapter newAdapter) external requiresAuth {
        require(address(newAdapter) != address(0), Errors.ZeroAddress());
        emit OracleAdapterUpdated(address(oracleAdapter), address(newAdapter));
        oracleAdapter = newAdapter;
    }

    // ========================================= REDEMPTION INTEGRATION =========================================

    /// @inheritdoc IElitraVaultV2
    function requestRedeem(uint256 shares, address receiver, address owner)
        public
        whenNotPaused
        returns (uint256)
    {
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        uint256 assets = previewRedeem(shares);

        // Ask strategy how to handle this redemption
        (RedemptionMode mode, uint256 actualAssets) = redemptionStrategy.processRedemption(
            this, shares, assets, owner, receiver
        );

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

    /// @inheritdoc IElitraVaultV2
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

    /// @inheritdoc IElitraVaultV2
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

    /// @inheritdoc IElitraVaultV2
    function setRedemptionStrategy(IRedemptionStrategy newStrategy) external requiresAuth {
        require(address(newStrategy) != address(0), Errors.ZeroAddress());
        emit RedemptionStrategyUpdated(address(redemptionStrategy), address(newStrategy));
        redemptionStrategy = newStrategy;
    }

    /// @inheritdoc IElitraVaultV2
    function getAvailableBalance() public view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }

    /// @inheritdoc IElitraVaultV2
    function pendingRedeemRequest(address user) public view returns (uint256 assets, uint256 pendingShares) {
        return (_pendingRedeem[user].assets, _pendingRedeem[user].shares);
    }

    // ========================================= STRATEGY MANAGEMENT =========================================

    /// @inheritdoc IElitraVaultV2
    function manage(address target, bytes calldata data, uint256 value)
        external
        requiresAuth
        returns (bytes memory result)
    {
        bytes4 functionSig = bytes4(data);
        require(
            authority().canCall(msg.sender, target, functionSig),
            Errors.TargetMethodNotAuthorized(target, functionSig)
        );

        result = target.functionCallWithValue(data, value);
    }

    // ========================================= ERC4626 OVERRIDES =========================================

    function totalAssets() public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + aggregatedUnderlyingBalances;
    }

    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256, address, address)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        revert Errors.UseRequestRedeem();
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        return requestRedeem(shares, receiver, owner);
    }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    function maxDeposit(address receiver) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (paused()) return 0;
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (paused()) return 0;
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (paused()) return 0;
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        if (paused()) return 0;
        return super.maxRedeem(owner);
    }

    // ========================================= EMERGENCY CONTROLS =========================================

    /// @inheritdoc IElitraVaultV2
    function pause() public requiresAuth {
        _pause();
    }

    /// @inheritdoc IElitraVaultV2
    function unpause() public requiresAuth {
        _unpause();
    }
}
