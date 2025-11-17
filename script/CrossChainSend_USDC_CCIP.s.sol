// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CrossChainSend_SEI_CCIP
 * @notice Script to send SEI from Ethereum to SEI chain using Chainlink CCIP
 * @dev This script uses CCIP to bridge SEI tokens to the same broadcaster address on SEI chain
 *
 * Usage:
 *   forge script script/CrossChainSend_SEI_CCIP.s.sol:CrossChainSend_SEI_CCIP \
 *     --rpc-url <SOURCE_CHAIN_RPC> \
 *     --broadcast \
 *     --verify
 *
 * Environment Variables:
 *   PRIVATE_KEY or MNEMONIC - For transaction signing
 *   SEI_TOKEN_ADDRESS - SEI token contract on source chain (Ethereum)
 *   CCIP_ROUTER_ADDRESS - CCIP Router contract address on source chain
 *   DESTINATION_CHAIN_SELECTOR - CCIP chain selector for SEI chain
 *   AMOUNT - Amount of SEI to bridge (in wei, defaults to 1 ether)
 */
contract CrossChainSend_USDC_CCIP is BaseScript {

    function run() public broadcast {
        // Get environment variables
        address usdcToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address ccipRouter = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
        uint64 destinationChainSelector = 9027416829622342829;
        uint256 amount = 10000;
        address receiver = broadcaster; // Send to same address on destination chain

        console.log("=== Cross-Chain USDC Send via CCIP ===");
        console.log("USDC Token (source):", usdcToken);
        console.log("CCIP Router (source):", ccipRouter);
        console.log("Destination Chain Selector:", destinationChainSelector);
        console.log("Amount:", amount);
        console.log("Sender:", broadcaster);
        console.log("Receiver:", receiver);

        // Check if destination chain is supported
        console.log("\n=== Checking Chain Support ===");
        try IRouterClient(ccipRouter).isChainSupported(destinationChainSelector) returns (bool supported) {
            console.log("Chain supported:", supported);
            require(supported, "Destination chain not supported by CCIP router");
        } catch {
            console.log("Warning: Could not verify chain support (router may not implement isChainSupported)");
        }

        // Get supported tokens for this lane
        console.log("\n=== Checking Token Support ===");
        try IRouterClient(ccipRouter).getSupportedTokens(destinationChainSelector) returns (address[] memory supportedTokens) {
            console.log("Number of supported tokens:", supportedTokens.length);
            bool tokenSupported = false;
            for (uint256 i = 0; i < supportedTokens.length; i++) {
                if (supportedTokens[i] == usdcToken) {
                    tokenSupported = true;
                    console.log("USDC is supported on this lane");
                    break;
                }
            }
            if (!tokenSupported && supportedTokens.length > 0) {
                console.log("WARNING: USDC may not be supported. First supported token:", supportedTokens[0]);
            }
        } catch {
            console.log("Warning: Could not verify token support");
        }

        // Check USDC balance
        uint256 balance = IERC20(usdcToken).balanceOf(broadcaster);
        require(balance >= amount, "Insufficient USDC balance");
        console.log("USDC Balance:", balance);

        // Check allowance and approve if needed
        uint256 allowance = IERC20(usdcToken).allowance(broadcaster, ccipRouter);
        if (allowance < amount) {
            console.log("\n=== Approving CCIP Router ===");
            console.log("Current allowance:", allowance);
            IERC20(usdcToken).approve(ccipRouter, type(uint256).max);
            console.log("Approval complete");
        }

        // Build CCIP message
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: usdcToken,
            amount: amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: "", // No additional data, just token transfer
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({
                    gasLimit: 0 // No gas needed on destination for simple transfer
                })
            ),
            feeToken: address(0) // Pay fees in native token (ETH)
        });

        // Get the fee
        console.log("\n=== Querying CCIP Fee ===");
        uint256 fee;
        try IRouterClient(ccipRouter).getFee(destinationChainSelector, message) returns (uint256 _fee) {
            fee = _fee;
            console.log("Fee (in native token):", fee);
        } catch Error(string memory reason) {
            console.log("Error getting fee:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Low-level error getting fee");
            console.logBytes(lowLevelData);
            revert("Failed to get CCIP fee - token may not be supported on this CCIP lane");
        }

        // Check broadcaster has enough native token for fees
        require(broadcaster.balance >= fee, "Insufficient balance for CCIP fees");
        console.log("Broadcaster balance:", broadcaster.balance);

        console.log("\n=== Broadcasting Transaction ===");

        // Send CCIP message
        bytes32 messageId = IRouterClient(ccipRouter).ccipSend{value: fee}(
            destinationChainSelector,
            message
        );

        console.log("\n=== Transaction Complete ===");
        console.log("Message ID:", vm.toString(messageId));
        console.log("USDC sent cross-chain. Monitor CCIP explorer for delivery status.");
    }
}

/**
 * @title IRouterClient Interface
 * @notice Interface for Chainlink CCIP Router
 */
interface IRouterClient {
    function getFee(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage memory message
    ) external view returns (uint256 fee);

    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage memory message
    ) external payable returns (bytes32 messageId);

    function isChainSupported(
        uint64 chainSelector
    ) external view returns (bool supported);

    function getSupportedTokens(
        uint64 chainSelector
    ) external view returns (address[] memory tokens);
}

/**
 * @title Client Library
 * @notice CCIP Client library for message structures
 */
library Client {
    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct EVM2AnyMessage {
        bytes receiver;
        bytes data;
        EVMTokenAmount[] tokenAmounts;
        bytes extraArgs;
        address feeToken;
    }

    struct EVMExtraArgsV1 {
        uint256 gasLimit;
    }

    function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(0x97a657c9, extraArgs); // EVM_EXTRA_ARGS_V1_TAG
    }
}
