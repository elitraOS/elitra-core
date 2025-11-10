// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { HybridRedemptionHook_Base_Test } from "./Base.t.sol";
import { RedemptionMode } from "../../../src/interfaces/IRedemptionHook.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";

contract ProcessRedemption_Test is HybridRedemptionHook_Base_Test {
    function test_ReturnsInstant_WhenSufficientLiquidity() public {
        // Mock vault to return sufficient balance
        vm.mockCall(
            vault,
            abi.encodeWithSelector(IElitraVault.getAvailableBalance.selector),
            abi.encode(1000e6) // 1000 USDC available
        );

        (RedemptionMode mode, uint256 actualAssets) = strategy.beforeRedeem(
            IElitraVault(vault),
            100, // shares
            500e6, // 500 USDC needed
            address(this),
            address(this)
        );

        assertEq(uint256(mode), uint256(RedemptionMode.INSTANT));
        assertEq(actualAssets, 500e6);
    }

    function test_ReturnsQueued_WhenInsufficientLiquidity() public {
        // Mock vault to return insufficient balance
        vm.mockCall(
            vault,
            abi.encodeWithSelector(IElitraVault.getAvailableBalance.selector),
            abi.encode(100e6) // Only 100 USDC available
        );

        (RedemptionMode mode, uint256 actualAssets) = strategy.beforeRedeem(
            IElitraVault(vault),
            100, // shares
            500e6, // 500 USDC needed
            address(this),
            address(this)
        );

        assertEq(uint256(mode), uint256(RedemptionMode.QUEUED));
        assertEq(actualAssets, 500e6);
    }
}
