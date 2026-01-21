// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { TakaraPoolGuard } from "../../src/guards/sei/TakaraPoolGuard.sol";
import { TakaraControllerGuard } from "../../src/guards/sei/TakaraControllerGuard.sol";

/**
 * @title Deploy_TakaraGuards
 * @notice Deploys TakaraPoolGuard and TakaraControllerGuard for SEI network
 * @dev Usage: forge script script/guard-deploy/Deploy_TakaraGuards.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 *
 * SEI Mainnet addresses:
 * - Takara SEI Pool: 0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2
 * - Takara USDC Pool: 0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0
 * - Takara Comptroller: 0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE
 */
contract Deploy_TakaraGuards is Script {
    // SEI Mainnet Takara addresses
    address constant TAKARA_SEI_POOL = 0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2;
    address constant TAKARA_USDC_POOL = 0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0;
    address constant TAKARA_COMPTROLLER = 0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TakaraPoolGuard for SEI pool
        console2.log("\nDeploying TakaraPoolGuard for SEI pool...");
        TakaraPoolGuard poolGuard = new TakaraPoolGuard();
        console2.log("TakaraPoolGuard:", address(poolGuard));


        // Deploy TakaraControllerGuard
        console2.log("\nDeploying TakaraControllerGuard...");
        TakaraControllerGuard controllerGuard = new TakaraControllerGuard();
        console2.log("TakaraControllerGuard:", address(controllerGuard));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("TakaraPoolGuard:", address(poolGuard));
        console2.log("TakaraControllerGuard:", address(controllerGuard));
    }

    function test() public {
        // Required for forge coverage to work
    }
}
