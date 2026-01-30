// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ElitraVault_Base_Test } from "./Base.t.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Mint_Test is ElitraVault_Base_Test {
    address public alice;

    function setUp() public override {
        super.setUp();
        alice = createUser("alice");
    }

    function test_Mint_MintsCorrectShares() public {
        vm.prank(alice);
        uint256 shares = vault.mint(1000e6, alice);

        assertEq(shares, 1000e6); // 1:1 on first mint
        assertEq(asset.balanceOf(address(vault)), 1000e6);
    }

    function test_Mint_EmitsDepositEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(alice, alice, 1000e6, 1000e6);

        vm.prank(alice);
        vault.mint(1000e6, alice);
    }

    function test_PreviewMint_ReturnsCorrectAssets() public {
        uint256 shares = 1000e6;
        uint256 expectedAssets = vault.previewMint(shares);

        vm.prank(alice);
        uint256 actualAssets = vault.mint(shares, alice);

        assertEq(expectedAssets, actualAssets);
    }

    function test_PreviewMint_WithDepositFee() public {
        // Set 1% deposit fee
        vm.prank(owner);
        vault.setDepositFee(1e16);

        uint256 shares = 1000e6;
        uint256 assetsNeeded = vault.previewMint(shares);

        // Should need more than 1000e6 due to fee
        assertGt(assetsNeeded, shares);
        assertApproxEqRel(assetsNeeded, 1010e6, 0.02e18); // ~1% more
    }

    function test_Mint_RevertsWhenPaused() public {
        vm.prank(owner);
        vault.pause();

        vm.expectRevert();
        vm.prank(alice);
        vault.mint(1000e6, alice);
    }
}
