// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { FeeRegistry } from "../../../src/fees/FeeRegistry.sol";

/**
 * @title FeeRegistryTest
 * @notice Comprehensive tests for FeeRegistry contract.
 */
contract FeeRegistryTest is Test {
    FeeRegistry public feeRegistry;

    address public owner;
    address public protocolFeeReceiver;
    address public alice;
    address public bob;
    address public vault;

    // Constants
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    function setUp() public {
        owner = makeAddr("owner");
        protocolFeeReceiver = makeAddr("protocolFeeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vault = makeAddr("vault");

        // Deploy FeeRegistry with owner and initial receiver
        vm.prank(owner);
        feeRegistry = new FeeRegistry(owner, protocolFeeReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsOwner() public {
        assertEq(feeRegistry.owner(), owner);
    }

    function test_Constructor_SetsProtocolFeeReceiver() public {
        assertEq(feeRegistry.protocolFeeReceiver(), protocolFeeReceiver);
    }

    function test_Constructor_RevertsWhen_ZeroReceiver() public {
        vm.expectRevert("receiver zero");
        vm.prank(owner);
        new FeeRegistry(owner, address(0));
    }

    function test_Constructor_InitializesGlobalRateToZero() public {
        assertEq(feeRegistry.protocolFeeRateBpsGlobal(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                      SET_PROTOCOL_FEE_RATE_BPS
    //////////////////////////////////////////////////////////////*/

    function test_SetProtocolFeeRateBps_Success() public {
        uint16 newRate = 500; // 5%

        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateUpdated(0, newRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(newRate);

        assertEq(feeRegistry.protocolFeeRateBpsGlobal(), newRate);
    }

    function test_SetProtocolFeeRateBps_MaxRate() public {
        uint16 newRate = MAX_PROTOCOL_RATE; // 30%

        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateUpdated(0, newRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(newRate);

        assertEq(feeRegistry.protocolFeeRateBpsGlobal(), newRate);
    }

    function test_SetProtocolFeeRateBps_RevertsWhen_RateTooHigh() public {
        uint16 invalidRate = MAX_PROTOCOL_RATE + 1;

        vm.expectRevert("rate too high");
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(invalidRate);
    }

    function test_SetProtocolFeeRateBps_RevertsWhen_NotOwner() public {
        uint16 newRate = 500;

        vm.expectRevert();
        vm.prank(alice);
        feeRegistry.setProtocolFeeRateBps(newRate);
    }

    function test_SetProtocolFeeRateBps_RevertsWhen_ZeroAddress() public {
        vm.prank(address(0));
        vm.expectRevert();
        feeRegistry.setProtocolFeeRateBps(100);
    }

    function test_SetProtocolFeeRateBps_EmitsEvent() public {
        uint16 oldRate = 100;
        uint16 newRate = 500;

        // Set initial rate
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(oldRate);

        // Update to new rate
        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateUpdated(oldRate, newRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(newRate);
    }

    /*//////////////////////////////////////////////////////////////
                  SET_PROTOCOL_FEE_RATE_BPS_FOR_VAULT
    //////////////////////////////////////////////////////////////*/

    function test_SetProtocolFeeRateBpsForVault_Success() public {
        uint16 customRate = 1000; // 10%

        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateForVaultUpdated(vault, 0, customRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), customRate);
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));
    }

    function test_SetProtocolFeeRateBpsForVault_MaxRate() public {
        uint16 customRate = MAX_PROTOCOL_RATE;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), customRate);
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));
    }

    function test_SetProtocolFeeRateBpsForVault_RevertsWhen_ZeroVault() public {
        uint16 customRate = 1000;

        vm.expectRevert("vault zero");
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(address(0), customRate);
    }

    function test_SetProtocolFeeRateBpsForVault_RevertsWhen_RateTooHigh() public {
        uint16 invalidRate = MAX_PROTOCOL_RATE + 1;

        vm.expectRevert("rate too high");
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, invalidRate);
    }

    function test_SetProtocolFeeRateBpsForVault_RevertsWhen_NotOwner() public {
        uint16 customRate = 1000;

        vm.expectRevert();
        vm.prank(alice);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);
    }

    function test_SetProtocolFeeRateBpsForVault_UpdatesExistingRate() public {
        uint16 oldRate = 500;
        uint16 newRate = 1500;

        // Set initial rate
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, oldRate);

        // Update rate
        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateForVaultUpdated(vault, oldRate, newRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, newRate);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), newRate);
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));
    }

    function test_SetProtocolFeeRateBpsForVault_MultipleVaults() public {
        address vault1 = makeAddr("vault1");
        address vault2 = makeAddr("vault2");
        uint16 rate1 = 500;
        uint16 rate2 = 1000;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault1, rate1);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault2, rate2);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault1), rate1);
        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault2), rate2);
        assertEq(uint8(feeRegistry.vaultRateState(vault1)), uint8(FeeRegistry.VaultRateState.Active));
        assertEq(uint8(feeRegistry.vaultRateState(vault2)), uint8(FeeRegistry.VaultRateState.Active));
    }

    /*//////////////////////////////////////////////////////////////
                  CLEAR_PROTOCOL_FEE_RATE_BPS_FOR_VAULT
    //////////////////////////////////////////////////////////////*/

    function test_ClearProtocolFeeRateBpsForVault_Success() public {
        uint16 customRate = 1000;

        // Set custom rate
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));
        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), customRate);

        // Clear custom rate
        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeRateForVaultUpdated(vault, customRate, 0);

        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), 0);
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.None));
    }

    function test_ClearProtocolFeeRateBpsForVault_RevertsWhen_ZeroVault() public {
        vm.expectRevert("vault zero");
        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(address(0));
    }

    function test_ClearProtocolFeeRateBpsForVault_RevertsWhen_NotOwner() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);
    }

    function test_ClearProtocolFeeRateBpsForVault_RevertsWhen_NoCustomRate() public {
        // Clear without setting - should revert
        vm.expectRevert("no custom rate");
        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);
    }

    function test_ClearProtocolFeeRateBpsForVault_DoesNotAffectOtherVaults() public {
        address vault1 = makeAddr("vault1");
        address vault2 = makeAddr("vault2");
        uint16 rate1 = 500;
        uint16 rate2 = 1000;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault1, rate1);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault2, rate2);

        // Clear vault1
        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault1);

        assertEq(uint8(feeRegistry.vaultRateState(vault1)), uint8(FeeRegistry.VaultRateState.None));
        assertEq(uint8(feeRegistry.vaultRateState(vault2)), uint8(FeeRegistry.VaultRateState.Active));
        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault2), rate2);
    }

    /*//////////////////////////////////////////////////////////////
                      PROTOCOL_FEE_RATE_BPS
    //////////////////////////////////////////////////////////////*/

    function test_ProtocolFeeRateBps_WithVault_ReturnsGlobalWhenNoCustom() public {
        uint16 globalRate = 500;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(globalRate);

        // Vault without custom rate should return global rate
        uint16 rate = feeRegistry.protocolFeeRateBps(vault);
        assertEq(rate, globalRate);
    }

    function test_ProtocolFeeRateBps_WithVault_ReturnsCustomRate() public {
        uint16 globalRate = 500;
        uint16 customRate = 1500;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(globalRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        // Vault with custom rate should return custom rate
        uint16 rate = feeRegistry.protocolFeeRateBps(vault);
        assertEq(rate, customRate);
    }

    function test_ProtocolFeeRateBps_WithVault_ReturnsZeroWhenNoCustomAndZeroGlobal() public {
        // No custom rate set, global rate is 0
        uint16 rate = feeRegistry.protocolFeeRateBps(vault);
        assertEq(rate, 0);
    }

    function test_ProtocolFeeRateBps_WithVault_DoesNotHaveCustomAfterClear() public {
        uint16 globalRate = 500;
        uint16 customRate = 1500;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(globalRate);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        assertEq(feeRegistry.protocolFeeRateBps(vault), customRate);

        // Clear custom rate
        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);

        // Should now return global rate
        assertEq(feeRegistry.protocolFeeRateBps(vault), globalRate);
    }

    /*//////////////////////////////////////////////////////////////
                   PROTOCOL_FEE_RATE_BPS (NO PARAMS)
    //////////////////////////////////////////////////////////////*/

    function test_ProtocolFeeRateBps_NoParams_ReturnsGlobalRate() public {
        uint16 globalRate = 500;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(globalRate);

        uint16 rate = feeRegistry.protocolFeeRateBps();
        assertEq(rate, globalRate);
    }

    function test_ProtocolFeeRateBps_NoParams_ReturnsZeroInitially() public {
        uint16 rate = feeRegistry.protocolFeeRateBps();
        assertEq(rate, 0);
    }

    function test_ProtocolFeeRateBps_NoParams_ReturnsMaxRate() public {
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(MAX_PROTOCOL_RATE);

        uint16 rate = feeRegistry.protocolFeeRateBps();
        assertEq(rate, MAX_PROTOCOL_RATE);
    }

    /*//////////////////////////////////////////////////////////////
                    SET_PROTOCOL_FEE_RECEIVER
    //////////////////////////////////////////////////////////////*/

    function test_SetProtocolFeeReceiver_Success() public {
        address newReceiver = makeAddr("newReceiver");

        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeReceiverUpdated(protocolFeeReceiver, newReceiver);

        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(newReceiver);

        assertEq(feeRegistry.protocolFeeReceiver(), newReceiver);
    }

    function test_SetProtocolFeeReceiver_RevertsWhen_ZeroAddress() public {
        vm.expectRevert("receiver zero");
        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(address(0));
    }

    function test_SetProtocolFeeReceiver_RevertsWhen_NotOwner() public {
        address newReceiver = makeAddr("newReceiver");

        vm.expectRevert();
        vm.prank(alice);
        feeRegistry.setProtocolFeeReceiver(newReceiver);
    }

    function test_SetProtocolFeeReceiver_EmitsEvent() public {
        address oldReceiver = feeRegistry.protocolFeeReceiver();
        address newReceiver = makeAddr("newReceiver");

        vm.expectEmit(true, true, true, true);
        emit FeeRegistry.ProtocolFeeReceiverUpdated(oldReceiver, newReceiver);

        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(newReceiver);
    }

    function test_SetProtocolFeeReceiver_MultipleUpdates() public {
        address receiver1 = makeAddr("receiver1");
        address receiver2 = makeAddr("receiver2");
        address receiver3 = makeAddr("receiver3");

        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(receiver1);
        assertEq(feeRegistry.protocolFeeReceiver(), receiver1);

        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(receiver2);
        assertEq(feeRegistry.protocolFeeReceiver(), receiver2);

        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(receiver3);
        assertEq(feeRegistry.protocolFeeReceiver(), receiver3);
    }

    /*//////////////////////////////////////////////////////////////
                          INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_GlobalAndCustomRatesWorkTogether() public {
        address vault1 = makeAddr("vault1");
        address vault2 = makeAddr("vault2");
        uint16 globalRate = 1000;
        uint16 customRate1 = 500;
        uint16 customRate2 = 2000;

        // Set global rate
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(globalRate);

        // Set custom rates for vault1 and vault2
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault1, customRate1);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault2, customRate2);

        // Verify rates
        assertEq(feeRegistry.protocolFeeRateBps(), globalRate);
        assertEq(feeRegistry.protocolFeeRateBps(vault1), customRate1);
        assertEq(feeRegistry.protocolFeeRateBps(vault2), customRate2);

        // Clear custom rate for vault1
        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault1);

        // vault1 should now use global rate
        assertEq(feeRegistry.protocolFeeRateBps(vault1), globalRate);
        assertEq(feeRegistry.protocolFeeRateBps(vault2), customRate2);
    }

    function test_Integration_OwnerCanTransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        feeRegistry.transferOwnership(newOwner);

        assertEq(feeRegistry.owner(), newOwner);

        // Old owner should no longer be able to set fees
        vm.expectRevert();
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(100);

        // New owner should be able to set fees
        vm.prank(newOwner);
        feeRegistry.setProtocolFeeRateBps(100);
        assertEq(feeRegistry.protocolFeeRateBps(), 100);
    }

    function test_Fuzz_SetProtocolFeeRateBps(uint16 newRate) public {
        // Only accept valid rates
        vm.assume(newRate <= MAX_PROTOCOL_RATE);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(newRate);

        assertEq(feeRegistry.protocolFeeRateBpsGlobal(), newRate);
    }

    function test_Fuzz_SetProtocolFeeRateBpsForVault(address vaultAddr, uint16 newRate) public {
        // Exclude zero address
        vm.assume(vaultAddr != address(0));
        // Only accept valid rates
        vm.assume(newRate <= MAX_PROTOCOL_RATE);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vaultAddr, newRate);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vaultAddr), newRate);
        assertEq(uint8(feeRegistry.vaultRateState(vaultAddr)), uint8(FeeRegistry.VaultRateState.Active));
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_View_ProtocolFeeRateBpsByVault() public {
        uint16 customRate = 1200;

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, customRate);

        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), customRate);
    }

    function test_View_HasCustomProtocolRate() public {
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.None));

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, 500);

        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));

        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);

        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.None));
    }

    function test_View_ProtocolFeeReceiver() public {
        assertEq(feeRegistry.protocolFeeReceiver(), protocolFeeReceiver);

        address newReceiver = makeAddr("newReceiver");
        vm.prank(owner);
        feeRegistry.setProtocolFeeReceiver(newReceiver);

        assertEq(feeRegistry.protocolFeeReceiver(), newReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                          COOLDOWN BEHAVIOR
    //////////////////////////////////////////////////////////////*/

    function test_Cooldown_GlobalRateUpdate_AppliesAfterDelay() public {
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateCooldown(1 days);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(500);

        // Still old value until cooldown elapses.
        assertEq(feeRegistry.protocolFeeRateBpsGlobal(), 0);
        assertEq(feeRegistry.protocolFeeRateBps(), 0);

        vm.warp(block.timestamp + 1 days);
        assertEq(feeRegistry.protocolFeeRateBps(), 500);
    }

    function test_Cooldown_CustomRateUpdate_AppliesAfterDelay() public {
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(300);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateCooldown(1 days);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, 1200);

        // FIX: Vault's current rate is now initialized to global rate (300), preventing 0-rate gap
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.Active));
        assertEq(feeRegistry.protocolFeeRateBpsByVault(vault), 300);
        assertEq(feeRegistry.protocolFeeRateBps(vault), 300);

        vm.warp(block.timestamp + 1 days);
        assertEq(feeRegistry.protocolFeeRateBps(vault), 1200);
    }

    function test_Cooldown_ClearCustomRate_AppliesAfterDelay() public {
        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBps(400);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateBpsForVault(vault, 1300);
        assertEq(feeRegistry.protocolFeeRateBps(vault), 1300);

        vm.prank(owner);
        feeRegistry.setProtocolFeeRateCooldown(1 days);

        vm.prank(owner);
        feeRegistry.clearProtocolFeeRateBpsForVault(vault);

        // FIX: Clear now respects cooldown — vault stays in PendingClear state during cooldown
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.PendingClear));
        assertEq(feeRegistry.protocolFeeRateBps(vault), 1300); // Still custom rate during cooldown

        (bool isPending, uint256 applyTimestamp) = feeRegistry.isProtocolRateClearPending(vault);
        assertTrue(isPending);
        assertEq(applyTimestamp, block.timestamp + 1 days);

        vm.warp(block.timestamp + 1 days);

        // Call syncVault to execute the pending clear (view functions don't modify state)
        feeRegistry.syncVault(vault);

        // After cooldown and sync, vault falls back to global rate
        assertEq(uint8(feeRegistry.vaultRateState(vault)), uint8(FeeRegistry.VaultRateState.None));
        assertEq(feeRegistry.protocolFeeRateBps(vault), 400);
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTANTS
    //////////////////////////////////////////////////////////////*/

    function test_Constant_MaxProtocolRate() public {
        assertEq(feeRegistry.MAX_PROTOCOL_RATE(), MAX_PROTOCOL_RATE);
    }
}
