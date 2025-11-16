// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMultichainDepositAdapter} from "../src/interfaces/IMultichainDepositAdapter.sol";

/**
 * @notice LayerZero V2 SendParam struct
 */
struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

/**
 * @notice LayerZero V2 MessagingFee struct
 */
struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

/**
 * @notice LayerZero V2 MessagingReceipt struct
 */
struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

/**
 * @title CrossChainDeposit_SEI_WSEI
 * @notice Script to execute cross-chain SEI deposit with WSEI wrapping
 * @dev This script calls the SEI OFT on source chain (e.g., Ethereum) to bridge SEI to SEI chain,
 *      where it will be wrapped to WSEI and deposited into the WSEI vault
 *
 * Usage:
 *   forge script script/CrossChainDeposit_SEI_WSEI.s.sol:CrossChainDeposit_SEI_WSEI \
 *     --rpc-url <SOURCE_CHAIN_RPC> \
 *     --broadcast \
 *     --verify
 *
 * Environment Variables:
 *   PRIVATE_KEY or MNEMONIC - For transaction signing
 *   SEI_OFT_ADDRESS - SEI OFT contract on source chain (default: 0xbdf43ecadc5cef51b7d1772f722e40596bc1788b)
 *   ADAPTER_ADDRESS - MultichainDepositAdapter address on SEI chain
 *   WSEI_ADDRESS - WSEI token address on SEI (default: 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7)
 *   WSEI_VAULT_ADDRESS - WSEI Vault address on SEI (default: 0x397e97798D2b2BBe17FaD2228D84C200c9F0554D)
 *   AMOUNT - Amount of SEI to bridge and deposit (in wei)
 *   RECEIVER - Address to receive vault shares (defaults to broadcaster)
 *   DST_EID - LayerZero destination endpoint ID for SEI chain
 */
