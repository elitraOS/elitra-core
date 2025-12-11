// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../../src/adapters/layerzero/LzCrosschainDepositAdapter.sol";
import { CrosschainDepositQueue } from "../../../src/adapters/CrosschainDepositQueue.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy_CrosschainDepositAdapter
 * @notice Deploys CrosschainDepositAdapter (upgradeable) for cross-chain vault deposits via LayerZero OFT compose
 * @dev Usage: forge script script/crosschain-deposit/Deploy_CrosschainDepositAdapter.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER: (optional) Owner address, defaults to deployer
 * - LZ_ENDPOINT: LayerZero endpoint address for this chain
 * - QUEUE_ADDRESS: CrosschainDepositQueue proxy address (deploy queue first!)
 *
 * Note: Deploy CrosschainDepositQueue FIRST, then deploy this adapter with the queue address.
 * After deploying, call queue.setAdapter(adapterAddress) to complete the setup.
 */
contract Deploy_CrosschainDepositAdapter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_V2");
        address queueAddress = vm.envAddress("LZ_CROSSCHAIN_DEPOSIT_QUEUE_ADDRESS");

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("LZ Endpoint:", lzEndpoint);
        console2.log("Queue Address:", queueAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Get ZapExecutor address
        address zapExecutor = vm.envAddress("ZAP_EXECUTOR_ADDRESS");

        // Deploy implementation
        console2.log("\nDeploying LayerZeroCrosschainDepositAdapter implementation...");
        LayerZeroCrosschainDepositAdapter adapterImpl = new LayerZeroCrosschainDepositAdapter(lzEndpoint);
        console2.log("LayerZeroCrosschainDepositAdapter implementation:", address(adapterImpl));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            LayerZeroCrosschainDepositAdapter.initialize.selector,
            owner,
            queueAddress,
            zapExecutor
        );

        // Deploy proxy
        console2.log("Deploying CrosschainDepositAdapter proxy (UUPS)...");
        ERC1967Proxy adapterProxy = new ERC1967Proxy(
            address(adapterImpl),
            initData
        );
        console2.log("CrosschainDepositAdapter proxy:", address(adapterProxy));

        // Set adapter on the queue
        console2.log("\nSetting adapter on queue...");
        CrosschainDepositQueue(queueAddress).setAdapterRegistration(address(adapterProxy), true);
        console2.log("Adapter set on queue successfully");

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("CrosschainDepositAdapter implementation:", address(adapterImpl));
        console2.log("CrosschainDepositAdapter proxy:", address(adapterProxy));
        console2.log("Queue Address:", queueAddress);
        console2.log("Owner:", owner);

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the proxy address to your config file");
        console2.log("2. Configure supported OFTs:");
        console2.log("   adapter.setSupportedOFT(TOKEN_ADDRESS, OFT_ADDRESS, true)");
        console2.log("3. Configure supported vaults:");
        console2.log("   adapter.setSupportedVault(VAULT_ADDRESS, true)");
        console2.log("4. Set LayerZero peer if needed:");
        console2.log("   adapter.setPeer(REMOTE_EID, REMOTE_ADAPTER_ADDRESS)");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
