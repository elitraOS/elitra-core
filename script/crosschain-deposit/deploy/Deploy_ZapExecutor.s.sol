// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ZapExecutor } from "../../src/adapters/ZapExecutor.sol";

/**
 * @title Deploy_ZapExecutor
 * @notice Deploys ZapExecutor (stateless helper for zaps)
 * @dev Usage: forge script script/crosschain-deposit/Deploy_ZapExecutor.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 *
 * Note: ZapExecutor is stateless and does not require initialization or ownership.
 * It can be shared across multiple adapters on the same chain.
 */
contract Deploy_ZapExecutor is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ZapExecutor (simple stateless contract, no proxy needed)
        console2.log("\nDeploying ZapExecutor...");
        ZapExecutor zapExecutor = new ZapExecutor();
        console2.log("ZapExecutor deployed at:", address(zapExecutor));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("ZapExecutor:", address(zapExecutor));

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the ZapExecutor address to your config file");
        console2.log("2. Use this address when deploying CrosschainDepositAdapter:");
        console2.log("   ZAP_EXECUTOR=%s", address(zapExecutor));
        console2.log("");
        console2.log("Note: This ZapExecutor can be reused for multiple adapters");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
