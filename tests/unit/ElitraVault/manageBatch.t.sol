// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";
import { Authority } from "@solmate/auth/Auth.sol";

// Mock target contract for testing manageBatch
contract MockTarget {
    uint256 public counter;
    uint256 public lastValue;

    function increment() external payable {
        counter++;
        lastValue = msg.value;
    }

    function add(uint256 amount) external payable {
        counter += amount;
        lastValue = msg.value;
    }

    function resetCounter() external {
        counter = 0;
    }
}

contract ManageBatch_Test is ElitraVault_Base_Test {
    MockTarget public target1;
    MockTarget public target2;
    MockAuthority public auth;

    function setUp() public override {
        super.setUp();
        target1 = new MockTarget();
        target2 = new MockTarget();

        // Set up authority with permissions
        auth = new MockAuthority(owner, Authority(address(0)));

        vm.startPrank(owner);
        vault.setAuthority(Authority(address(auth)));

        // Grant permission to call any function on target contracts
        auth.setPublicCapability(address(target1), MockTarget.increment.selector, true);
        auth.setPublicCapability(address(target1), MockTarget.add.selector, true);
        auth.setPublicCapability(address(target2), MockTarget.increment.selector, true);
        auth.setPublicCapability(address(target2), MockTarget.add.selector, true);
        vm.stopPrank();
    }

    function test_ManageBatch_ExecutesMultipleOperations() public {
        // Prepare batch operations
        address[] memory targets = new address[](3);
        bytes[] memory data = new bytes[](3);
        uint256[] memory values = new uint256[](3);

        // Operation 1: increment target1
        targets[0] = address(target1);
        data[0] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[0] = 0;

        // Operation 2: add 5 to target1
        targets[1] = address(target1);
        data[1] = abi.encodeWithSelector(MockTarget.add.selector, 5);
        values[1] = 0;

        // Operation 3: increment target2
        targets[2] = address(target2);
        data[2] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[2] = 0;

        // Execute batch as owner
        vm.prank(owner);
        vault.manageBatch(targets, data, values);

        // Verify operations were executed
        assertEq(target1.counter(), 6); // 1 + 5
        assertEq(target2.counter(), 1);
    }

    function test_ManageBatch_EmitsEvents() public {
        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);
        uint256[] memory values = new uint256[](2);

        targets[0] = address(target1);
        data[0] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[0] = 0;

        targets[1] = address(target2);
        data[1] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[1] = 0;

        // Expect events to be emitted
        vm.expectEmit(true, true, false, true);
        emit IElitraVault.ManageBatchOperation(
            0,
            address(target1),
            MockTarget.increment.selector,
            0,
            ""
        );

        vm.expectEmit(true, true, false, true);
        emit IElitraVault.ManageBatchOperation(
            1,
            address(target2),
            MockTarget.increment.selector,
            0,
            ""
        );

        vm.prank(owner);
        vault.manageBatch(targets, data, values);
    }

    function test_ManageBatch_RevertsOnArrayLengthMismatch() public {
        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](3); // Mismatched length
        uint256[] memory values = new uint256[](2);

        vm.prank(owner);
        vm.expectRevert("Array length mismatch");
        vault.manageBatch(targets, data, values);
    }

    function test_ManageBatch_RevertsWhenUnauthorized() public {
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory values = new uint256[](1);

        targets[0] = address(target1);
        data[0] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[0] = 0;

        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert(); // Should revert due to requiresAuth
        vault.manageBatch(targets, data, values);
    }

    function test_ManageBatch_HandlesValueTransfers() public {
        // Fund the vault with ETH
        vm.deal(address(vault), 1 ether);

        address[] memory targets = new address[](2);
        bytes[] memory data = new bytes[](2);
        uint256[] memory values = new uint256[](2);

        targets[0] = address(target1);
        data[0] = abi.encodeWithSelector(MockTarget.increment.selector);
        values[0] = 0.1 ether;

        targets[1] = address(target2);
        data[1] = abi.encodeWithSelector(MockTarget.add.selector, 10);
        values[1] = 0.2 ether;

        vm.prank(owner);
        vault.manageBatch(targets, data, values);

        // Verify ETH was transferred
        assertEq(target1.lastValue(), 0.1 ether);
        assertEq(target2.lastValue(), 0.2 ether);
    }
}
