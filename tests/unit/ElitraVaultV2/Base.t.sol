// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ElitraVaultV2 } from "../../../src/ElitraVaultV2.sol";
import { ManualOracleAdapter } from "../../../src/adapters/ManualOracleAdapter.sol";
import { HybridRedemptionStrategy } from "../../../src/strategies/HybridRedemptionStrategy.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ElitraVaultV2_Base_Test is Test {
    ElitraVaultV2 public vaultImplementation;
    ElitraVaultV2 public vault;
    ManualOracleAdapter public oracleAdapter;
    HybridRedemptionStrategy public redemptionStrategy;
    ERC20Mock public asset;

    address public owner;
    address public proxyAdmin;

    function setUp() public virtual {
        owner = makeAddr("owner");
        proxyAdmin = makeAddr("proxyAdmin");

        // Deploy asset
        asset = new ERC20Mock();

        // Deploy adapters
        oracleAdapter = new ManualOracleAdapter(owner);
        redemptionStrategy = new HybridRedemptionStrategy();

        // Deploy vault implementation
        vaultImplementation = new ElitraVaultV2();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            ElitraVaultV2.initialize.selector,
            address(asset),
            owner,
            address(oracleAdapter),
            address(redemptionStrategy),
            "Elitra USDC Vault V2",
            "eUSDC-v2"
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(vaultImplementation),
            proxyAdmin,
            initData
        );

        vault = ElitraVaultV2(payable(address(proxy)));
    }

    function createUser(string memory name) internal returns (address user) {
        user = makeAddr(name);
        asset.mint(user, 1_000_000e6); // 1M USDC
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }
}
