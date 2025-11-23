// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { Call } from "../interfaces/IElitraVault.sol";
import { Compatible } from "./Compatible.sol";
import { AuthUpgradeable, Authority } from "./AuthUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title VaultBase
/// @author Elitra
/// @notice Base contract for Vaults and SubVaults providing auth, pause, and management features
abstract contract VaultBase is AuthUpgradeable, PausableUpgradeable, Compatible {
    using Address for address;

    /// @notice Emitted when a batch of calls is executed
    /// @param index The index of the call in the batch
    /// @param target The address of the target contract
    /// @param functionSig The function signature of the call
    /// @param value The amount of ETH sent with the call
    /// @param result The return data of the call
    event ManageBatchOperation(
        uint256 indexed index,
        address indexed target,
        bytes4 functionSig,
        uint256 value,
        bytes result
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault base
    /// @param _owner The address of the owner
    function __VaultBase_init(address _owner) internal onlyInitializing {
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();
    }

    /// @notice Pause the vault
    function pause() public virtual requiresAuth {
        _pause();
    }

    /// @notice Unpause the vault
    function unpause() public virtual requiresAuth {
        _unpause();
    }

    /// @notice Execute a call to a target contract
    /// @param target The address of the target contract
    /// @param data The calldata to execute
    /// @param value The amount of ETH to send
    /// @return result The return data of the call
    function manage(address target, bytes calldata data, uint256 value)
        external
        virtual
        requiresAuth
        returns (bytes memory result)
    {
        bytes4 functionSig = bytes4(data);
        require(
            authority().canCall(msg.sender, target, functionSig),
            Errors.TargetMethodNotAuthorized(target, functionSig)
        );

        result = target.functionCallWithValue(data, value);
    }

    /// @notice Execute a batch of calls
    /// @param calls The array of calls to execute
    function manageBatch(Call[] calldata calls)
        external
        virtual
        requiresAuth
    {
        require(calls.length > 0, "No calls provided");

        for (uint256 i = 0; i < calls.length; i++) {
            bytes4 functionSig = bytes4(calls[i].data);
            require(
                authority().canCall(msg.sender, calls[i].target, functionSig),
                Errors.TargetMethodNotAuthorized(calls[i].target, functionSig)
            );

            bytes memory result = calls[i].target.functionCallWithValue(calls[i].data, calls[i].value);
            emit ManageBatchOperation(i, calls[i].target, functionSig, calls[i].value, result);
        }
    }
}
