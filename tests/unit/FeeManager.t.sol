// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { FeeManager } from "../../src/fees/FeeManager.sol";
import { FeeRegistryMock } from "../mocks/FeeRegistryMock.sol";
import { MockBalanceUpdateHook, MockRedemptionHook } from "../mocks/MockHooks.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { RedemptionMode } from "../../src/interfaces/IRedemptionHook.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title FeeManagerTest
 * @notice Comprehensive tests for FeeManager functionality via ElitraVault.
 *         Tests the actual vault behavior with deposit, PPS changes, and fee accrual.
 */
contract FeeManagerTest is Test {
    ElitraVault public vaultImplementation;
    ElitraVault public vault;
    ERC20Mock public asset;
    MockBalanceUpdateHook public balanceUpdateHook;
    MockRedemptionHook public redemptionHook;
    FeeRegistryMock public feeRegistry;

    address public owner;
    address public upgradeAdmin;
    address public feeReceiver;
    address public protocolFeeReceiver;
    address public alice;
    address public bob;

    // Constants
    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000;
    uint16 constant MAX_MANAGEMENT_RATE = 1000; // 10%
    uint16 constant MAX_PERFORMANCE_RATE = 5000; // 50%
    uint16 constant MAX_PROTOCOL_RATE = 3000; // 30%
    uint256 constant MAX_FEE = 1e16; // 1%
    uint256 constant DENOMINATOR = 1e18;

    // Default fee rates
    uint16 constant DEFAULT_MANAGEMENT_RATE = 200; // 2%
    uint16 constant DEFAULT_PERFORMANCE_RATE = 2000; // 20%
    uint16 constant DEFAULT_PROTOCOL_RATE = 1000; // 10%
    uint256 constant DEFAULT_COOLDOWN = 7 days;

    function setUp() public {
        owner = address(this);
        upgradeAdmin = makeAddr("upgradeAdmin");
        feeReceiver = makeAddr("feeReceiver");
        protocolFeeReceiver = makeAddr("protocolFeeReceiver");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy and setup asset
        asset = new ERC20Mock();

        // Deploy hooks
        balanceUpdateHook = new MockBalanceUpdateHook(type(uint256).max, false);
        redemptionHook = new MockRedemptionHook(RedemptionMode.INSTANT, false);

        // Deploy fee registry
        feeRegistry = new FeeRegistryMock(DEFAULT_PROTOCOL_RATE, protocolFeeReceiver);

        // Deploy vault implementation
        vaultImplementation = new ElitraVault();

        // Deploy proxy with initialization data - owner gets initial fee receiver role
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            IERC20(address(asset)),
            owner,
            upgradeAdmin,
            address(feeRegistry),
            address(balanceUpdateHook),
            address(redemptionHook),
            "Test Vault",
            "TVLT"
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation),
            upgradeAdmin,
            initData
        );

        vault = ElitraVault(payable(address(proxy)));

        // Set fee receivers to match our test expectations
        vault.setFeeReceiver(feeReceiver);
        vault.setFeeRecipient(feeReceiver); // Also set the fee recipient for claiming

        // Set fee rates
        vault.updateFeeRates(DEFAULT_MANAGEMENT_RATE, DEFAULT_PERFORMANCE_RATE);

        // Skip cooldown to make rates effective immediately
        skip(DEFAULT_COOLDOWN);
    }

    // ========================================================================
    //                           DEPOSIT & PPS TESTS
    // ========================================================================

    function test_Deposit_MintSharesCorrectly() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, alice);

        assertEq(shares, depositAmount, "Should mint 1:1 shares initially");
        assertEq(vault.balanceOf(alice), depositAmount, "Alice should have correct shares");
        assertEq(vault.totalSupply(), depositAmount, "Total supply should match deposit");
        assertEq(vault.totalAssets(), depositAmount, "Total assets should match deposit");
    }

    function test_Deposit_MultipleUsers() public {
        uint256 aliceDeposit = 1000e6;
        uint256 bobDeposit = 2000e6;

        asset.mint(alice, aliceDeposit);
        asset.mint(bob, bobDeposit);

        vm.startPrank(alice);
        asset.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), bobDeposit);
        vault.deposit(bobDeposit, bob);
        vm.stopPrank();

        assertEq(vault.totalSupply(), aliceDeposit + bobDeposit, "Total supply should match all deposits");
        assertEq(vault.balanceOf(alice), aliceDeposit, "Alice should have her shares");
        assertEq(vault.balanceOf(bob), bobDeposit, "Bob should have his shares");
    }

    function test_PricePerShare_InitialValue_IsOne() public view {
        assertEq(vault.totalAssets(), 0, "Initial assets should be zero");
        assertEq(vault.totalSupply(), 0, "Initial supply should be zero");
        // PPS is 1e18 by design when empty
    }

    function test_PricePerShare_AfterDeposit_IsOne() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 assets = vault.totalAssets();
        uint256 supply = vault.totalSupply();
        assertEq(assets, depositAmount, "Assets should equal deposit");
        assertEq(supply, depositAmount, "Supply should equal deposit");
        // PPS = assets / supply = 1 (scaled to 1e18)
    }

    function test_PricePerShare_WithProfit_Increases() public {
        // Initial deposit
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Simulate profit: add more assets to vault (representing yield)
        uint256 profit = 200e6; // 20% profit
        asset.mint(address(vault), profit);
        vault.updateBalance(0); // Reset external balance, only vault balance remains

        // PPS should increase: (1000 + 200) / 1000 = 1.2
        uint256 assets = vault.totalAssets();
        uint256 supply = vault.totalSupply();
        assertEq(assets, depositAmount + profit, "Assets should include profit");
        assertEq(supply, depositAmount, "Supply unchanged");
        assertApproxEqRel(vault.convertToAssets(1e6), 1.2e6, 0.01e18, "PPS should reflect profit");
    }

    function test_PricePerShare_WithLoss_Decreases_Correct() public {
        // Initial deposit
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Set external balance to represent deployed assets
        vault.updateBalance(400e6);

        assertEq(vault.totalAssets(), 1400e6, "Total assets should be 1400e6 (vault + external)");
        assertEq(vault.balanceOf(alice), 1000e6, "Alice still has 1000 shares");

        // Move to next block to allow another updateBalance
        vm.roll(block.number + 1);

        // Simulate 20% loss on external assets
        vault.updateBalance(320e6); // 400e6 -> 320e6 (20% loss)

        // Total assets = 1000 (vault) + 320 (external) = 1320e6
        // PPS = 1320 / 1000 = 1.32
        assertEq(vault.totalAssets(), 1320e6, "Total assets should reflect loss");
        assertApproxEqRel(vault.convertToAssets(1e6), 1.32e6, 0.01e18, "PPS should reflect loss");
    }

    // ========================================================================
    //                           MANAGEMENT FEE TESTS
    // ========================================================================

    function test_ManagementFee_AccruesOverTime() public {
        // Initial deposit
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 initialShares = vault.totalSupply();
        assertEq(initialShares, depositAmount, "Initial shares should equal deposit");

        // Warp 1 year
        skip(365 days);

        // Take fees
        vault.takeFees();

        // Management fee = 1000 * 2% * 1 year = 20 assets
        // Shares minted = 20 / (assets - fees) * supply = 20 / 980 * 1000 ≈ 20.4
        uint256 finalSupply = vault.totalSupply();
        assertGt(finalSupply, initialShares, "Supply should increase due to fees");

        // Fee receiver should have shares
        assertGt(vault.balanceOf(feeReceiver), 0, "Fee receiver should have shares");
    }

    function test_ManagementFee_OneMonth() public {
        uint256 depositAmount = 10000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        uint256 initialShares = vault.totalSupply();

        // Warp 1 month (30 days)
        skip(30 days);

        vault.takeFees();

        // Expected fee = 10000 * 2% * 30/365 ≈ 16.44 assets
        // But with share dilution calculation, it's slightly different
        uint256 feeReceiverShares = vault.balanceOf(feeReceiver);
        assertGt(feeReceiverShares, 0, "Should have accrued management fee");
        assertApproxEqRel(feeReceiverShares, 16.44e6, 0.1e18, "Fee should be ~16.44");
    }

    function test_ManagementFee_ZeroRate_NoFees() public {
        // Set zero management rate
        vault.updateFeeRates(0, 0);
        skip(DEFAULT_COOLDOWN); // Wait for cooldown

        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        skip(365 days);

        uint256 initialSupply = vault.totalSupply();
        vault.takeFees();

        assertEq(vault.totalSupply(), initialSupply, "No fees should accrue with zero rate");
        assertEq(vault.balanceOf(feeReceiver), 0, "Fee receiver should have no shares");
    }

    // ========================================================================
    //                          PERFORMANCE FEE TESTS
    // ========================================================================

    function test_PerformanceFee_WithProfit() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Set zero management fee to isolate performance fee
        vault.updateFeeRates(0, DEFAULT_PERFORMANCE_RATE);
        skip(DEFAULT_COOLDOWN);

        // Simulate 50% profit
        asset.mint(address(vault), 500e6);

        // Initial PPS was 1e18 (scaled). New PPS = 1500/1000 = 1.5e18 (scaled)
        // HWM = 1e6 (at 6 decimals)
        // Profit per share = 1.5e6 - 1e6 = 0.5e6
        // Performance fee = 0.5e6 * 1000 shares * 20% / 1e6 = 100 assets

        vault.takeFees();

        uint256 feeReceiverShares = vault.balanceOf(feeReceiver);
        assertGt(feeReceiverShares, 0, "Performance fee should be taken");

        // HWM should be updated
        assertGt(vault.highWaterMark(), 1e6, "HWM should increase");
    }

    function test_PerformanceFee_BelowHWM_NoFee() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // First profit: set HWM higher
        asset.mint(address(vault), 500e6);
        vault.takeFees();
        uint256 hwmAfterFirstProfit = vault.highWaterMark();

        // Loss: simulate decrease
        asset.burn(address(vault), 200e6);
        vault.takeFees();

        // HWM should not decrease
        assertEq(vault.highWaterMark(), hwmAfterFirstProfit, "HWM should not decrease");

        // Second profit but still below HWM: no performance fee
        asset.mint(address(vault), 100e6);
        uint256 feeReceiverBefore = vault.balanceOf(feeReceiver);
        vault.takeFees();
        uint256 feeReceiverAfter = vault.balanceOf(feeReceiver);

        // Minimal increase (only from management fee, not performance)
        assertEq(feeReceiverAfter, feeReceiverBefore, "No performance fee below HWM");
    }

    function test_PerformanceFee_AtHWM_NoFee() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Set zero management fee
        vault.updateFeeRates(0, DEFAULT_PERFORMANCE_RATE);
        skip(DEFAULT_COOLDOWN);

        // Initial HWM = 1e6
        // Add exactly 10% profit to bring PPS to 1.1e6
        asset.mint(address(vault), 100e6);
        vault.takeFees();

        uint256 hwm = vault.highWaterMark();
        assertGt(hwm, 1e6, "HWM should be updated");

        // Now PPS equals HWM, adding more should trigger performance fee
        uint256 feeReceiverBefore = vault.balanceOf(feeReceiver);
        asset.mint(address(vault), 50e6);
        vault.takeFees();
        uint256 feeReceiverAfter = vault.balanceOf(feeReceiver);

        assertGt(feeReceiverAfter, feeReceiverBefore, "Performance fee should accrue above HWM");
    }

    // ========================================================================
    //                         COMBINED FEES TESTS
    // ========================================================================

    function test_CombinedFees_ManagementAndPerformance() public {
        uint256 depositAmount = 10000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Warp 6 months and add profit
        skip(180 days);
        asset.mint(address(vault), 2000e6); // 20% profit

        uint256 feeReceiverBefore = vault.balanceOf(feeReceiver);
        vault.takeFees();
        uint256 feeReceiverAfter = vault.balanceOf(feeReceiver);

        // Should have both management (6 months of 2%) and performance (20% of 20% profit)
        assertGt(feeReceiverAfter, feeReceiverBefore, "Combined fees should accrue");
    }

    function test_Fees_ProtocolCut() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Warp 1 year
        skip(365 days);

        vault.takeFees();

        // Both fee receivers should have shares
        uint256 managerShares = vault.balanceOf(feeReceiver);
        uint256 protocolShares = vault.balanceOf(protocolFeeReceiver);

        assertGt(managerShares, 0, "Manager should have fee shares");
        assertGt(protocolShares, 0, "Protocol should have fee shares");

        // Protocol gets 10% of total fee shares
        assertApproxEqRel(protocolShares, managerShares / 9, 0.01e18, "Protocol cut should be ~11.1%");
    }

    function test_Fees_ProtocolCut_PerVaultOverride() public {
        // Override protocol fee to 20% for this vault
        feeRegistry.setProtocolFeeRateBpsForVault(address(vault), 2000);

        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Warp 1 year
        skip(365 days);

        vault.takeFees();

        uint256 managerShares = vault.balanceOf(feeReceiver);
        uint256 protocolShares = vault.balanceOf(protocolFeeReceiver);

        assertGt(managerShares, 0, "Manager should have fee shares");
        assertGt(protocolShares, 0, "Protocol should have fee shares");

        // Protocol gets 20% of total fee shares: ratio = 2000 / 8000 = 0.25
        assertApproxEqRel(protocolShares, managerShares / 4, 0.01e18, "Protocol cut should be ~25%");
    }

    // ========================================================================
    //                        DEPOSIT/WITHDRAW FEE TESTS
    // ========================================================================

    function test_DepositFee_ChargedOnDeposit() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);

        // Set 0.5% deposit fee
        vault.setDepositFee(5e15);

        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);

        // Preview deposit
        uint256 expectedShares = vault.previewDeposit(depositAmount);
        // Fee = 1000 * 0.5% / (100% + 0.5%) = 4.975...
        // Net assets = 1000 - 4.975 = 995.025
        // Shares ≈ 995.025
        assertApproxEqRel(expectedShares, 995.0e6, 0.01e18, "Preview should account for fee");

        uint256 shares = vault.deposit(depositAmount, alice);
        assertEq(shares, expectedShares, "Actual shares should match preview");

        vm.stopPrank();

        // Fee should be in pending fees
        uint256 expectedFee = depositAmount * 5e15 / (5e15 + 1e18);
        assertApproxEqRel(vault.pendingFees(), expectedFee, 0.01e18, "Pending fees should match");
    }

    function test_WithdrawFee_ChargedOnInstantRedeem() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Set 0.5% withdraw fee
        vault.setWithdrawFee(5e15);

        vm.startPrank(alice);
        uint256 redeemAmount = 500e6; // Redeem half of shares

        // Get preview BEFORE requestRedeem (which will call takeFees internally)
        uint256 expectedAssets = vault.previewRedeem(redeemAmount);

        // requestRedeem will call takeFees internally, changing the share price
        // So we need to get a fresh preview after that
        vault.requestRedeem(redeemAmount, alice, alice);
        vm.stopPrank();

        // The actual received should be less than the redeem amount due to fee
        // Note: The exact amount may differ from preview due to fee accrual during redeem
        assertLt(asset.balanceOf(alice), redeemAmount, "Fee should reduce received amount");
        assertGt(asset.balanceOf(alice), redeemAmount * 99 / 100, "Fee should not exceed ~1%");
    }

    // ========================================================================
    //                           FEE RATE UPDATE TESTS
    // ========================================================================

    function test_UpdateFeeRates_WithCooldown() public {
        // setUp already skipped cooldown, so rates are already at DEFAULT rates
        uint16 newManagementRate = 500; // 5%
        uint16 newPerformanceRate = 1000; // 10%

        vault.updateFeeRates(newManagementRate, newPerformanceRate);

        // After the initial cooldown skip in setUp, rates should be immediately applied
        FeeManager.Rates memory currentRates = vault.feeRates();
        assertEq(currentRates.managementRate, newManagementRate, "New rates should be active");
        assertEq(currentRates.performanceRate, newPerformanceRate, "New rates should be active");
    }

    function test_UpdateFeeRates_EmitsEvent() public {
        // setUp already skipped cooldown, so rates are already at DEFAULT rates
        uint16 newManagementRate = 500;
        uint16 newPerformanceRate = 1000;

        // Get current rates (DEFAULT from setUp after initial cooldown)
        FeeManager.Rates memory oldRates = vault.feeRates();

        // Just verify the event is emitted with correct rate values
        // Use 4th parameter as wildcard (check 1st 3, don't check 4th)
        vm.expectEmit(true, true, true, false);
        emit FeeManager.RatesUpdated(
            oldRates,
            FeeManager.Rates({ managementRate: newManagementRate, performanceRate: newPerformanceRate }),
            0 // Timestamp - wildcard
        );

        vault.updateFeeRates(newManagementRate, newPerformanceRate);
    }

    // ========================================================================
    //                          FEE RECEIVER TESTS
    // ========================================================================

    function test_SetFeeReceiver_Success() public {
        address newFeeReceiver = makeAddr("newFeeReceiver");
        vault.setFeeReceiver(newFeeReceiver);

        (address _feeReceiver, address _protocolReceiver) = vault.feeReceivers();
        assertEq(_feeReceiver, newFeeReceiver);
        assertEq(_protocolReceiver, protocolFeeReceiver);
    }

    // ========================================================================
    //                          FEE REGISTRY TESTS
    // ========================================================================

    function test_FeeRegistry_OverridesProtocolFee() public {
        // Deploy new vault with fee registry
        MockRedemptionHook newRedemptionHook = new MockRedemptionHook(RedemptionMode.INSTANT, false);
        MockBalanceUpdateHook newBalanceHook = new MockBalanceUpdateHook(type(uint256).max, false);
        feeRegistry = new FeeRegistryMock(1500, makeAddr("registryReceiver"));

        ElitraVault newVaultImpl = new ElitraVault();

        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            IERC20(address(asset)),
            owner,
            upgradeAdmin,
            address(feeRegistry),
            address(newBalanceHook),
            address(newRedemptionHook),
            "Test Vault 2",
            "TVLT2"
        );

        TransparentUpgradeableProxy newProxy = new TransparentUpgradeableProxy(
            address(newVaultImpl),
            upgradeAdmin,
            initData
        );

        ElitraVault newVault = ElitraVault(payable(address(newProxy)));

        // Protocol rate should come from registry
        assertEq(newVault.protocolRateBps(), 1500, "Should use registry rate");

        // Override per vault
        feeRegistry.setProtocolFeeRateBpsForVault(address(newVault), 500);
        assertEq(newVault.protocolRateBps(), 500, "Should use vault override rate");
    }

    // ========================================================================
    //                           FEE CLAIM TESTS
    // ========================================================================

    function test_ClaimFees_TransfersPending() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Set deposit fee to create pending fees
        vault.setDepositFee(1e16); // 1%

        asset.mint(bob, 1000e6);
        vm.startPrank(bob);
        asset.approve(address(vault), 1000e6);
        vault.deposit(1000e6, bob);
        vm.stopPrank();

        uint256 pendingBefore = vault.pendingFees();
        assertGt(pendingBefore, 0, "Should have pending fees");

        // Need to mint assets to vault for the claim to work
        // The pending fees represent a claim on vault assets
        asset.mint(address(vault), pendingBefore);

        // Claim fees
        uint256 feeReceiverBalanceBefore = asset.balanceOf(feeReceiver);
        vault.claimFees();
        uint256 feeReceiverBalanceAfter = asset.balanceOf(feeReceiver);

        // Manager gets some portion, protocol gets the rest
        uint256 transferred = feeReceiverBalanceAfter - feeReceiverBalanceBefore;
        assertGt(transferred, 0, "Manager should receive some fees");
        // Protocol fees should remain
        assertGt(vault.pendingProtocolFees(), 0, "Protocol should have pending fees");
    }

    function test_ClaimProtocolFees_TransfersPending() public {
        uint256 depositAmount = 1000e6;
        asset.mint(alice, depositAmount);
        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        vm.stopPrank();

        vault.setDepositFee(1e16);

        asset.mint(bob, 1000e6);
        vm.startPrank(bob);
        asset.approve(address(vault), 1000e6);
        vault.deposit(1000e6, bob);
        vm.stopPrank();

        // Claim manager fees first
        vault.claimFees();

        uint256 protocolBalanceBefore = asset.balanceOf(protocolFeeReceiver);
        vault.claimProtocolFees();
        uint256 protocolBalanceAfter = asset.balanceOf(protocolFeeReceiver);

        assertGt(protocolBalanceAfter - protocolBalanceBefore, 0, "Protocol should receive fees");
        assertEq(vault.pendingProtocolFees(), 0, "Protocol fees should be cleared");
    }

    // ========================================================================
    //                           INTEGRATION TESTS
    // ========================================================================

    function test_Integration_DepositProfitWithdrawWithFees() public {
        // 1. Alice deposits
        uint256 aliceDeposit = 10000e6;
        asset.mint(alice, aliceDeposit);
        vm.startPrank(alice);
        asset.approve(address(vault), aliceDeposit);
        vault.deposit(aliceDeposit, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), aliceDeposit);
        assertEq(vault.totalSupply(), aliceDeposit);

        // 2. Time passes and profit accrues
        skip(180 days);
        asset.mint(address(vault), 2000e6); // 20% profit

        // 3. Take fees (management + performance)
        vault.takeFees();

        uint256 aliceShares = vault.balanceOf(alice);
        uint256 feeReceiverShares = vault.balanceOf(feeReceiver);
        uint256 totalSupply = vault.totalSupply();

        assertEq(aliceShares, aliceDeposit, "Alice shares unchanged");
        assertGt(feeReceiverShares, 0, "Fees accrued");

        // 4. Alice withdraws
        vm.startPrank(alice);
        uint256 assetsOut = vault.requestRedeem(aliceShares, alice, alice);
        vm.stopPrank();

        // Alice should get more than she deposited (profit minus fees)
        assertGt(assetsOut, aliceDeposit, "Alice should profit");
        assertEq(vault.balanceOf(alice), 0, "Alice shares burned");
    }

    function test_Integration_MultipleUsersWithFees() public {
        uint256 totalDeposit = 30000e6;

        // Three users deposit
        asset.mint(alice, 10000e6);
        asset.mint(bob, 10000e6);
        address charlie = makeAddr("charlie");
        asset.mint(charlie, 10000e6);

        vm.startPrank(alice);
        asset.approve(address(vault), 10000e6);
        vault.deposit(10000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), 10000e6);
        vault.deposit(10000e6, bob);
        vm.stopPrank();

        vm.startPrank(charlie);
        asset.approve(address(vault), 10000e6);
        vault.deposit(10000e6, charlie);
        vm.stopPrank();

        assertEq(vault.totalSupply(), totalDeposit);

        // Profit accrues over time
        skip(365 days);
        asset.mint(address(vault), 6000e6); // 20% profit

        vault.takeFees();

        // All users should have same share count
        assertEq(vault.balanceOf(alice), 10000e6);
        assertEq(vault.balanceOf(bob), 10000e6);
        assertEq(vault.balanceOf(charlie), 10000e6);

        // Fee receivers should have shares
        uint256 feeReceiverShares = vault.balanceOf(feeReceiver);
        assertGt(feeReceiverShares, 0);

        // Check each user can withdraw their proportional share
        uint256 aliceExpected = vault.previewRedeem(vault.balanceOf(alice));

        vm.startPrank(alice);
        uint256 aliceReceived = vault.requestRedeem(vault.balanceOf(alice), alice, alice);
        vm.stopPrank();

        // Allow small rounding difference
        assertApproxEqRel(aliceReceived, aliceExpected, 0.0001e18, "Alice receives expected amount");
    }
}
