// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ElitraVault } from "../src/ElitraVault.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract Upgrade is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultProxy = vm.envAddress("VAULT_PROXY_ADDRESS");

        console2.log("Deployer:", deployer);
        console2.log("Vault Proxy:", vaultProxy);

        // Get the proxy admin address from the proxy
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new implementation
        console2.log("\n    === Deploying New ElitraVault Implementation ===");
        ElitraVault newImplementation = new ElitraVault();
        console2.log("New Implementation:", address(newImplementation));

        // 2. Get ProxyAdmin address
        // The admin is stored in a specific storage slot defined by EIP-1967
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address proxyAdmin = address(uint160(uint256(vm.load(vaultProxy, adminSlot))));
        console2.log("ProxyAdmin:", proxyAdmin);

        // 3. Upgrade the proxy
        console2.log("\n=== Upgrading Proxy ===");
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(vaultProxy),
            address(newImplementation),
            "" // No initialization call needed for upgrades
        );

        vm.stopBroadcast();

        console2.log("\n=== Upgrade Summary ===");
        console2.log("Vault Proxy:", vaultProxy);
        console2.log("Old Implementation: (check logs above)");
        console2.log("New Implementation:", address(newImplementation));
        console2.log("ProxyAdmin:", proxyAdmin);
        console2.log("\n Upgrade successful!");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
