// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { WNativeGuard } from "../../../src/guards/base/WNativeGuard.sol";

/**
 * @title WNativeGuardTest
 * @notice Comprehensive tests for WNativeGuard functionality.
 */
contract WNativeGuardTest is Test {
    WNativeGuard public guard;
    address public owner;
    address public spender1;
    address public spender2;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        spender1 = makeAddr("spender1");
        spender2 = makeAddr("spender2");
        user = makeAddr("user");

        guard = new WNativeGuard(owner);
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_SetsOwner() public view {
        assertEq(guard.owner(), owner, "Owner should be set correctly");
    }

    // ========================================================================
    //                         SET SPENDER TESTS
    // ========================================================================

    function test_SetSpender_ByOwner_UpdatesWhitelist() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        assertTrue(guard.whitelistedSpenders(spender1), "Spender should be whitelisted");
    }

    function test_SetSpender_ByOwner_CanRemoveFromWhitelist() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);
        assertTrue(guard.whitelistedSpenders(spender1), "Spender should be whitelisted");

        vm.prank(owner);
        guard.setSpender(spender1, false);
        assertFalse(guard.whitelistedSpenders(spender1), "Spender should be removed from whitelist");
    }

    function test_SetSpender_NotOwner_Reverts() public {
        vm.expectRevert();
        vm.prank(user);
        guard.setSpender(spender1, true);
    }

    // ========================================================================
    //                          VALIDATE TESTS
    // ========================================================================

    function test_Validate_Approve_WhitelistedSpender_ReturnsTrue() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x095ea7b3), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for whitelisted spender");
    }

    function test_Validate_Approve_NonWhitelistedSpender_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x095ea7b3), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for non-whitelisted spender");
    }

    function test_Validate_Deposit_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xd0e30db0));

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for deposit");
    }

    function test_Validate_Deposit_WithValue_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xd0e30db0));

        bool result = guard.validate(user, data, 1 ether);
        assertTrue(result, "Should return true for deposit with value");
    }

    function test_Validate_Withdraw_ReturnsTrue() public {
        uint256 withdrawAmount = 1 ether;
        bytes memory data = abi.encodeWithSelector(bytes4(0x2e1a7d4d), withdrawAmount);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for withdraw");
    }

    function test_Validate_Withdraw_ZeroAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x2e1a7d4d), uint256(0));

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for zero withdraw");
    }

    function test_Validate_Withdraw_MaxAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x2e1a7d4d), type(uint256).max);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for max withdraw");
    }

    function test_Validate_Transfer_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for transfer");
    }

    function test_Validate_TransferFrom_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x23b872dd), user, spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for transferFrom");
    }

    function test_Validate_EmptyCalldata_ReturnsFalse() public {
        bytes memory data = "";

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for empty calldata");
    }

    function test_Validate_AnyFunctionSelector_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x12345678));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for unknown selector");
    }

    function test_Validate_AllowedOperations_AllReturnTrue() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory approveData = abi.encodeWithSelector(bytes4(0x095ea7b3), spender1, uint256(100));
        bytes memory depositData = abi.encodeWithSelector(bytes4(0xd0e30db0));
        bytes memory withdrawData = abi.encodeWithSelector(bytes4(0x2e1a7d4d), uint256(100));

        bool approveResult = guard.validate(user, approveData, 0);
        bool depositResult = guard.validate(user, depositData, 0);
        bool withdrawResult = guard.validate(user, withdrawData, 0);

        assertTrue(approveResult, "approve should be allowed");
        assertTrue(depositResult, "deposit should be allowed");
        assertTrue(withdrawResult, "withdraw should be allowed");
    }

    function test_Validate_IgnoresValue_ForNonDeposit() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x095ea7b3), spender1, uint256(100));

        bool result = guard.validate(user, data, 100 ether);
        assertTrue(result, "Should ignore value for approve");
    }

    function test_Validate_IgnoresFrom() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xd0e30db0));

        bool resultUser = guard.validate(user, data, 0);
        bool resultOwner = guard.validate(owner, data, 0);

        assertTrue(resultUser, "Should return true for user");
        assertTrue(resultOwner, "Should return true for owner");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_Validate_Approve_AnySpender(address spender, uint256 amount) public {
        vm.prank(owner);
        guard.setSpender(spender, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x095ea7b3), spender, amount);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for any whitelisted spender");
    }

    function testFuzz_Validate_Deposit_AnyValue(uint256 value) public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xd0e30db0));

        bool result = guard.validate(user, data, value);
        assertTrue(result, "Should return true for deposit with any value");
    }

    function testFuzz_Validate_Withdraw_AnyAmount(uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x2e1a7d4d), amount);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for any withdraw amount");
    }

    function testFuzz_SetSpender_AnyAddress(address spender) public {
        vm.prank(owner);
        guard.setSpender(spender, true);

        assertTrue(guard.whitelistedSpenders(spender), "Should whitelist any address");
    }
}
