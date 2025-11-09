// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "./libraries/Errors.sol";
import { IElitraVault } from "./interfaces/IElitraVault.sol";

import { Compatible } from "./base/Compatible.sol";
import { AuthUpgradeable, Authority } from "./base/AuthUpgradeable.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";


/// @title ElitraVault - A simple vault contract that allows for an operator to manage the vault.
/// @dev This contract is based on the ERC4626 standard and uses the Auth contract for access control.
/// It provides an asynchronous redeem mechanism that allows users to request a redeem and the operator to fulfill it.
/// This would allow the operator to move funds to a different chain or strategy before the user can claim the assets.
/// If the vault has enough assets to fulfill the request, the assets are withdrawn and returned to the owner
/// immediately. Otherwise, the assets are transferred to the vault and the request is stored until the operator
/// fulfills it.

contract ElitraVault is ERC4626Upgradeable, Compatible, IElitraVault, AuthUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Address for address;

    /// @dev Assume requests are non-fungible and all have ID = 0, so we can differentiate between a request ID and the
    /// assets amount.
    uint256 internal constant REQUEST_ID = 0;
    /// @dev The denominator used for precision calculations.
    uint256 internal constant DENOMINATOR = 1e18;
    /// @dev The maximum percentage that can be set as a threshold for the percentage change. 1e17 = 10%
    uint256 internal constant MAX_PERCENTAGE_THRESHOLD = 1e17;

    /// @dev the aggregated underlying balances across all strategies/chains, reported by an oracle
    uint256 public aggregatedUnderlyingBalances;
    /// @dev the last block number when the aggregated underlying balances were updated
    uint256 public lastBlockUpdated;
    /// @dev the last price per share calculated after the aggregated underlying balances are reported
    uint256 public lastPricePerShare;
    /// @dev the total amount of assets that are pending redemption
    uint256 public totalPendingAssets;
    /// @dev the maximum percentage change allowed before the vault is paused. It can be updated by the owner.
    /// 1e18 = 100%. It's value depends on the frequency of the oracle updates.
    uint256 public maxPercentageChange;

    /// @dev used to store the amount of shares that are pending redemption, it must be fulfilled by the vault operator
    mapping(address user => PendingRedeem redeem) internal _pendingRedeem;

    //============================== CONSTRUCTOR ===============================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //============================== INITIALIZER ===============================
    function initialize(IERC20 _asset, address _owner, string memory _name, string memory _symbol) public initializer {
        __Context_init();
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();
        maxPercentageChange = 1e16; // 1%
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /// @notice Allows the vault operator to manage the vault.
    /// @param target The target contract to make a call to.
    /// @param data The data to send to the target contract.
    /// @param value The amount of native assets to send with the call.
    function manage(
        address target,
        bytes calldata data,
        uint256 value
    )
        external
        requiresAuth
        returns (bytes memory result)
    {
        bytes4 functionSig = bytes4(data);
        require(
            authority().canCall(msg.sender, target, functionSig), Errors.TargetMethodNotAuthorized(target, functionSig)
        );

        result = target.functionCallWithValue(data, value);
    }

    /// @notice Same as `manage` but allows for multiple calls in a single transaction.
    /// @param targets The target contracts to make calls to.
    /// @param data The data to send to the target contracts.
    /// @param values The amounts of native assets to send with the calls.
    function manage(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    )
        external
        requiresAuth
        returns (bytes[] memory results)
    {
        uint256 targetsLength = targets.length;
        results = new bytes[](targetsLength);
        for (uint256 i; i < targetsLength; ++i) {
            bytes4 functionSig = bytes4(data[i]);
            require(
                authority().canCall(msg.sender, targets[i], functionSig),
                Errors.TargetMethodNotAuthorized(targets[i], functionSig)
            );
            results[i] = targets[i].functionCallWithValue(data[i], values[i]);
        }
    }

    /// @notice Pause the contract to prevent any further deposits, withdrawals, or transfers.
    function pause() public requiresAuth {
        _pause();
    }

    /// @notice Unpause the contract to allow deposits, withdrawals, and transfers.
    function unpause() public requiresAuth {
        _unpause();
    }

    /// @notice If the vault has enough assets to fulfill the request,
    /// withdraw the assets and return them to the owner.
    /// Otherwise, transfer the shares to the vault and store the request.
    /// The shares are burned when the request is fulfilled and the assets are transferred to the owner.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The address of the receiver of the assets.
    /// @param owner The address of the owner.
    /// @return The ID of the request which is always 0 or the assets amount if the request is immediately
    /// processed.
    function requestRedeem(uint256 shares, address receiver, address owner) public whenNotPaused returns (uint256) {
        require(shares > 0, Errors.SharesAmountZero());
        require(owner == msg.sender, Errors.NotSharesOwner());
        require(balanceOf(owner) >= shares, Errors.InsufficientShares());

        uint256 assets = super.previewRedeem(shares);

        // instant redeem if the vault has enough assets
        if (_getAvailableBalance() >= assets) {
            _withdraw(owner, receiver, owner, assets, shares);
            emit RedeemRequest(receiver, owner, assets, shares, true);
            return assets;
        }

        emit RedeemRequest(receiver, owner, assets, shares, false);
        // transfer the shares to the vault and store the request
        _transfer(owner, address(this), shares);

        totalPendingAssets += assets;
        PendingRedeem storage pending = _pendingRedeem[receiver];
        pending.shares += shares;
        pending.assets += assets;

        return REQUEST_ID;
    }

    /// @notice The operator can fulfill a redeem request. Requires authorization.
    /// @param receiver The address of the receiver of the assets.
    /// @param shares The amount of shares to fulfil.
    /// @param assets The amount of assets to fulfil.
    function fulfillRedeem(address receiver, uint256 shares, uint256 assets) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestFulfilled(receiver, shares, assets);
        // burn the shares from the vault and transfer the assets to the receiver
        _withdraw(address(this), receiver, address(this), assets, shares);
    }

    /// @notice The operator can cancel a redeem request in case of an black swan event.
    /// @param receiver The address of the receiver of the assets.
    /// @param shares The amount of shares to cancel.
    /// @param assets The amount of assets to cancel.
    function cancelRedeem(address receiver, uint256 shares, uint256 assets) external requiresAuth {
        PendingRedeem storage pending = _pendingRedeem[receiver];
        require(pending.shares != 0 && shares <= pending.shares, Errors.InvalidSharesAmount());
        require(pending.assets != 0 && assets <= pending.assets, Errors.InvalidAssetsAmount());

        pending.shares -= shares;
        pending.assets -= assets;
        totalPendingAssets -= assets;

        emit RequestCancelled(receiver, shares, assets);
        // transfer the shares back to the owner
        _transfer(address(this), receiver, shares);
    }

    /// @notice The oracle can update the aggregated underlying balances across all strategies/chains.
    /// @dev Can be called only once per block to prevent oracle abuse and flash loan attacks.
    /// @param newAggregatedBalance The new aggregated underlying balances.
    function onUnderlyingBalanceUpdate(uint256 newAggregatedBalance) external requiresAuth {
        require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

        /// @dev the price per share is calculated taking into account the new aggregated underlying balances
        uint256 newPricePerShare = _totalAssets(newAggregatedBalance).mulDiv(DENOMINATOR, totalSupply());
        uint256 percentageChange = _calculatePercentageChange(lastPricePerShare, newPricePerShare);

        /// @dev Pause the vault if the percentage change is greater than the threshold (works in both directions)
        if (percentageChange > maxPercentageChange) {
            _pause();
            return;
        }

        emit UnderlyingBalanceUpdated(aggregatedUnderlyingBalances, newAggregatedBalance);
        aggregatedUnderlyingBalances = newAggregatedBalance;

        lastPricePerShare = newPricePerShare;
        lastBlockUpdated = block.number;
    }

    /// @notice Update the maximum percentage change allowed before the vault is paused.
    /// @param newMaxPercentageChange The new maximum percentage change. Max value is 1e17 (10%).
    function updateMaxPercentageChange(uint256 newMaxPercentageChange) external requiresAuth {
        require(newMaxPercentageChange < MAX_PERCENTAGE_THRESHOLD, Errors.InvalidMaxPercentage());
        emit MaxPercentageUpdated(maxPercentageChange, newMaxPercentageChange);
        maxPercentageChange = newMaxPercentageChange;
    }

    //============================== VIEW FUNCTIONS ===============================

    /// @notice Get the amount of assets and shares that are pending redemption.
    /// @param user The address of the user.
    function pendingRedeemRequest(address user) public view returns (uint256 assets, uint256 pendingShares) {
        return (_pendingRedeem[user].assets, _pendingRedeem[user].shares);
    }

    //============================== OVERRIDES ===============================

    /// @notice Override the default `totalAssets` function to return the total assets held by the vault and the
    /// aggregated underlying balances across all strategies/chains.
    function totalAssets() public view override returns (uint256) {
        return _totalAssets(aggregatedUnderlyingBalances);
    }

    /// @dev Override the default `deposit` function to add the `whenNotPaused` modifier.
    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /// @dev Override the default `mint` function to add the `whenNotPaused` modifier.
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    /// @notice This method is disabled. Use `requestRedeem` or `redeem`instead.
    function withdraw(uint256, address, address) public override whenNotPaused returns (uint256) {
        revert Errors.UseRequestRedeem();
    }

    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        return requestRedeem(shares, receiver, owner);
    }

    /// @dev Override the default `_update` function to add the `whenNotPaused` modifier.
    /// The _update function is called on all transfers, mints and burns.
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    function maxDeposit(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxDeposit(receiver);
    }

    function maxMint(address receiver) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxMint(receiver);
    }

    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (paused()) {
            return 0;
        }
        return super.maxRedeem(owner);
    }

    function _totalAssets(uint256 _underlyingBalances) internal view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + _underlyingBalances;
    }

    //============================== PRIVATE FUNCTIONS ===============================

    /// @dev Used to calculate the percentage change between two prices. 1e18 = 100%.
    /// @param oldPrice The old price.
    /// @param newPrice The new price.
    /// @return The percentage change. 1e18 = 100%.
    function _calculatePercentageChange(uint256 oldPrice, uint256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) {
            return 0;
        }
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return diff.mulDiv(DENOMINATOR, oldPrice, Math.Rounding.Ceil);
    }

    /// @dev The available balance is the balance of the vault minus the total pending assets.
    /// @return The available balance.
    function _getAvailableBalance() internal view returns (uint256) {
        uint256 balance = IERC20(asset()).balanceOf(address(this));
        return balance > totalPendingAssets ? balance - totalPendingAssets : 0;
    }
}
