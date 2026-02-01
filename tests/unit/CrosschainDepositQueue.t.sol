// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { CrosschainDepositQueue } from "../../src/adapters/CrosschainDepositQueue.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ICrosschainDepositQueue } from "../../src/interfaces/ICrosschainDepositQueue.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CrosschainDepositQueue_Test is Test {
    CrosschainDepositQueue public implementation;
    CrosschainDepositQueue public queue;
    ERC20Mock public token;
    address public owner;
    address public adapter;
    address public zapExecutor;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        adapter = makeAddr("adapter");
        zapExecutor = makeAddr("zapExecutor");
        user = makeAddr("user");

        token = new ERC20Mock();

        // Deploy implementation
        implementation = new CrosschainDepositQueue();

        bytes memory initData = abi.encodeWithSelector(
            CrosschainDepositQueue.initialize.selector,
            owner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        queue = CrosschainDepositQueue(payable(address(proxy)));

        vm.prank(owner);
        queue.setAdapterRegistration(adapter, true);

        vm.prank(owner);
        queue.setZapExecutor(zapExecutor);
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public view {
        assertTrue(queue.hasRole(queue.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(queue.hasRole(queue.OPERATOR_ROLE(), owner));
    }

    function test_Initialize_RevertsWhenZeroOwner() public {
        CrosschainDepositQueue newImpl = new CrosschainDepositQueue();

        bytes memory initData = abi.encodeWithSelector(
            CrosschainDepositQueue.initialize.selector,
            address(0)
        );

        vm.expectRevert("Invalid owner");
        new ERC1967Proxy(address(newImpl), initData);
    }

    // =========================================
    // recordFailedDeposit
    // =========================================

    function test_RecordFailedDeposit_Success() public {
        uint256 amount = 100e18;
        token.mint(adapter, amount);

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1, // srcEid
            address(token),
            amount,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        assertEq(queue.totalFailedDeposits(), 1);

        ICrosschainDepositQueue.FailedDeposit memory deposit = queue.getFailedDeposit(0);
        assertEq(deposit.user, user);
        assertEq(deposit.amount, amount);
        assertEq(uint8(deposit.status), uint8(ICrosschainDepositQueue.DepositStatus.Failed));

        uint256[] memory userDeposits = queue.getUserFailedDeposits(user);
        assertEq(userDeposits.length, 1);
        assertEq(userDeposits[0], 0);
    }

    function test_RecordFailedDeposit_EmitsFailedDepositRecordedEvent() public {
        uint256 amount = 100e18;
        token.mint(adapter, amount);
        address vault = makeAddr("vault");

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        vm.expectEmit(true, true, true, true);
        emit ICrosschainDepositQueue.FailedDepositRecorded(0, user, address(token), adapter, amount, 1e18, "");

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            vault,
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();
    }

    function test_RecordFailedDeposit_RevertsWhenNotAdapter() public {
        vm.expectRevert("Only registered adapter");
        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            100e18,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
    }

    // =========================================
    // admin functions
    // =========================================

    function test_SetAdapterRegistration_Success() public {
        address newAdapter = makeAddr("newAdapter");

        vm.prank(owner);
        queue.setAdapterRegistration(newAdapter, true);

        assertTrue(queue.isAdapterRegistered(newAdapter));
    }

    function test_SetAdapterRegistration_EmitsEvent() public {
        address newAdapter = makeAddr("newAdapter");

        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit ICrosschainDepositQueue.AdapterRegistered(newAdapter, true);

        queue.setAdapterRegistration(newAdapter, true);
        vm.stopPrank();
    }

    function test_SetAdapterRegistration_RevertsWhenNotOwnerOrOperator() public {
        vm.prank(user);
        vm.expectRevert();
        queue.setAdapterRegistration(makeAddr("newAdapter"), true);
    }

    function test_SetZapExecutor_Success() public {
        address newExecutor = makeAddr("newExecutor");

        vm.prank(owner);
        queue.setZapExecutor(newExecutor);

        assertEq(queue.zapExecutor(), newExecutor);
    }

    function test_SetZapExecutor_RevertsWhenNotOwnerOrOperator() public {
        vm.prank(user);
        vm.expectRevert();
        queue.setZapExecutor(makeAddr("newExecutor"));
    }

    function test_SetZapExecutor_RevertsWhenZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid zap executor");
        queue.setZapExecutor(address(0));
    }

    // =========================================
    // refundFailedDeposit
    // =========================================

    function test_RefundFailedDeposit_Success() public {
        uint256 amount = 100e18;
        token.mint(adapter, amount);

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        uint256 balanceBefore = token.balanceOf(user);

        vm.prank(user);
        queue.refundFailedDeposit(0);

        assertEq(token.balanceOf(user), balanceBefore + amount);
    }

    function test_RefundFailedDeposit_RevertsWhenNotFailed() public {
        // Deposit is already in Failed status, test after resolution
        uint256 amount = 100e18;
        token.mint(adapter, amount);

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        // Refund once (changes status to Resolved)
        vm.prank(user);
        queue.refundFailedDeposit(0);

        // Try to refund again
        vm.prank(user);
        vm.expectRevert("Not failed status");
        queue.refundFailedDeposit(0);
    }

    // =========================================
    // view functions
    // =========================================

    function test_GetFailedDeposit_ReturnsCorrectData() public {
        uint256 amount = 100e18;
        token.mint(adapter, amount);
        address vault = makeAddr("vault");

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            vault,
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        ICrosschainDepositQueue.FailedDeposit memory deposit = queue.getFailedDeposit(0);

        assertEq(deposit.user, user);
        assertEq(deposit.srcEid, 1);
        assertEq(deposit.token, address(token));
        assertEq(deposit.amount, amount);
        assertEq(deposit.vault, vault);
        assertEq(uint8(deposit.status), uint8(ICrosschainDepositQueue.DepositStatus.Failed));
    }

    function test_GetUserFailedDeposits_ReturnsUserDeposits() public {
        uint256 amount = 100e18;
        token.mint(adapter, amount);

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        // Mint tokens again for second deposit
        token.mint(adapter, amount);

        vm.startPrank(adapter);
        token.approve(address(queue), amount);

        queue.recordFailedDeposit(
            user,
            1,
            address(token),
            amount,
            makeAddr("vault"),
            bytes32(0),
            "",
            1e18,
            0,
            new Call[](0)
        );
        vm.stopPrank();

        uint256[] memory userDeposits = queue.getUserFailedDeposits(user);
        assertEq(userDeposits.length, 2);
    }
}
