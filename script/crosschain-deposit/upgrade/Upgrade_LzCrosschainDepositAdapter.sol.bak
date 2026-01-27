// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../../src/adapters/layerzero/LzCrosschainDepositAdapter.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title Upgrade_LzCrosschainDepositAdapter
 * @notice Upgrades the LayerZeroCrosschainDepositAdapter implementation using UUPS pattern
 * @dev Usage: forge script script/crosschain-deposit/Upgrade_LzCrosschainDepositAdapter.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key (must be owner of the proxy)
 * - LZ_ADAPTER_PROXY_ADDRESS: Address of the deployed proxy to upgrade
 * - LZ_ENDPOINT_V2: LayerZero endpoint contract address (required for constructor)
 */
contract Upgrade_LzCrosschainDepositAdapter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address adapterProxy = vm.envAddress("LZ_CROSSCHAIN_DEPOSIT_ADAPTER_ADDRESS");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT_V2");

        console2.log("=== Upgrade Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Adapter Proxy:", adapterProxy);
        console2.log("LayerZero Endpoint:", lzEndpoint);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new implementation
        console2.log("\n=== Deploying New LayerZeroCrosschainDepositAdapter Implementation ===");
        LayerZeroCrosschainDepositAdapter newImplementation = new LayerZeroCrosschainDepositAdapter(lzEndpoint);
        console2.log("New Implementation:", address(newImplementation));

        // 2. Upgrade the proxy using UUPS pattern
        console2.log("\n=== Upgrading Proxy (UUPS) ===");
        LayerZeroCrosschainDepositAdapter(payable(adapterProxy)).upgradeTo(address(newImplementation));

        vm.stopBroadcast();

        console2.log("\n=== Upgrade Summary ===");
        console2.log("Adapter Proxy:", adapterProxy);
        console2.log("New Implementation:", address(newImplementation));
        console2.log("\nUpgrade successful!");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
