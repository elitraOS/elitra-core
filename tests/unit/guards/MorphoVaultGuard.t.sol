// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { MorphoVaultGuard } from "../../../src/guards/sei/MorphoVaultGuard.sol";

/**
 * @title MorphoVaultGuardTest
 * @notice Comprehensive tests for MorphoVaultGuard functionality.
 */
contract MorphoVaultGuardTest is Test {
    MorphoVaultGuard public guard;
    address public vault;
    address public user;
    address public attacker;

    function setUp() public {
        vault = makeAddr("vault");
        user = makeAddr("user");
        attacker = makeAddr("attacker");

        guard = new MorphoVaultGuard(vault);
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_SetsVault() public view {
        assertEq(guard.vault(), vault, "Vault should be set correctly");
    }

    function test_Constructor_DeploysSuccessfully() public view {
        // deposit(uint256,address) selector: 0x6e553f65
        // withdraw(uint256,address,address) selector: 0xb460af94
        assertEq(guard.vault(), vault, "Vault should be set correctly");
    }

    // ========================================================================
    //                          VALIDATE DEPOSIT TESTS
    // ========================================================================

    function test_Validate_Deposit_VaultReceiver_ReturnsTrue() public {
        uint256 assets = 1000e18;
        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), assets, vault);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for deposit to vault");
    }

    function test_Validate_Deposit_NonVaultReceiver_ReturnsFalse() public {
        uint256 assets = 1000e18;
        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), assets, user);

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when receiver is not vault");
    }

    function test_Validate_Deposit_AttackerReceiver_ReturnsFalse() public {
        uint256 assets = 1000e18;
        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), assets, attacker);

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when receiver is attacker");
    }

    function test_Validate_Deposit_ZeroAssets_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), uint256(0), vault);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for zero assets");
    }

    function test_Validate_Deposit_MaxAssets_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x6e553f65),
            type(uint256).max,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for max assets");
    }

    function test_Validate_Deposit_VariousAmounts() public {
        uint256[4] memory amounts = [uint256(1e18), uint256(100e18), uint256(1000e18), uint256(1000000e18)];

        for (uint256 i = 0; i < amounts.length; i++) {
            bytes memory data = abi.encodeWithSelector(
                bytes4(0x6e553f65),
                amounts[i],
                vault
            );
            bool result = guard.validate(user, data, 0);
            assertTrue(result, "Should return true for deposit amount");
        }
    }

    // ========================================================================
    //                         VALIDATE WITHDRAW TESTS
    // ========================================================================

    function test_Validate_Withdraw_VaultReceiverAndOwner_ReturnsTrue() public {
        uint256 assets = 500e18;
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            assets,
            vault,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true when receiver and owner are vault");
    }

    function test_Validate_Withdraw_NonVaultReceiver_ReturnsFalse() public {
        uint256 assets = 500e18;
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            assets,
            user,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when receiver is not vault");
    }

    function test_Validate_Withdraw_NonVaultOwner_ReturnsFalse() public {
        uint256 assets = 500e18;
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            assets,
            vault,
            user
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when owner is not vault");
    }

    function test_Validate_Withdraw_NeitherVault_ReturnsFalse() public {
        uint256 assets = 500e18;
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            assets,
            user,
            attacker
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when neither receiver nor owner is vault");
    }

    function test_Validate_Withdraw_ZeroAssets_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            uint256(0),
            vault,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for zero assets");
    }

    function test_Validate_Withdraw_MaxAssets_ReturnsTrue() public {
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            type(uint256).max,
            vault,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for max assets");
    }

    function test_Validate_Withdraw_VariousAmounts() public {
        uint256[4] memory amounts = [uint256(1e18), uint256(50e18), uint256(500e18), uint256(500000e18)];

        for (uint256 i = 0; i < amounts.length; i++) {
            bytes memory data = abi.encodeWithSelector(
                bytes4(0xb460af94),
                amounts[i],
                vault,
                vault
            );
            bool result = guard.validate(user, data, 0);
            assertTrue(result, "Should return true for withdraw amount");
        }
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Transfer_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), vault, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for transfer");
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

    function test_Validate_OnlyDepositAndWithdrawAllowed() public {
        // Test that only deposit and withdraw selectors are allowed (with proper receivers)
        bytes memory depositData = abi.encodeWithSelector(
            bytes4(0x6e553f65),
            uint256(100),
            vault
        );
        bytes memory withdrawData = abi.encodeWithSelector(
            bytes4(0xb460af94),
            uint256(100),
            vault,
            vault
        );
        bytes memory otherData = abi.encodeWithSelector(bytes4(0xdeadbeef));

        bool depositResult = guard.validate(user, depositData, 0);
        bool withdrawResult = guard.validate(user, withdrawData, 0);
        bool otherResult = guard.validate(user, otherData, 0);

        assertTrue(depositResult, "deposit with vault receiver should be allowed");
        assertTrue(withdrawResult, "withdraw with vault receiver and owner should be allowed");
        assertFalse(otherResult, "other selector should not be allowed");
    }

    // ========================================================================
    //                          VALUE IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresValue() public {
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x6e553f65),
            uint256(100),
            vault
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

        bytes memory data = abi.encodeWithSelector(
            bytes4(0x6e553f65),
            uint256(100),
            vault
        );

        bool result1 = guard.validate(from1, data, 0);
        bool result2 = guard.validate(from2, data, 0);

        assertTrue(result1, "Should return true for from1");
        assertTrue(result2, "Should return true for from2");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_Validate_Deposit_AnyAmount(uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), amount, vault);

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any deposit amount");
    }

    function testFuzz_Validate_Withdraw_AnyAmount(uint256 amount) public {
        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            amount,
            vault,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any withdraw amount");
    }

    function testFuzz_Validate_Deposit_NonVaultReceiver_ReturnsFalse(uint256 amount, address receiver) public {
        vm.assume(receiver != vault);

        bytes memory data = abi.encodeWithSelector(bytes4(0x6e553f65), amount, receiver);

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when receiver is not vault");
    }

    function testFuzz_Validate_Withdraw_NonVaultReceiver_ReturnsFalse(
        uint256 amount,
        address receiver
    ) public {
        vm.assume(receiver != vault);

        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            amount,
            receiver,
            vault
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when receiver is not vault");
    }

    function testFuzz_Validate_Withdraw_NonVaultOwner_ReturnsFalse(uint256 amount, address owner) public {
        vm.assume(owner != vault);

        bytes memory data = abi.encodeWithSelector(
            bytes4(0xb460af94),
            amount,
            vault,
            owner
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when owner is not vault");
    }
}
