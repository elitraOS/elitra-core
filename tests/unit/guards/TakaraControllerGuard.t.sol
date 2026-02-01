// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { TakaraControllerGuard } from "../../../src/guards/sei/TakaraControllerGuard.sol";

/**
 * @title TakaraControllerGuardTest
 * @notice Comprehensive tests for TakaraControllerGuard functionality.
 */
contract TakaraControllerGuardTest is Test {
    TakaraControllerGuard public guard;
    address public user;

    function setUp() public {
        user = makeAddr("user");
        guard = new TakaraControllerGuard();
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_DeploysSuccessfully() public view {
        assertEq(
            guard.CLAIM_REWARD_SELECTOR(),
            bytes4(0xb88a802f),
            "CLAIM_REWARD_SELECTOR should be correct"
        );
    }

    // ========================================================================
    //                       VALIDATE CLAIM REWARD TESTS
    // ========================================================================

    function test_Validate_ClaimReward_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for claimReward");
    }

    function test_Validate_ClaimReward_WithValue_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result = guard.validate(user, data, 100 ether);

        assertTrue(result, "Should return true for claimReward with value");
    }

    function test_Validate_ClaimReward_FromAnyAddress() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result1 = guard.validate(user1, data, 0);
        bool result2 = guard.validate(user2, data, 0);
        bool result3 = guard.validate(user3, data, 0);

        assertTrue(result1, "Should return true for user1");
        assertTrue(result2, "Should return true for user2");
        assertTrue(result3, "Should return true for user3");
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Mint_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xa0712d68), uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for mint");
    }

    function test_Validate_Redeem_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xdb006a75), uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for redeem");
    }

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

    function test_Validate_OnlyClaimRewardAllowed() public {
        // Test that only claimReward selector is allowed
        bytes memory claimRewardData = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());
        bytes memory otherData = abi.encodeWithSelector(bytes4(0xdeadbeef));

        bool claimResult = guard.validate(user, claimRewardData, 0);
        bool otherResult = guard.validate(user, otherData, 0);

        assertTrue(claimResult, "claimReward should be allowed");
        assertFalse(otherResult, "other selector should not be allowed");
    }

    function test_Validate_CommonSelectors_ReturnFalse() public {
        // Test some common ERC20 and other selectors
        bytes4[4] memory selectors = [
            bytes4(0xa9059cbb), // transfer
            bytes4(0x23b872dd), // transferFrom
            bytes4(0x095ea7b3), // approve
            bytes4(0x70a08231) // balanceOf
        ];

        for (uint256 i = 0; i < selectors.length; i++) {
            bytes memory data = abi.encodeWithSelector(selectors[i]);
            bool result = guard.validate(user, data, 0);
            assertFalse(result, "Should return false for common selector");
        }
    }

    // ========================================================================
    //                          VALUE IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresValue() public {
        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result0 = guard.validate(user, data, 0);
        bool result100 = guard.validate(user, data, 100 ether);
        bool resultMax = guard.validate(user, data, type(uint256).max);

        assertTrue(result0, "Should return true with 0 value");
        assertTrue(result100, "Should return true with non-zero value");
        assertTrue(resultMax, "Should return true with max value");
    }

    // ========================================================================
    //                          FROM IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresFrom() public {
        address from1 = makeAddr("from1");
        address from2 = makeAddr("from2");
        address from3 = makeAddr("from3");

        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result1 = guard.validate(from1, data, 0);
        bool result2 = guard.validate(from2, data, 0);
        bool result3 = guard.validate(from3, data, 0);

        assertTrue(result1, "Should return true for from1");
        assertTrue(result2, "Should return true for from2");
        assertTrue(result3, "Should return true for from3");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_Validate_ClaimReward_AnyAddress(address from) public {
        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result = guard.validate(from, data, 0);

        assertTrue(result, "Should return true for claimReward from any address");
    }

    function testFuzz_Validate_ClaimReward_AnyValue(address from, uint256 value) public {
        bytes memory data = abi.encodeWithSelector(guard.CLAIM_REWARD_SELECTOR());

        bool result = guard.validate(from, data, value);

        assertTrue(result, "Should return true for claimReward with any value");
    }

    function testFuzz_Validate_OtherSelector_ReturnsFalse(bytes4 selector) public {
        // Exclude claimReward selector
        vm.assume(selector != guard.CLAIM_REWARD_SELECTOR());

        bytes memory data = abi.encodeWithSelector(selector);

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for selectors other than claimReward");
    }

    function testFuzz_Validate_OtherSelectorWithValue_ReturnsFalse(bytes4 selector, uint256 value) public {
        // Exclude claimReward selector
        vm.assume(selector != guard.CLAIM_REWARD_SELECTOR());

        bytes memory data = abi.encodeWithSelector(selector);

        bool result = guard.validate(user, data, value);

        assertFalse(result, "Should return false for other selectors with any value");
    }
}
