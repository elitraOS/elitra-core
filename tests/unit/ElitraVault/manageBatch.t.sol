// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IElitraVault, Call } from "../../../src/interfaces/IElitraVault.sol";
import { IVaultBase } from "../../../src/interfaces/IVaultBase.sol";
import { AllowAllGuard, BlockAllGuard } from "../../mocks/MockGuards.sol";
import { Errors } from "../../../src/libraries/Errors.sol";

// Mock target contract for testing manageBatchWithDelta
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

contract ManageBatchWithDelta_Test is ElitraVault_Base_Test {
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

    function test_ManageBatch_RevertsWithUseManageBatchWithDelta() public {
        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        vm.prank(owner);
        vm.expectRevert(Errors.UseManageBatchWithDelta.selector);
        vault.manageBatch(calls);
    }

    function test_ManageBatchWithDelta_ExecutesMultipleOperations() public {
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

        // Execute batch as owner with no external delta (operations don't affect vault asset balance)
        vm.prank(owner);
        vault.manageBatchWithDelta(calls, 0);

        // Verify operations were executed
        assertEq(target1.counter(), 6); // 1 + 5
        assertEq(target2.counter(), 1);
    }

    function test_ManageBatchWithDelta_RevertsOnEmptyCalls() public {
        Call[] memory calls = new Call[](0);

        vm.prank(owner);
        vm.expectRevert("No calls provided");
        vault.manageBatchWithDelta(calls, 0);
    }

    function test_ManageBatchWithDelta_RevertsWhenUnauthorized() public {
        Call[] memory calls = new Call[](1);

        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert(); // Should revert due to requiresAuth
        vault.manageBatchWithDelta(calls, 0);
    }

    function test_ManageBatchWithDelta_HandlesValueTransfers() public {
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
        vault.manageBatchWithDelta(calls, 0);

        // Verify ETH was transferred
        assertEq(target1.lastValue(), 0.1 ether);
        assertEq(target2.lastValue(), 0.2 ether);
    }

    function test_ManageBatchWithDelta_RevertsWithBlockAllGuard() public {
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
        vault.manageBatchWithDelta(calls, 0);
    }

    function test_ManageBatchWithDelta_PositiveExternalDelta() public {
        uint256 initialBalance = vault.aggregatedUnderlyingBalances();

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        // Simulate an external increase in vault assets (e.g., yield accrued)
        uint256 positiveDelta = 100e6; // 100 USDC

        vm.prank(owner);
        vault.manageBatchWithDelta(calls, int256(positiveDelta));

        // Verify aggregated balance increased
        assertEq(vault.aggregatedUnderlyingBalances(), initialBalance + positiveDelta);
    }

    function test_ManageBatchWithDelta_NegativeExternalDelta() public {
        // First set up the vault with some assets
        uint256 initialBalance = 1000e6; // 1000 USDC
        deal(address(asset), address(this), initialBalance);
        asset.approve(address(vault), initialBalance);
        vault.deposit(initialBalance, address(this));

        // Update the aggregated balance to reflect the deposited assets
        vm.prank(owner);
        vault.updateBalance(initialBalance);

        uint256 balanceAfterUpdate = vault.aggregatedUnderlyingBalances();
        assertEq(balanceAfterUpdate, initialBalance);

        // Increase the max percentage change threshold to allow larger decreases
        vm.prank(owner);
        balanceUpdateHook.updateMaxPercentage(0.1e18); // 10%

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        // Simulate an external decrease in vault assets (e.g., loss, fee)
        uint256 negativeDelta = 50e6; // 50 USDC (5% decrease)

        vm.prank(owner);
        vault.manageBatchWithDelta(calls, -int256(negativeDelta));

        // Verify aggregated balance decreased
        assertEq(vault.aggregatedUnderlyingBalances(), balanceAfterUpdate - negativeDelta);
    }

    function test_ManageBatchWithDelta_NegativeDeltaExceedsBalance() public {
        // First set up the vault with some assets
        uint256 initialBalance = 100e6; // 100 USDC
        deal(address(asset), address(this), initialBalance);
        asset.approve(address(vault), initialBalance);
        vault.deposit(initialBalance, address(this));

        // Update the aggregated balance to reflect the deposited assets
        vm.prank(owner);
        vault.updateBalance(initialBalance);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(target1),
            data: abi.encodeWithSelector(MockTarget.increment.selector),
            value: 0
        });

        // Try to decrease more than available balance
        uint256 negativeDelta = 200e6; // 200 USDC (more than 100 USDC balance)

        vm.prank(owner);
        vm.expectRevert("External delta exceeds balances");
        vault.manageBatchWithDelta(calls, -int256(negativeDelta));
    }
}
