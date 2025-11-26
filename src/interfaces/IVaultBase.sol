// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "./ITransactionGuard.sol";

/// @notice Call structure for batch operations
struct Call {
    address target;
    bytes data;
    uint256 value;
}

/**
 * @title IVaultBase
 * @author Elitra
 * @notice Interface for base vault functionality including guards and management
 */
interface IVaultBase {
    // Events
    /// @notice Emitted when a guard is updated
    /// @param target The target contract address
    /// @param guard The guard contract address
    event GuardUpdated(address indexed target, address indexed guard);

    /// @notice Emitted when a guard is removed
    /// @param target The target contract address
    event GuardRemoved(address indexed target);

    /// @notice Emitted when a trusted target is updated
    /// @param target The target contract address
    /// @param isTrusted Whether the target is trusted
    event TrustedTargetUpdated(address indexed target, bool isTrusted);

    /// @notice Emitted when a batch operation is executed
    /// @param index The index of the operation in the batch
    /// @param target The target contract address
    /// @param functionSig The function signature
    /// @param value The value sent with the call
    /// @param result The return data of the call
    event ManageBatchOperation(
        uint256 indexed index,
        address indexed target,
        bytes4 functionSig,
        uint256 value,
        bytes result
    );

    // Guard management
    
    /// @notice Sets the guard for a specific target
    /// @param target The target contract address
    /// @param guard The guard contract address
    function setGuard(address target, address guard) external;

    /// @notice Removes the guard for a specific target
    /// @param target The target contract address
    function removeGuard(address target) external;

    /// @notice Returns the guard for a specific target
    /// @param target The target contract address
    /// @return The guard contract
    function guards(address target) external view returns (ITransactionGuard);
    
    // Trusted target management

    /// @notice Sets a target as trusted or untrusted
    /// @param target The target contract address
    /// @param isTrusted Whether the target is trusted
    function setTrustedTarget(address target, bool isTrusted) external;

    /// @notice Returns whether a target is trusted
    /// @param target The target contract address
    /// @return Whether the target is trusted
    function isTrustedTarget(address target) external view returns (bool);

    // Strategy management

    /// @notice Execute a batch of calls
    /// @param calls The array of calls to execute
    function manageBatch(Call[] calldata calls) external payable;

    // Emergency controls
    
    /// @notice Pause the vault
    function pause() external;

    /// @notice Unpause the vault
    function unpause() external;
}
