// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ElitraVaultFactory } from "../../src/ElitraVaultFactory.sol";
import { ManualBalanceUpdateHook } from "../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../src/hooks/HybridRedemptionHook.sol";

contract Deploy_Vault_Via_Factory is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);

        // Required System Contracts
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address feeRegistryAddress = vm.envAddress("FEE_REGISTRY");
        
        // Vault Config
        address assetAddress = vm.envAddress("ASSET_ADDRESS");
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        uint256 initialSeed = vm.envUint("INITIAL_SEED"); // Must be > 1e6
        address seedReceiver = vm.envOr("SEED_RECEIVER", owner);
        bytes32 salt = bytes32(vm.envUint("SALT")); // Default 0 if not set, but unique per sender

        console2.log("Deployer:", deployer);
        console2.log("Factory:", factoryAddress);
        console2.log("FeeRegistry:", feeRegistryAddress);
        console2.log("Asset:", assetAddress);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Hooks
        console2.log("Deploying Hooks...");
        ManualBalanceUpdateHook balanceHook = new ManualBalanceUpdateHook(owner);
        HybridRedemptionHook redemptionHook = new HybridRedemptionHook();
        
        console2.log("BalanceHook:", address(balanceHook));
        console2.log("RedemptionHook:", address(redemptionHook));

        // 2. Approve Asset for Seeding
        // Note: The deployer must hold `initialSeed` of `assetAddress`
        IERC20 asset = IERC20(assetAddress);
        asset.approve(factoryAddress, initialSeed);

        // 3. Deploy Vault via Factory
        console2.log("Calling factory.deployAndSeed...");
        ElitraVaultFactory factory = ElitraVaultFactory(factoryAddress);

        (address vault, ) = factory.deployAndSeed(
            asset,
            owner,
            feeRegistryAddress,
            balanceHook,
            redemptionHook,
            name,
            symbol,
            salt,
            initialSeed,
            seedReceiver
        );

        vm.stopBroadcast();

        console2.log("\n=== Vault Deployed ===");
        console2.log("Vault Address:", vault);
    }
}
