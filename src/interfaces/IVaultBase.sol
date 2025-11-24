// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Call } from "./IElitraVault.sol";
import { ITransactionGuard } from "./ITransactionGuard.sol";

/**
 * @title IVaultBase
 * @notice Interface for base vault functionality including guards and management
 */
interface IVaultBase {
    // Events
    event GuardUpdated(address indexed target, address indexed guard);
    event GuardRemoved(address indexed target);
    event ManageBatchOperation(
        uint256 indexed index,
        address indexed target,
        bytes4 functionSig,
        uint256 value,
        bytes result
    );

    // Guard management
    function setGuard(address target, address guard) external;
    function removeGuard(address target) external;
    function guards(address target) external view returns (ITransactionGuard);

    // Strategy management
    function manageBatch(Call[] calldata calls) external;

    // Emergency controls
    function pause() external;
    function unpause() external;
}
