// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IBalanceUpdateHook } from "./IBalanceUpdateHook.sol";
import { IRedemptionHook } from "./IRedemptionHook.sol";

/// @notice Call structure for batch operations
struct Call {
    address target;
    bytes data;
    uint256 value;
}

/// @title IElitraVault
/// @notice Interface for ElitraVault with adapter integration
interface IElitraVault is IERC4626 {
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
    event RedeemRequest(
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        bool instant
    );
    event RequestFulfilled(address indexed receiver, uint256 shares, uint256 assets);
    event RequestCancelled(address indexed receiver, uint256 shares, uint256 assets);
    event ManageBatchOperation(
        uint256 indexed index,
        address indexed target,
        bytes4 functionSig,
        uint256 value,
        bytes result
    );

    // Balance update hook integration
    function updateBalance(uint256 newAggregatedBalance) external;
    function setBalanceUpdateHook(IBalanceUpdateHook hook) external;
    function balanceUpdateHook() external view returns (IBalanceUpdateHook);
    function lastBlockUpdated() external view returns (uint256);
    function lastPricePerShare() external view returns (uint256);
    function aggregatedUnderlyingBalances() external view returns (uint256);

    // Redemption hook integration
    function setRedemptionHook(IRedemptionHook hook) external;
    function redemptionHook() external view returns (IRedemptionHook);
    function getAvailableBalance() external view returns (uint256);
    function requestRedeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function fulfillRedeem(address receiver, uint256 shares, uint256 assets) external;
    function cancelRedeem(address receiver, uint256 shares, uint256 assets) external;
    function pendingRedeemRequest(address user) external view returns (uint256 assets, uint256 pendingShares);

    // Strategy management
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory);
    function manageBatch(Call[] calldata calls) external;

    // Emergency controls
    function pause() external;
    function unpause() external;
}
