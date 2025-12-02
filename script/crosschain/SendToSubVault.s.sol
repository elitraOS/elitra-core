// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ElitraVault } from "../../src/ElitraVault.sol";
import { CrosschainStrategyAdapter } from "../../src/adapters/layerzero/CrosschainStrategyAdapter.sol";
import { Call } from "../../src/interfaces/IElitraVault.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

/**
 * @title SendToSubVault
 * @notice Script to send funds from SEI ElitraVault to ARB SubVault via LayerZero
 * @dev Usage: forge script script/crosschain/SendToSubVault.s.sol --rpc-url $RPC_URL --broadcast
 *
 * Required environment variables:
 * - PRIVATE_KEY: Manager private key (must have authority on vault)
 * - VAULT_ADDRESS: The ElitraVault proxy address on SEI
 * - ASSET_ADDRESS: The underlying asset (USDT0) address on SEI
 * - CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS: The adapter address on SEI
 * - ARB_EID: Arbitrum LayerZero endpoint ID (30110)
 * - ARB_SUB_VAULT_ADDRESS: The SubVault address on Arbitrum
 * - SEND_AMOUNT: Amount to send (in wei/smallest unit)
 * - LZ_OPTIONS: (optional) LayerZero options bytes, defaults to empty
 */
contract SendToSubVault is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(privateKey);

        // Load addresses from env
        address vaultAddress = vm.envAddress("CURRENT_VAULT_ADDRESS");
        address assetAddress = vm.envAddress("CURRENT_ASSET_ADDRESS");
        address adapterAddress = vm.envAddress("CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("DEST_EID"));
        address dstVault = vm.envAddress("DEST_VAULT_ADDRESS");
        uint256 sendAmount = vm.envUint("SEND_AMOUNT");

        // Contracts
        ElitraVault vault = ElitraVault(payable(vaultAddress));
        IERC20 asset = IERC20(assetAddress);
        CrosschainStrategyAdapter adapter = CrosschainStrategyAdapter(payable(adapterAddress));

        console2.log("=== Send To SubVault Configuration ===");
        console2.log("Caller:", caller);
        console2.log("Vault:", vaultAddress);
        console2.log("Asset:", assetAddress);
        console2.log("Adapter:", adapterAddress);
        console2.log("Destination EID:", dstEid);
        console2.log("Destination Vault:", dstVault);
        console2.log("Send Amount:", sendAmount);

        // Check vault balance
        uint256 vaultBalance = asset.balanceOf(vaultAddress);
        console2.log("\nVault Asset Balance:", vaultBalance);
        require(vaultBalance >= sendAmount, "Insufficient vault balance");

        // LayerZero options (empty for default gas settings)
        bytes memory options = vm.envOr("LZ_OPTIONS", bytes(""));

        // Quote the LayerZero fee
        console2.log("\n=== Quoting LayerZero Fee ===");
        MessagingFee memory fee = adapter.quoteSendToVault(
            dstEid,
            dstVault,
            assetAddress,
            sendAmount,
            options,
            false // pay in native
        );
        console2.log("Native Fee:", fee.nativeFee);
        console2.log("LZ Token Fee:", fee.lzTokenFee);

        // Add 10% buffer to fee
        uint256 totalFee = fee.nativeFee * 110 / 100;
        console2.log("Total Fee (with 10% buffer):", totalFee);

        // Build the batch calls
        // Call 1: Approve adapter to pull tokens from vault
        bytes memory approveData = abi.encodeWithSelector(
            IERC20.approve.selector,
            adapterAddress,
            sendAmount
        );

        // Call 2: Call sendToVault on adapter (adapter will pull tokens via transferFrom)
        bytes memory sendData = abi.encodeWithSelector(
            CrosschainStrategyAdapter.sendToVault.selector,
            dstEid,
            dstVault,
            assetAddress,
            sendAmount,
            options
        );

        bytes memeory depostToTakaraData = abi.encodeWithSelector(
            TakaraComptroller.deposit.selector,
            sendAmount
        );

        // Create calls array
        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: assetAddress,
            data: approveData,
            value: 0
        });
        calls[1] = Call({
            target: adapterAddress,
            data: sendData,
            value: totalFee
        });

        // my view: first two call: bridge fund from sei -> eth
        // last call: investing on sei -> takara

        console2.log("\n=== Executing Batch ===");
        console2.log("Call 1: Approve adapter to spend", sendAmount, "tokens");
        console2.log("Call 2: sendToVault (adapter pulls tokens) with", totalFee, "wei for LZ fee");

        vm.startBroadcast(privateKey);

        // Execute the batch (need to send ETH with the call)
        vault.manageBatch{ value: totalFee }(calls);

        vm.stopBroadcast();

        // Check balances after
        uint256 vaultBalanceAfter = asset.balanceOf(vaultAddress);
        console2.log("\n=== After Send ===");
        console2.log("Vault Asset Balance:", vaultBalanceAfter);
        console2.log("Tokens Sent:", vaultBalance - vaultBalanceAfter);
    }

    function test() public {
        // Required for forge coverage to work
    }
}
