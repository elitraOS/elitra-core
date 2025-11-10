// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ElitraVault } from "../src/ElitraVault.sol";
import { ManualBalanceUpdateHook } from "../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../src/hooks/HybridRedemptionHook.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER", deployer);
        address proxyAdmin = vm.envOr("PROXY_ADMIN", deployer);
        address asset = vm.envAddress("ASSET_ADDRESS"); // USDC address

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("Asset:", asset);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy adapters
        console2.log("Deploying ManualBalanceUpdateHook...");
        ManualBalanceUpdateHook oracleAdapter = new ManualBalanceUpdateHook(owner);
        console2.log("ManualBalanceUpdateHook:", address(oracleAdapter));

        console2.log("Deploying HybridRedemptionHook...");
        HybridRedemptionHook redemptionStrategy = new HybridRedemptionHook();
        console2.log("HybridRedemptionHook:", address(redemptionStrategy));

        // 2. Deploy vault implementation
        console2.log("Deploying ElitraVault implementation...");
        ElitraVault implementation = new ElitraVault();
        console2.log("ElitraVault implementation:", address(implementation));

        // 3. Deploy proxy
        string memory name = "Elitra USDC Vault";
        string memory symbol = "eUSDC";

        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            address(oracleAdapter),
            address(redemptionStrategy),
            name,
            symbol
        );

        console2.log("Deploying TransparentUpgradeableProxy...");
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            proxyAdmin,
            initData
        );
        console2.log("Proxy (ElitraVault):", address(proxy));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("ManualBalanceUpdateHook:", address(oracleAdapter));
        console2.log("HybridRedemptionHook:", address(redemptionStrategy));
        console2.log("ElitraVault implementation:", address(implementation));
        console2.log("ElitraVault proxy:", address(proxy));
    }

    function test() public {
        // Required for forge coverage to work
    }
}
