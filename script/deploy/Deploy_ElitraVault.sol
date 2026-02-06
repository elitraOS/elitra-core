// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { ElitraVaultFactory } from "../../src/ElitraVaultFactory.sol";
import { ManualBalanceUpdateHook } from "../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../src/hooks/HybridRedemptionHook.sol";
import { FeeRegistry } from "../../src/fees/FeeRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        address asset = vm.envAddress("ASSET_ADDRESS"); // USDC address
        address factory = vm.envAddress("ELITRA_VAULT_FACTORY_ADDRESS");
        address feeRegistry = vm.envAddress("FEE_REGISTRY_ADDRESS");

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Asset:", asset);
        console2.log("Factory:", factory);
        console2.log("Fee Registry:", feeRegistry);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy adapters
        console2.log("Deploying ManualBalanceUpdateHook...");
        ManualBalanceUpdateHook balanceHook = new ManualBalanceUpdateHook(owner);
        console2.log("ManualBalanceUpdateHook:", address(balanceHook));

        console2.log("Deploying HybridRedemptionHook...");
        HybridRedemptionHook redemptionHook = new HybridRedemptionHook();
        console2.log("HybridRedemptionHook:", address(redemptionHook));

        // 2. Deploy vault via factory
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        // make salt random bytes 32
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, deployer));
        uint256 initialSeed = 1000001;

        console2.log("Name:", name);
        console2.log("Symbol:", symbol);
        console2.log("Salt:", vm.toString(salt));
        console2.log("Initial Seed:", initialSeed);

        // Approve factory to pull seed assets
        console2.log("Approving factory to spend seed assets...");
        IERC20(asset).approve(factory, initialSeed);

        console2.log("Deploying vault via factory...");
        ElitraVaultFactory(factory).deployAndSeed(
            IERC20(asset),
            owner,
            feeRegistry,
            balanceHook,
            redemptionHook,
            name,
            symbol,
            salt,
            initialSeed,
            owner // seed receiver is owner
        );

        // Predict vault address to verify deployment
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            ElitraVaultFactory(factory).owner(),
            feeRegistry,
            address(balanceHook),
            address(redemptionHook),
            name,
            symbol
        );
        address vaultAddress = ElitraVaultFactory(factory).predictAddress(salt, deployer, initData);
        console2.log("Vault deployed at:", vaultAddress);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("ManualBalanceUpdateHook:", address(balanceHook));
        console2.log("HybridRedemptionHook:", address(redemptionHook));
        console2.log("ElitraVault:", vaultAddress);
    }

    function test() public {
        // Required for forge coverage to work
    }
}
