// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import { IBalanceUpdateHook } from "./IBalanceUpdateHook.sol";
import { IRedemptionHook } from "./IRedemptionHook.sol";
import { IVaultBase, Call } from "./IVaultBase.sol";

/// @title IElitraVault
/// @notice Interface for ElitraVault with adapter integration
interface IElitraVault is IERC4626Upgradeable, IVaultBase {
    /// @notice Pending redemption data structure
    struct PendingRedeem {
        uint256 shares;
        uint256 assets;
    }

    // Events
    event UnderlyingBalanceUpdated(uint256 indexed timestamp, uint256 oldBalance, uint256 newBalance);
    event PPSUpdated(uint256 indexed timestamp, uint256 oldPPS, uint256 newPPS);
    event VaultPausedDueToThreshold(uint256 indexed timestamp, uint256 oldPPS, uint256 newPPS);
    event BalanceUpdateHookUpdated(address indexed oldHook, address indexed newHook);
    event RedemptionHookUpdated(address indexed oldHook, address indexed newHook);
    event RedeemRequest(address indexed receiver, address indexed owner, uint256 assets, uint256 shares, bool instant);
    event RequestFulfilled(address indexed receiver, uint256 shares, uint256 assets);
    event RequestCancelled(address indexed receiver, uint256 shares, uint256 assets);
    event NavFreshnessThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    // Balance update hook integration
    function updateBalance(uint256 newAggregatedBalance) external;
    function setBalanceUpdateHook(IBalanceUpdateHook hook) external;
    function balanceUpdateHook() external view returns (IBalanceUpdateHook);
    function lastBlockUpdated() external view returns (uint256);
    function lastPricePerShare() external view returns (uint256);
    function aggregatedUnderlyingBalances() external view returns (uint256);

    // NAV freshness
    function navFreshnessThreshold() external view returns (uint256);
    function lastTimestampUpdated() external view returns (uint256);
    function setNavFreshnessThreshold(uint256 threshold) external;

    // Redemption hook integration
    function setRedemptionHook(IRedemptionHook hook) external;
    function redemptionHook() external view returns (IRedemptionHook);
    function getAvailableBalance() external view returns (uint256);
    function requestRedeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function fulfillRedeem(address receiver, uint256 shares, uint256 assets) external;
    function cancelRedeem(address receiver, uint256 shares, uint256 assets) external;
    function pendingRedeemRequest(address user) external view returns (uint256 assets, uint256 pendingShares);
}
