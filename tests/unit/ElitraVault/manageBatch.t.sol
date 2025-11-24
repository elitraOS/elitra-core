// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault, Call } from "../../../src/interfaces/IElitraVault.sol";
import { IVaultBase } from "../../../src/interfaces/IVaultBase.sol";
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
        Call[] memory calls = new Call[](3);

        // Operation 1: increment target1
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        // Operation 2: add 5 to target1
        calls[1] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.add.selector, 5),
            value: 0
        });

        // Operation 3: increment target2
        calls[2] = Call({
            target: address(target2),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        // Execute batch as owner
        vm.prank(owner);
        vault.manageBatch(calls);

        // Verify operations were executed
        assertEq(target1.counter(), 6); // 1 + 5
        assertEq(target2.counter(), 1);
    }

    function test_ManageBatch_RevertsOnEmptyCalls() public {
        Call[] memory calls = new Call[](0);

        vm.prank(owner);
        vm.expectRevert("No calls provided");
        vault.manageBatch(calls);
    }

    function test_ManageBatch_RevertsWhenUnauthorized() public {
        Call[] memory calls = new Call[](1);

        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert(); // Should revert due to requiresAuth
        vault.manageBatch(calls);
    }

    function test_ManageBatch_HandlesValueTransfers() public {
        // Fund the vault with ETH
        vm.deal(address(vault), 1 ether);

        Call[] memory calls = new Call[](2);

        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0.1 ether
        });

        calls[1] = Call({
            target: address(target2),
            data: abi.encodeWithSelector(MockTarget.add.selector, 10),
            value: 0.2 ether
        });

        vm.prank(owner);
        vault.manageBatch(calls);

        // Verify ETH was transferred
        assertEq(target1.lastValue(), 0.1 ether);
        assertEq(target2.lastValue(), 0.2 ether);
    }
}
