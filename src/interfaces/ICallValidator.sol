// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICallValidator {
    /// @notice Returns true if the call is safe, false otherwise
    /// @param from The caller (e.g. Manager/Bridge)
    /// @param data The calldata being sent to the target
    /// @param value The value being sent
    function validate(address from, bytes calldata data, uint256 value) external view returns (bool);
}

