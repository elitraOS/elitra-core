// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { YeiIncentivesGuard } from "../../src/guards/sei/YeiIncentivesGuard.sol";

/**
 * @title WhitelistYeiIncentivesAsset
 * @notice Whitelists an asset in the YeiIncentivesGuard
 * @dev Usage: forge script script/guard-config/WhitelistYeiIncentivesAsset.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Owner private key
 * - GUARD_ADDRESS: The YeiIncentivesGuard address
 * - ASSET_ADDRESS: The asset address to whitelist
 */
contract WhitelistYeiIncentivesAsset is Script {
    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        address guardAddress = vm.envAddress("GUARD_ADDRESS");
        address assetAddress = vm.envAddress("ASSET_ADDRESS");

        console2.log("\n=== Whitelist Configuration ===");
        console2.log("Guard Address:", guardAddress);
        console2.log("Asset Address:", assetAddress);

        vm.startBroadcast(ownerPrivateKey);

        YeiIncentivesGuard guard = YeiIncentivesGuard(guardAddress);
        
        // Check current whitelist status
        bool currentStatus = guard.whitelistedAssets(assetAddress);
        console2.log("Current whitelist status:", currentStatus);

        // Whitelist the asset
        guard.setAsset(assetAddress, true);
        console2.log("Asset whitelisted successfully");

        // Verify whitelist status
        bool newStatus = guard.whitelistedAssets(assetAddress);
        console2.log("New whitelist status:", newStatus);

        vm.stopBroadcast();

        console2.log("\n=== Whitelist Complete ===");
    }

    function test() public {
        // Required for forge coverage to work
    }
}

