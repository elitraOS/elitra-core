// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/console.sol";
import {MultichainDepositAdapter} from "../src/MultichainDepositAdapter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy_MultichainDepositAdapter
 * @notice Script to deploy MultichainDepositAdapter with UUPS proxy on SEI chain
 * @dev Deploys the adapter and configures it with supported vaults and OFTs
 *
 * Usage:
 *   source config/sei/wsei.sh  # Load SEI configuration
 *   forge script script/Deploy_MultichainDepositAdapter.s.sol:Deploy_MultichainDepositAdapter \
 *     --rpc-url $SEI_RPC_URL \
 *     --broadcast \
 *     --verify
 *
 * Environment Variables:
 *   PRIVATE_KEY or MNEMONIC - For deployment
 *   LAYERZERO_ENDPOINT - LayerZero endpoint address on SEI
 *   OWNER_ADDRESS - Owner address (defaults to broadcaster)
 *
 *   From wsei.sh:
 *   VAULT_ADDRESS - WSEI Vault address
 *   ASSET_ADDRESS - WSEI token address
 *
 *   Optional:
 *   SEI_OFT_ADDRESS - SEI OFT address on SEI chain
 *   VERIFY - Set to true to verify on explorer
 */
contract Deploy_MultichainDepositAdapter is BaseScript {
   

    MultichainDepositAdapter public adapterImplementation;
    MultichainDepositAdapter public adapter;
    ERC1967Proxy public proxy;

    function run() public broadcast returns (address proxyAddress) {
        console.log("\n=== Deploying MultichainDepositAdapter on SEI ===\n");

        // Get configuration from environment
        address layerzeroEndpoint = vm.envAddress("LAYERZERO_ENDPOINT_V2");
        address owner = vm.envOr("OWNER_ADDRESS", broadcaster);
        address wseiVault = vm.envAddress("VAULT_ADDRESS"); // From wsei.sh
        address wsei = vm.envAddress("ASSET_ADDRESS"); // From wsei.sh
        address seiOft = vm.envAddress("ETH_SEI_OFT_ADDRESS");

        console.log("Configuration:");
        console.log("  LayerZero Endpoint:", layerzeroEndpoint);
        console.log("  Owner:", owner);
        console.log("  WSEI Vault:", wseiVault);
        console.log("  WSEI Token:", wsei);
        console.log("  SEI OFT:", seiOft);
        console.log("  Deployer:", broadcaster);
        console.log("");

        // Deploy implementation
        console.log("Deploying implementation...");
        adapterImplementation = new MultichainDepositAdapter(layerzeroEndpoint);
        console.log("Implementation deployed at:", address(adapterImplementation));

        // Encode initializer
        bytes memory initData = abi.encodeCall(
            MultichainDepositAdapter.initialize,
            (owner)
        );

        // Deploy proxy
        console.log("\nDeploying proxy...");
        proxy = new ERC1967Proxy(
            address(adapterImplementation),
            initData
        );
        proxyAddress = address(proxy);
        console.log("Proxy deployed at:", proxyAddress);

        // Wrap proxy in adapter interface
        adapter = MultichainDepositAdapter(payable(proxyAddress));

        // Verify initialization
        console.log("\nVerifying initialization...");
        console.log("  Owner:", adapter.owner());
        console.log("  Endpoint:", address(adapter.endpoint()));
        console.log("  Total deposits:", adapter.totalDeposits());

        // // Configure adapter (if owner is broadcaster)
        // if (owner == broadcaster) {
        //     console.log("\n=== Configuring Adapter ===\n");

        //     // Set supported vault
        //     console.log("Setting supported vault...");
        //     adapter.setSupportedVault(wseiVault, true);
        //     console.log("  WSEI Vault supported:", adapter.supportedVaults(wseiVault));

        //     // Set supported OFT
        //     console.log("\nSetting supported OFT...");
        //     // Note: SEI native token needs to map to the OFT contract
        //     // You may need to adjust this based on your OFT setup
        //     adapter.setSupportedOFT(
        //         wsei, // token (WSEI in this case, or native SEI)
        //         seiOft, // OFT contract
        //         true // isActive
        //     );
        //     console.log("  OFT configured for token:", wsei);
        //     console.log("  OFT address:", seiOft);
        //     console.log("  OFT supported:", adapter.supportedOFTs(seiOft));

        //     console.log("\n=== Configuration Complete ===\n");
        // } else {
        //     console.log("\n=== Manual Configuration Required ===");
        //     console.log("Owner is not broadcaster. Run these commands as owner:");
        //     console.log("");
        //     console.log("# Set supported vault");
        //     console.log("cast send %s \"setSupportedVault(address,bool)\" %s true --rpc-url $SEI_RPC_URL", proxyAddress, wseiVault);
        //     console.log("");
        //     console.log("# Set supported OFT");
        //     console.log("cast send %s \"setSupportedOFT(address,address,bool)\" %s %s true --rpc-url $SEI_RPC_URL", proxyAddress, wsei, seiOft);
        //     console.log("");
        // }

        // // Display summary
        // console.log("\n=== Deployment Summary ===");
        // console.log("Implementation:", address(adapterImplementation));
        // console.log("Proxy (Adapter):", proxyAddress);
        // console.log("Owner:", owner);
        // console.log("");
        // console.log("Next steps:");
        // console.log("1. Verify contracts on explorer (if not done automatically)");
        // console.log("2. Deposit refund gas: cast send", proxyAddress, "\"depositRefundGas()\" --value 1ether --rpc-url $SEI_RPC_URL");
        // console.log("3. Configure LayerZero peers on source chains");
        // console.log("4. Test with small cross-chain deposit");
        // console.log("");

        // Save deployment info
        _saveDeployment(proxyAddress, address(adapterImplementation));

        return proxyAddress;
    }

    /**
     * @notice Save deployment information
     */
    function _saveDeployment(address proxyAddr, address implAddr) internal {
        string memory deploymentInfo = string.concat(
            "MultichainDepositAdapter Deployment\n",
            "====================================\n",
            "Chain ID: ", vm.toString(getChainId()), "\n",
            "Proxy: ", vm.toString(proxyAddr), "\n",
            "Implementation: ", vm.toString(implAddr), "\n",
            "Owner: ", vm.toString(adapter.owner()), "\n",
            "Endpoint: ", vm.toString(address(adapter.endpoint())), "\n",
            "Deployed at: ", vm.toString(block.timestamp), "\n"
        );

        console.log("\n", deploymentInfo);
    }
}
