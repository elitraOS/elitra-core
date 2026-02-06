// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { TokenGuard } from "../../src/guards/base/TokenGuard.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";

/**
 * @title Deploy_USDCTokenGuard
 * @notice Deploys TokenGuard for USDC with pre-whitelisted spenders from guard registry
 * @dev Usage: forge script script/guard-deploy/Deploy_USDCTokenGuard.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - VAULT_ADDRESS: The Elitra vault address that will be protected
 *
 * SEI Mainnet USDC address: 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1
 */
contract Deploy_USDCTokenGuard is Script {
    // SEI Mainnet USDC address
    address constant USDC = 0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1;

    // Whitelisted spenders from guard-registry/sei/usdc.md
    address constant YEI_POOL = 0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638;
    address constant TAKARA_USDC_POOL = 0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0;
    address constant MORPHO_USDC_VAULT = 0x015F10a56e97e02437D294815D8e079e1903E41C;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");

        console2.log("\n=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Vault:", vaultAddress);

        vm.startBroadcast(deployerPrivateKey);

        ElitraVault vault = ElitraVault(payable(vaultAddress));

        console2.log("\nDeploying TokenGuard for USDC...");
        TokenGuard guard = new TokenGuard(deployer);
        console2.log("TokenGuard:", address(guard));

        // Whitelist spenders from guard registry
        console2.log("\nWhitelisting spenders...");
        guard.setSpender(YEI_POOL, true);
        console2.log("  - Yei Pool:", YEI_POOL);

        guard.setSpender(TAKARA_USDC_POOL, true);
        console2.log("  - Takara USDC Pool:", TAKARA_USDC_POOL);

        guard.setSpender(MORPHO_USDC_VAULT, true);
        console2.log("  - Morpho USDC Vault:", MORPHO_USDC_VAULT);

        // Set guard for USDC token
        console2.log("\nSetting guard on vault...");
        vault.setGuard(USDC, address(guard));
        console2.log("  Set guard for USDC:", USDC);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("TokenGuard:", address(guard));
        console2.log("Guard set on vault:", vaultAddress);
        console2.log("For USDC:", USDC);
        console2.log("\nWhitelisted spenders:");
        console2.log("  - Yei Pool:", YEI_POOL);
        console2.log("  - Takara USDC Pool:", TAKARA_USDC_POOL);
        console2.log("  - Morpho USDC Vault:", MORPHO_USDC_VAULT);

        console2.log("\n=== Next Steps ===");
        console2.log("Add more spenders as needed:");
        console2.log("  cast send", address(guard), "'setSpender(address,bool)' <SPENDER> true");
    }

    function test() public {
        // Required for forge coverage to work
    }
}
