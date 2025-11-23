// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Call } from "./IElitraVault.sol";

/**
 * @title ISubVault
 * @notice Interface for SubVault with adapter integration
 */
interface ISubVault {
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory);
    function manageBatch(Call[] calldata calls) external; 
}