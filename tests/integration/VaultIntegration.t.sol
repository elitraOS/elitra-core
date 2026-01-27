// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { ManualBalanceUpdateHook } from "../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../src/hooks/HybridRedemptionHook.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract VaultIntegration_Test is Test {
    ElitraVault public vault;
    ManualBalanceUpdateHook public balanceUpdateHook;
    HybridRedemptionHook public redemptionHook;
    ERC20Mock public usdc;

    address public owner;
    address public alice;
    address public bob;
    address public strategy;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        strategy = makeAddr("strategy");

        // Deploy USDC mock
        usdc = new ERC20Mock();

        // Deploy adapters
        balanceUpdateHook = new ManualBalanceUpdateHook(owner);
        redemptionHook = new HybridRedemptionHook();

        // Deploy vault
        ElitraVault implementation = new ElitraVault();
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            address(usdc),
            owner,
            owner,
            address(0),
            address(balanceUpdateHook),
            address(redemptionHook),
            "Elitra USDC Vault",
            "eUSDC-v2"
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            initData
        );
        vault = ElitraVault(payable(address(proxy)));

        // Fund users
        usdc.mint(alice, 10_000e6);
        usdc.mint(bob, 10_000e6);

        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    // function test_FullLifecycle() public {
    //     // 1. Alice and Bob deposit
    //     vm.prank(alice);
    //     vault.deposit(5000e6, alice);

    //     vm.prank(bob);
    //     vault.deposit(3000e6, bob);

    //     assertEq(vault.totalAssets(), 8000e6);
    //     assertEq(vault.balanceOf(alice), 5000e6);
    //     assertEq(vault.balanceOf(bob), 3000e6);

    //     // 2. Simulate deploying to strategy
    //     vm.prank(address(vault));
    //     usdc.transfer(strategy, 7000e6);

    //     assertEq(usdc.balanceOf(address(vault)), 1000e6); // 1000 idle
    //     assertEq(usdc.balanceOf(strategy), 7000e6);

    //     // 3. Oracle reports strategy balance + yield
    //     vm.prank(owner);
    //     vault.updateBalance(7000e6); // Initialize PPS

    //     vm.roll(block.number + 1);
    //     vm.prank(owner);
    //     vault.updateBalance(7050e6); // 50 USDC yield (~0.7% increase)

    //     assertEq(vault.totalAssets(), 8050e6); // 1000 idle + 7050 strategy
    //     assertGt(vault.lastPricePerShare(), 1e18); // Price increased

    //     // 4. Alice requests instant redemption (should succeed, idle = 1000)
    //     vm.prank(alice);
    //     uint256 assetsOut = vault.requestRedeem(500e6, alice, alice);
    //     assertGt(assetsOut, 0); // Instant redemption
    //     assertGt(usdc.balanceOf(alice), 5000e6); // Got assets back

    //     // 5. Bob requests large redemption (should queue, idle < his request)
    //     vm.prank(bob);
    //     uint256 requestId = vault.requestRedeem(2000e6, bob, bob);
    //     assertEq(requestId, 0); // Queued (REQUEST_ID = 0)

    //     (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(bob);
    //     assertEq(pendingShares, 2000e6);
    //     assertGt(pendingAssets, 0);

    //     // 6. Strategy returns funds
    //     vm.prank(strategy);
    //     usdc.transfer(address(vault), pendingAssets);

    //     // 7. Owner fulfills Bob's redemption
    //     vm.prank(owner);
    //     vault.fulfillRedeem(bob, pendingShares, pendingAssets);

    //     assertGt(usdc.balanceOf(bob), 3000e6); // Bob got assets
    //     (uint256 remaining,) = vault.pendingRedeemRequest(bob);
    //     assertEq(remaining, 0); // Queue cleared
    // }
}
