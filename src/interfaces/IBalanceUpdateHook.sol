// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IBalanceUpdateHook
/// @notice Hook interface for validating and processing balance updates
interface IBalanceUpdateHook {
    /// @notice Called before balance update to validate and calculate new PPS
    /// @param currentPPS Current price per share
    /// @param totalSupply Total vault shares
    /// @param idleAssets Idle assets in vault
    /// @param newAggregatedBalance New aggregated balance from strategies
    /// @return shouldContinue If false, update should be rejected and vault paused
    /// @return newPPS Calculated new price per share
    function beforeBalanceUpdate(
        uint256 currentPPS,
        uint256 totalSupply,
        uint256 idleAssets,
        uint256 newAggregatedBalance
    ) external view returns (bool shouldContinue, uint256 newPPS);

    /// @notice Called after balance update completes (for future extensibility)
    /// @param oldBalance Previous aggregated balance
    /// @param newBalance New aggregated balance
    /// @param newPPS New price per share
    function afterBalanceUpdate(
        uint256 oldBalance,
        uint256 newBalance,
        uint256 newPPS
    ) external view;

    /// @notice Update the maximum price change threshold
    /// @param newThreshold New max percentage change (1e18 = 100%)
    function updateMaxPercentageChange(uint256 newThreshold) external;

    /// @notice Get current max percentage change threshold
    function maxPercentageChange() external view returns (uint256);
}
