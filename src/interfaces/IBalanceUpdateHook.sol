// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title IBalanceUpdateHook
/// @notice Hook interface for validating and processing balance updates
interface IBalanceUpdateHook {
    /// @notice Called before balance update to validate a precomputed new PPS
    /// @param currentPPS Current price per share
    /// @param newPPS New price per share computed by the vault
    /// @return shouldContinue If false, update should be rejected and vault paused
    function beforeBalanceUpdate(uint256 currentPPS, uint256 newPPS) external view returns (bool shouldContinue);

    /// @notice Called after balance update completes (for future extensibility)
    /// @param oldBalance Previous aggregated balance
    /// @param newBalance New aggregated balance
    /// @param newPPS New price per share
    function afterBalanceUpdate(
        uint256 oldBalance,
        uint256 newBalance,
        uint256 newPPS
    ) external view;


    /// @notice Get current max percentage change threshold
    function maxPercentageChange() external view returns (uint256);
}
