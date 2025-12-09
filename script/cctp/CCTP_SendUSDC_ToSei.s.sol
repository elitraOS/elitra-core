// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseScript } from "../Base.s.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITokenMessengerV2 } from "src/interfaces/external/cctp/ITokenMessengerV2.sol";

/**
 * @title CCTP_SendUSDC_ToSei
 * @notice Script to send USDC from supported chains to SEI using Circle CCTP V2
 * @dev BSC does NOT support USDC via CCTP (only USYC). Use Ethereum, Base, or Arbitrum as source.
 *
 * Usage:
 *   forge script script/cctp/CCTP_SendUSDC_ToSei.s.sol:CCTP_SendUSDC_ToSei \
 *     --rpc-url $RPC_URL \
 *     --broadcast
 *
 * Environment Variables:
 *   PRIVATE_KEY - For transaction signing
 *   AMOUNT - Amount of USDC to send (in 6 decimals, e.g., 1000000 = 1 USDC)
 *   RECIPIENT - (Optional) Recipient address on SEI, defaults to broadcaster
 *   MAX_FEE - (Optional) Max fee in USDC units, defaults to 1% of amount
 */
contract CCTP_SendUSDC_ToSei is BaseScript {
    // CCTP V2 Domain IDs
    uint32 internal constant DOMAIN_ETHEREUM = 0;
    uint32 internal constant DOMAIN_AVALANCHE = 1;
    uint32 internal constant DOMAIN_OP_MAINNET = 2;
    uint32 internal constant DOMAIN_ARBITRUM = 3;
    uint32 internal constant DOMAIN_BASE = 6;
    uint32 internal constant DOMAIN_POLYGON = 7;
    uint32 internal constant DOMAIN_SEI = 16;

    // Finality thresholds
    uint32 internal constant FINALITY_FAST = 1000; // ~seconds, higher fee
    uint32 internal constant FINALITY_STANDARD = 2000; // ~minutes, lower fee

    // CCTP V2 TokenMessenger (same address across all EVM chains)
    address internal constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;

    // USDC Addresses per Chain
    address internal constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant USDC_AVALANCHE = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address internal constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address internal constant USDC_OP_MAINNET = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

    function run() public broadcast {
        // Get configuration
        uint256 amount = vm.envOr("AMOUNT", uint256(10000)); // Default 0.01 USDC
        address recipient = vm.envOr("RECIPIENT", broadcaster);
        uint256 maxFee = vm.envOr("MAX_FEE", amount / 100); // Default 1%

        // Detect source chain and get USDC address
        uint256 chainId = getChainId();
        (address usdc, uint32 sourceDomain, string memory chainName) = _getChainConfig(chainId);

        _logConfig(chainName, sourceDomain, usdc, amount, recipient, maxFee);

        // Check USDC balance
        uint256 balance = IERC20(usdc).balanceOf(broadcaster);
        console.log("\n=== Balance Check ===");
        console.log("USDC Balance:", balance);
        require(balance >= amount, "Insufficient USDC balance");

        // Approve TokenMessenger to spend USDC
        _approveIfNeeded(usdc, amount);

        // Convert recipient address to bytes32 format
        bytes32 mintRecipient = _addressToBytes32(recipient);

        // Call depositForBurn on TokenMessenger V2
        console.log("\n=== Calling depositForBurn ===");
        console.log("Destination Domain (SEI):", DOMAIN_SEI);
        console.log("Max Fee:", maxFee);
        console.log("Finality: STANDARD (2000)");

        ITokenMessengerV2(TOKEN_MESSENGER_V2).depositForBurn(
            amount,
            DOMAIN_SEI,
            mintRecipient,
            usdc,
            bytes32(0), // Any address can relay
            maxFee,
            FINALITY_FAST
        );

        console.log("\n=== Transaction Complete ===");
        console.log("USDC burned on source chain");
        console.log("");
        console.log("Next steps:");
        console.log("1. Wait for attestation (~10-20 minutes for standard finality)");
        console.log("2. Query: https://iris-api.circle.com/v2/messages/{txHash}");
        console.log("3. Once attested, USDC will be auto-minted on SEI");
    }

    function _logConfig(
        string memory chainName,
        uint32 sourceDomain,
        address usdc,
        uint256 amount,
        address recipient,
        uint256 maxFee
    ) internal view {
        console.log("=== CCTP V2 USDC Transfer to SEI ===");
        console.log("Source Chain:", chainName);
        console.log("Source Domain:", sourceDomain);
        console.log("USDC Address:", usdc);
        console.log("TokenMessenger V2:", TOKEN_MESSENGER_V2);
        console.log("Amount:", amount);
        console.log("Max Fee:", maxFee);
        console.log("Sender:", broadcaster);
        console.log("Recipient:", recipient);
    }

    function _approveIfNeeded(address usdc, uint256 amount) internal {
        uint256 allowance = IERC20(usdc).allowance(broadcaster, TOKEN_MESSENGER_V2);
        if (allowance < amount) {
            console.log("\n=== Approving TokenMessenger ===");
            console.log("Current allowance:", allowance);
            IERC20(usdc).approve(TOKEN_MESSENGER_V2, type(uint256).max);
            console.log("Approval complete");
        }
    }

    function _getChainConfig(
        uint256 chainId
    ) internal pure returns (address usdc, uint32 domain, string memory name) {
        if (chainId == 1) {
            return (USDC_ETHEREUM, DOMAIN_ETHEREUM, "Ethereum");
        } else if (chainId == 8453) {
            return (USDC_BASE, DOMAIN_BASE, "Base");
        } else if (chainId == 42161) {
            return (USDC_ARBITRUM, DOMAIN_ARBITRUM, "Arbitrum");
        } else if (chainId == 43114) {
            return (USDC_AVALANCHE, DOMAIN_AVALANCHE, "Avalanche");
        } else if (chainId == 137) {
            return (USDC_POLYGON, DOMAIN_POLYGON, "Polygon");
        } else if (chainId == 10) {
            return (USDC_OP_MAINNET, DOMAIN_OP_MAINNET, "OP Mainnet");
        } else {
            revert("Unsupported chain");
        }
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
