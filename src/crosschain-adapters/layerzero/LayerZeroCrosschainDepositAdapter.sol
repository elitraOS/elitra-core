// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseCrosschainDepositAdapter } from "../BaseCrosschainDepositAdapter.sol";
import { IOAppComposer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IWETH9 } from "../../interfaces/IWETH9.sol";

/**
 * @title LayerZeroCrosschainDepositAdapter
 * @author Elitra
 * @notice Upgradeable adapter for cross-chain vault deposits via LayerZero OFT compose
 * @dev Implements IOAppComposer interface to receive OFT compose messages from LayerZero V2
 *
 * @dev This adapter enables users to send tokens cross-chain via LayerZero OFT and auto-deposit
 *      them into vaults on the destination chain. It uses the "compose" feature of OFT which
 *      allows custom logic to be executed after tokens are received.
 *
 * @dev Process flow:
 *      1. User calls OFT.send() on source chain with composeMsg containing vault deposit params
 *      2. LayerZero delivers tokens to this adapter on destination chain
 *      3. lzCompose callback is triggered with the compose message
 *      4. Adapter processes tokens (wraps native if needed) and executes vault deposit
 */
contract LayerZeroCrosschainDepositAdapter is BaseCrosschainDepositAdapter, IOAppComposer {
    // ================== STATE VARIABLES ==================

    /// @notice LayerZero V2 endpoint contract
    // Immutable endpoint to ensure routing cannot be changed post-deploy.
    ILayerZeroEndpointV2 public immutable endpoint;

    /// @notice Maps underlying token addresses to their OFT contract addresses
    // token => OFT mapping for admin tooling and config audits.
    mapping(address => address) public tokenToOFT;

    /// @notice Maps OFT contract addresses to their underlying token addresses
    // OFT => token mapping used at runtime when receiving messages.
    mapping(address => address) public oftToToken;

    /// @notice Tracks which OFTs are approved for use by this adapter
    // Allowlist of OFT senders permitted to trigger deposits.
    mapping(address => bool) public supportedOFTs;

    /// @notice WETH9 token address (for wrapping native tokens received via OFT)
    // WETH address used to wrap native assets delivered by OFT.
    address public weth;

    // ================== INITIALIZER ==================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint) {
        // Endpoint is fixed for security and routing integrity.
        endpoint = ILayerZeroEndpointV2(_endpoint);
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter (replaces constructor for upgradeable contracts)
     * @param _owner Owner who can manage the adapter (add OFTs, pause, etc.)
     * @param _queue CrosschainDepositQueue address for handling failed deposits
     * @param _zapExecutor ZapExecutor address for executing token swaps before deposit
     * @param _weth WETH9 address for wrapping native tokens
     */
    function initialize(address _owner, address _queue, address _zapExecutor, address _weth)
        public
        initializer
    {
        // Initialize inherited adapter state and store WETH address.
        __BaseAdapter_init(_owner, _queue, _zapExecutor);
        weth = _weth;
    }

    /**
     * @notice Updates the WETH9 address
     * @param _weth New WETH9 contract address
     */
    function setWeth(address _weth) external onlyOwner {
        // Allow owner to update WETH if needed.
        weth = _weth;
    }

    // ================== LAYERZERO COMPOSE ==================

    /**
     * @notice LayerZero compose callback - receives tokens and processes vault deposit
     * @dev Called by LayerZero endpoint when OFT compose message is received
     *
     * @param _from Address of the OFT contract that sent the message
     * @param _guid Unique identifier for this LayerZero message (used as depositId)
     * @param _message The compose message containing vault deposit parameters
     *
     *
     * @dev Compose message format (encoded by sender):
     *      abi.encode(vault, receiver, minAmountOut, zapCalls)
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address, // executor
        bytes calldata // extraData
    )
        external
        payable
        override
        whenNotPaused
        nonReentrant
    {
        // Security: Only accept compose messages from the LayerZero endpoint.
        require(msg.sender == address(endpoint), "Only endpoint");

        // Security: Only accept from pre-approved OFTs.
        require(supportedOFTs[_from], "OFT not supported");

        // Decode the OFT compose message using LayerZero's codec.
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Get the underlying token address from the OFT mapping.
        address token = _getTokenFromOFT(_from);

        // If the received token is native (maps to WETH), wrap it.
        // This handles cases where OFT is wrapping a native token (e.g., SEI -> WSEI).
        if (token == weth) {
            IWETH9(weth).deposit{ value: amountLD }();
        }

        // Execute the vault deposit using base adapter logic.
        // srcEid serves as the source identifier for tracking.
        _processReceivedFunds(_from, srcEid, token, amountLD, _guid, composeMsg);
    }

    // ================== ADMIN FUNCTIONS ==================

    /**
     * @notice Sets or updates the OFT token mapping for a specific token
     * @dev Enables the adapter to recognize and process tokens from specific OFTs
     * @param token Underlying token address (e.g., USDC, WETH)
     * @param oft OFT contract address that wraps this token
     * @param isActive Whether to enable or disable this OFT
     *
     * @dev Only the owner can call this function
     * @dev Both addresses must be non-zero
     */
    function setSupportedOFT(address token, address oft, bool isActive) external onlyOwner {
        // Validate inputs and prevent zero-address mappings.
        require(token != address(0) && oft != address(0), "Invalid address");
        tokenToOFT[token] = oft;
        oftToToken[oft] = token;
        // Toggle allowlist status for the OFT.
        supportedOFTs[oft] = isActive;
    }

    // ================== INTERNAL FUNCTIONS ==================

    /**
     * @notice Get the underlying token address from an OFT address
     * @dev Handles the case where an OFT might wrap the token itself (no separate underlying)
     * @param oft OFT contract address
     * @return token The underlying token address, or the OFT address if no mapping exists
     */
    function _getTokenFromOFT(address oft) internal view returns (address) {
        // Prefer explicit mapping when it exists.
        address token = oftToToken[oft];
        if (token != address(0)) {
            return token;
        }
        // Some OFTs are the token itself (e.g., native token OFTs).
        return oft;
    }

    // ================== UUPS UPGRADE ==================

    /**
     * @notice Internal function to authorize contract upgrades
     * @dev Only the owner can upgrade the contract
     */
    function _authorizeUpgrade(address) internal override onlyOwner { }

    /**
     * @notice Allow contract to receive ETH for gas refunds
     * @dev LayerZero may send refund gas fees to this contract
     */
    receive() external payable { }
}
