// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { Authority } from "@solmate/auth/Auth.sol";
import { ElitraVault } from "src/ElitraVault.sol";
import { ManualBalanceUpdateHook } from "src/hooks/ManualBalanceUpdateHook.sol";
/**
 * @title SetupRoles
 * @notice Configures roles and permissions for Elitra Vault
 * @dev Sets up RolesAuthority with proper vault permissions
 */
contract SetupRoles is Script {
    // Role definitions
    uint8 public constant MANAGER_ROLE = 0;
    uint8 public constant ORACLE_ROLE = 1;
    uint8 public constant KEEPER_ROLE = 2;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get addresses from environment
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address rolesAuthorityAddress = vm.envAddress("ROLES_AUTHORITY_ADDRESS");
        address oracleHookAddress = vm.envAddress("ORACLE_HOOK_ADDRESS");

        console2.log("=== Setup Roles Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);
        console2.log("RolesAuthority:", rolesAuthorityAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));
        RolesAuthority authority = RolesAuthority(rolesAuthorityAddress);
        ManualBalanceUpdateHook oracleHook = ManualBalanceUpdateHook(oracleHookAddress);

        // Set the vault's authority to the RolesAuthority
        console2.log("\n1. Setting vault authority...");
        vault.setAuthority(Authority(rolesAuthorityAddress));
        console2.log("   Vault authority set to:", rolesAuthorityAddress);

        console2.log("\n2. Setting oracle hook authority...");
        oracleHook.setAuthority(Authority(rolesAuthorityAddress));
        console2.log("   Oracle hook authority set to:", rolesAuthorityAddress);

        // allow broadcast address, to call the updateBalance function
        authority.setUserRole(deployer, ORACLE_ROLE, true);
        console2.log("   Deployer assigned ORACLE_ROLE");


        // Give deployer the MANAGER_ROLE
        console2.log("\n2. Assigning MANAGER_ROLE to deployer...");
        authority.setUserRole(deployer, MANAGER_ROLE, true);
        console2.log("   Deployer assigned MANAGER_ROLE");

        // Configure MANAGER_ROLE capabilities
        console2.log("\n3. Configuring MANAGER_ROLE capabilities...");


        // Manager can call updateBalance()
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, ElitraVault.updateBalance.selector, true);
        console2.log("   - Can call updateBalance()");

        // Manager can call pause()
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, ElitraVault.pause.selector, true);
        console2.log("   - Can call pause()");

        // Manager can call unpause()
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, ElitraVault.unpause.selector, true);
        console2.log("   - Can call unpause()");

        // Manager can call setBalanceUpdateHook()
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, ElitraVault.setBalanceUpdateHook.selector, true);
        console2.log("   - Can call setBalanceUpdateHook()");

        // Manager can call setRedemptionHook()
        authority.setRoleCapability(MANAGER_ROLE, vaultAddress, ElitraVault.setRedemptionHook.selector, true);
        console2.log("   - Can call setRedemptionHook()");

        // Configure ORACLE_ROLE capabilities
        console2.log("\n4. Configuring ORACLE_ROLE capabilities...");

        // Oracle can call updateBalance()
        authority.setRoleCapability(ORACLE_ROLE, vaultAddress, ElitraVault.updateBalance.selector, true);
        console2.log("   - Can call updateBalance()");

        // Configure KEEPER_ROLE capabilities
        console2.log("\n5. Configuring KEEPER_ROLE capabilities...");

        // Keeper can call fulfillRedeem()
        authority.setRoleCapability(KEEPER_ROLE, vaultAddress, ElitraVault.fulfillRedeem.selector, true);
        console2.log("   - Can call fulfillRedeem()");

        // Keeper can call cancelRedeem()
        authority.setRoleCapability(KEEPER_ROLE, vaultAddress, ElitraVault.cancelRedeem.selector, true);
        console2.log("   - Can call cancelRedeem()");

        vm.stopBroadcast();

        console2.log("\n=== Setup Complete ===");
        console2.log("Roles configured:");
        console2.log("  MANAGER_ROLE (0):", deployer);
        console2.log("  ORACLE_ROLE  (1): Not assigned (assign as needed)");
        console2.log("  KEEPER_ROLE  (2): Not assigned (assign as needed)");
        console2.log("\nTo assign additional roles:");
        console2.log("  cast send", rolesAuthorityAddress);
        console2.log("    'setUserRole(address,uint8,bool)' <user> <role> true");
        console2.log("    --private-key $PRIVATE_KEY --rpc-url $RPC_URL");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
