// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { BaseCrosschainDepositAdapter } from "../../src/adapters/BaseCrosschainDepositAdapter.sol";
import { ICrosschainDepositAdapter } from "../../src/interfaces/ICrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

// Mock implementation for testing
contract MockAdapter is BaseCrosschainDepositAdapter {
    function initialize(
        address _owner,
        address _queue,
        address _zapExecutor
    ) external initializer {
        __BaseAdapter_init(_owner, _queue, _zapExecutor);
    }

    function exposedProcessReceivedFunds(
        address user,
        uint32 sourceId,
        address token,
        uint256 amount,
        bytes32 messageId,
        bytes memory payload
    ) external {
        _processReceivedFunds(user, sourceId, token, amount, messageId, payload);
    }
}

contract BaseCrosschainDepositAdapter_Test is Test {
    MockAdapter public adapter;
    ERC20Mock public token;
    address public owner;
    address public queue;
    address public zapExecutor;
    address public vault;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        queue = makeAddr("queue");
        zapExecutor = makeAddr("zapExecutor");
        vault = makeAddr("vault");
        user = makeAddr("user");

        token = new ERC20Mock();

        adapter = new MockAdapter();
        adapter.initialize(owner, queue, zapExecutor);

        vm.prank(owner);
        adapter.setSupportedVault(vault, true);
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public {
        assertEq(adapter.owner(), owner);
    }

    function test_Initialize_SetsQueue() public {
        assertEq(adapter.depositQueue(), queue);
    }

    function test_Initialize_SetsZapExecutor() public {
        assertEq(address(adapter.zapExecutor()), zapExecutor);
    }

    function test_Initialize_GrantsRoles() public {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), owner));
    }

    // =========================================
    // setSupportedVault
    // =========================================

    function test_SetSupportedVault_Success() public {
        address newVault = makeAddr("newVault");

        vm.prank(owner);
        adapter.setSupportedVault(newVault, true);

        assertTrue(adapter.isVaultSupported(newVault));
    }

    function test_SetSupportedVault_RemoveVault() public {
        vm.prank(owner);
        adapter.setSupportedVault(vault, false);

        assertFalse(adapter.isVaultSupported(vault));
    }

    function test_SetSupportedVault_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.setSupportedVault(makeAddr("newVault"), true);
    }

    // =========================================
    // setZapExecutor
    // =========================================

    function test_SetZapExecutor_Success() public {
        address newExecutor = makeAddr("newExecutor");

        vm.prank(owner);
        adapter.setZapExecutor(newExecutor);

        assertEq(address(adapter.zapExecutor()), newExecutor);
    }

    function test_SetZapExecutor_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.setZapExecutor(makeAddr("newExecutor"));
    }

    // =========================================
    // setDepositQueue
    // =========================================

    function test_SetDepositQueue_Success() public {
        address newQueue = makeAddr("newQueue");

        vm.prank(owner);
        adapter.setDepositQueue(newQueue);

        assertEq(adapter.depositQueue(), newQueue);
    }

    function test_SetDepositQueue_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.setDepositQueue(makeAddr("newQueue"));
    }

    // =========================================
    // pause/unpause
    // =========================================

    function test_Pause_Success() public {
        vm.prank(owner);
        adapter.pause();

        assertTrue(adapter.paused());
    }

    function test_Pause_RevertsWhenNotOwnerOrOperator() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        adapter.pause();

        vm.prank(owner);
        adapter.unpause();

        assertFalse(adapter.paused());
    }

    // =========================================
    // setOperator/removeOperator
    // =========================================

    function test_SetOperator_Success() public {
        address newOperator = makeAddr("newOperator");

        vm.prank(owner);
        adapter.setOperator(newOperator);

        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), newOperator));
    }

    function test_RemoveOperator_Success() public {
        address newOperator = makeAddr("newOperator");

        vm.prank(owner);
        adapter.setOperator(newOperator);

        vm.prank(owner);
        adapter.removeOperator(newOperator);

        assertFalse(adapter.hasRole(adapter.OPERATOR_ROLE(), newOperator));
    }

    // =========================================
    // emergencyRecover
    // =========================================

    function test_EmergencyRecover_ERC20_Success() public {
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);
        address recipient = makeAddr("recipient");

        vm.prank(owner);
        adapter.emergencyRecover(address(token), recipient, amount);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(adapter)), 0);
    }

    function test_EmergencyRecover_ERC20_ZeroAmount() public {
        uint256 amount = 100e18;
        token.mint(address(adapter), amount);
        address recipient = makeAddr("recipient");
        uint256 balanceBefore = token.balanceOf(recipient);

        vm.prank(owner);
        adapter.emergencyRecover(address(token), recipient, 0);

        // Should transfer 0 amount (comment was wrong - function transfers exact amount)
        assertEq(token.balanceOf(recipient), balanceBefore);
    }

    function test_EmergencyRecover_ETH_Success() public {
        uint256 amount = 1 ether;
        vm.deal(address(adapter), amount);
        address recipient = makeAddr("recipient");

        vm.prank(owner);
        adapter.emergencyRecover(address(0), recipient, amount);

        assertEq(recipient.balance, amount);
        assertEq(address(adapter).balance, 0);
    }

    function test_EmergencyRecover_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.emergencyRecover(address(token), user, 100e18);
    }

    // =========================================
    // view functions
    // =========================================

    function test_GetDepositRecord_ReturnsZeroForNonExistent() public view {
        ICrosschainDepositAdapter.DepositRecord memory record = adapter.getDepositRecord(999);
        assertEq(record.user, address(0));
    }

    function test_GetUserDepositIds_ReturnsEmptyForNoDeposits() public view {
        uint256[] memory ids = adapter.getUserDepositIds(user);
        assertEq(ids.length, 0);
    }

    // =========================================
    // transferOwnership
    // =========================================

    function test_TransferOwnership_Success() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        adapter.transferOwnership(newOwner);

        assertEq(adapter.owner(), newOwner);
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), newOwner));
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), newOwner));
    }

    function test_TransferOwnership_RevokesOldOwnerRoles() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        adapter.transferOwnership(newOwner);

        assertFalse(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), owner));
        assertFalse(adapter.hasRole(adapter.OPERATOR_ROLE(), owner));
    }
}
