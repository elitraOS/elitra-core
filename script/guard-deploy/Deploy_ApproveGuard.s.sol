// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ApproveGuard } from "../../src/guards/base/ApproveGuard.sol";

/**
 * @title Deploy_ApproveGuard
 * @notice Deploys ApproveGuard with whitelisted spenders
 * @dev Usage: forge script script/Deploy_ApproveGuard.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - WHITELISTED_SPENDERS: Comma-separated list of addresses to whitelist (e.g., "0x123,0x456")
 */
contract Deploy_ApproveGuard is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

    
        vm.startBroadcast(deployerPrivateKey);

        console2.log("\nDeploying ApproveGuard...");
        ApproveGuard guard = new ApproveGuard(deployer);
        console2.log("ApproveGuard:", address(guard));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("ApproveGuard:", address(guard));

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the deployed address to your config file");
        console2.log("2. Set the guard on your vault for the token address:");
        console2.log("   vault.setGuard(TOKEN_ADDRESS, APPROVE_GUARD_ADDRESS)");
    }


    function test() public {
        // Required for forge coverage to work
    }
}
