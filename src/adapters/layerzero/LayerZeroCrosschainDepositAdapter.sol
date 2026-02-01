// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseCrosschainDepositAdapter } from "../BaseCrosschainDepositAdapter.sol";
import { IOAppComposer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IWETH9 } from "../../interfaces/IWETH9.sol";

/**
 * @title LayerZeroCrosschainDepositAdapter
 * @notice Upgradeable adapter for cross-chain vault deposits via LayerZero OFT compose.
 * @dev Implements IOAppComposer interface to receive OFT compose messages.
 */
contract LayerZeroCrosschainDepositAdapter is BaseCrosschainDepositAdapter, IOAppComposer {
    // ================== STATE VARIABLES ==================

    /// @notice LayerZero endpoint
    ILayerZeroEndpointV2 public immutable endpoint;

    mapping(address => address) public tokenToOFT; // token => OFT contract
    mapping(address => address) public oftToToken; // OFT => token contract
    mapping(address => bool) public supportedOFTs;
    address public weth;

    // ================== INITIALIZER ==================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter (replaces constructor for upgradeable contracts)
     * @param _owner Owner of the contract
     * @param _queue CrosschainDepositQueue address
     * @param _zapExecutor ZapExecutor address
     * @param _weth WETH9 address
     */
    function initialize(address _owner, address _queue, address _zapExecutor, address _weth)
        public
        initializer
    {
        __BaseAdapter_init(_owner, _queue, _zapExecutor);
        weth = _weth;
    }

    function setWeth(address _weth) external onlyOwner {
        weth = _weth;
    }

    // ================== LAYERZERO COMPOSE ==================

    /**
     * @notice LayerZero compose callback - receives tokens and processes deposit.
     * @dev Called by LayerZero endpoint when OFT compose message is received.
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
        // Only accept compose messages from the LayerZero endpoint.
        require(msg.sender == address(endpoint), "Only endpoint");

        // Only accept from supported OFTs.
        require(supportedOFTs[_from], "OFT not supported");

        // Decode the OFT compose message.
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Get the token that was received (from the OFT mapping).
        address token = _getTokenFromOFT(_from);

        // Deposit goes to WETH in case of OFT is native.
        if (token == weth) {
            IWETH9(weth).deposit{ value: amountLD }();
        }

        // Call base logic (passing srcEid as the sourceId).
        _processReceivedFunds(_from, srcEid, token, amountLD, _guid, composeMsg);
    }

    // ================== ADMIN FUNCTIONS ==================

    /**
     * @notice Set supported OFT token mapping.
     * @param token Underlying token address
     * @param oft OFT contract address
     * @param isActive Whether the OFT is active
     */
    function setSupportedOFT(address token, address oft, bool isActive) external onlyOwner {
        require(token != address(0) && oft != address(0), "Invalid address");
        tokenToOFT[token] = oft;
        oftToToken[oft] = token;
        supportedOFTs[oft] = isActive;
    }

    // ================== INTERNAL FUNCTIONS ==================

    /**
     * @notice Get token address from OFT address.
     */
    function _getTokenFromOFT(address oft) internal view returns (address) {
        address token = oftToToken[oft];
        if (token != address(0)) {
            return token;
        }
        return oft;
    }

    // ================== UUPS UPGRADE ==================

    /**
     * @dev Internal function to authorize upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner { }

    /**
     * @notice Allow contract to receive ETH for refund gas fees.
     */
    receive() external payable { }
}
