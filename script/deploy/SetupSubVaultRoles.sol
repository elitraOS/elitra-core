// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { Authority } from "@solmate/auth/Auth.sol";
import { SubVault } from "../../src/vault/SubVault.sol";
import {VaultBase} from "../../src/vault/VaultBase.sol";

/**
 * @title SetupSubVaultRoles
 * @author Elitra
 * @notice Configures roles and permissions for SubVault
 * @dev Sets up RolesAuthority with proper subvault permissions (Manager only)
 */
contract SetupSubVaultRoles is Script {
    // Role definitions
    /// @notice Role identifier for the Manager role
    uint8 public constant MANAGER_ROLE = 0;

    /// @notice Main script execution entry point
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get addresses from environment
        // Using VAULT_ADDRESS generic name, user should point this to the SubVault Proxy
        address vaultAddress = vm.envAddress("REMOTE_SUB_VAULT_ADDRESS");
        address rolesAuthorityAddress = vm.envAddress("REMOTE_AUTHORITY_ADDRESS");

        console2.log("=== Setup SubVault Roles Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("SubVault:", vaultAddress);
        console2.log("RolesAuthority:", rolesAuthorityAddress);

        vm.startBroadcast(deployerPrivateKey);

        SubVault vault = SubVault(payable(vaultAddress));
        RolesAuthority authority = RolesAuthority(rolesAuthorityAddress);

        // Set the vault's authority to the RolesAuthority
        console2.log("\n1. Setting vault authority...");
        vault.setAuthority(Authority(rolesAuthorityAddress));
        console2.log("   Vault authority set to:", rolesAuthorityAddress);

        // Give deployer the MANAGER_ROLE
        console2.log("\n2. Assigning MANAGER_ROLE to deployer...");
        authority.setUserRole(deployer, MANAGER_ROLE, true);
        console2.log("   Deployer assigned MANAGER_ROLE");

        // Configure MANAGER_ROLE capabilities
        console2.log("\n3. Configuring MANAGER_ROLE capabilities...");

        // // Manager can call pause()
        // authority.setRoleCapability(MANAGER_ROLE, vaultAddress, SubVault.pause.selector, true);
        // console2.log("   - Can call pause()");

        // // Manager can call unpause()
        // authority.setRoleCapability(MANAGER_ROLE, vaultAddress, SubVault.unpause.selector, true);
        // console2.log("   - Can call unpause()");

        // Manager can call manageBatch() (execute strategies)
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, VaultBase.manageBatch.selector, true);
        console2.log("   - Can call manageBatch()");

        vm.stopBroadcast();

        console2.log("\n=== Setup Complete ===");
        console2.log("Roles configured:");
        console2.log("  MANAGER_ROLE (0):", deployer);
        console2.log("\nTo assign additional roles:");
        console2.log("  cast send", rolesAuthorityAddress);
        console2.log("    'setUserRole(address,uint8,bool)' <user> <role> true");
        console2.log("    --private-key $PRIVATE_KEY --rpc-url $RPC_URL");
    }
}

