// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { MorphoVaultGuard } from "../../src/guards/sei/MorphoVaultGuard.sol";

/**
 * @title Deploy_MorphoGuards
 * @notice Deploys MorphoVaultGuard for SEI network ERC4626/Morpho vaults
 * @dev Usage: forge script script/guard-deploy/Deploy_MorphoGuards.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 *
 * SEI Mainnet addresses:
 * - Morpho SEI Vault: 0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923
 * - Morpho USDC Vault: 0x015f10a56e97e02437d294815d8e079e1903e41c
 */
contract Deploy_MorphoGuards is Script {
    // SEI Mainnet Morpho vault addresses
    address constant MORPHO_SEI_VAULT = 0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923;
    address constant MORPHO_USDC_VAULT = 0x015F10a56e97e02437D294815D8e079e1903E41C;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MorphoVaultGuard
        console2.log("\nDeploying MorphoVaultGuard...");
        MorphoVaultGuard morphoGuard = new MorphoVaultGuard(deployer, vaultAddress);
        console2.log("MorphoVaultGuard:", address(morphoGuard));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("MorphoVaultGuard:", address(morphoGuard));

        console2.log("\n=== Next Steps ===");
        console2.log("Set guards on your vault for each Morpho vault:");
        console2.log("  vault.setGuard(MORPHO_SEI_VAULT, MORPHO_GUARD)");
        console2.log("  vault.setGuard(MORPHO_USDC_VAULT, MORPHO_GUARD)");
        console2.log("");
        console2.log("Morpho SEI Vault:", MORPHO_SEI_VAULT);
        console2.log("Morpho USDC Vault:", MORPHO_USDC_VAULT);
    }

    function test() public {
        // Required for forge coverage to work
    }
}
