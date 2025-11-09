// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ManualOracleAdapter } from "../../../src/adapters/ManualOracleAdapter.sol";
import { IElitraVault } from "../../../src/interfaces/IElitraVault.sol";
import { ElitraVault } from "../../../src/ElitraVault.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { HybridRedemptionStrategy } from "../../../src/strategies/HybridRedemptionStrategy.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ManualOracleAdapter_Base_Test is Test {
    ManualOracleAdapter public adapter;
    address public owner;
    ElitraVault public vault;
    IERC20 public asset;

    function setUp() public virtual {
        owner = makeAddr("owner");

        // Deploy mock asset
        asset = new ERC20Mock();

        // Deploy adapter
        adapter = new ManualOracleAdapter(owner);

        // Deploy redemption strategy
        HybridRedemptionStrategy redemptionStrategy = new HybridRedemptionStrategy();

        // Deploy vault
        ElitraVault vaultImpl = new ElitraVault();
        bytes memory vaultData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            adapter,
            redemptionStrategy,
            "Test Vault",
            "tVault"
        );
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultImpl), owner, vaultData);
        vault = ElitraVault(payable(address(vaultProxy)));

        // Mint some tokens to vault to simulate existing deposits
        ERC20Mock(address(asset)).mint(address(vault), 1000e6);
        // Also mint shares by depositing
        ERC20Mock(address(asset)).mint(owner, 1000e6);
        vm.startPrank(owner);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(1000e6, owner);
        vm.stopPrank();
    }
}
