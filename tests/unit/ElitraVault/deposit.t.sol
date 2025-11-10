// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Deposit_Test is ElitraVault_Base_Test {
    address public alice;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");
    }

    function test_Deposit_MintsCorrectShares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(1000e6, alice);

        assertEq(shares, 1000e6); // 1:1 on first deposit
        assertEq(asset.balanceOf(address(vault)), 1000e6);
    }

    function test_Deposit_EmitsDepositEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(alice, alice, 1000e6, 1000e6);

        vm.prank(alice);
        vault.deposit(1000e6, alice);

        // alice shares balance
        assertGt(vault.balanceOf(alice), 0);
    }
}
