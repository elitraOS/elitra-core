// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { CrosschainDepositQueue } from "../../../src/adapters/layerzero/CrosschainDepositQueue.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy_CrosschainDepositQueue
 * @notice Deploys CrosschainDepositQueue (upgradeable) for handling failed cross-chain deposits
 * @dev Usage: forge script script/crosschain-deposit/Deploy_CrosschainDepositQueue.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER: (optional) Owner address, defaults to deployer
 *
 * Note: Deploy this FIRST before deploying CrosschainDepositAdapter.
 * After deploying the adapter, call queue.setAdapter(adapterAddress).
 */
contract Deploy_CrosschainDepositQueue is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        console2.log("\nDeploying CrosschainDepositQueue implementation...");
        CrosschainDepositQueue queueImpl = new CrosschainDepositQueue();
        console2.log("CrosschainDepositQueue implementation:", address(queueImpl));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            CrosschainDepositQueue.initialize.selector,
            owner
        );

        // Deploy proxy
        console2.log("Deploying CrosschainDepositQueue proxy (UUPS)...");
        ERC1967Proxy queueProxy = new ERC1967Proxy(
            address(queueImpl),
            initData
        );
        console2.log("CrosschainDepositQueue proxy:", address(queueProxy));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("CrosschainDepositQueue implementation:", address(queueImpl));
        console2.log("CrosschainDepositQueue proxy:", address(queueProxy));
        console2.log("Owner:", owner);

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the proxy address to your config file");
        console2.log("2. Deploy CrosschainDepositAdapter with this queue address:");
        console2.log("   QUEUE_ADDRESS=%s", address(queueProxy));
        console2.log("3. After deploying adapter, set it on the queue:");
        console2.log("   queue.setAdapter(ADAPTER_ADDRESS)");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
