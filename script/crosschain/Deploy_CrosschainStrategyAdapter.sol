// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { CrosschainStrategyAdapter } from "../../src/adapters/layerzero/CrosschainStrategyAdapter.sol";

/**
 * @title Deploy_CrosschainStrategyAdapter
 * @notice Deploys CrosschainStrategyAdapter for cross-chain token transfers via LayerZero OFT
 * @dev Usage: forge script script/Deploy_CrosschainStrategyAdapter.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER: (optional) Owner address, defaults to deployer
 * - CURRENT_VAULT_ADDRESS: The vault address that is allowed to call sendToVault
 * - WRAPPED_NATIVE: The wrapped native token address (e.g., WSEI on SEI)
 */
contract Deploy_CrosschainStrategyAdapter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        address vault = vm.envAddress("CURRENT_VAULT_ADDRESS");
        address wrappedNative = vm.envAddress("WRAPPED_NATIVE");

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Vault:", vault);
        console2.log("Wrapped Native:", wrappedNative);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\nDeploying CrosschainStrategyAdapter...");
        CrosschainStrategyAdapter adapter = new CrosschainStrategyAdapter(owner, vault, wrappedNative);
        console2.log("CrosschainStrategyAdapter:", address(adapter));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("CrosschainStrategyAdapter:", address(adapter));
        console2.log("Owner:", owner);
        console2.log("Vault:", vault);
        console2.log("Wrapped Native:", wrappedNative);

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the deployed address to your config file");
        console2.log("2. Configure token mapping:");
        console2.log("   adapter.setTokenConfig(TOKEN_ADDRESS, OFT_ADDRESS)");
        console2.log("3. Configure remote vault:");
        console2.log("   adapter.setRemoteVault(DST_EID, DST_VAULT_ADDRESS)");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
