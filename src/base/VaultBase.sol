// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { Call } from "../interfaces/IElitraVault.sol";
import { IVaultBase } from "../interfaces/IVaultBase.sol";
import { ITransactionGuard } from "../interfaces/ITransactionGuard.sol";
import { Compatible } from "./Compatible.sol";
import { AuthUpgradeable, Authority } from "./AuthUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/// @title VaultBase
/// @author Elitra
/// @notice Base contract for Vaults and SubVaults providing auth, pause, and management features
abstract contract VaultBase is AuthUpgradeable, PausableUpgradeable, Compatible, IVaultBase {
    using Address for address;

    /// @notice Mapping of target contracts to their guards
    mapping(address target => ITransactionGuard guard) public override guards;

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

    /// @notice Sets the guard for a specific target
    /// @param target The target contract address
    /// @param guard The guard contract address
    function setGuard(address target, address guard) external virtual requiresAuth {
        guards[target] = ITransactionGuard(guard);
        emit GuardUpdated(target, guard);
    }

    /// @notice Removes the guard for a specific target
    /// @param target The target contract address
    function removeGuard(address target) external virtual requiresAuth {
        delete guards[target];
        emit GuardRemoved(target);
    }

    /// @notice Execute a call to a target contract
    /// @param target The address of the target contract
    /// @param data The calldata to execute
    /// @param value The amount of ETH to send
    /// @return result The return data of the call
    function _manage(address target, bytes calldata data, uint256 value)
        internal
        requiresAuth
        returns (bytes memory result)
    {
        ITransactionGuard guard = guards[target];
        require(address(guard) != address(0), Errors.TransactionValidationFailed(target));
        
        require(
            guard.validate(msg.sender, data, value),
            Errors.TransactionValidationFailed(target)
        );

        result = target.functionCallWithValue(data, value);
    }

    /// @notice Execute a batch of calls
    /// @param calls The array of calls to execute
    function manageBatch(Call[] calldata calls)
        public
        virtual
        requiresAuth
    {
        require(calls.length > 0, "No calls provided");

        for (uint256 i = 0; i < calls.length; ++i) {
            bytes memory result = _manage(calls[i].target, calls[i].data, calls[i].value);
            emit ManageBatchOperation(i, calls[i].target, bytes4(calls[i].data), calls[i].value, result);
        }
    }
}
