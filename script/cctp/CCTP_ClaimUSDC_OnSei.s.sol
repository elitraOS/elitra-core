// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseScript } from "../Base.s.sol";
import { console } from "forge-std/console.sol";

/**
 * @title CCTP_ClaimUSDC_OnSei
 * @notice Script to claim USDC on SEI after CCTP transfer attestation is complete
 *
 * Usage:
 *   MESSAGE=0x... ATTESTATION=0x... forge script script/cctp/CCTP_ClaimUSDC_OnSei.s.sol:CCTP_ClaimUSDC_OnSei \
 *     --rpc-url $SEI_RPC_URL \
 *     --broadcast
 */
contract CCTP_ClaimUSDC_OnSei is BaseScript {
    // CCTP V2 MessageTransmitter on SEI (same address across all EVM chains)
    address internal constant MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    function run() public broadcast {
        bytes memory message = hex"0000000100000006000000106f7cd236ca58f04827dbf8003ac11f0cfb82479a2388dba01cc4394aad0a9e5000000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d00000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d0000000000000000000000000000000000000000000000000000000000000000000003e8000003e800000001000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000d4b5314e9412dbc1c772093535df451a1e2af1a40000000000000000000000000000000000000000000000000000000000002710000000000000000000000000d4b5314e9412dbc1c772093535df451a1e2af1a400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000aec870b";
        bytes memory attestation = hex"31c032c522f75e13359bfd8101b5998fae0400c44b3a9eb0798578781cfcdafa4e2a71fb07d9bbf041321c03eec8143dd7275afc4f5153eeb2ddfbcd1b5c04541b3d45f5f13ef3ffd3c03d1a8f21df22a2a97c744a926e920f6577923542e73c597308aec059424049640dd5c9a80c181c96ab3ad49ed2205a3b39a2021baea9c71c";

        require(message.length > 0, "MESSAGE env var required");
        require(attestation.length > 0, "ATTESTATION env var required");

        console.log("=== CCTP Claim USDC on SEI ===");
        console.log("MessageTransmitter:", MESSAGE_TRANSMITTER_V2);
        console.log("Message length:", message.length);
        console.log("Attestation length:", attestation.length);

        // Call receiveMessage on MessageTransmitter
        (bool success,) = MESSAGE_TRANSMITTER_V2.call(
            abi.encodeWithSignature("receiveMessage(bytes,bytes)", message, attestation)
        );

        require(success, "receiveMessage failed");

        console.log("\n=== Claim Complete ===");
        console.log("USDC should now be in recipient wallet on SEI");
    }
}
