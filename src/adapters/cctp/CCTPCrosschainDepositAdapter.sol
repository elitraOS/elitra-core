// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseCrosschainDepositAdapter } from "../BaseCrosschainDepositAdapter.sol";
import { IMessageTransmitterV2 } from "../../interfaces/external/cctp/IMessageTransmitterV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Call } from "../../interfaces/IVaultBase.sol";

/**
 * @title CCTPCrosschainDepositAdapter
 * @author Elitra
 * @notice Adapter for cross-chain vault deposits via Circle CCTP V2 hooks
 * @dev Enables users to burn USDC on source chains and auto-deposit to vaults on destination chains
 */
contract CCTPCrosschainDepositAdapter is BaseCrosschainDepositAdapter {
    // ================== STATE VARIABLES ==================

    /// @notice CCTP V2 MessageTransmitter contract for relaying cross-chain messages
    IMessageTransmitterV2 public messageTransmitter;

    /// @notice USDC token address on this chain (typically native USDC)
    address public usdc;

    /// @notice Tracks processed message hashes to prevent replay attacks
    mapping(bytes32 => bool) public processedMessages;

    // ================== CONSTANTS ==================

    /// @notice Supported CCTP message format version
    uint32 public constant SUPPORTED_MESSAGE_VERSION = 1;

    /// @notice Supported CCTP message body version
    uint32 public constant SUPPORTED_BODY_VERSION = 1;

    // ================== ERRORS ==================

    /// @notice Thrown when the message transmitter address is invalid
    error InvalidMessageTransmitter();

    /// @notice Thrown when the USDC address is invalid
    error InvalidUSDC();

    /// @notice Thrown when a message has already been processed (replay protection)
    error MessageAlreadyProcessed();

    /// @notice Thrown when CCTP message relay fails
    error RelayFailed();

    // ================== EVENTS ==================

    /// @notice Emitted when a CCTP message is successfully relayed
    /// @param messageHash Hash of the relayed message (for replay protection tracking)
    /// @param sourceDomain CCTP domain ID of the source chain
    /// @param mintRecipient Address that received the minted tokens
    /// @param amount Amount of USDC received
    event MessageRelayed(bytes32 indexed messageHash, uint32 sourceDomain, address mintRecipient, uint256 amount);

    // ================== INITIALIZER ==================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter with CCTP configuration
     * @param _owner Owner who can manage the adapter
     * @param _messageTransmitter CCTP V2 MessageTransmitter contract address
     * @param _usdc USDC token address on this chain
     * @param _queue CrosschainDepositQueue address for handling failed deposits
     * @param _zapExecutor ZapExecutor address for executing token swaps before deposit
     */
    function initialize(
        address _owner,
        address _messageTransmitter,
        address _usdc,
        address _queue,
        address _zapExecutor
    ) public initializer {
        if (_messageTransmitter == address(0)) revert InvalidMessageTransmitter();
        if (_usdc == address(0)) revert InvalidUSDC();

        __BaseAdapter_init(_owner, _queue, _zapExecutor);

        messageTransmitter = IMessageTransmitterV2(_messageTransmitter);
        usdc = _usdc;
    }

    // ================== CORE FUNCTIONS ==================

    /**
     * @notice Relays a CCTP message and executes the deposit hook
     * @dev Called by relayers after receiving attestation from CCTP
     * @param message The CCTP burn message containing deposit details
     * @param attestation Signature attesting to the validity of the burn message
     * @return relaySuccess True if the message was successfully relayed
     * @return hookSuccess True if the deposit hook executed successfully
     *
     * @dev Process flow:
     *      1. Calculate message hash and check replay protection
     *      2. Mark message as processed (before external call for reentrancy safety)
     *      3. Call CCTP MessageTransmitter to receive the attested message
     *      4. Calculate USDC amount received via balance delta
     *      5. Decode hook data from the message
     *      6. Execute vault deposit via BaseCrosschainDepositAdapter logic
     */
    function relay(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant whenNotPaused returns (bool relaySuccess, bool hookSuccess) {
        // Calculate message hash to prevent replay attacks
        bytes32 messageHash = keccak256(message);
        if (processedMessages[messageHash]) revert MessageAlreadyProcessed();

        // Mark as processed before external call (CEI pattern)
        processedMessages[messageHash] = true;

        // Get balance before relay to calculate received amount
        uint256 balanceBefore = IERC20(usdc).balanceOf(address(this));

        // Relay message through CCTP MessageTransmitter (mints USDC to this contract)
        relaySuccess = messageTransmitter.receiveMessage(message, attestation);
        if (!relaySuccess) revert RelayFailed();

        // Calculate received amount using balance delta
        uint256 balanceAfter = IERC20(usdc).balanceOf(address(this));
        uint256 amountReceived = balanceAfter - balanceBefore;

        // Decode CCTP message parts to extract deposit parameters
        (uint32 sourceDomain, address mintRecipient, bytes memory hookData) = _decodeMessage(message);

        emit MessageRelayed(messageHash, sourceDomain, mintRecipient, amountReceived);

        // If hook data exists, execute deposit via Base logic
        // Hook data format: abi.encode(vault, receiver, minAmountOut, zapCalls)
        if (hookData.length > 0) {
            // CCTP "sourceDomain" maps to "sourceId" in Base adapter
            _processReceivedFunds(mintRecipient, sourceDomain, usdc, amountReceived, messageHash, hookData);
            hookSuccess = true;
        } else {
            revert("No hook data");
        }
    }

    /**
     * @notice Helper function to encode hook data for cross-chain deposits
     * @dev This ensures encoding format stays in sync between off-chain scripts and on-chain decoding
     * @param vault Target vault address where tokens will be deposited
     * @param receiver Address that will receive the vault shares
     * @param minAmountOut Minimum amount of tokens to receive after zapping (slippage protection)
     * @param zapCalls Array of calls to execute token swaps before deposit
     * @return encoded The abi encoded hook data
     */
    function encodeHookData(
        address vault,
        address receiver,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external pure returns (bytes memory) {
        // HookData structure: abi.encode(vault, receiver, minAmountOut, zapCalls)
        return abi.encode(vault, receiver, minAmountOut, zapCalls);
    }

    // ================== INTERNAL FUNCTIONS ==================

    /**
     * @notice Decodes a CCTP message to extract relevant fields for deposit processing
     * @dev CCTP message format is defined by Circle's CCTP V2 specification
     * @param message The raw CCTP burn message
     * @return sourceDomain CCTP domain ID of the source chain
     * @return mintRecipient Address that should receive the minted tokens
     * @return hookData Additional data containing vault deposit parameters
     *
     * @dev Message structure (per CCTP V2 spec):
     *      - Bytes 0-4: Version
     *      - Bytes 4-8: Source Domain ID (uint32)
     *      - Bytes 8-36: Sender address
     *      - Bytes 36-68: Recipient address (bytes32)
     *      - ... (other fields)
     *      - Bytes 148+: Message body
     *          - Bytes 36-68 of body: Recipient (mintRecipient)
     *          - Bytes 228+: Optional hook data (if present)
     */
    function _decodeMessage(
        bytes calldata message
    ) internal pure returns (uint32 sourceDomain, address mintRecipient, bytes memory hookData) {
        // Extract source domain (bytes 4-8, formatted as uint32)
        sourceDomain = uint32(bytes4(message[4:8]));

        // Message body starts at offset 148 per CCTP V2 spec
        bytes calldata messageBody = message[148:];

        // Extract mintRecipient from message body (offset 36-68)
        bytes32 recipientBytes32 = bytes32(messageBody[36:68]);
        mintRecipient = address(uint160(uint256(recipientBytes32)));

        // Extract hookData if present (starts at offset 228 in body)
        // Hook data is appended by the sender and contains vault deposit instructions
        if (messageBody.length > 228) {
            hookData = messageBody[228:];
        }
    }

    // ================== ADMIN FUNCTIONS ==================

    /**
     * @notice Allow contract to receive ETH
     * @dev Should not be needed for pure USDC operations but included for safety
     */
    receive() external payable { }
}
