// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Errors } from "./libraries/Errors.sol";
import { IElitraRegistry } from "./interfaces/IElitraRegistry.sol";
import { Authority, AuthUpgradeable } from "./base/AuthUpgradeable.sol";

/// @title ElitraRegistry - A registry for Elitra vaults
/// @dev This contract is used to register and unregister Elitra vaults
contract ElitraRegistry is AuthUpgradeable, IElitraRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _vaults;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, Authority _authority) public initializer {
        __Auth_init(_owner, _authority);
    }

    /// @inheritdoc IElitraRegistry
    function addElitraVault(address vaultAddress) external requiresAuth {
        if (vaultAddress == address(0)) {
            revert Errors.Registry__VaultAddressZero();
        }

        IERC4626 vault = IERC4626(vaultAddress);
        address asset = vault.asset();

        if (!_vaults.add(vaultAddress)) {
            revert Errors.Registry__VaultAlreadyExists(vaultAddress);
        }

        emit ElitraVaultAdded(asset, vaultAddress);
    }

    /// @inheritdoc IElitraRegistry
    function removeElitraVault(address vaultAddress) external requiresAuth {
        if (vaultAddress == address(0)) {
            revert Errors.Registry__VaultAddressZero();
        }

        if (!_vaults.remove(vaultAddress)) {
            revert Errors.Registry__VaultNotExists(vaultAddress);
        }

        IERC4626 vault = IERC4626(vaultAddress);
        address asset = vault.asset();

        emit ElitraVaultRemoved(asset, vaultAddress);
    }

    /// @inheritdoc IElitraRegistry
    function isElitraVault(address vaultAddress) external view override returns (bool) {
        return _vaults.contains(vaultAddress);
    }

    /// @inheritdoc IElitraRegistry
    function listElitraVaults() external view returns (address[] memory) {
        return _vaults.values();
    }
}
