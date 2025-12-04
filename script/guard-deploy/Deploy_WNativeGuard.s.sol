// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { WNativeGuard } from "../../src/guards/base/WNativeGuard.sol";

/**
 * @title Deploy_WNativeGuard
 * @notice Deploys WNativeGuard for wrapped native tokens (WSEI, WETH, etc.)
 * @dev Usage: forge script script/guard-deploy/Deploy_WNativeGuard.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 */
contract Deploy_WNativeGuard is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\nDeploying WNativeGuard...");
        WNativeGuard guard = new WNativeGuard(deployer);
        console2.log("WNativeGuard:", address(guard));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("WNativeGuard:", address(guard));

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the deployed address to your config file");
        console2.log("2. Set the guard on your vault for the WSEI/WETH address:");
        console2.log("   vault.setGuard(WNATIVE_ADDRESS, WNATIVE_GUARD_ADDRESS)");
        console2.log("3. Whitelist spenders as needed:");
        console2.log("   guard.setSpender(SPENDER_ADDRESS, true)");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
