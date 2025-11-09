// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IElitraVault } from "./IElitraVault.sol";

/// @title IOracleAdapter
/// @notice Interface for oracle adapters that validate and execute balance updates
interface IOracleAdapter {
    /// @notice Validate and execute an oracle update on the vault
    /// @param vault The vault to update
    /// @param newBalance The new aggregated balance being reported
    /// @return success Whether update was applied (false if paused due to threshold)
    function updateVaultBalance(IElitraVault vault, uint256 newBalance) external returns (bool success);

    /// @notice Update the maximum price change threshold
    /// @param newThreshold New max percentage change (1e18 = 100%)
    function updateMaxPercentageChange(uint256 newThreshold) external;

    /// @notice Get current max percentage change threshold
    function maxPercentageChange() external view returns (uint256);
}
