// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeRegistry {
    /// @notice Protocol fee rate in bps (1e4 = 100%).
    function protocolFeeRateBps() external view returns (uint16);
}
