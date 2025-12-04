// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title Verify_SubVault_Proxy
 * @notice Helper script to verify the SubVault proxy contract on Etherscan
 * @dev This script outputs the encoded constructor arguments needed for verification
 * 
 * Usage:
 * 1. Run this script to get the encoded constructor args:
 *    forge script script/verify/Verify_SubVault_Proxy.sol
 * 
 * 2. Use the output with forge verify-contract command
 */
contract Verify_SubVault_Proxy is Script {
    function run() external view {
        // Deployed addresses from your deployment
        address subVaultImpl = 0x2a75D11c3D289873698cAfcA1196A12C0e82e1aa;
        address proxyAdmin = 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4;
        address owner = 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4;
        address proxyAddress = 0x6E00Fc2897803a98856a9029De74C9f95CfE17E0;
        
        // Encode the initialization data (same as deployment)
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address)",
            owner
        );
        
        // Encode the constructor arguments for TransparentUpgradeableProxy
        bytes memory constructorArgs = abi.encode(
            subVaultImpl,
            proxyAdmin,
            initData
        );
        
        console2.log("\n=== SubVault Proxy Verification ===");
        console2.log("Proxy Address:", proxyAddress);
        console2.log("Implementation:", subVaultImpl);
        console2.log("Proxy Admin:", proxyAdmin);
        console2.log("Owner:", owner);
        console2.log("\n=== Encoded Constructor Arguments ===");
        console2.logBytes(constructorArgs);
        
        console2.log("\n=== Verification Command ===");
        console2.log("Run this command to verify the proxy:\n");
        console2.log("forge verify-contract \\");
        console2.log("  0x6E00Fc2897803a98856a9029De74C9f95CfE17E0 \\");
        console2.log("  lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy \\");
        console2.log("  --chain-id 1 \\");
        console2.log("  --verifier-url https://api.etherscan.io/api \\");
        console2.log("  --etherscan-api-key $ETHERSCAN_API_KEY \\");
        console2.log("  --compiler-version 0.8.28 \\");
        console2.log("  --evm-version cancun \\");
        console2.log("  --constructor-args $(cast abi-encode \"constructor(address,address,bytes)\" 0x2a75D11c3D289873698cAfcA1196A12C0e82e1aa 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4 $(cast abi-encode \"initialize(address)\" 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4))");
        
        console2.log("\n=== Alternative: Direct hex encoding ===");
        console2.log("If the above fails, use this pre-encoded hex:\n");
        console2.log("--constructor-args-hex");
        console2.log("(hex value will be shown in the output above)");
    }
}

