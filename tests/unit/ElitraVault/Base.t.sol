// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ElitraVault } from "../../../src/ElitraVault.sol";
import { ManualBalanceUpdateHook } from "../../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../../src/hooks/HybridRedemptionHook.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ElitraVault_Base_Test is Test {
    ElitraVault public vaultImplementation;
    ElitraVault public vault;
    ManualBalanceUpdateHook public balanceUpdateHook;
    HybridRedemptionHook public redemptionHook;
    ERC20Mock public asset;

    address public owner;
    address public proxyAdmin;

    function setUp() public virtual {
        owner = makeAddr("owner");
        proxyAdmin = makeAddr("proxyAdmin");

        // Deploy asset
        asset = new ERC20Mock();

        // Deploy adapters
        balanceUpdateHook = new ManualBalanceUpdateHook(owner);
        redemptionHook = new HybridRedemptionHook();

        // Deploy vault implementation
        vaultImplementation = new ElitraVault();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            address(asset),
            owner,
            address(balanceUpdateHook),
            address(redemptionHook),
            "Elitra USDC Vault",
            "eUSDC-v2"
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation),
            proxyAdmin,
            initData
        );

        vault = ElitraVault(payable(address(proxy)));
    }

    function createUser(string memory name) internal returns (address user) {
        user = makeAddr(name);
        asset.mint(user, 1_000_000e6); // 1M USDC
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }
}
