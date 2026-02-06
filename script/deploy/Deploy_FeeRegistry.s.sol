// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { FeeRegistry } from "../../src/fees/FeeRegistry.sol";

contract Deploy_FeeRegistry is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        address feeReceiver = vm.envOr("FEE_RECEIVER", owner);

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Fee Receiver:", feeReceiver);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying FeeRegistry...");
        FeeRegistry feeRegistry = new FeeRegistry(owner, feeReceiver);
        console2.log("FeeRegistry deployed at:", address(feeRegistry));

        vm.stopBroadcast();
    }
}
