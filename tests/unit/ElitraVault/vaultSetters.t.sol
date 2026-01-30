// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";
import { IBalanceUpdateHook } from "../../../src/interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook } from "../../../src/interfaces/IRedemptionHook.sol";
import { ManualBalanceUpdateHook } from "../../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../../src/hooks/HybridRedemptionHook.sol";
import { Errors } from "../../../src/libraries/Errors.sol";

contract VaultSetters_Test is ElitraVault_Base_Test {
    function test_SetBalanceUpdateHook_Success() public {
        ManualBalanceUpdateHook newHook = new ManualBalanceUpdateHook(owner);

        vm.expectEmit(true, true, true, true);
        emit IElitraVault.BalanceUpdateHookUpdated(address(balanceUpdateHook), address(newHook));

        vm.prank(owner);
        vault.setBalanceUpdateHook(newHook);

        assertEq(address(vault.balanceUpdateHook()), address(newHook));
    }

    function test_SetBalanceUpdateHook_RevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        vault.setBalanceUpdateHook(IBalanceUpdateHook(address(0)));
    }

    function test_SetBalanceUpdateHook_RevertsWhenUnauthorized() public {
        ManualBalanceUpdateHook newHook = new ManualBalanceUpdateHook(owner);
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        vault.setBalanceUpdateHook(newHook);
    }

    function test_SetRedemptionHook_Success() public {
        HybridRedemptionHook newHook = new HybridRedemptionHook();

        vm.expectEmit(true, true, true, true);
        emit IElitraVault.RedemptionHookUpdated(address(redemptionHook), address(newHook));

        vm.prank(owner);
        vault.setRedemptionHook(newHook);

        assertEq(address(vault.redemptionHook()), address(newHook));
    }

    function test_SetRedemptionHook_RevertsWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector));
        vault.setRedemptionHook(IRedemptionHook(address(0)));
    }

    function test_SetRedemptionHook_RevertsWhenUnauthorized() public {
        HybridRedemptionHook newHook = new HybridRedemptionHook();
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        vault.setRedemptionHook(newHook);
    }

    function test_SetNavFreshnessThreshold_Success() public {
        uint256 newThreshold = 1 hours;

        vm.expectEmit(true, true, true, true);
        emit IElitraVault.NavFreshnessThresholdUpdated(0, newThreshold);

        vm.prank(owner);
        vault.setNavFreshnessThreshold(newThreshold);

        assertEq(vault.navFreshnessThreshold(), newThreshold);
    }

    function test_SetNavFreshnessThreshold_ToZero_DisablesCheck() public {
        vm.prank(owner);
        vault.setNavFreshnessThreshold(0);

        assertEq(vault.navFreshnessThreshold(), 0);
    }

    function test_SetNavFreshnessThreshold_RevertsWhenUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        vault.setNavFreshnessThreshold(1 hours);
    }

    function test_Pause_Success() public {
        vm.prank(owner);
        vault.pause();

        assertTrue(vault.paused());
    }

    function test_Pause_RevertsWhenUnauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        vault.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        vault.pause();

        vm.prank(owner);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function test_Unpause_RevertsWhenUnauthorized() public {
        vm.prank(owner);
        vault.pause();

        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        vault.unpause();
    }

    function test_NavFreshnessThreshold_RevertsDepositWhenStale() public {
        address alice = createUser("alice");

        // Set threshold to 1 hour
        vm.prank(owner);
        vault.setNavFreshnessThreshold(1 hours);

        // Update balance to set lastTimestampUpdated
        vm.prank(owner);
        vault.updateBalance(1000e6);

        // Fast forward past threshold
        vm.warp(block.timestamp + 2 hours);

        // Deposit should revert due to stale NAV
        vm.expectRevert(abi.encodeWithSelector(Errors.StaleNav.selector));
        vm.prank(alice);
        vault.deposit(100e6, alice);
    }
}
