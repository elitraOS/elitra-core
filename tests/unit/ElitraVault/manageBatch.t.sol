// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { Call } from "../../../src/interfaces/IVaultBase.sol";
import { AllowAllGuard, BlockAllGuard } from "../../mocks/MockGuards.sol";

// Mock target contract for testing manageBatch behavior
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
    AllowAllGuard public allowAllGuard;
    BlockAllGuard public blockAllGuard;

    function setUp() public override {
        super.setUp();
        target1 = new MockTarget();
        target2 = new MockTarget();

        allowAllGuard = new AllowAllGuard();
        blockAllGuard = new BlockAllGuard();

        vm.startPrank(owner);
        // Set guards for target contracts
        vault.setGuard(address(target1), address(allowAllGuard));
        vault.setGuard(address(target2), address(allowAllGuard));
        vm.stopPrank();
    }

    function test_ManageBatch_ExecutesMultipleOperations_AndPausesVault() public {
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

        // Execute batch as owner.
        vm.prank(owner);
        vault.manageBatch(calls);

        // Verify operations were executed
        assertEq(target1.counter(), 6); // 1 + 5
        assertEq(target2.counter(), 1);
        assertTrue(vault.paused());
        assertTrue(vault.pendingOracleSyncAfterManageBatch());
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
        assertTrue(vault.paused());
    }

    function test_ManageBatch_RevertsWithBlockAllGuard() public {
        // Create a new target with BlockAllGuard
        MockTarget target3 = new MockTarget();

        vm.prank(owner);
        vault.setGuard(address(target3), address(blockAllGuard));

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target3),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        vm.prank(owner);
        vm.expectRevert(); // Should revert due to guard validation failure
        vault.manageBatch(calls);
    }

    function test_ManageBatch_DoesNotMutateAggregatedBalance() public {
        uint256 initialBalance = 1000e6;
        vm.prank(owner);
        vault.updateBalance(initialBalance);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        vm.prank(owner);
        vault.manageBatch(calls);

        // Strategy execution does not update accounting. Oracle must call updateBalance.
        assertEq(vault.aggregatedUnderlyingBalances(), initialBalance);
        assertTrue(vault.pendingOracleSyncAfterManageBatch());
    }

    function test_UpdateBalance_AfterManageBatch_UnpausesAndClearsSyncFlag() public {
        uint256 initialBalance = 1000e6; // 1000 USDC
        vm.prank(owner);
        vault.updateBalance(initialBalance);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        vm.prank(owner);
        vault.manageBatch(calls);

        assertTrue(vault.paused());
        assertTrue(vault.pendingOracleSyncAfterManageBatch());

        // updateBalance requires next block
        vm.roll(block.number + 1);
        vm.prank(owner);
        vault.updateBalance(initialBalance);

        assertFalse(vault.paused());
        assertFalse(vault.pendingOracleSyncAfterManageBatch());
    }
}
