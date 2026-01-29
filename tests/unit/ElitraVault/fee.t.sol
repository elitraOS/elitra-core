// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";
import { Errors } from "../../../src/libraries/Errors.sol";

contract Fee_Test is ElitraVault_Base_Test {
    address public alice;
    address public feeCollector;

    // 0.5% fee = 5e15 (0.005 * 1e18)
    uint256 constant HALF_PERCENT_FEE = 5e15;
    // 1% fee = 1e16 (0.01 * 1e18)
    uint256 constant ONE_PERCENT_FEE = 1e16;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");
        feeCollector = makeAddr("feeCollector");
    }

    // ========================================= SET FEE TESTS =========================================

    function test_SetDepositFee_Success() public {
        vm.prank(owner);
        vault.setDepositFee(HALF_PERCENT_FEE);

        assertEq(vault.feeOnDeposit(), HALF_PERCENT_FEE);
    }

    function test_SetDepositFee_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IElitraVault.DepositFeeUpdated(0, HALF_PERCENT_FEE);

        vm.prank(owner);
        vault.setDepositFee(HALF_PERCENT_FEE);
    }

    function test_SetDepositFee_RevertsIfExceedsMax() public {
        // Max fee is 1% (1e16), try to set 2%
        uint256 tooHighFee = 2e16;

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidFee.selector);
        vault.setDepositFee(tooHighFee);
    }

    function test_SetWithdrawFee_Success() public {
        vm.prank(owner);
        vault.setWithdrawFee(HALF_PERCENT_FEE);

        assertEq(vault.feeOnWithdraw(), HALF_PERCENT_FEE);
    }

    function test_SetWithdrawFee_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IElitraVault.WithdrawFeeUpdated(0, HALF_PERCENT_FEE);

        vm.prank(owner);
        vault.setWithdrawFee(HALF_PERCENT_FEE);
    }

    function test_SetWithdrawFee_RevertsIfExceedsMax() public {
        uint256 tooHighFee = 2e16;

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidFee.selector);
        vault.setWithdrawFee(tooHighFee);
    }

    function test_SetFeeRecipient_Success() public {
        vm.prank(owner);
        vault.setFeeRecipient(feeCollector);

        assertEq(vault.feeRecipient(), feeCollector);
    }

    function test_SetFeeRecipient_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IElitraVault.FeeRecipientUpdated(owner, feeCollector);

        vm.prank(owner);
        vault.setFeeRecipient(feeCollector);
    }

    // ========================================= DEPOSIT FEE TESTS =========================================

    function test_Deposit_AccumulatesFeeInPendingFees() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        uint256 depositAmount = 1000e6;

        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        // Fee should be accumulated
        // Fee calculation: assets * fee / (fee + 1e18)
        // = 1000e6 * 1e16 / (1e16 + 1e18)
        // = 1000e6 * 1e16 / 1.01e18
        // ≈ 9.9e6 (approximately 0.99% of 1000e6)
        uint256 pendingFees = vault.pendingFees();
        assertGt(pendingFees, 0);
        
        // Fee should be roughly 1% of deposit (slightly less due to formula)
        // 1% of 1000e6 = 10e6, but actual is ~9.9e6
        assertApproxEqRel(pendingFees, 10e6, 0.02e18); // Within 2% tolerance
    }

    function test_Deposit_FeesExcludedFromTotalAssets() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        uint256 depositAmount = 1000e6;

        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        uint256 pendingFees = vault.pendingFees();
        uint256 vaultBalance = asset.balanceOf(address(vault));
        uint256 totalAssets = vault.totalAssets();

        // totalAssets should equal vaultBalance - pendingFees
        assertEq(totalAssets, vaultBalance - pendingFees);
    }

    function test_Deposit_SharesCalculatedOnNetAmount() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        uint256 depositAmount = 1000e6;

        vm.prank(alice);
        uint256 shares = vault.deposit(depositAmount, alice);

        // Shares should be less than deposit amount due to fee
        // Net deposit = 1000e6 - fee ≈ 990e6
        assertLt(shares, depositAmount);
        assertApproxEqRel(shares, 990e6, 0.02e18); // Within 2% of expected
    }

    function test_PreviewDeposit_ReturnsCorrectShares() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        uint256 depositAmount = 1000e6;
        uint256 previewedShares = vault.previewDeposit(depositAmount);

        vm.prank(alice);
        uint256 actualShares = vault.deposit(depositAmount, alice);

        // Preview should match actual (or be slightly less due to rounding)
        assertEq(previewedShares, actualShares);
    }

    // ========================================= WITHDRAW FEE TESTS =========================================

    function test_InstantRedeem_AccumulatesFeeInPendingFees() public {
        // Alice deposits first (no fee)
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        // Set 1% withdraw fee
        vm.prank(owner);
        vault.setWithdrawFee(ONE_PERCENT_FEE);

        uint256 aliceShares = vault.balanceOf(alice);
        uint256 aliceBalanceBefore = asset.balanceOf(alice);

        // Instant redeem
        vm.prank(alice);
        uint256 assetsReceived = vault.requestRedeem(aliceShares, alice, alice);

        uint256 pendingFees = vault.pendingFees();
        
        // Fee should be accumulated
        assertGt(pendingFees, 0);
        
        // Alice should receive less than her shares value due to fee
        uint256 aliceBalanceAfter = asset.balanceOf(alice);
        uint256 actualReceived = aliceBalanceAfter - aliceBalanceBefore;
        
        // The actual received should be approximately what previewRedeem returned
        // (may differ slightly due to how redemption hook processes it)
        assertGt(actualReceived, 0);
        assertLt(actualReceived, 1000e6); // Less than original deposit due to fee
        
        // Fee + received should approximately equal original deposit
        assertApproxEqRel(pendingFees + actualReceived, 1000e6, 0.02e18);
    }

    function test_PreviewRedeem_ReturnsCorrectAssets() public {
        // Alice deposits first (no fee)
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        // Set 1% withdraw fee
        vm.prank(owner);
        vault.setWithdrawFee(ONE_PERCENT_FEE);

        uint256 aliceShares = vault.balanceOf(alice);
        uint256 previewedAssets = vault.previewRedeem(aliceShares);

        vm.prank(alice);
        uint256 actualAssets = vault.requestRedeem(aliceShares, alice, alice);

        // Preview should match actual
        assertEq(previewedAssets, actualAssets);
    }

    // ========================================= CLAIM FEES TESTS =========================================

    function test_ClaimFees_TransfersToRecipient() public {
        // Setup: set fees and recipient
        vm.startPrank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);
        vault.setFeeRecipient(feeCollector);
        vm.stopPrank();

        // Alice deposits to generate fees
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        uint256 pendingFees = vault.pendingFees();
        assertGt(pendingFees, 0);

        uint256 feeCollectorBalanceBefore = asset.balanceOf(feeCollector);

        // Claim fees
        vm.prank(owner);
        vault.claimFees();

        uint256 feeCollectorBalanceAfter = asset.balanceOf(feeCollector);

        // Fee collector should have received the fees
        assertEq(feeCollectorBalanceAfter - feeCollectorBalanceBefore, pendingFees);
        
        // Pending fees should be zero
        assertEq(vault.pendingFees(), 0);
    }

    function test_ClaimFees_EmitsEvent() public {
        // Setup
        vm.startPrank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);
        vault.setFeeRecipient(feeCollector);
        vm.stopPrank();

        vm.prank(alice);
        vault.deposit(1000e6, alice);

        uint256 pendingFees = vault.pendingFees();

        vm.expectEmit(true, true, true, true);
        emit IElitraVault.FeesClaimed(feeCollector, pendingFees);

        vm.prank(owner);
        vault.claimFees();
    }

    function test_ClaimFees_RevertsIfNoFees() public {
        vm.startPrank(owner);
        vault.setFeeRecipient(feeCollector);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidAssetsAmount.selector);
        vault.claimFees();
    }

    function test_ClaimFees_UsesDefaultRecipient() public {
        // Setup: set fees, default recipient is owner
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        // Alice deposits to generate fees
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        uint256 pendingFees = vault.pendingFees();
        uint256 ownerBalanceBefore = asset.balanceOf(owner);

        // Claim fees to default recipient
        vm.prank(owner);
        vault.claimFees();

        uint256 ownerBalanceAfter = asset.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, pendingFees);
        assertEq(vault.pendingFees(), 0);
    }

    // ========================================= FEE DOES NOT AFFECT SHARE PRICE =========================================

    function test_Fee_DoesNotAffectSharePrice() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        // Alice deposits
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        uint256 pricePerShareAfterAlice = vault.totalAssets() * 1e18 / vault.totalSupply();

        // Bob deposits
        address bob = createUser("bob");
        vm.prank(bob);
        vault.deposit(1000e6, bob);

        uint256 pricePerShareAfterBob = vault.totalAssets() * 1e18 / vault.totalSupply();

        // Price per share should remain constant (fees don't affect it)
        assertEq(pricePerShareAfterAlice, pricePerShareAfterBob);
    }

    function test_MultipleDeposits_AccumulateFees() public {
        vm.prank(owner);
        vault.setDepositFee(ONE_PERCENT_FEE);

        // Multiple users deposit
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        uint256 feesAfterAlice = vault.pendingFees();

        address bob = createUser("bob");
        vm.prank(bob);
        vault.deposit(2000e6, bob);

        uint256 feesAfterBob = vault.pendingFees();

        // Fees should accumulate
        assertGt(feesAfterBob, feesAfterAlice);
        
        // Bob's fee should be roughly 2x Alice's (he deposited 2x)
        uint256 bobFee = feesAfterBob - feesAfterAlice;
        assertApproxEqRel(bobFee, feesAfterAlice * 2, 0.02e18);
    }
}
