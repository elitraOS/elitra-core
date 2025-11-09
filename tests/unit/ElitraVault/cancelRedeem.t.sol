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
        oracleAdapter.updateVaultBalance(vault, 2000e6);

        vm.roll(block.number + 1);
        vm.prank(alice);
        vault.requestRedeem(500e6, alice, alice);
    }

    function test_CancelRedeem_ReturnsShares() public {
        // Get actual pending values
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(alice);

        uint256 aliceSharesBefore = vault.balanceOf(alice);

        vm.prank(owner);
        vault.cancelRedeem(alice, pendingShares, pendingAssets);

        assertEq(vault.balanceOf(alice), aliceSharesBefore + pendingShares);

        // Pending redemption cleared
        (uint256 newPendingAssets, uint256 newPendingShares) = vault.pendingRedeemRequest(alice);
        assertEq(newPendingAssets, 0);
        assertEq(newPendingShares, 0);
    }

    function test_CancelRedeem_EmitsEvent() public {
        // Get actual pending values
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(alice);

        vm.expectEmit(true, true, true, true);
        emit IElitraVault.RequestCancelled(alice, pendingShares, pendingAssets);

        vm.prank(owner);
        vault.cancelRedeem(alice, pendingShares, pendingAssets);
    }
}
