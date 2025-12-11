// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseScript } from "../Base.s.sol";
import { console } from "forge-std/console.sol";
import { CCTPCrosschainDepositAdapter } from "src/adapters/cctp/CCTPCrosschainDepositAdapter.sol";

/**
 * @title CCTP_RelayWithAdapter
 * @notice Script to relay CCTP message with hook data via CCTPCrosschainDepositAdapter
 *
 * Usage:
 *   ADAPTER=0x... MESSAGE=0x... ATTESTATION=0x... forge script script/cctp/CCTP_RelayWithAdapter.s.sol \
 *     --rpc-url $SEI_RPC_URL \
 *     --broadcast
 *
 * Example with your attestation:
 *   ADAPTER=0x... \
 *   MESSAGE=0x000000010000000600000010a1abf0796f7356cbbe4eb7e385042e341a69e928b9224008c2b635a7d53061c700000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d00000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d0000000000000000000000000000000000000000000000000000000000000000000003e8000003e800000001000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000d4b5314e9412dbc1c772093535df451a1e2af1a40000000000000000000000000000000000000000000000000000000000002710000000000000000000000000d4b5314e9412dbc1c772093535df451a1e2af1a400000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000af1ca4900000000000000000000000082eb7d078de7e6bf160de007c39542c482e438f4000000000000000000000000d4b5314e9412dbc1c772093535df451a1e2af1a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000 \
 *   ATTESTATION=0x61eac7384ed11c8afa4785e2b0283b837a07d45244147b3b5306a093db0c4d4b1ad1d0c1dcd18ddfb10b8f92f24105dde1c7ff9f1fd82469c862ccf2f6c145b31c73b57bfb4793803b16c66fc2d39a0a4b40a7891bda721421f1e0f1f48e3f1a1878f5aa6e9122070462ceb539feea323437444081289bbd984003b91caf2abfa51b \
 *   forge script script/cctp/CCTP_RelayWithAdapter.s.sol --rpc-url $SEI_RPC_URL --broadcast
 */
contract CCTP_RelayWithAdapter is BaseScript {
    function run() public broadcast {
        // Get adapter address
        address adapterAddress = vm.envAddress("CCTP_ADAPTER_ADDRESS");
        require(adapterAddress != address(0), "ADAPTER env var required");

        // Get message and attestation from env
        bytes memory message = vm.envBytes("MESSAGE");
        bytes memory attestation = vm.envBytes("ATTESTATION");

        require(message.length > 0, "MESSAGE env var required");
        require(attestation.length > 0, "ATTESTATION env var required");

        console.log("=== CCTP Relay via CCTPCrosschainDepositAdapter ===");
        console.log("Adapter Address:", adapterAddress);
        console.log("Message length:", message.length);
        console.log("Attestation length:", attestation.length);
        console.log("Relayer:", broadcaster);

        // Decode message to show details
        _logMessageDetails(message);

        // Call relay on adapter
        console.log("\n=== Calling relay() ===");
        CCTPCrosschainDepositAdapter adapter = CCTPCrosschainDepositAdapter(payable(adapterAddress));

        (bool relaySuccess, bool hookSuccess) = adapter.relay(message, attestation);

        console.log("\n=== Relay Complete ===");
        console.log("Relay Success:", relaySuccess);
        console.log("Hook Success:", hookSuccess);

        if (relaySuccess && hookSuccess) {
            console.log("\nUSDC received and deposited to vault successfully!");
            console.log("Check recipient's vault shares");
        } else {
            console.log("\nRelay failed - check adapter logs");
        }
    }

    function _logMessageDetails(bytes memory message) internal pure {
        // Extract source domain (offset 4)
        uint32 sourceDomain;
        assembly {
            sourceDomain := mload(add(message, 8))
        }
        sourceDomain = sourceDomain >> 224; // Shift to get uint32

        // Extract mint recipient from message body (offset 148 + 36)
        address mintRecipient;
        assembly {
            let ptr := add(message, add(148, 68)) // 148 offset + 36 + 32
            mintRecipient := mload(ptr)
        }

        // Extract amount (offset 148 + 68)
        uint256 amount;
        assembly {
            let ptr := add(message, add(148, 100)) // 148 offset + 68 + 32
            amount := mload(ptr)
        }

        console.log("\n=== Message Details ===");
        console.log("Source Domain:", sourceDomain);
        console.log("Mint Recipient:", mintRecipient);
        console.log("Amount:", amount);

        // Check if hook data exists (message body offset 148 + min body size 228)
        if (message.length > 376) {
            console.log("Hook Data detected");

            // Extract vault address from hook data
            address vault;
            assembly {
                let ptr := add(message, add(148, 260)) // 148 + 228 + 32
                vault := mload(ptr)
            }

            // Extract receiver address
            address receiver;
            assembly {
                let ptr := add(message, add(148, 292)) // 148 + 228 + 64
                receiver := mload(ptr)
            }

            console.log("\n=== Hook Data ===");
            console.log("Target Vault:", vault);
            console.log("Receiver:", receiver);
        }
    }
}
