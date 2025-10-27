// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IElitraRegistry {
    event ElitraVaultAdded(address indexed asset, address indexed vault);
    event ElitraVaultRemoved(address indexed asset, address indexed vault);

    /// @notice Checks if an address is a valid Elitra vault
    /// @param vaultAddress Vault address to be added
    function isElitraVault(address vaultAddress) external view returns (bool);

    /// @notice Registers an Elitra vault
    /// @param vaultAddress Elitra vault address to be added
    function addElitraVault(address vaultAddress) external;

    /// @notice Removes Elitra vault registration
    /// @param vaultAddress Elitra vault address to be removed
    function removeElitraVault(address vaultAddress) external;

    /// @notice Returns a list of all registered Elitra vaults
    function listElitraVaults() external view returns (address[] memory);
}
