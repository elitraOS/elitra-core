// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ElitraVault } from "src/ElitraVault.sol";
import { Authority } from "@solmate/auth/Auth.sol";
import { IVaultBase, Call } from "src/interfaces/IVaultBase.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { WNativeGuard } from "src/guards/base/WNativeGuard.sol";




contract GuardForkTest is Test {
    // BSC Mainnet deployment addresses
    address VAULT = vm.envAddress("VAULT_ADDRESS");
    address AUTHORITY = vm.envAddress("ROLES_AUTHORITY_ADDRESS");
    address OWNER = 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4;
    address YEI_POOL = vm.envAddress("YEI_POOL");
    WNativeGuard wseiGuard;
    ElitraVault vault;
    Authority authority;
    address owner;
    IERC20 asset;


    function setUp() public {
        // Fork BSC mainnet - use RPC_URL from environment or default
        string memory rpcUrl = vm.envString("RPC_URL");
        vm.createSelectFork(rpcUrl);

        // Load deployed contracts
        vault = ElitraVault(payable(VAULT));
        authority = Authority(AUTHORITY);
        asset = IERC20(vm.envAddress("ASSET_ADDRESS"));

        // Get the owner from the deployed contract
        owner = vault.owner();

        wseiGuard = new WNativeGuard(owner);

        console.log("=== BSC Mainnet Fork Test Setup ===");
        console.log("Vault:", address(vault));
        console.log("Authority:", address(authority));
        console.log("Owner:", owner);
        console.log("Chain ID:", block.chainid);
    }

    function test_yei_pool_guard() public {
        vm.startPrank(owner);
        // get vault asset balance
        uint256 assetBalance = IERC20(asset).balanceOf(address(vault));
        console.log("Asset Balance:", assetBalance);

        // View current yei pool guard 
        address yeiPoolGuard = address(vault.guards(YEI_POOL));
        console.log("Yei Pool Guard:", yeiPoolGuard);

        // View current asset guard
        address assetGuard = address(vault.guards(address(asset)));
        console.log("Asset Guard:", assetGuard);

        // YEi deposit selector: supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        bytes4 selector = bytes4(keccak256("supply(address,uint256,address,uint16)"));
        console.logBytes4(selector);


        // encode the call data
        bytes memory data = abi.encodeWithSelector(selector, address(asset), 1000000, address(vault), 0);
        // Try to deposit to yei

        wseiGuard.setSpender(YEI_POOL, true);

        // Set guard for the vault
        vault.setGuard(address(asset), address(wseiGuard));

        // Call[0], we need to approve the asset to the yei pool
        Call[] memory calls = new Call[](2);

        calls[0] = Call({
            target: address(asset),
            data: abi.encodeWithSelector(IERC20.approve.selector, YEI_POOL, 1000000),
            value: 0
        });

        calls[1] = Call({
            target: YEI_POOL,
            data: data,
            value: 0
        });
        vault.manageBatch(calls);


        console.log("Next, trying to withdraw from yei pool");
        // wait for next block
        vm.roll(block.number + 1);


        // withdraw(address asset, uint256 amount, address to)
        bytes4 withdrawSelector = bytes4(keccak256("withdraw(address,uint256,address)"));
        console.logBytes4(withdrawSelector);

        // encode the call data
        bytes memory withdrawData = abi.encodeWithSelector(withdrawSelector, address(asset), 1000000, address(vault));
        console.logBytes(withdrawData);

        Call[] memory withdrawCalls = new Call[](1);
        withdrawCalls[0] = Call({
            target: YEI_POOL,
            data: withdrawData,
            value: 0
        });
        vault.manageBatch(withdrawCalls);

        vm.stopPrank();
    }

}

