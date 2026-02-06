// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Api3SwapAdapter } from "../../src/adapters/Api3SwapAdapter.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_Api3SwapAdapter
 * @notice Deploys Api3SwapAdapter with proxy and sets it as a trusted target on the vault
 * @dev Usage: forge script script/deploy/Deploy_Api3SwapAdapter.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will use this adapter
 *
 * The adapter will be initialized with:
 * - Owner: deployer address
 * - Vault: VAULT_ADDRESS
 * - minReturnBps: 9900 (99% - require swap output to be within 99% of oracle price)
 * - defaultStaleSeconds: 1 hour
 * - Router whitelist: enabled
 * - Token whitelist: enabled
 */
contract Deploy_Api3SwapAdapter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation
        console2.log("\nDeploying Api3SwapAdapter implementation...");
        Api3SwapAdapter implementation = new Api3SwapAdapter();
        console2.log("Implementation:", address(implementation));

        // 2. Deploy proxy with initialization
        console2.log("\nDeploying ERC1967Proxy...");
        bytes memory initData = abi.encodeWithSelector(
            Api3SwapAdapter.initialize.selector,
            deployer, // owner
            vaultAddress // vault
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console2.log("Proxy:", address(proxy));

        // 3. Set adapter as trusted target on vault
        console2.log("\nSetting adapter as trusted target on vault...");
        ElitraVault vault = ElitraVault(payable(vaultAddress));
        vault.setTrustedTarget(address(proxy), true);
        console2.log("  Set trusted target:", address(proxy));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("Api3SwapAdapter implementation:", address(implementation));
        console2.log("Api3SwapAdapter proxy:", address(proxy));
        console2.log("Trusted target set on vault:", vaultAddress);

        console2.log("\n=== Post-Deployment Setup ===");
        console2.log("The adapter is now ready to use. Configure it with:");
        console2.log("1. Whitelist routers: adapter.setWhitelistedRouter(router, true)");
        console2.log("2. Whitelist tokens: adapter.setWhitelistedToken(token, true)");
        console2.log("3. Set price feeds: adapter.setPriceFeed(token, proxy, decimals, staleSeconds)");
        console2.log("");
        console2.log("Example configuration:");
        console2.log("  # Whitelist a DEX router");
        console2.log("  cast send", address(proxy), "'setWhitelistedRouter(address,bool)' <ROUTER> true");
        console2.log("");
        console2.log("  # Whitelist tokens");
        console2.log("  cast send", address(proxy), "'setWhitelistedToken(address,bool)' <TOKEN> true");
        console2.log("");
        console2.log("  # Set price feed for token");
        console2.log("  cast send", address(proxy), "'setPriceFeed(address,address,uint8,uint32)' <TOKEN> <API3_PROXY> 8 3600");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
