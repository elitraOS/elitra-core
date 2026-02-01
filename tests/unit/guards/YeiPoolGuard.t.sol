// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { YeiPoolGuard } from "../../../src/guards/sei/YeiPoolGuard.sol";

/**
 * @title YeiPoolGuardTest
 * @notice Comprehensive tests for YeiPoolGuard functionality.
 */
contract YeiPoolGuardTest is Test {
    YeiPoolGuard public guard;
    address public owner;
    address public vault;
    address public asset1;
    address public asset2;
    address public user;
    address public attacker;

    function setUp() public {
        owner = makeAddr("owner");
        vault = makeAddr("vault");
        asset1 = makeAddr("asset1");
        asset2 = makeAddr("asset2");
        user = makeAddr("user");
        attacker = makeAddr("attacker");

        guard = new YeiPoolGuard(owner, vault);
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_SetsOwner() public view {
        assertEq(guard.owner(), owner, "Owner should be set correctly");
    }

    function test_Constructor_SetsVault() public view {
        assertEq(guard.vault(), vault, "Vault should be set correctly");
    }

    // ========================================================================
    //                         SET ASSET TESTS
    // ========================================================================

    function test_SetAsset_ByOwner_UpdatesWhitelist() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        assertTrue(guard.whitelistedAssets(asset1), "Asset should be whitelisted");
    }

    function test_SetAsset_ByOwner_CanRemoveFromWhitelist() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);
        assertTrue(guard.whitelistedAssets(asset1), "Asset should be whitelisted");

        vm.prank(owner);
        guard.setAsset(asset1, false);
        assertFalse(guard.whitelistedAssets(asset1), "Asset should be removed from whitelist");
    }

    function test_SetAsset_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit YeiPoolGuard.AssetWhitelistUpdated(asset1, true);
        guard.setAsset(asset1, true);
    }

    function test_SetAsset_NotOwner_Reverts() public {
        vm.expectRevert();
        vm.prank(user);
        guard.setAsset(asset1, true);
    }

    // ========================================================================
    //                        VALIDATE SUPPLY TESTS
    // ========================================================================

    function test_Validate_Supply_WhitelistedAsset_VaultReceiver_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            vault,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for valid supply");
    }

    function test_Validate_Supply_NonWhitelistedAsset_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            vault,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for non-whitelisted asset");
    }

    function test_Validate_Supply_NonVaultReceiver_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            user,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false when receiver is not vault");
    }

    function test_Validate_Supply_AttackerReceiver_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            attacker,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false when receiver is attacker");
    }

    function test_Validate_Supply_BothConditionsMet_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        uint256 supplyAmount = 5000;
        uint16 referralCode = 123;

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            supplyAmount,
            vault,
            referralCode
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true when both conditions met");
    }

    // ========================================================================
    //                       VALIDATE WITHDRAW TESTS
    // ========================================================================

    function test_Validate_Withdraw_WhitelistedAsset_VaultRecipient_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            uint256(1000),
            vault
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for valid withdraw");
    }

    function test_Validate_Withdraw_NonWhitelistedAsset_ReturnsFalse() public {
        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            uint256(1000),
            vault
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for non-whitelisted asset");
    }

    function test_Validate_Withdraw_NonVaultRecipient_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            uint256(1000),
            user
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false when recipient is not vault");
    }

    function test_Validate_Withdraw_AttackerRecipient_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            uint256(1000),
            attacker
        );

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false when recipient is attacker");
    }

    function test_Validate_Withdraw_BothConditionsMet_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset2, true);

        uint256 withdrawAmount = 3000;

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset2,
            withdrawAmount,
            vault
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true when both conditions met");
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Transfer_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

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
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x12345678));

        bool result = guard.validate(user, data, 0);
        assertFalse(result, "Should return false for unknown selector");
    }

    function test_Validate_MultipleWhitelistedAssets_AllWork() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);
        vm.prank(owner);
        guard.setAsset(asset2, true);

        bytes memory data1 = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            vault,
            uint16(0)
        );

        bytes memory data2 = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset2,
            uint256(2000),
            vault,
            uint16(0)
        );

        bool result1 = guard.validate(user, data1, 0);
        bool result2 = guard.validate(user, data2, 0);

        assertTrue(result1, "Should return true for asset1");
        assertTrue(result2, "Should return true for asset2");
    }

    function test_Validate_Supply_ZeroAmount_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(0),
            vault,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for zero amount");
    }

    function test_Validate_Withdraw_ZeroAmount_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            uint256(0),
            vault
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for zero amount");
    }

    function test_Validate_IgnoresValue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            uint256(1000),
            vault,
            uint16(0)
        );

        bool result0 = guard.validate(user, data, 0);
        bool result100 = guard.validate(user, data, 100 ether);

        assertTrue(result0, "Should return true with 0 value");
        assertTrue(result100, "Should return true with non-zero value");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_SetAsset_AnyAddress(address asset) public {
        vm.prank(owner);
        guard.setAsset(asset, true);

        assertTrue(guard.whitelistedAssets(asset), "Should whitelist any address");
    }

    function testFuzz_Validate_Supply_AnyAmount(uint256 amount) public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.SUPPLY_SELECTOR(),
            asset1,
            amount,
            vault,
            uint16(0)
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for any amount");
    }

    function testFuzz_Validate_Withdraw_AnyAmount(uint256 amount) public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(
            guard.WITHDRAW_SELECTOR(),
            asset1,
            amount,
            vault
        );

        bool result = guard.validate(user, data, 0);
        assertTrue(result, "Should return true for any amount");
    }
}
