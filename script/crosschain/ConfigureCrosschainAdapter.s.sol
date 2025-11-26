// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { CrosschainStrategyAdapter } from "../../src/adapters/layerzero/CrosschainStrategyAdapter.sol";

/**
 * @title ConfigureCrosschainAdapter
 * @notice Script to configure CrosschainStrategyAdapter (set token config and remote vault)
 * @dev Usage: forge script script/crosschain/ConfigureCrosschainAdapter.s.sol --rpc-url $RPC_URL --broadcast
 *
 * Required environment variables:
 * - PRIVATE_KEY: Owner private key
 * - CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS: The deployed adapter address
 * - TOKEN_ADDRESS: The token address on this chain
 * - OFT_ADDRESS: The OFT contract address for the token
 * - DST_EID: LayerZero destination endpoint ID
 * - DST_VAULT_ADDRESS: The vault address on destination chain
 */
contract ConfigureCrosschainAdapter is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(privateKey);

        address adapterAddress = vm.envAddress("CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS");
        address tokenAddress = vm.envAddress("CURRENT_TOKEN_ADDRESS");
        address oftAddress = vm.envAddress("CURRENT_OFT_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("CURRENT_DST_EID"));
        address dstVaultAddress = vm.envAddress("CURRENT_DST_VAULT_ADDRESS");

        CrosschainStrategyAdapter adapter = CrosschainStrategyAdapter(payable(adapterAddress));

        console2.log("=== Configuration ===");
        console2.log("Caller:", caller);
        console2.log("Adapter:", adapterAddress);
        console2.log("Token:", tokenAddress);
        console2.log("OFT:", oftAddress);
        console2.log("Destination EID:", dstEid);
        console2.log("Destination Vault:", dstVaultAddress);

        // Check current owner
        address owner = adapter.owner();
        console2.log("Adapter Owner:", owner);
        require(caller == owner, "Caller is not the owner");

        vm.startBroadcast(privateKey);

        // 1. Set token config
        console2.log("\nStep 1: Setting token config...");
        adapter.setTokenConfig(tokenAddress, oftAddress);
        console2.log("Token config set successfully!");

        // 2. Set remote vault
        console2.log("\nStep 2: Setting remote vault...");
        adapter.setRemoteVault(dstEid, dstVaultAddress);
        console2.log("Remote vault set successfully!");

        vm.stopBroadcast();

        // Verify configuration
        console2.log("\n=== Verification ===");
        address configuredOft = adapter.tokenToOft(tokenAddress);
        address configuredVault = adapter.dstEidToVault(dstEid);
        console2.log("Configured OFT:", configuredOft);
        console2.log("Configured Remote Vault:", configuredVault);

        console2.log("\n=== Configuration Complete ===");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
