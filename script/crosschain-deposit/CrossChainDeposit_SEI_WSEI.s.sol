// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Call } from "../../src/interfaces/IElitraVault.sol";

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
 *   forge script script/crosschain-deposit/CrossChainDeposit_SEI_WSEI.s.sol:CrossChainDeposit_SEI_WSEI \
 *     --rpc-url <SOURCE_CHAIN_RPC> \
 *     --broadcast \
 *     -vvv
 *
 * Environment Variables:
 *   PRIVATE_KEY - For transaction signing
 *   ETH_SEI_OFT_ADDRESS - SEI OFT contract on source chain
 *   LZ_CROSSCHAIN_ADAPTER_ADDRESS - CrosschainDepositAdapter address on SEI chain
 *   ASSET_ADDRESS - WSEI token address on SEI
 *   VAULT_ADDRESS - WSEI Vault address on SEI
 *   AMOUNT - Amount of SEI to bridge and deposit (in wei, defaults to 1 ether)
 *   RECEIVER - Address to receive vault shares (defaults to deployer)
 *   LZ_SEI_EID - LayerZero destination endpoint ID for SEI chain
 */
contract CrossChainDeposit_SEI_WSEI is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get environment variables
        address ethSeiOft = vm.envAddress("ETH_OFT_ADDRESS");
        address adapterAddress = vm.envAddress("LZ_CROSSCHAIN_ADAPTER_ADDRESS");
        address wseiAddress = vm.envAddress("ASSET_ADDRESS");
        address wseiVault = vm.envAddress("VAULT_ADDRESS");
        uint256 amount = vm.envOr("AMOUNT", uint256(0.001 ether));
        address receiver = vm.envOr("RECEIVER", deployer);
        uint32 dstEid = uint32(vm.envUint("LZ_EID"));

        console.log("=== Cross-Chain SEI Deposit to WSEI Vault ===");
        console.log("Deployer:", deployer);
        console.log("SEI OFT (source):", ethSeiOft);
        console.log("Adapter (SEI chain):", adapterAddress);
        console.log("WSEI (SEI chain):", wseiAddress);
        console.log("WSEI Vault (SEI chain):", wseiVault);
        console.log("Amount:", amount);
        console.log("Receiver:", receiver);
        console.log("Destination EID:", dstEid);

        // Build zap calls for wrapping SEI to WSEI on destination chain
        Call[] memory zapCalls = new Call[](1);

        // Wrap SEI to WSEI by calling WSEI.deposit() with value
        zapCalls[0] = Call({
            target: wseiAddress,
            value: amount, // Send SEI value to wrap
            data: abi.encodeWithSignature("deposit()") // WSEI.deposit()
        });

        // minAmountOut: expect at least 99% of amount after wrapping (should be 1:1)
        uint256 minAmountOut = (amount * 9900) / 10000;

        // Encode compose message: (vault, receiver, minAmountOut, zapCalls)
        bytes memory composeMsg = abi.encode(wseiVault, receiver, minAmountOut, zapCalls);

        console.log("\n=== Compose Message ===");
        console.log("Vault:", wseiVault);
        console.log("Receiver:", receiver);
        console.log("Min Amount Out:", minAmountOut);
        console.log("Zap calls count:", zapCalls.length);
        console.logBytes(composeMsg);

        // Build execution options with gas for lzReceive and lzCompose
        bytes memory options = _buildOptions();

        // Build SendParam for LayerZero OFT
        SendParam memory sendParam = _buildSendParam(dstEid, adapterAddress, amount, composeMsg, options);

        // Quote the messaging fee
        (uint256 nativeFee, uint256 lzTokenFee) = _quoteSend(ethSeiOft, sendParam);

        console.log("\n=== LayerZero Fees ===");
        console.log("Native fee:", nativeFee);
        console.log("LZ token fee:", lzTokenFee);

        // Check deployer has enough SEI for amount + gas
        uint256 requiredBalance = amount + nativeFee;
        console.log("deployer balance:", deployer.balance);
        console.log("Required balance:", requiredBalance);
        require(deployer.balance >= requiredBalance, "Insufficient balance for amount + gas");

        console.log("\n=== Broadcasting Transaction ===");
        console.log("Required balance:", requiredBalance);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Call SEI OFT to send tokens cross-chain
        // This will trigger lzCompose on the adapter on SEI chain
        _sendOFT(ethSeiOft, sendParam, nativeFee, deployer);

        vm.stopBroadcast();

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
    function _buildSendParam(
        uint32 dstEid,
        address to,
        uint256 amount,
        bytes memory composeMsg,
        bytes memory options
    ) internal pure returns (SendParam memory) {
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
    function _quoteSend(
        address oft,
        SendParam memory sendParam
    ) internal view returns (uint256 nativeFee, uint256 lzTokenFee) {
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        nativeFee = fee.nativeFee;
        lzTokenFee = fee.lzTokenFee;
    }

    /**
     * @notice Send OFT cross-chain
     */
    function _sendOFT(
        address oft,
        SendParam memory sendParam,
        uint256 nativeFee,
        address refundAddress
    ) internal {
        MessagingFee memory fee = MessagingFee({
            nativeFee: nativeFee,
            lzTokenFee: 0
        });

        MessagingReceipt memory receipt = IOFT(oft).send{value: nativeFee}(
            sendParam,
            fee,
            payable(refundAddress)
        );

        console.log("OFT send successful");
        console.log("Message GUID:", vm.toString(receipt.guid));
        console.log("Nonce:", receipt.nonce);
    }

    function test() public {
        // Required for forge coverage to work
    }
}

/**
 * @title IOFT Interface
 * @notice Interface for LayerZero OFT contracts
 */
interface IOFT {
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee);

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt);
}

/**
 * @title WSEI Interface
 * @notice Interface for wrapped SEI
 */
interface IWSEI {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
