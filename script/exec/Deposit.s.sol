// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";

/**
 * @title Deposit
 * @notice Script to deposit assets into ElitraVault
 * @dev Usage: forge script script/Deposit.s.sol --rpc-url $RPC_URL --broadcast
 *
 * Required environment variables:
 * - PRIVATE_KEY: Depositor private key
 * - VAULT_ADDRESS: The ElitraVault proxy address
 * - ASSET_ADDRESS: The underlying asset (e.g., USDT0) address
 * - DEPOSIT_AMOUNT: Amount to deposit (in wei/smallest unit)
 * - RECEIVER: (optional) Address to receive shares, defaults to depositor
 */
contract Deposit is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address depositor = vm.addr(deployerPrivateKey);

        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address assetAddress = vm.envAddress("ASSET_ADDRESS");
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT");
        address receiver = vm.envOr("RECEIVER", depositor);

        IERC20 asset = IERC20(assetAddress);
        IERC4626Upgradeable vault = IERC4626Upgradeable(vaultAddress);

        console2.log("=== Deposit Configuration ===");
        console2.log("Depositor:", depositor);
        console2.log("Vault:", vaultAddress);
        console2.log("Asset:", assetAddress);
        console2.log("Deposit Amount:", depositAmount);
        console2.log("Receiver:", receiver);

        // Check balances before
        uint256 assetBalanceBefore = asset.balanceOf(depositor);
        uint256 shareBalanceBefore = vault.balanceOf(receiver);

        console2.log("\n=== Before Deposit ===");
        console2.log("Depositor Asset Balance:", assetBalanceBefore);
        console2.log("Receiver Share Balance:", shareBalanceBefore);

        require(assetBalanceBefore >= depositAmount, "Insufficient asset balance");

        // Preview deposit
        uint256 expectedShares = vault.previewDeposit(depositAmount);
        console2.log("Expected Shares:", expectedShares);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Approve vault to spend assets
        console2.log("\n=== Executing Deposit ===");
        console2.log("Step 1: Approving vault to spend assets...");
        asset.approve(vaultAddress, depositAmount);

        // 2. Deposit assets
        console2.log("Step 2: Depositing assets...");
        uint256 sharesReceived = vault.deposit(depositAmount, receiver);

        vm.stopBroadcast();

        // Check balances after
        uint256 assetBalanceAfter = asset.balanceOf(depositor);
        uint256 shareBalanceAfter = vault.balanceOf(receiver);

        console2.log("\n=== After Deposit ===");
        console2.log("Depositor Asset Balance:", assetBalanceAfter);
        console2.log("Receiver Share Balance:", shareBalanceAfter);
        console2.log("Shares Received:", sharesReceived);

        console2.log("\n=== Summary ===");
        console2.log("Assets Deposited:", assetBalanceBefore - assetBalanceAfter);
        console2.log("Shares Minted:", shareBalanceAfter - shareBalanceBefore);
    }

    function test() public {
        // Required for forge coverage to work
    }
}
