// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { ElitraVaultFactory } from "../../src/ElitraVaultFactory.sol";

contract Deploy_Factory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Vault Implementation
        console2.log("Deploying ElitraVault implementation...");
        ElitraVault implementation = new ElitraVault();
        console2.log("ElitraVault implementation deployed at:", address(implementation));

        // 2. Deploy Factory
        console2.log("Deploying ElitraVaultFactory...");
        ElitraVaultFactory factory = new ElitraVaultFactory(address(implementation));
        console2.log("ElitraVaultFactory deployed at:", address(factory));

        // Transfer Factory ownership if needed
        if (factory.owner() != owner) {
            factory.transferOwnership(owner);
            console2.log("Transferred Factory ownership to:", owner);
        }

        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("ElitraVault Implementation:", address(implementation));
        console2.log("ElitraVaultFactory:", address(factory));
    }
}
