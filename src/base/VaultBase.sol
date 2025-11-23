// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { Call } from "../interfaces/IElitraVault.sol";
import { ICallValidator } from "../interfaces/ICallValidator.sol";
import { Compatible } from "./Compatible.sol";
import { AuthUpgradeable, Authority } from "./AuthUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title VaultBase
/// @author Elitra
/// @notice Base contract for Vaults and SubVaults providing auth, pause, and management features
abstract contract VaultBase is AuthUpgradeable, PausableUpgradeable, Compatible {
    using Address for address;

    /// @notice Mapping of target contracts to their validators
    mapping(address target => ICallValidator validator) public validators;

    /// @notice Emitted when a validator is updated
    /// @param target The target contract address
    /// @param validator The validator contract address
    event ValidatorUpdated(address indexed target, address indexed validator);

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

    /// @notice Sets the validator for a specific target
    /// @param target The target contract address
    /// @param validator The validator contract address
    function setValidator(address target, address validator) external virtual requiresAuth {
        validators[target] = ICallValidator(validator);
        emit ValidatorUpdated(target, validator);
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
        ICallValidator validator = validators[target];
        require(address(validator) != address(0), Errors.TransactionValidationFailed(target));
        
        require(
            validator.validate(msg.sender, data, value),
            Errors.TransactionValidationFailed(target)
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
