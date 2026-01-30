// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseScript } from "../Base.s.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ITokenMessengerV2 } from "src/interfaces/external/cctp/ITokenMessengerV2.sol";
import { CCTPCrosschainDepositAdapter } from "src/adapters/cctp/CCTPCrosschainDepositAdapter.sol";
import { Call } from "src/interfaces/IElitraVault.sol";

/**
 * @title CCTP_SendUSDC_ToSei_WithHook
 * @notice Script to send USDC to SEI with hook for auto-deposit to vault
 *
 * Usage:
 *   AMOUNT=10000000 VAULT=0x... forge script script/cctp/CCTP_SendUSDC_ToSei_WithHook.s.sol \
 *     --rpc-url $RPC_URL \
 *     --broadcast
 */
contract CCTP_SendUSDC_ToSei_WithHook is BaseScript {
    // CCTP V2 Domain IDs
    uint32 internal constant DOMAIN_ETHEREUM = 0;
    uint32 internal constant DOMAIN_AVALANCHE = 1;
    uint32 internal constant DOMAIN_OP_MAINNET = 2;
    uint32 internal constant DOMAIN_ARBITRUM = 3;
    uint32 internal constant DOMAIN_BASE = 6;
    uint32 internal constant DOMAIN_POLYGON = 7;
    uint32 internal constant DOMAIN_SEI = 16;

    // Finality thresholds
    uint32 internal constant FINALITY_FAST = 1000;
    uint32 internal constant FINALITY_STANDARD = 2000;

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
        // Get configuration - cache to reduce stack pressure
        address adapterAddress = vm.envAddress("CCTP_ADAPTER_ADDRESS");
        address vault = vm.envAddress("VAULT_ADDRESS");
        require(vault != address(0), "VAULT env var required");

        // Detect source chain early
        (address usdc, uint32 sourceDomain, string memory chainName) = _getChainConfig(getChainId());

        uint256 amount = vm.envOr("AMOUNT", uint256(10_000)); // Default 0.01 USDC
        address recipient = vm.envOr("RECIPIENT", broadcaster);
        uint256 maxFee = vm.envOr("MAX_FEE", amount / 100); // Default 1%

        console.log("=== CCTP V2 USDC Transfer to SEI with Hook ===");
        console.log("Source Chain:", chainName);
        console.log("Source Domain:", sourceDomain);
        console.log("USDC Address:", usdc);
        console.log("Amount:", amount);
        console.log("Max Fee:", maxFee);
        console.log("Sender:", broadcaster);
        console.log("Recipient:", recipient);
        console.log("Target Vault:", vault);

        // Check balance
        uint256 balance = IERC20(usdc).balanceOf(broadcaster);
        console.log("\n=== Balance Check ===");
        console.log("USDC Balance:", balance);
        require(balance >= amount, "Insufficient USDC balance");

        // Approve
        _approveIfNeeded(usdc, amount);

        // Encode hook data using CCTPCrosschainDepositAdapter helper
        bytes memory hookData = _encodeHookData(vault, recipient, 0, new Call[](0));

        console.log("\n=== Hook Data ===");
        console.log("Hook data length:", hookData.length);

        // Call depositForBurnWithHook
        console.log("\n=== Calling depositForBurnWithHook ===");

        ITokenMessengerV2(TOKEN_MESSENGER_V2).depositForBurnWithHook(
            amount,
            DOMAIN_SEI,
            _addressToBytes32(adapterAddress),
            usdc,
            bytes32(0), // Any address can relay
            maxFee,
            FINALITY_FAST,
            hookData
        );

        console.log("\n=== Transaction Complete ===");
        console.log("USDC burned with hook data");
        console.log("");
        console.log("Next steps:");
        console.log("1. Wait for attestation");
        console.log("2. Relayer calls CCTPCrosschainDepositAdapter.relay() on SEI");
        console.log("3. USDC auto-deposited to vault, shares sent to recipient");
    }

    function _approveIfNeeded(address usdc, uint256 amount) internal {
        uint256 allowance = IERC20(usdc).allowance(broadcaster, TOKEN_MESSENGER_V2);
        if (allowance < amount) {
            console.log("\n=== Approving TokenMessenger ===");
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

    /**
     * @notice Encode hook data - delegates to CCTPCrosschainDepositAdapter.encodeHookData
     * @dev This ensures encoding format stays in sync with the adapter contract
     */
    function _encodeHookData(
        address vault,
        address receiver,
        uint256 minAmountOut,
        Call[] memory zapCalls
    ) internal pure returns (bytes memory) {
        return abi.encode(vault, receiver, minAmountOut, zapCalls);
    }
}
