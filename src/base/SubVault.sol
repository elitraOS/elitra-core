// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VaultBase } from "../base/VaultBase.sol";
import { ISubVault } from "../interfaces/ISubVault.sol";
import { IVaultBase } from "../interfaces/IVaultBase.sol";
import { ITransactionGuard } from "../interfaces/ITransactionGuard.sol";
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

    // Subvault is simple vaultbase with no additional functionality, simply for investing token with security 
}
