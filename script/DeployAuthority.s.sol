// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { RolesAuthority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { Authority } from "@solmate/auth/Auth.sol";

/**
 * @title DeployAuthority
 * @notice Deploys RolesAuthority contract for vault authorization
 * @dev Usage: forge script script/DeployAuthority.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployAuthority is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy RolesAuthority with owner and no parent authority
        console2.log("Deploying RolesAuthority...");
        RolesAuthority authority = new RolesAuthority(owner, Authority(address(0)));

        console2.log("RolesAuthority deployed at:", address(authority));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("RolesAuthority:", address(authority));
        console2.log("Owner:", owner);
        console2.log("\nNext steps:");
        console2.log("1. Save the RolesAuthority address to your config file:");
        console2.log("   echo 'export AUTHORITY_ADDRESS=%s' > config/sei/authority.sh", address(authority));
        console2.log("2. Use this address when deploying vaults");
        console2.log("3. Configure roles using SetupRoles script or setup-auth.sh");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
