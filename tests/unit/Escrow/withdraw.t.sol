// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraEscrow } from "src/ElitraEscrow.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Base_Test } from "../ElitraVault/Base.t.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";

contract Withdraw_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_escrow_withdraw() public {
        vm.startPrank({ msgSender: users.admin });
        ElitraEscrow escrow = new ElitraEscrow(address(depositVault));
        deal({ token: address(usdc), to: address(escrow), give: 1000 * 1e6, adjust: true });

        bytes memory data = abi.encodeWithSelector(ElitraEscrow.withdraw.selector, address(usdc), 500 * 1e6);

        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, address(escrow), ElitraEscrow.withdraw.selector, true
        );

        uint256 vaultUsdcBalance = usdc.balanceOf(address(depositVault));
        depositVault.manage(address(escrow), data, 0);
        uint256 vaultUsdcBalanceAfter = usdc.balanceOf(address(depositVault));
        assertEq(vaultUsdcBalanceAfter, vaultUsdcBalance + 500 * 1e6);
    }

    function test_escrow_withdraw_reverts_Escrow__AmountZero() public {
        vm.startPrank({ msgSender: users.admin });
        ElitraEscrow escrow = new ElitraEscrow(address(depositVault));
        deal({ token: address(usdc), to: address(escrow), give: 1000 * 1e6, adjust: true });

        bytes memory data = abi.encodeWithSelector(ElitraEscrow.withdraw.selector, address(usdc), 0);

        MockAuthority(address(depositVault.authority())).setRoleCapability(
            ADMIN_ROLE, address(escrow), ElitraEscrow.withdraw.selector, true
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.Escrow__AmountZero.selector));
        depositVault.manage(address(escrow), data, 0);
    }

    function test_escrow_withdraw_reverts_Escrow__OnlyVault() public {
        vm.startPrank({ msgSender: users.admin });
        ElitraEscrow escrow = new ElitraEscrow(address(depositVault));
        deal({ token: address(usdc), to: address(escrow), give: 1000 * 1e6, adjust: true });

        vm.expectRevert(abi.encodeWithSelector(Errors.Escrow__OnlyVault.selector));
        escrow.withdraw(address(usdc), 500 * 1e6);
    }
}
