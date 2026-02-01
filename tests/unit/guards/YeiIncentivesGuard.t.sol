// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { YeiIncentivesGuard } from "../../../src/guards/sei/YeiIncentivesGuard.sol";

/**
 * @title YeiIncentivesGuardTest
 * @notice Comprehensive tests for YeiIncentivesGuard functionality.
 */
contract YeiIncentivesGuardTest is Test {
    YeiIncentivesGuard public guard;
    address public owner;
    address public user;
    address public asset1;
    address public asset2;
    address public asset3;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        asset1 = makeAddr("asset1");
        asset2 = makeAddr("asset2");
        asset3 = makeAddr("asset3");

        guard = new YeiIncentivesGuard(owner);
    }

    // ========================================================================
    //                           CONSTRUCTOR TESTS
    // ========================================================================

    function test_Constructor_SetsOwner() public view {
        assertEq(guard.owner(), owner, "Owner should be set correctly");
    }

    // ========================================================================
    //                          SET ASSET TESTS
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
        emit YeiIncentivesGuard.AssetWhitelistUpdated(asset1, true);
        guard.setAsset(asset1, true);
    }

    function test_SetAsset_NotOwner_Reverts() public {
        vm.expectRevert();
        vm.prank(user);
        guard.setAsset(asset1, true);
    }

    // ========================================================================
    //                          SET ASSETS BATCH TESTS
    // ========================================================================

    function test_SetAssets_ByOwner_UpdatesMultipleAssets() public {
        address[] memory assets = new address[](3);
        assets[0] = asset1;
        assets[1] = asset2;
        assets[2] = asset3;

        vm.prank(owner);
        guard.setAssets(assets, true);

        assertTrue(guard.whitelistedAssets(asset1), "asset1 should be whitelisted");
        assertTrue(guard.whitelistedAssets(asset2), "asset2 should be whitelisted");
        assertTrue(guard.whitelistedAssets(asset3), "asset3 should be whitelisted");
    }

    function test_SetAssets_ByOwner_CanRemoveMultipleAssets() public {
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = asset2;

        vm.prank(owner);
        guard.setAssets(assets, true);

        assertTrue(guard.whitelistedAssets(asset1), "asset1 should be whitelisted");
        assertTrue(guard.whitelistedAssets(asset2), "asset2 should be whitelisted");

        vm.prank(owner);
        guard.setAssets(assets, false);

        assertFalse(guard.whitelistedAssets(asset1), "asset1 should be removed");
        assertFalse(guard.whitelistedAssets(asset2), "asset2 should be removed");
    }

    function test_SetAssets_EmptyArray_DoesNotRevert() public {
        address[] memory assets = new address[](0);

        vm.prank(owner);
        guard.setAssets(assets, true);

        // Should not revert
    }

    function test_SetAssets_EmitsEvents() public {
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = asset2;

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit YeiIncentivesGuard.AssetWhitelistUpdated(asset1, true);
        guard.setAssets(assets, true);
    }

    function test_SetAssets_NotOwner_Reverts() public {
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = asset2;

        vm.expectRevert();
        vm.prank(user);
        guard.setAssets(assets, true);
    }

    // ========================================================================
    //                          VALIDATE TESTS
    // ========================================================================

    function test_Validate_ClaimAllRewardsToSelf_SingleWhitelistedAsset_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        address[] memory assets = new address[](1);
        assets[0] = asset1;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for single whitelisted asset");
    }

    function test_Validate_ClaimAllRewardsToSelf_MultipleWhitelistedAssets_ReturnsTrue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);
        vm.prank(owner);
        guard.setAsset(asset2, true);
        vm.prank(owner);
        guard.setAsset(asset3, true);

        address[] memory assets = new address[](3);
        assets[0] = asset1;
        assets[1] = asset2;
        assets[2] = asset3;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for all whitelisted assets");
    }

    function test_Validate_ClaimAllRewardsToSelf_NonWhitelistedAsset_ReturnsFalse() public {
        address[] memory assets = new address[](1);
        assets[0] = asset1;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for non-whitelisted asset");
    }

    function test_Validate_ClaimAllRewardsToSelf_OneNonWhitelistedAsset_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);
        vm.prank(owner);
        guard.setAsset(asset2, true);
        // asset3 is not whitelisted

        address[] memory assets = new address[](3);
        assets[0] = asset1;
        assets[1] = asset2;
        assets[2] = asset3;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false when any asset is not whitelisted");
    }

    function test_Validate_ClaimAllRewardsToSelf_EmptyArray_ReturnsFalse() public {
        address[] memory assets = new address[](0);

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for empty array");
    }

    function test_Validate_ClaimAllRewardsToSelf_WhitelistedThenRemoved_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        vm.prank(owner);
        guard.setAsset(asset1, false);

        address[] memory assets = new address[](1);
        assets[0] = asset1;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for removed asset");
    }

    // ========================================================================
    //                          OTHER FUNCTION TESTS
    // ========================================================================

    function test_Validate_Transfer_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0xa9059cbb), asset1, uint256(100));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for transfer");
    }

    function test_Validate_Approve_ReturnsFalse() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

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
        vm.prank(owner);
        guard.setAsset(asset1, true);

        bytes memory data = abi.encodeWithSelector(bytes4(0x12345678));

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for unknown selector");
    }

    // ========================================================================
    //                          VALUE IGNORANCE TESTS
    // ========================================================================

    function test_Validate_IgnoresValue() public {
        vm.prank(owner);
        guard.setAsset(asset1, true);

        address[] memory assets = new address[](1);
        assets[0] = asset1;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
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
        vm.prank(owner);
        guard.setAsset(asset1, true);

        address[] memory assets = new address[](1);
        assets[0] = asset1;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool resultUser = guard.validate(user, data, 0);
        bool resultOwner = guard.validate(owner, data, 0);

        assertTrue(resultUser, "Should return true for user");
        assertTrue(resultOwner, "Should return true for owner");
    }

    // ========================================================================
    //                            FUZZ TESTS
    // ========================================================================

    function testFuzz_SetAsset_AnyAddress(address asset) public {
        vm.prank(owner);
        guard.setAsset(asset, true);

        assertTrue(guard.whitelistedAssets(asset), "Should whitelist any address");
    }

    function testFuzz_SetAssets_MultipleAddresses(address _asset1, address _asset2, address _asset3) public {
        address[] memory assets = new address[](3);
        assets[0] = _asset1;
        assets[1] = _asset2;
        assets[2] = _asset3;

        vm.prank(owner);
        guard.setAssets(assets, true);

        assertTrue(guard.whitelistedAssets(_asset1), "Should whitelist asset1");
        assertTrue(guard.whitelistedAssets(_asset2), "Should whitelist asset2");
        assertTrue(guard.whitelistedAssets(_asset3), "Should whitelist asset3");
    }

    function testFuzz_Validate_ClaimAllRewards_AnyWhitelistedAssets(
        address _asset1,
        address _asset2
    ) public {
        vm.prank(owner);
        guard.setAsset(_asset1, true);
        vm.prank(owner);
        guard.setAsset(_asset2, true);

        address[] memory assets = new address[](2);
        assets[0] = _asset1;
        assets[1] = _asset2;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertTrue(result, "Should return true for any whitelisted assets");
    }

    function testFuzz_Validate_ClaimAllRewards_NonWhitelistedAsset_ReturnsFalse(address _asset) public {
        // Don't whitelist the asset
        address[] memory assets = new address[](1);
        assets[0] = _asset;

        bytes memory data = abi.encodeWithSelector(
            guard.CLAIM_ALL_REWARDS_TO_SELF_SELECTOR(),
            assets
        );

        bool result = guard.validate(user, data, 0);

        assertFalse(result, "Should return false for non-whitelisted asset");
    }
}
