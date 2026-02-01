// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { TokenGuard } from "../../../src/guards/base/TokenGuard.sol";

/**
 * @title TokenGuardTest
 * @notice Comprehensive tests for TokenGuard functionality.
 */
contract TokenGuardTest is Test {
    TokenGuard public guard;
    address public owner;
    address public spender1;
    address public spender2;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        spender1 = makeAddr("spender1");
        spender2 = makeAddr("spender2");
        user = makeAddr("user");

        guard = new TokenGuard(owner);
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

        // approve(address,uint256) selector: 0x095ea7b3
        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for whitelisted spender");
    }

    function test_Validate_Approve_NonWhitelistedSpender_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for non-whitelisted spender");
    }

    function test_Validate_Approve_RemovedSpender_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));

        bool result1 = guard.validate(user, data, 0);
        assertTrue(result1, "Should return true initially");

        vm.prank(owner);
        guard.setSpender(spender1, false);

        bool result2 = guard.validate(user, data, 0);
        assertFalse(result2, "Should return false after removal");
    }

    function test_Validate_Approve_MultipleWhitelistedSpenders_AllWork() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);
        vm.prank(owner);
        guard.setSpender(spender2, true);

        bytes memory data1 = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));
        bytes memory data2 = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender2, uint256(200));

        bool result1 = guard.validate(user, data1, 0);
        bool result2 = guard.validate(user, data2, 0);

        assertTrue(result1, "Should return true for spender1");
        assertTrue(result2, "Should return true for spender2");
    }

    function test_Validate_Transfer_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        // transfer(address,uint256) selector: 0xa9059cbb
        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for transfer");
    }

    function test_Validate_TransferFrom_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        // transferFrom(address,address,uint256) selector: 0x23b872dd
        bytes memory data = abi.encodeWithSelector(bytes4(0x23b872dd), user, spender1, uint256(100));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for transferFrom");
    }

    function test_Validate_EmptyCalldata_ReturnsFalse() public {
        bytes memory data = "";

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for empty calldata");
    }

    function test_Validate_Approve_ZeroAmount_ReturnsTrue() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(0));

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for zero amount approve");
    }

    function test_Validate_Approve_MaxAmount_ReturnsTrue() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, type(uint256).max);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for max amount approve");
    }

    function test_Validate_AnyFunctionSelector_ReturnsFalse() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        // Random selector
        bytes memory data = abi.encodeWithSelector(bytes4(0x12345678));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for unknown selector");
    }

    function test_Validate_IgnoresValue() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));

        bool result0 = guard.validate(user, data, 0);
        bool result100 = guard.validate(user, data, 100 ether);

        assertTrue(result0, "Should return true with 0 value");
        assertTrue(result100, "Should return true with non-zero value");
    }

    function test_Validate_IgnoresFrom() public {
        vm.prank(owner);
        guard.setSpender(spender1, true);

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender1, uint256(100));

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

        bytes memory data = abi.encodeWithSelector(guard.APPROVE_SELECTOR(), spender, amount);

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for any whitelisted spender");
    }

    function testFuzz_SetSpender_AnyAddress(address spender) public {
        vm.prank(owner);
        guard.setSpender(spender, true);

        assertTrue(guard.whitelistedSpenders(spender), "Should whitelist any address");
    }
}
