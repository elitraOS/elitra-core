// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../../src/adapters/layerzero/LzCrosschainDepositAdapter.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy_LzCrosschainDepositAdapter
 * @notice Deploys LayerZeroCrosschainDepositAdapter for cross-chain vault deposits via LayerZero OFT
 * @dev Usage: forge script script/crosschain-deposit/deploy/Deploy_LzCrosschainDepositAdapter.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER: (optional) Owner address, defaults to deployer
 * - LZ_ENDPOINT: LayerZero endpoint contract address on this chain
 * - QUEUE: Queue contract address for deposit processing
 * - ZAP_EXECUTOR: Zap executor contract address for swap operations
 */
contract Deploy_LzCrosschainDepositAdapter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", address(deployer));
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_V2");
        address queue = vm.envAddress("CROSSCHAIN_DEPOSIT_QUEUE_ADDRESS");
        address zapExecutor = vm.envAddress("ZAP_EXECUTOR_ADDRESS");

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("LayerZero Endpoint:", lzEndpoint);
        console2.log("Queue:", queue);
        console2.log("Zap Executor:", zapExecutor);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\nDeploying LayerZeroCrosschainDepositAdapter implementation...");
        LayerZeroCrosschainDepositAdapter implementation = new LayerZeroCrosschainDepositAdapter(lzEndpoint);
        console2.log("Implementation:", address(implementation));

        console2.log("\nDeploying ERC1967Proxy...");
        bytes memory initData = abi.encodeWithSelector(
            LayerZeroCrosschainDepositAdapter.initialize.selector,
            owner,
            queue,
            zapExecutor
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("Proxy:", address(proxy));

        vm.stopBroadcast();
    }

    function test() public {
        // Required for forge coverage to work
    }
}
