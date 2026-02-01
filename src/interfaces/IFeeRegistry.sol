// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title IFeeRegistry
/// @notice Interface for protocol fee registry managing fee rates and recipients
interface IFeeRegistry {
    /// @notice Protocol fee rate in bps (1e4 = 100%).
    function protocolFeeRateBps() external view returns (uint16);

    /// @notice Protocol fee rate in bps for a specific vault (falls back to global if not set).
    function protocolFeeRateBps(address vault) external view returns (uint16);

    /// @notice Protocol fee recipient address.
    function protocolFeeReceiver() external view returns (address);
}