contract CrossChainDeposit_SEI_WSEI is BaseScript {

    function run() public broadcast {
        // Get environment variables or use defaults
        address seiOft = vm.envAddress("ETH_SEI_OFT_ADDRESS");
        address adapterAddress = vm.envAddress("SEI_LZ_ADAPTER_ADDRESS"); // Must be set
        address wseiAddress = vm.envAddress("ASSET_ADDRESS");
        address wseiVault = vm.envAddress("VAULT_ADDRESS");
        uint256 amount = 1 ether;
        address receiver = broadcaster;
        uint32 dstEid = uint32(vm.envUint("LAYERZERO_SEI_EID"));

        console.log("=== Cross-Chain SEI Deposit to WSEI Vault ===");
        console.log("SEI OFT (source):", seiOft);
        console.log("Adapter (SEI chain):", adapterAddress);
        console.log("WSEI (SEI chain):", wseiAddress);
        console.log("WSEI Vault (SEI chain):", wseiVault);
        console.log("Amount:", amount);
        console.log("Receiver:", receiver);
        console.log("Destination EID:", dstEid);

        // Build zap calls for wrapping SEI to WSEI on destination chain
        IMultichainDepositAdapter.Call[] memory zapCalls = new IMultichainDepositAdapter.Call[](1);

        // Wrap SEI to WSEI by calling WSEI.deposit() with value
        zapCalls[0] = IMultichainDepositAdapter.Call({
            target: wseiAddress,
            value: amount, // Send SEI value to wrap
            data: abi.encodeWithSignature("deposit()") // WSEI.deposit()
        });

        // Encode compose message: (vault, receiver, zapCalls)
        bytes memory composeMsg = abi.encode(wseiVault, receiver, zapCalls);

        console.log("\n=== Compose Message ===");
        console.log("Vault:", wseiVault);
        console.log("Receiver:", receiver);
        console.log("Zap calls count:", zapCalls.length);
        console.logBytes(composeMsg);

        // Build execution options with gas for lzReceive and lzCompose
        bytes memory options = _buildOptions();

        // Build SendParam for LayerZero OFT
        SendParam memory sendParam = _buildSendParam(dstEid, adapterAddress, amount, composeMsg, options);

        // Quote the messaging fee
        (uint256 nativeFee, uint256 lzTokenFee) = _quoteSend(seiOft, sendParam);

        console.log("\n=== LayerZero Fees ===");
        console.log("Native fee:", nativeFee);
        console.log("LZ token fee:", lzTokenFee);

        // Check broadcaster has enough SEI for amount + gas
        uint256 requiredBalance = amount + nativeFee;
        require(broadcaster.balance >= requiredBalance, "Insufficient balance for amount + gas");

        console.log("\n=== Broadcasting Transaction ===");
        console.log("Required balance:", requiredBalance);
        console.log("Broadcaster balance:", broadcaster.balance);

        // Call SEI OFT to send tokens cross-chain
        // This will trigger lzCompose on the adapter on SEI chain
        _sendOFT(seiOft, sendParam, nativeFee);

        console.log("\n=== Transaction Complete ===");
        console.log("SEI sent cross-chain. Monitor adapter on SEI chain for deposit completion.");
    }

    /**
     * @notice Build execution options for LayerZero
     * @dev Format: TYPE_3 | WORKER_ID | option_length | option_type | encoded_option
     */
    function _buildOptions() internal pure returns (bytes memory) {
        // Worker ID = 1 (Executor)
        // Option Type 1 = lzReceive gas
        // Option Type 3 = lzCompose gas

        // lzReceive option: gas limit for receiving the OFT on destination
        bytes memory lzReceiveOption = abi.encodePacked(
            uint128(200000), // gas limit
            uint128(0)       // msg.value
        );

        // lzCompose option: gas limit for executing compose message (our zap + deposit)
        bytes memory lzComposeOption = abi.encodePacked(
            uint16(0),        // index (0 for first compose)
            uint128(1200000), // gas limit (need more for zap + deposit)
            uint128(0)        // msg.value
        );

        // Combine options into Type 3 format
        return abi.encodePacked(
            uint16(3),  // Type 3 (addExecutorLzReceiveOption + addExecutorLzComposeOption)
            uint8(1),   // Worker ID (Executor)
            uint16(lzReceiveOption.length + 1),  // Option length + 1 byte for option type
            uint8(1),   // Option type: lzReceive
            lzReceiveOption,
            uint8(1),   // Worker ID (Executor)
            uint16(lzComposeOption.length + 1),  // Option length + 1 byte for option type
            uint8(3),   // Option type: lzCompose
            lzComposeOption
        );
    }

    /**
     * @notice Build LayerZero SendParam struct
     */
    function _buildSendParam(uint32 dstEid, address to, uint256 amount, bytes memory composeMsg, bytes memory options)
        internal
        pure
        returns (SendParam memory)
    {
        // SendParam struct:
        // - dstEid: destination endpoint ID
        // - to: recipient address (adapter) as bytes32
        // - amountLD: amount in local decimals
        // - minAmountLD: minimum amount (slippage protection)
        // - extraOptions: execution options for gas
        // - composeMsg: our custom compose message
        // - oftCmd: OFT command (empty for standard send)

        bytes32 toBytes32 = bytes32(uint256(uint160(to)));

        return SendParam({
            dstEid: dstEid,
            to: toBytes32,
            amountLD: amount,
            minAmountLD: (amount * 9900) / 10000, // 1% slippage
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: ""
        });
    }

    /**
     * @notice Quote the send fee
     */
    function _quoteSend(address oft, SendParam memory sendParam) internal view returns (uint256 nativeFee, uint256 lzTokenFee) {
        // Use interface to call quoteSend
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        nativeFee = fee.nativeFee;
        lzTokenFee = fee.lzTokenFee;
    }

    /**
     * @notice Send OFT cross-chain
     */
    function _sendOFT(address oft, SendParam memory sendParam, uint256 nativeFee) internal {
        // Use interface to call send
        MessagingFee memory fee = MessagingFee({
            nativeFee: nativeFee,
            lzTokenFee: 0
        });

        MessagingReceipt memory receipt = IOFT(oft).send{value: nativeFee}(
            sendParam,
            fee,
            payable(broadcaster) // refundAddress
        );

        console.log("OFT send successful");
        console.log("Message GUID:", vm.toString(receipt.guid));
        console.log("Nonce:", receipt.nonce);
    }
}

/**
 * @title IOFT Interface
 * @notice Interface for LayerZero OFT contracts
 */
interface IOFT {
    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken)
        external view returns (MessagingFee memory msgFee);

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external payable returns (MessagingReceipt memory msgReceipt);
}

/**
 * @title WSEI Interface
 * @notice Interface for wrapped SEI
 */
interface IWSEI {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
