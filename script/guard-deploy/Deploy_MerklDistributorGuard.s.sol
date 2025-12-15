// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MerklDistributorGuard } from "../../src/guards/sei/MerklDistributorGuard.sol";

/**
 * @title Deploy_MerklDistributorGuard
 * @notice Deploys MerklDistributorGuard (for SEI) to validate Merkl Distributor claim operations.
 * @dev Usage: forge script script/guard-deploy/Deploy_MerklDistributorGuard.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 *
 * SEI Mainnet addresses (from guard-registry docs):
 * - Merkl Distributor: 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae
 */
contract Deploy_MerklDistributorGuard is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\nDeploying MerklDistributorGuard...");
        MerklDistributorGuard guard = new MerklDistributorGuard(deployer, vaultAddress);
        console2.log("MerklDistributorGuard:", address(guard));

        vm.stopBroadcast();

        console2.log("\n=== Next Steps ===");
        console2.log("1) Set the guard on your vault for the Merkl distributor target:");
        console2.log("   vault.setGuard(MERKL_DISTRIBUTOR, MERKL_GUARD)");
        console2.log("2) Whitelist reward tokens on the guard (SEI/USDC, etc.):");
        console2.log("   guard.setToken(TOKEN, true)");
    }

    function test() public {
        // Required for forge coverage to work
    }
}


