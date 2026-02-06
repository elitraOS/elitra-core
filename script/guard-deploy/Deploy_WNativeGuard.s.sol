// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { WNativeGuard } from "../../src/guards/base/WNativeGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_WNativeGuard
 * @notice Deploys WNativeGuard for wrapped native tokens (WSEI, WETH, etc.)
 * @dev Usage: forge script script/guard-deploy/Deploy_WNativeGuard.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 * - WNATIVE_ADDRESS: The wrapped native token address (WSEI, WETH, etc.)
 */
contract Deploy_WNativeGuard is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address wnativeAddress = vm.envAddress("WNATIVE_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);
        console2.log("WNative:", wnativeAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        console2.log("\nDeploying WNativeGuard...");
        WNativeGuard guard = new WNativeGuard(deployer);
        console2.log("WNativeGuard:", address(guard));

        // Set guard for wrapped native token
        console2.log("\nSetting guard on vault...");
        vault.setGuard(wnativeAddress, address(guard));
        console2.log("  Set guard for WNative:", wnativeAddress);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("WNativeGuard:", address(guard));
        console2.log("Guard set on vault:", vaultAddress);
        console2.log("For WNative:", wnativeAddress);

        console2.log("\n=== Next Steps ===");
        console2.log("Whitelist spenders as needed:");
        console2.log("  cast send", address(guard), "'setSpender(address,bool)' <SPENDER> true");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
