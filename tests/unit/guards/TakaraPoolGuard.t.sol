// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { TakaraPoolGuard } from "../../../src/guards/sei/TakaraPoolGuard.sol";

/**
 * @title TakaraPoolGuardTest
 * @notice Comprehensive tests for TakaraPoolGuard functionality.
 */
contract TakaraPoolGuardTest is Test {
    TakaraPoolGuard public guard;
    address public user;

    function setUp() public {
        user = makeAddr("user");
        guard = new TakaraPoolGuard();
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_DeploysSuccessfully() public view {
        assertEq(guard.MINT_SELECTOR(), bytes4(0xa0712d68), "MINT_SELECTOR should be correct");
        assertEq(guard.REDEEM_SELECTOR(), bytes4(0xdb006a75), "REDEEM_SELECTOR should be correct");
    }

    // ========================================================================
    //                          VALIDATE MINT TESTS
    // ========================================================================

    function test_Validate_Mint_ReturnsTrue() public {
        uint256 mintAmount = 1000e18;
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), mintAmount);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for mint");
    }

    function test_Validate_Mint_ZeroAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), uint256(0));

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for zero mint amount");
    }

    function test_Validate_Mint_MaxAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), type(uint256).max);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for max mint amount");
    }

    function test_Validate_Mint_SpecificAmounts() public {
        uint256[3] memory amounts = [uint256(1e18), uint256(1000e18), uint256(500000e18)];

        for (uint256 i = 0; i < amounts.length; i++) {
            bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), amounts[i]);
            bool result = guard.validate(user, data, 0);
            assertTrue(result, "Should return true for mint amount");
        }
    }

    // ========================================================================
    //                         VALIDATE REDEEM TESTS
    // ========================================================================

    function test_Validate_Redeem_ReturnsTrue() public {
        uint256 redeemAmount = 500e18;
        bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), redeemAmount);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for redeem");
    }

    function test_Validate_Redeem_ZeroAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), uint256(0));

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for zero redeem amount");
    }

    function test_Validate_Redeem_MaxAmount_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), type(uint256).max);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for max redeem amount");
    }

    function test_Validate_Redeem_SpecificAmounts() public {
        uint256[3] memory amounts = [uint256(1e18), uint256(500e18), uint256(1000000e18)];

        for (uint256 i = 0; i < amounts.length; i++) {
            bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), amounts[i]);
            bool result = guard.validate(user, data, 0);
            assertTrue(result, "Should return true for redeem amount");
        }
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Transfer_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), user, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for transfer");
    }

    function test_Validate_TransferFrom_ReturnsFalse() public {
        address recipient = makeAddr("recipient");
        bytes memory data = abi.encodeWithSelector(bytes4(0x23b872dd), user, recipient, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for transferFrom");
    }

    function test_Validate_Approve_ReturnsFalse() public {
        address spender = makeAddr("spender");
        bytes memory data = abi.encodeWithSelector(bytes4(0x095ea7b3), spender, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for approve");
    }

    function test_Validate_EmptyCalldata_ReturnsFalse() public {
        bytes memory data = "";

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for empty calldata");
    }

    function test_Validate_AnyFunctionSelector_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x12345678));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for unknown selector");
    }

    function test_Validate_OnlyMintAndRedeemAllowed() public {
        // Test that only mint and redeem selectors are allowed
        bytes memory mintData = abi.encodeWithSelector(guard.MINT_SELECTOR(), uint256(100));
        bytes memory redeemData = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), uint256(100));
        bytes memory otherData = abi.encodeWithSelector(bytes4(0xdeadbeef));

        bool mintResult = guard.validate(user, mintData, 0);
        bool redeemResult = guard.validate(user, redeemData, 0);
        bool otherResult = guard.validate(user, otherData, 0);

        assertTrue(mintResult, "mint should be allowed");
        assertTrue(redeemResult, "redeem should be allowed");
        assertFalse(otherResult, "other selector should not be allowed");
    }

    // ========================================================================
    //                          VALUE IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresValue() public {
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), uint256(100));

        bool result0 = guard.validate(user, data, 0);
        bool result100 = guard.validate(user, data, 100 ether);

        assertTrue(result0, "Should return true with 0 value");
        assertTrue(result100, "Should return true with non-zero value");
    }

    // ========================================================================
    //                          FROM IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresFrom() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), uint256(100));

        bool resultUser1 = guard.validate(user1, data, 0);
        bool resultUser2 = guard.validate(user2, data, 0);

        assertTrue(resultUser1, "Should return true for user1");
        assertTrue(resultUser2, "Should return true for user2");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_Validate_Mint_AnyAmount(uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), amount);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any mint amount");
    }

    function testFuzz_Validate_Redeem_AnyAmount(uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), amount);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any redeem amount");
    }

    function testFuzz_Validate_Mint_AnyAddress(address from, uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(guard.MINT_SELECTOR(), amount);

        bool result = guard.validate(from, data, 0);

        assertTrue(result, "Should return true for mint from any address");
    }

    function testFuzz_Validate_Redeem_AnyAddress(address from, uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(guard.REDEEM_SELECTOR(), amount);

        bool result = guard.validate(from, data, 0);

        assertTrue(result, "Should return true for redeem from any address");
    }

    function testFuzz_Validate_OtherSelector_ReturnsFalse(bytes4 selector) public {
        // Exclude mint and redeem selectors
        vm.assume(selector != guard.MINT_SELECTOR());
        vm.assume(selector != bytes4(0xdb006a75));

        bytes memory data = abi.encodeWithSelector(selector);

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for selectors other than mint and redeem");
    }
}
