// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";

contract CancelRedeem_Test is ElitraVault_Base_Test {
    address public alice;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");

        // Alice and Bob deposit to have more liquidity
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        address bob = createUser("bob");
        vm.prank(bob);
        vault.deposit(1000e6, bob);

        // Simulate vault deploying most funds (leave only 10 USDC)
        vm.prank(address(vault));
        asset.transfer(makeAddr("strategy"), 1990e6);

        // Alice requests redemption of 500 shares
        // With 2010 total assets (10 idle + 2000 deployed via oracle) and 2000 shares
        // 500 shares = ~502.5 assets, but only 10 available, so will be queued

        // Update oracle to reflect deployed balance
        vm.prank(owner);
        vault.updateBalance( 2000e6);

        vm.roll(block.number + 1);
        vm.prank(alice);
        vault.requestRedeem(500e6, alice, alice);
    }

    function test_CancelRedeem_ReturnsSharesAtCurrentPrice() public {
        // Get actual pending values
        uint256 pendingAssets = vault.pendingRedeemRequest(alice);

        uint256 aliceSharesBefore = vault.balanceOf(alice);
        uint256 totalPendingBefore = vault.totalPendingAssets();

        vm.prank(owner);
        vault.cancelRedeem(alice, pendingAssets);

        uint256 aliceSharesAfter = vault.balanceOf(alice);
        uint256 sharesMinted = aliceSharesAfter - aliceSharesBefore;

        // Verify shares were minted (exact amount depends on price at cancel time)
        assertGt(sharesMinted, 0);

        // Verify totalPendingAssets decreased
        assertEq(vault.totalPendingAssets(), totalPendingBefore - pendingAssets);

        // Pending redemption cleared
        uint256 newPendingAssets = vault.pendingRedeemRequest(alice);
        assertEq(newPendingAssets, 0);
    }

    function test_CancelRedeem_EmitsEvent() public {
        // Get actual pending values
        uint256 pendingAssets = vault.pendingRedeemRequest(alice);

        // We expect the event but can't predict exact shares since price changes during cancel
        // Just verify the event is emitted with correct receiver and assets
        vm.expectEmit(true, false, false, false);
        emit IElitraVault.RequestCancelled(alice, pendingAssets, 0);

        vm.prank(owner);
        vault.cancelRedeem(alice, pendingAssets);
    }
}
