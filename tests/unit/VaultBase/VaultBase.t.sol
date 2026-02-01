// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { VaultBase } from "../../../src/vault/VaultBase.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { MockTransactionGuard } from "../../mocks/MockGuards.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title VaultBaseMock
/// @notice A mock implementation of VaultBase for testing
contract VaultBaseMock is VaultBase {
    function initialize(address _owner, address _upgradeAdmin) external initializer {
        __VaultBase_init(_owner, _upgradeAdmin);
    }

    function _authorizeUpgrade(address newImpl) internal override {
        // Use VaultBase's upgrade authorization
        super._authorizeUpgrade(newImpl);
    }
}

contract VaultBase_Test is Test {
    VaultBaseMock public implementation;
    VaultBaseMock public vaultBase;
    ERC20Mock public token;
    MockTransactionGuard public mockGuard;

    address public owner;
    address public upgradeAdmin;
    address public target;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        upgradeAdmin = makeAddr("upgradeAdmin");
        target = makeAddr("target");
        user = makeAddr("user");

        token = new ERC20Mock();
        mockGuard = new MockTransactionGuard();

        // Deploy implementation
        implementation = new VaultBaseMock();

        bytes memory initData = abi.encodeWithSelector(
            VaultBaseMock.initialize.selector,
            owner,
            upgradeAdmin
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        vaultBase = VaultBaseMock(payable(address(proxy)));
    }

    // =========================================
    // pause/unpause
    // =========================================

    function test_Pause_Success() public {
        vm.prank(owner);
        vaultBase.pause();

        assertTrue(vaultBase.paused());
    }

    function test_Pause_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        vaultBase.pause();

        vm.prank(owner);
        vaultBase.unpause();

        assertFalse(vaultBase.paused());
    }

    function test_Unpause_RevertsWhenNotAuthorized() public {
        vm.prank(owner);
        vaultBase.pause();

        vm.prank(user);
        vm.expectRevert();
        vaultBase.unpause();
    }

    // =========================================
    // setGuard
    // =========================================

    function test_SetGuard_SetsGuardForTarget() public {
        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));

        assertEq(address(vaultBase.guards(target)), address(mockGuard));
    }

    function test_SetGuard_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.setGuard(target, address(mockGuard));
    }

    // =========================================
    // setTrustedTarget
    // =========================================

    function test_SetTrustedTarget_AddsTarget() public {
        vm.prank(owner);
        vaultBase.setTrustedTarget(target, true);

        assertTrue(vaultBase.isTrustedTarget(target));
    }

    function test_SetTrustedTarget_RemovesTarget() public {
        vm.prank(owner);
        vaultBase.setTrustedTarget(target, true);

        vm.prank(owner);
        vaultBase.setTrustedTarget(target, false);

        assertFalse(vaultBase.isTrustedTarget(target));
    }

    function test_SetTrustedTarget_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.setTrustedTarget(target, true);
    }

    // =========================================
    // upgradeTo
    // =========================================

    function test_UpgradeTo_Success() public {
        VaultBaseMock newImpl = new VaultBaseMock();

        vm.prank(upgradeAdmin);
        vaultBase.upgradeTo(address(newImpl));

        // The proxy should now point to the new implementation
        assertEq(vaultBase.owner(), owner);
    }

    function test_UpgradeTo_RevertsWhenNotUpgradeAdmin() public {
        VaultBaseMock newImpl = new VaultBaseMock();

        vm.prank(user);
        vm.expectRevert();
        vaultBase.upgradeTo(address(newImpl));
    }

    // =========================================
    // isAuthorized
    // =========================================

    function test_IsAuthorized_ReturnsTrueForOwner() public view {
        assertTrue(vaultBase.isAuthorized(owner, bytes4(0)));
    }

    function test_IsAuthorized_ReturnsFalseForRandomUser() public view {
        assertFalse(vaultBase.isAuthorized(user, bytes4(0)));
    }
}
