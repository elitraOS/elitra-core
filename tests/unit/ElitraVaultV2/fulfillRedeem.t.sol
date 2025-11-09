// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVaultV2_Base_Test } from "./Base.t.sol";
import { IElitraVaultV2 } from "../../../src/interfaces/IElitraVaultV2.sol";

contract FulfillRedeem_Test is ElitraVaultV2_Base_Test {
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

    function test_FulfillRedeem_TransfersAssets() public {
        // Get actual pending values
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(alice);

        // Simulate strategy returning funds
        address strategy = makeAddr("strategy");
        vm.prank(strategy);
        asset.transfer(address(vault), pendingAssets);

        uint256 aliceBalanceBefore = asset.balanceOf(alice);

        vm.prank(owner);
        vault.fulfillRedeem(alice, pendingShares, pendingAssets);

        assertEq(asset.balanceOf(alice), aliceBalanceBefore + pendingAssets);

        // Pending redemption cleared
        (uint256 newPendingAssets, uint256 newPendingShares) = vault.pendingRedeemRequest(alice);
        assertEq(newPendingAssets, 0);
        assertEq(newPendingShares, 0);
    }

    function test_FulfillRedeem_EmitsEvent() public {
        // Get actual pending values
        (uint256 pendingAssets, uint256 pendingShares) = vault.pendingRedeemRequest(alice);

        address strategy = makeAddr("strategy");
        vm.prank(strategy);
        asset.transfer(address(vault), pendingAssets);

        vm.expectEmit(true, true, true, true);
        emit IElitraVaultV2.RequestFulfilled(alice, pendingShares, pendingAssets);

        vm.prank(owner);
        vault.fulfillRedeem(alice, pendingShares, pendingAssets);
    }
}
