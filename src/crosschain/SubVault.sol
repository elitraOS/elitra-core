// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VaultBase } from "../base/VaultBase.sol";
import { ISubVault } from "../interfaces/ISubVault.sol";
import { ICallValidator } from "../interfaces/ICallValidator.sol";
import { Call } from "../interfaces/IElitraVault.sol";
import { Errors } from "../libraries/Errors.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SubVault
 * @author Elitra
 * @notice A simple vault that holds assets and executes calls (strategies).
 * @dev Inherits VaultBase for Auth, Pause, and Management capabilities.
 *      Intended to be used as a destination for bridged funds to execute cross-chain strategies.
 */
contract SubVault is VaultBase, ISubVault {
    using Address for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the SubVault
     * @param _owner The address of the owner (likely the main ElitraVault or a bridge adapter)
     */
    function initialize(address _owner) public initializer {
        __VaultBase_init(_owner);
    }

    /// @inheritdoc ISubVault
    function manage(address target, bytes calldata data, uint256 value)
        external
        override(VaultBase, ISubVault)
        requiresAuth
        returns (bytes memory result)
    {
        ICallValidator validator = validators[target];
        require(address(validator) != address(0), Errors.TransactionValidationFailed(target));

        require(
            validator.validate(msg.sender, data, value),
            Errors.TransactionValidationFailed(target)
        );

        result = target.functionCallWithValue(data, value);
    }

    /// @inheritdoc ISubVault
    function manageBatch(Call[] calldata calls)
        external
        override(VaultBase, ISubVault)
        requiresAuth
    {
        require(calls.length > 0, "No calls provided");

        for (uint256 i = 0; i < calls.length; ++i) {
            ICallValidator validator = validators[calls[i].target];
            require(address(validator) != address(0), Errors.TransactionValidationFailed(calls[i].target));

            require(
                validator.validate(msg.sender, calls[i].data, calls[i].value),
                Errors.TransactionValidationFailed(calls[i].target)
            );

            bytes memory result = calls[i].target.functionCallWithValue(calls[i].data, calls[i].value);
            bytes4 functionSig = bytes4(calls[i].data);
            emit ManageBatchOperation(i, calls[i].target, functionSig, calls[i].value, result);
        }
    }
}
