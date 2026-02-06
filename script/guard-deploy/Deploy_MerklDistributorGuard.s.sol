// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MerklDistributorGuard } from "../../src/guards/sei/MerklDistributorGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

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
    // SEI Mainnet Merkl Distributor address
    address constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        console2.log("\nDeploying MerklDistributorGuard...");
        MerklDistributorGuard guard = new MerklDistributorGuard(vaultAddress);
        console2.log("MerklDistributorGuard:", address(guard));

        // Set guard for Merkl Distributor
        console2.log("\nSetting guard on vault...");
        vault.setGuard(MERKL_DISTRIBUTOR, address(guard));
        console2.log("  Set guard for Merkl Distributor:", MERKL_DISTRIBUTOR);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("MerklDistributorGuard:", address(guard));
        console2.log("Guard set on vault:", vaultAddress);
        console2.log("For Merkl Distributor:", MERKL_DISTRIBUTOR);
    }

    function test() public {
        // Required for forge coverage to work
    }
}


