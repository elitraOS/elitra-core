// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ElitraVault } from "src/ElitraVault.sol";
import { Authority } from "@solmate/auth/Auth.sol";
import { IVaultBase, Call } from "src/interfaces/IVaultBase.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MorphoVaultGuard } from "src/guards/sei/MorphoVaultGuard.sol";




contract MorphoGuardForkTest is Test {
    // SEI Mainnet deployment addresses
    address VAULT;
    address AUTHORITY;
    address constant OWNER = 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4;
    address MORPHO_VAULT;
    MorphoVaultGuard morphoGuard;
    ElitraVault vault;
    Authority authority;
    address owner;
    IERC20 asset;
    bool forkEnabled;


    function setUp() public {
        // Check if required environment variables are set
        try vm.envString("RPC_URL") returns (string memory rpcUrl) {
            try vm.envAddress("VAULT_ADDRESS") returns (address vaultAddr) {
                VAULT = vaultAddr;
                try vm.envAddress("ROLES_AUTHORITY_ADDRESS") returns (address authAddr) {
                    AUTHORITY = authAddr;
                    try vm.envAddress("MORPHO_VAULT") returns (address morphoVault) {
                        MORPHO_VAULT = morphoVault;
                        try vm.envAddress("ASSET_ADDRESS") returns (address assetAddr) {
                            asset = IERC20(assetAddr);

                            // Fork SEI mainnet
                            vm.createSelectFork(rpcUrl);

                            // Load deployed contracts
                            vault = ElitraVault(payable(VAULT));
                            authority = Authority(AUTHORITY);

                            // Get the owner from the deployed contract
                            owner = vault.owner();

                            morphoGuard = new MorphoVaultGuard(address(vault));

                            forkEnabled = true;

                            console.log("=== SEI Mainnet Fork Test Setup ===");
                            console.log("Vault:", address(vault));
                            console.log("Authority:", address(authority));
                            console.log("Owner:", owner);
                            console.log("Chain ID:", block.chainid);
                        } catch {
                            forkEnabled = false;
                        }
                    } catch {
                        forkEnabled = false;
                    }
                } catch {
                    forkEnabled = false;
                }
            } catch {
                forkEnabled = false;
            }
        } catch {
            forkEnabled = false;
        }
    }

    function test_morpho_vault_guard() public {
        if (!forkEnabled) {
            return;
        }
        vm.startPrank(owner);
        // get vault asset balance
        uint256 assetBalance = IERC20(asset).balanceOf(address(vault));
        console.log("Asset Balance:", assetBalance);

        // View current morpho vault guard
        address morphoVaultGuard = address(vault.guards(MORPHO_VAULT));
        console.log("Morpho Vault Guard:", morphoVaultGuard);

        // View current asset guard
        address assetGuard = address(vault.guards(address(asset)));
        console.log("Asset Guard:", assetGuard);

        // Morpho deposit selector: deposit(uint256 assets, address receiver)
        bytes4 selector = bytes4(keccak256("deposit(uint256,address)"));
        console.logBytes4(selector);


        // encode the call data
        bytes memory data = abi.encodeWithSelector(selector, 1000000, address(vault));
        // Try to deposit to morpho

        // Set guard for the morpho vault
        vault.setGuard(MORPHO_VAULT, address(morphoGuard));

        // Set guard for the asset
        vault.setGuard(address(asset), address(morphoGuard));

        // Call[0], we need to approve the asset to the morpho vault
        Call[] memory calls = new Call[](2);

        calls[0] = Call({
            target: address(asset),
            data: abi.encodeWithSelector(IERC20.approve.selector, MORPHO_VAULT, 1000000),
            value: 0
        });

        calls[1] = Call({
            target: MORPHO_VAULT,
            data: data,
            value: 0
        });
        vault.manageBatch(calls);


        console.log("Next, trying to withdraw from morpho vault");
        // wait for next block
        vm.roll(block.number + 1);


        // withdraw(uint256 assets, address receiver, address owner)
        bytes4 withdrawSelector = bytes4(keccak256("withdraw(uint256,address,address)"));
        console.logBytes4(withdrawSelector);

        // encode the call data
        bytes memory withdrawData = abi.encodeWithSelector(withdrawSelector, 1000000, address(vault), address(vault));
        console.logBytes(withdrawData);

        Call[] memory withdrawCalls = new Call[](1);
        withdrawCalls[0] = Call({
            target: MORPHO_VAULT,
            data: withdrawData,
            value: 0
        });
        vault.manageBatch(withdrawCalls);

        vm.stopPrank();
    }

}
