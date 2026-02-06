// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { TokenGuard } from "../../src/guards/base/TokenGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_WSEITokenGuard
 * @notice Deploys TokenGuard for WSEI with pre-whitelisted spenders from guard registry
 * @dev Usage: forge script script/guard-deploy/Deploy_WSEITokenGuard.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 *
 * SEI Mainnet WSEI address: 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7
 */
contract Deploy_WSEITokenGuard is Script {
    // SEI Mainnet WSEI address
    address constant WSEI = 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7;

    // Whitelisted spenders from guard-registry/sei/wsei.md
    address constant YEI_POOL = 0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638;
    address constant TAKARA_SEI_POOL = 0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2;
    address constant MORPHO_SEI_VAULT = 0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        console2.log("\nDeploying TokenGuard for WSEI...");
        TokenGuard guard = new TokenGuard(deployer);
        console2.log("TokenGuard:", address(guard));

        // Whitelist spenders from guard registry
        console2.log("\nWhitelisting spenders...");
        guard.setSpender(YEI_POOL, true);
        console2.log("  - Yei Pool:", YEI_POOL);

        guard.setSpender(TAKARA_SEI_POOL, true);
        console2.log("  - Takara SEI Pool:", TAKARA_SEI_POOL);

        guard.setSpender(MORPHO_SEI_VAULT, true);
        console2.log("  - Morpho SEI Vault:", MORPHO_SEI_VAULT);

        // Set guard for WSEI token
        console2.log("\nSetting guard on vault...");
        vault.setGuard(WSEI, address(guard));
        console2.log("  Set guard for WSEI:", WSEI);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("TokenGuard:", address(guard));
        console2.log("Guard set on vault:", vaultAddress);
        console2.log("For WSEI:", WSEI);
        console2.log("\nWhitelisted spenders:");
        console2.log("  - Yei Pool:", YEI_POOL);
        console2.log("  - Takara SEI Pool:", TAKARA_SEI_POOL);
        console2.log("  - Morpho SEI Vault:", MORPHO_SEI_VAULT);

        console2.log("\n=== Next Steps ===");
        console2.log("Add more spenders as needed:");
        console2.log("  cast send", address(guard), "'setSpender(address,bool)' <SPENDER> true");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
