// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { MerklDistributorGuard } from "../../../src/guards/sei/MerklDistributorGuard.sol";

/**
 * @title MerklDistributorGuardTest
 * @notice Comprehensive tests for MerklDistributorGuard functionality.
 */
contract MerklDistributorGuardTest is Test {
    MerklDistributorGuard public guard;
    address public vault;
    address public user;
    address public attacker;
    address public token1;
    address public token2;

    function setUp() public {
        vault = makeAddr("vault");
        user = makeAddr("user");
        attacker = makeAddr("attacker");
        token1 = makeAddr("token1");
        token2 = makeAddr("token2");

        guard = new MerklDistributorGuard(vault);
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_SetsVault() public view {
        assertEq(guard.vault(), vault, "Vault should be set correctly");
    }

    function test_Constructor_DeploysSuccessfully() public view {
        // CLAIM_SELECTOR is constant but not public, so we verify via behavior
        assertEq(guard.vault(), vault, "Vault should be set correctly");
    }

    // ========================================================================
    //                          VALIDATE CLAIM TESTS
    // ========================================================================

    function test_Validate_Claim_SingleUserVault_ReturnsTrue() public {
        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for valid single user claim");
    }

    function test_Validate_Claim_MultipleUsersAllVault_ReturnsTrue() public {
        address[] memory users = new address[](3);
        users[0] = vault;
        users[1] = vault;
        users[2] = vault;

        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = token2;
        tokens[2] = token1;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18;
        amounts[1] = 200e18;
        amounts[2] = 300e18;

        bytes32[][] memory proofs = new bytes32[][](3);
        proofs[0] = new bytes32[](0);
        proofs[1] = new bytes32[](0);
        proofs[2] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for valid multi-user claim");
    }

    function test_Validate_Claim_EmptyUsers_ReturnsFalse() public {
        address[] memory users = new address[](0);

        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        bytes32[][] memory proofs = new bytes32[][](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for empty users");
    }

    function test_Validate_Claim_UserNotVault_ReturnsFalse() public {
        address[] memory users = new address[](1);
        users[0] = user;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when user is not vault");
    }

    function test_Validate_Claim_OneUserNotVault_ReturnsFalse() public {
        address[] memory users = new address[](2);
        users[0] = vault;
        users[1] = user;

        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 200e18;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](0);
        proofs[1] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when any user is not vault");
    }

    function test_Validate_Claim_AttackerUser_ReturnsFalse() public {
        address[] memory users = new address[](1);
        users[0] = attacker;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for attacker user");
    }

    // ========================================================================
    //                      ARRAY LENGTH MISMATCH TESTS
    // ========================================================================

    function test_Validate_Claim_MismatchedTokensLength_ReturnsFalse() public {
        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for mismatched tokens length");
    }

    function test_Validate_Claim_MismatchedAmountsLength_ReturnsFalse() public {
        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e18;
        amounts[1] = 2000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for mismatched amounts length");
    }

    function test_Validate_Claim_MismatchedProofsLength_ReturnsFalse() public {
        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](0);
        proofs[1] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for mismatched proofs length");
    }

    function test_Validate_Claim_AllArraysMatch_ReturnsTrue() public {
        address[] memory users = new address[](3);
        users[0] = vault;
        users[1] = vault;
        users[2] = vault;

        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = token2;
        tokens[2] = token1;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18;
        amounts[1] = 200e18;
        amounts[2] = 300e18;

        bytes32[][] memory proofs = new bytes32[][](3);
        proofs[0] = new bytes32[](0);
        proofs[1] = new bytes32[](0);
        proofs[2] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true when all arrays match length");
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Transfer_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), vault, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for transfer");
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

    // ========================================================================
    //                          VALUE IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresValue() public {
        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result0 = guard.validate(user, data, 0);
        bool result100 = guard.validate(user, data, 100 ether);

        assertTrue(result0, "Should return true with 0 value");
        assertTrue(result100, "Should return true with non-zero value");
    }

    // ========================================================================
    //                          FROM IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresFrom() public {
        address from1 = makeAddr("from1");
        address from2 = makeAddr("from2");

        address[] memory users = new address[](1);
        users[0] = vault;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result1 = guard.validate(from1, data, 0);
        bool result2 = guard.validate(from2, data, 0);

        assertTrue(result1, "Should return true for from1");
        assertTrue(result2, "Should return true for from2");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_Validate_Claim_AnyAmounts(uint256 amount1, uint256 amount2) public {
        address[] memory users = new address[](2);
        users[0] = vault;
        users[1] = vault;

        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](0);
        proofs[1] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any amounts when users are vault");
    }

    function testFuzz_Validate_Claim_NonVaultUser_ReturnsFalse(address badUser) public {
        vm.assume(badUser != vault);

        address[] memory users = new address[](1);
        users[0] = badUser;

        address[] memory tokens = new address[](1);
        tokens[0] = token1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e18;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](0);

        // claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector: 0x71ee95c0
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x71ee95c0),
            users,
            tokens,
            amounts,
            proofs
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when user is not vault");
    }
}
