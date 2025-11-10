// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";

contract RequestRedeem_Test is ElitraVault_Base_Test {
    address public alice;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");

        // Alice deposits 1000 USDC
        vm.prank(alice);
        vault.deposit(1000e6, alice);
    }

    function test_InstantRedeem_WhenSufficientLiquidity() public {
        vm.prank(alice);
        uint256 assetsOut = vault.requestRedeem(500e6, alice, alice);

        // Should return assets (instant) - 1:1 ratio since no price change
        assertEq(assetsOut, 500e6);
        assertEq(vault.balanceOf(alice), 500e6); // 500 shares remaining
        assertEq(vault.totalAssets(), 500e6); // 500 assets remaining in vault
    }

    function test_QueuedRedeem_WhenInsufficientLiquidity() public {
        // Bob also deposits to have more total supply
        address bob = createUser("bob");
        vm.prank(bob);
        vault.deposit(1000e6, bob);

        // Simulate vault deploying funds using oracle to set aggregated balance
        // Transfer 1800 out of 2000 total assets
        vm.prank(address(vault));
        asset.transfer(makeAddr("strategy"), 1800e6);

        // Now vault only has 200 USDC idle (2000 total - 1800 deployed)
        // Update oracle to reflect this (aggregatedBalance = 1800)
        vm.prank(owner);
        vault.updateBalance( 1800e6);

        // Alice wants to redeem 500 shares
        // With 2000 totalAssets and 2000 shares, 500 shares = 500 assets
        // But only 200 is available, so should queue
        vm.prank(alice);
        uint256 result = vault.requestRedeem(500e6, alice, alice);

        // Should return REQUEST_ID (queued)
        assertEq(result, 0); // REQUEST_ID

        // Check pending redemption
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(alice);
        assertEq(pendingShares, 500e6);
        assertGt(pendingAssets, 0); // Assets calculated at redemption time

        // Shares transferred to vault
        assertEq(vault.balanceOf(address(vault)), 500e6);
        assertEq(vault.balanceOf(alice), 500e6);
    }
}
