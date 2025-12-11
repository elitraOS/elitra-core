// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseCrosschainDepositAdapter } from "../BaseCrosschainDepositAdapter.sol";
import { IMessageTransmitterV2 } from "../../interfaces/external/cctp/IMessageTransmitterV2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Call } from "../../interfaces/IVaultBase.sol";

/**
 * @title CCTPCrosschainDepositAdapter
 * @notice Adapter for cross-chain vault deposits via Circle CCTP V2 hooks
 */
contract CCTPCrosschainDepositAdapter is BaseCrosschainDepositAdapter {
    // ================== STATE VARIABLES ==================

    /// @notice CCTP V2 MessageTransmitter contract
    IMessageTransmitterV2 public messageTransmitter;

    /// @notice USDC token address on this chain
    address public usdc;

    /// @notice Processed message hashes to prevent replay
    mapping(bytes32 => bool) public processedMessages;

    // ================== CONSTANTS ==================

    uint32 public constant SUPPORTED_MESSAGE_VERSION = 1;
    uint32 public constant SUPPORTED_BODY_VERSION = 1;

    // ================== ERRORS ==================

    error InvalidMessageTransmitter();
    error InvalidUSDC();
    error MessageAlreadyProcessed();
    error RelayFailed();

    // ================== EVENTS ==================

    event MessageRelayed(bytes32 indexed messageHash, uint32 sourceDomain, address mintRecipient, uint256 amount);

    // ================== INITIALIZER ==================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter
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
     * @notice Relay CCTP message and execute hook for vault deposit
     */
    function relay(
        bytes calldata message,
        bytes calldata attestation
    ) external nonReentrant whenNotPaused returns (bool relaySuccess, bool hookSuccess) {
        // Calculate message hash to prevent replay
        bytes32 messageHash = keccak256(message);
        if (processedMessages[messageHash]) revert MessageAlreadyProcessed();
        
        // Mark as processed before external call
        processedMessages[messageHash] = true;

        // Get balance before relay
        uint256 balanceBefore = IERC20(usdc).balanceOf(address(this));

        // Relay message through CCTP MessageTransmitter
        relaySuccess = messageTransmitter.receiveMessage(message, attestation);
        if (!relaySuccess) revert RelayFailed();

        // Calculate received amount
        uint256 balanceAfter = IERC20(usdc).balanceOf(address(this));
        uint256 amountReceived = balanceAfter - balanceBefore;

        // Decode CCTP parts
        (uint32 sourceDomain, address mintRecipient, bytes memory hookData) = _decodeMessage(message);

        emit MessageRelayed(messageHash, sourceDomain, mintRecipient, amountReceived);

        // If hook data exists, execute deposit via Base logic
        if (hookData.length > 0) {
            // CCTP "sourceDomain" maps to "sourceId" in Base
            _processReceivedFunds(mintRecipient, sourceDomain, usdc, amountReceived, messageHash, hookData);
            hookSuccess = true;
        } else {
            // No hook - just leave USDC in contract
            hookSuccess = true;
        }
    }

    /**
     * @notice Encode hook data helper
     */
    function encodeHookData(
        address vault,
        address receiver,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external pure returns (bytes memory) {
        // HookData structure matches the decode payload in Base
        return abi.encode(vault, receiver, minAmountOut, zapCalls);
    }

    // ================== INTERNAL FUNCTIONS ==================

    /**
     * @notice Decode CCTP message to extract relevant fields
     */
    function _decodeMessage(
        bytes calldata message
    ) internal pure returns (uint32 sourceDomain, address mintRecipient, bytes memory hookData) {
        // Extract source domain (offset 4)
        sourceDomain = uint32(bytes4(message[4:8]));

        // Message body starts at offset 148
        bytes calldata messageBody = message[148:];

        // Extract mintRecipient (offset 36 in body)
        bytes32 recipientBytes32 = bytes32(messageBody[36:68]);
        mintRecipient = address(uint160(uint256(recipientBytes32)));

        // Extract hookData if present (offset 228 in body)
        if (messageBody.length > 228) {
            hookData = messageBody[228:];
        }
    }

    /**
     * @notice CCTP doesn't use OFTs - this function is not applicable
     * @dev Required by ICrosschainDepositAdapter interface but not used in CCTP
     */
    function setSupportedOFT(address, address, bool) external pure {
        revert("CCTP does not use OFTs");
    }

    /**
     * @notice Allow contract to receive ETH (should not happen for pure USDC ops but good for safety)
     */
    receive() external payable { }
}
