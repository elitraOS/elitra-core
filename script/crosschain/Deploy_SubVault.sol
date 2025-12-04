// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { SubVault } from "../../src/vault/SubVault.sol";
import { CrosschainStrategyAdapter } from "../../src/adapters/layerzero/CrosschainStrategyAdapter.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy_SubVault
 * @notice Deploys SubVault (upgradeable) and CrosschainStrategyAdapter for source chains
 * @dev Usage: forge script script/Deploy_SubVault.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER: (optional) Owner address, defaults to deployer
 * - PROXY_ADMIN: (optional) Proxy admin address, defaults to deployer
 * - MAIN_VAULT_ADDRESS: The main ElitraVault address on the destination chain (for reference)
 * - TOKEN_ADDRESS: The token address on this chain
 * - OFT_ADDRESS: The OFT contract address for the token on this chain
 * - DST_EID: LayerZero destination endpoint ID (e.g., 30280 for SEI)
 * - DST_VAULT_ADDRESS: The vault address on destination chain to receive funds
 */
contract Deploy_SubVault is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        // address proxyAdmin = vm.envOr("PROXY_ADMIN", deployer); // Not needed for UUPS
        // Fallback to TOKEN_ADDRESS or ASSET_ADDRESS if WRAPPED_NATIVE_ADDRESS is not set
        address wrappedNative = vm.envOr("WRAPPED_NATIVE_ADDRESS", vm.envOr("TOKEN_ADDRESS", vm.envAddress("ASSET_ADDRESS")));

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        // console2.log("Proxy Admin:", proxyAdmin);

        vm.startBroadcast(deployerPrivateKey);

        // ========== 1. Deploy SubVault (Upgradeable) ==========
        console2.log("\n--- Deploying SubVault ---");

        // Deploy implementation
        console2.log("Deploying SubVault implementation...");
        SubVault subVaultImpl = new SubVault();
        console2.log("SubVault implementation:", address(subVaultImpl));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            SubVault.initialize.selector,
            owner
        );

        // Deploy proxy
        console2.log("Deploying SubVault proxy (UUPS)...");
        ERC1967Proxy subVaultProxy = new ERC1967Proxy(
            address(subVaultImpl),
            initData
        );
        console2.log("SubVault proxy:", address(subVaultProxy));

        // ========== 2. Deploy CrosschainStrategyAdapter ==========
        console2.log("\n--- Deploying CrosschainStrategyAdapter ---");

        CrosschainStrategyAdapter adapter = new CrosschainStrategyAdapter(
            owner,
            address(subVaultProxy), // SubVault is the vault that can call sendToVault
            wrappedNative
        );
        console2.log("CrosschainStrategyAdapter:", address(adapter));

        vm.stopBroadcast();

        // ========== Summary ==========
        console2.log("\n=== Deployment Summary ===");
        console2.log("SubVault implementation:", address(subVaultImpl));
        console2.log("SubVault proxy:", address(subVaultProxy));
        console2.log("CrosschainStrategyAdapter:", address(adapter));

        console2.log("\n=== Next Steps ===");
        console2.log("1. Save the deployed addresses to your config file");
        console2.log("2. Configure the CrosschainStrategyAdapter:");
        console2.log("   - Set token config: adapter.setTokenConfig(TOKEN_ADDRESS, OFT_ADDRESS)");
        console2.log("   - Set remote vault: adapter.setRemoteVault(DST_EID, DST_VAULT_ADDRESS)");
        console2.log("3. Set up authority/roles on SubVault if using RolesAuthority");
        console2.log("4. Set guard on SubVault to control allowed operations");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
