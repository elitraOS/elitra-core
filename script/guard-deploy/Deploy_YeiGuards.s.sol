// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { YeiPoolGuard } from "../../src/guards/sei/YeiPoolGuard.sol";
import { YeiIncentivesGuard } from "../../src/guards/sei/YeiIncentivesGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_YeiGuards
 * @notice Deploys YeiPoolGuard and YeiIncentivesGuard for SEI network
 * @dev Usage: forge script script/guard-deploy/Deploy_YeiGuards.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 *
 * SEI Mainnet addresses:
 * - Yei Pool: 0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638
 * - Yei Incentives Controller: 0x60485C5E5E3D535B16CC1bd2C9243C7877374259
 */
contract Deploy_YeiGuards is Script {
    // SEI Mainnet Yei addresses
    address constant YEI_POOL = 0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638;
    address constant YEI_INCENTIVES_CONTROLLER = 0x60485C5E5E3D535B16CC1bd2C9243C7877374259;

    // Common SEI assets
    address constant WSEI = 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7;
    address constant USDC = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        // Deploy YeiPoolGuard
        console2.log("\nDeploying YeiPoolGuard...");
        YeiPoolGuard poolGuard = new YeiPoolGuard(deployer, vaultAddress);
        console2.log("YeiPoolGuard:", address(poolGuard));

        // Whitelist common assets
        poolGuard.setAsset(WSEI, true);
        poolGuard.setAsset(USDC, true);
        console2.log("Whitelisted WSEI and USDC");

        // Deploy YeiIncentivesGuard
        console2.log("\nDeploying YeiIncentivesGuard...");
        YeiIncentivesGuard incentivesGuard = new YeiIncentivesGuard(deployer);
        console2.log("YeiIncentivesGuard:", address(incentivesGuard));

        // Set guards for Yei
        console2.log("\nSetting guards on vault...");
        vault.setGuard(YEI_POOL, address(poolGuard));
        console2.log("  Set guard for Yei Pool:", YEI_POOL);

        vault.setGuard(YEI_INCENTIVES_CONTROLLER, address(incentivesGuard));
        console2.log("  Set guard for Yei Incentives Controller:", YEI_INCENTIVES_CONTROLLER);

        // Whitelist common assets
        console2.log("\nWhitelisting common assets...");
        incentivesGuard.setAsset(USDC, true);
        console2.log("  Whitelisted WSEI and USDC");
        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("YeiPoolGuard:", address(poolGuard));
        console2.log("YeiIncentivesGuard:", address(incentivesGuard));
        console2.log("Guards set on vault:", vaultAddress);
    }

    function test() public {
        // Required for forge coverage to work
    }
}
