// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { TokenGuard } from "../../src/guards/base/TokenGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_TokenGuard
 * @notice Deploys TokenGuard with whitelisted spenders
 * @dev Usage: forge script script/Deploy_TokenGuard.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 * - TOKEN_ADDRESS: The token address to set guard for
 */
contract Deploy_TokenGuard is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);
        console2.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        console2.log("\nDeploying TokenGuard...");
        TokenGuard guard = new TokenGuard(deployer);
        console2.log("TokenGuard:", address(guard));

        // Set guard for token
        console2.log("\nSetting guard on vault...");
        vault.setGuard(tokenAddress, address(guard));
        console2.log("  Set guard for token:", tokenAddress);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("TokenGuard:", address(guard));
        console2.log("Guard set on vault:", vaultAddress);
        console2.log("For token:", tokenAddress);

        console2.log("\n=== Next Steps ===");
        console2.log("Whitelist spenders as needed:");
        console2.log("  cast send", address(guard), "'setSpender(address,bool)' <SPENDER> true");
    }


    function test() public {
        // Required for forge coverage to work
    }
}
