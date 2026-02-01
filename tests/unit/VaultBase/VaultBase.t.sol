// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { VaultBase } from "../../../src/vault/VaultBase.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { MockTransactionGuard } from "../../mocks/MockGuards.sol";
import { IVaultBase } from "../../../src/interfaces/IVaultBase.sol";

contract VaultBaseMock is VaultBase {
    function initialize(address _owner, address _upgradeAdmin) external {
        __VaultBase_init(_owner, _upgradeAdmin);
    }
}

contract VaultBase_Test is Test {
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

        vaultBase = new VaultBaseMock();
        vaultBase.initialize(owner, upgradeAdmin);
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
    // setGuard/removeGuard
    // =========================================

    function test_SetGuard_Success() public {
        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));

        assertEq(address(vaultBase.guards(target)), address(mockGuard));

        address[] memory guarded = vaultBase.getGuardedTargets();
        assertEq(guarded.length, 1);
        assertEq(guarded[0], target);
    }

    function test_SetGuard_EmitsGuardUpdatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IVaultBase.GuardUpdated(target, address(mockGuard));

        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));
    }

    function test_SetGuard_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.setGuard(target, address(mockGuard));
    }

    function test_RemoveGuard_Success() public {
        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));

        vm.prank(owner);
        vaultBase.removeGuard(target);

        assertEq(address(vaultBase.guards(target)), address(0));

        address[] memory guarded = vaultBase.getGuardedTargets();
        assertEq(guarded.length, 0);
    }

    function test_RemoveGuard_EmitsGuardRemovedEvent() public {
        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));

        vm.expectEmit(true, false, false, true);
        emit IVaultBase.GuardRemoved(target);

        vm.prank(owner);
        vaultBase.removeGuard(target);
    }

    function test_RemoveGuard_RevertsWhenNotAuthorized() public {
        vm.prank(owner);
        vaultBase.setGuard(target, address(mockGuard));

        vm.prank(user);
        vm.expectRevert();
        vaultBase.removeGuard(target);
    }

    // =========================================
    // setTrustedTarget
    // =========================================

    function test_SetTrustedTarget_AddsTarget() public {
        vm.prank(owner);
        vaultBase.setTrustedTarget(target, true);

        assertTrue(vaultBase.isTrustedTarget(target));

        address[] memory trusted = vaultBase.getTrustedTargets();
        assertEq(trusted.length, 1);
        assertEq(trusted[0], target);
    }

    function test_SetTrustedTarget_EmitsTrustedTargetUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IVaultBase.TrustedTargetUpdated(target, true);

        vm.prank(owner);
        vaultBase.setTrustedTarget(target, true);
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
    // sweepToken/sweepETH
    // =========================================

    function test_SweepToken_TransfersToOwner() public {
        uint256 amount = 100e18;
        token.mint(address(vaultBase), amount);

        vm.prank(owner);
        vaultBase.sweepToken(address(token));

        assertEq(token.balanceOf(address(vaultBase)), 0);
        assertEq(token.balanceOf(owner), amount);
    }

    function test_SweepToken_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.sweepToken(address(token));
    }

    function test_SweepETH_TransfersToOwner() public {
        uint256 amount = 1 ether;
        vm.deal(address(vaultBase), amount);

        vm.prank(owner);
        vaultBase.sweepETH();

        assertEq(address(vaultBase).balance, 0);
        assertEq(owner.balance, amount);
    }

    function test_SweepETH_RevertsWhenNotAuthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vaultBase.sweepETH();
    }

    // =========================================
    // setUpgradeAdmin
    // =========================================

    function test_SetUpgradeAdmin_Success() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(upgradeAdmin);
        vaultBase.setUpgradeAdmin(newAdmin);

        assertEq(vaultBase.upgradeAdmin(), newAdmin);
    }

    function test_SetUpgradeAdmin_RevertsWhenNotUpgradeAdmin() public {
        vm.prank(owner);
        vm.expectRevert();
        vaultBase.setUpgradeAdmin(makeAddr("newAdmin"));
    }

    function test_SetUpgradeAdmin_RevertsWhenZeroAddress() public {
        vm.prank(upgradeAdmin);
        vm.expectRevert();
        vaultBase.setUpgradeAdmin(address(0));
    }

    // =========================================
    // upgradeAdmin view
    // =========================================

    function test_UpgradeAdmin_ReturnsInitialValue() public view {
        assertEq(vaultBase.upgradeAdmin(), upgradeAdmin);
    }
}
