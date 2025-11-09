// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IOracleAdapter } from "./IOracleAdapter.sol";
import { IRedemptionStrategy } from "./IRedemptionStrategy.sol";

/// @title IElitraVaultV2
/// @notice Interface for ElitraVault V2 with adapter integration
interface IElitraVaultV2 is IERC4626 {
    /// @notice Pending redemption data structure
    struct PendingRedeem {
        uint256 shares;
        uint256 assets;
    }

    // Events
    event UnderlyingBalanceUpdated(uint256 oldBalance, uint256 newBalance);
    event OracleAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
    event RedemptionStrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event RedeemRequest(
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        bool instant
    );
    event RequestFulfilled(address indexed receiver, uint256 shares, uint256 assets);
    event RequestCancelled(address indexed receiver, uint256 shares, uint256 assets);

    // Oracle integration
    function setAggregatedBalance(uint256 newBalance, uint256 newPPS) external;
    function setOracleAdapter(IOracleAdapter adapter) external;
    function oracleAdapter() external view returns (IOracleAdapter);
    function lastBlockUpdated() external view returns (uint256);
    function lastPricePerShare() external view returns (uint256);
    function aggregatedUnderlyingBalances() external view returns (uint256);

    // Redemption integration
    function setRedemptionStrategy(IRedemptionStrategy strategy) external;
    function redemptionStrategy() external view returns (IRedemptionStrategy);
    function getAvailableBalance() external view returns (uint256);
    function requestRedeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function fulfillRedeem(address receiver, uint256 shares, uint256 assets) external;
    function cancelRedeem(address receiver, uint256 shares, uint256 assets) external;
    function pendingRedeemRequest(address user) external view returns (uint256 assets, uint256 pendingShares);

    // Strategy management
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory);

    // Emergency controls
    function pause() external;
    function unpause() external;
}
