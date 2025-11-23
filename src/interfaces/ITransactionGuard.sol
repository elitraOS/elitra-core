// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ITransactionGuard
/// @author Elitra
/// @notice Interface for transaction guards
interface ITransactionGuard {
    /// @notice Checks if a transaction is safe to execute
    /// @param from The caller (e.g. Manager/Bridge)
    /// @param data The calldata being sent to the target
    /// @param value The value being sent
    /// @return safe True if the transaction is safe, false otherwise
    function validate(address from, bytes calldata data, uint256 value) external view returns (bool safe);
}

