// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IVaultBase } from "./IVaultBase.sol";

/**
 * @title ISubVault
 * @notice Interface for SubVault with adapter integration
 */
interface ISubVault is IVaultBase {
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory);
}