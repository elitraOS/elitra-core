// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";

contract OracleIntegration_Test is ElitraVault_Base_Test {
    address public alice;
    address public strategy;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");
        strategy = makeAddr("strategy");

        // Alice deposits 1000 USDC
        vm.prank(alice);
        vault.deposit(1000e6, alice);

        // Simulate 1000 deployed to strategy
        vm.prank(address(vault));
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        asset.transfer(strategy, 1000e6);

        // Initialize lastPricePerShare with 1000e6 aggregated balance (1:1 ratio)
        vm.prank(owner);
        vault.updateBalance(1000e6);
    }

    function test_OracleUpdate_UpdatesAggregatedBalance() public {
        vm.roll(block.number + 1); // Move to next block

        // Update with 5 USDC yield (0.5% increase, within 1% threshold)
        vm.prank(owner);
        vault.updateBalance(1005e6);

        assertEq(vault.aggregatedUnderlyingBalances(), 1005e6);
        assertEq(vault.totalAssets(), 1005e6); // All assets deployed to strategy
    }

    function test_OracleUpdate_UpdatesPricePerShare() public {
        uint256 oldPPS = vault.lastPricePerShare();

        vm.roll(block.number + 1); // Move to next block

        // Update with 5 USDC yield (0.5% increase, within 1% threshold)
        vm.prank(owner);
        vault.updateBalance(1005e6);

        uint256 newPPS = vault.lastPricePerShare();
        assertGt(newPPS, oldPPS); // Price increased due to yield
    }

    function test_OracleUpdate_PausesVault_WhenPriceChangeExceedsThreshold() public {
        vm.roll(block.number + 1); // Move to next block

        // Try to update with huge balance increase (>1% threshold)
        vm.prank(owner);
        vault.updateBalance(50000e6); // 50x increase

        assertTrue(vault.paused()); // Vault should be paused
        assertEq(vault.aggregatedUnderlyingBalances(), 1000e6); // Balance should not be updated (remains at previous value)
    }

    function test_UpdateBalance_RevertsWhen_NotAuthorized() public {
        vm.roll(block.number + 1);

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(alice);
        vault.updateBalance(1000e6);
    }

    function test_UpdateBalance_DoesNotPauseAfterFeeDilution() public {
        // Configure max management rate (10% annualized) to force >1% dilution over time.
        vm.prank(owner);
        vault.updateFeeRates(1000, 0);

        // Accrue enough time so fee-minted shares dilute PPS by more than 1%.
        skip(40 days);

        vm.prank(owner);
        vault.takeFees();

        // `takeFees` should keep cached PPS in sync with dilution, avoiding false threshold trips.
        vm.roll(block.number + 1);
        vm.prank(owner);
        vault.updateBalance(1000e6);

        assertFalse(vault.paused());
    }
}
