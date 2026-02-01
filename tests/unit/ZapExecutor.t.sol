// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ZapExecutor } from "../../src/adapters/ZapExecutor.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ManualBalanceUpdateHook } from "../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../src/hooks/HybridRedemptionHook.sol";
import { FeeRegistryMock } from "../mocks/FeeRegistryMock.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IVaultBase } from "../../src/interfaces/IVaultBase.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";

contract ZapExecutor_Test is Test {
    ZapExecutor public zapExecutor;
    ElitraVault public vault;
    ERC20Mock public asset;
    ManualBalanceUpdateHook public balanceHook;
    HybridRedemptionHook public redemptionHook;
    FeeRegistryMock public feeRegistry;

    address public owner;
    address public receiver;
    address public adapter;

    function setUp() public {
        owner = makeAddr("owner");
        receiver = makeAddr("receiver");
        adapter = makeAddr("adapter");

        asset = new ERC20Mock();
        balanceHook = new ManualBalanceUpdateHook(owner);
        redemptionHook = new HybridRedemptionHook();
        feeRegistry = new FeeRegistryMock(0, owner);

        // Deploy vault
        ElitraVault vaultImpl = new ElitraVault();
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            address(asset),
            owner,
            owner,
            address(feeRegistry),
            address(balanceHook),
            address(redemptionHook),
            "Test Vault",
            "TV"
        );

        vault = ElitraVault(payable(address(new TransparentUpgradeableProxy(address(vaultImpl), owner, initData))));

        zapExecutor = new ZapExecutor();

        // Mint tokens to adapter
        asset.mint(adapter, 1000e18);
    }

    // =========================================
    // executeZapAndDeposit - Direct Deposit
    // =========================================

    function test_ExecuteZapAndDeposit_DirectDeposit_Success() public {
        uint256 amount = 100e18;

        vm.startPrank(adapter);
        asset.approve(address(zapExecutor), amount);

        uint256 shares = zapExecutor.executeZapAndDeposit(
            address(asset),
            amount,
            address(vault),
            receiver,
            0, // minAmountOut
            new Call[](0) // no zap calls
        );
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.balanceOf(receiver), shares);
    }

    function test_ExecuteZapAndDeposit_DirectDeposit_RevertsOnTokenMismatch() public {
        ERC20Mock otherToken = new ERC20Mock();
        otherToken.mint(adapter, 100e18);

        vm.startPrank(adapter);
        otherToken.approve(address(zapExecutor), 100e18);

        vm.expectRevert();
        zapExecutor.executeZapAndDeposit(
            address(otherToken),
            100e18,
            address(vault),
            receiver,
            0,
            new Call[](0)
        );
    }

    function test_ExecuteZapAndDeposit_RevertsOnSlippageExceeded() public {
        uint256 amount = 100e18;

        vm.startPrank(adapter);
        asset.approve(address(zapExecutor), amount);

        vm.expectRevert(ZapExecutor.SlippageExceeded.selector);
        zapExecutor.executeZapAndDeposit(
            address(asset),
            amount,
            address(vault),
            receiver,
            200e18, // minAmountOut higher than amount
            new Call[](0)
        );
    }

    // =========================================
    // sweepToken
    // =========================================

    function test_SweepToken_TransfersDust() public {
        address sweeper = makeAddr("sweeper");
        uint256 dustAmount = 1e18;

        asset.mint(address(zapExecutor), dustAmount);

        uint256 balBefore = asset.balanceOf(sweeper);
        zapExecutor.sweepToken(address(asset));

        assertEq(asset.balanceOf(address(zapExecutor)), 0);
        assertEq(asset.balanceOf(sweeper), balBefore + dustAmount);
    }

    function test_SweepToken_NoOpWhenZeroBalance() public {
        // Should not revert even with zero balance
        zapExecutor.sweepToken(address(asset));
    }

    // =========================================
    // sweepNative
    // =========================================

    function test_SweepNative_TransfersETH() public {
        address sweeper = makeAddr("sweeper");
        uint256 ethAmount = 1 ether;

        vm.deal(address(zapExecutor), ethAmount);

        zapExecutor.sweepNative();

        assertEq(address(zapExecutor).balance, 0);
        assertEq(sweeper.balance, ethAmount);
    }

    function test_SweepNative_NoOpWhenZeroBalance() public {
        // Should not revert even with zero balance
        zapExecutor.sweepNative();
    }
}
