// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseCrosschainDepositAdapter } from "../BaseCrosschainDepositAdapter.sol";
import { OAppUpgradeable, Origin } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import { OAppOptionsType3Upgradeable } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { IOAppComposer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";

/**
 * @title CrosschainDepositAdapter
 * @notice Upgradeable adapter for cross-chain vault deposits via LayerZero OFT compose
 */
contract CrosschainDepositAdapter is 
    BaseCrosschainDepositAdapter, 
    OAppUpgradeable, 
    OAppOptionsType3Upgradeable, 
    IOAppComposer 
{
    // ================== STATE VARIABLES ==================

    mapping(address => address) public tokenToOFT; // token => OFT contract
    mapping(address => address) public oftToToken; // OFT => token contract
    mapping(address => bool) public supportedOFTs;

    // ================== INITIALIZER ==================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint) OAppUpgradeable(_endpoint) {
        _disableInitializers();
    }

    function initialize(address _owner, address _queue, address _zapExecutor) public initializer {
        __BaseAdapter_init(_owner, _queue, _zapExecutor);
        __OApp_init(_owner);
    }

    // ================== LAYERZERO COMPOSE ==================

    /**
     * @notice LayerZero compose callback - receives tokens and processes deposit
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
        override(IOAppComposer)
        whenNotPaused
        nonReentrant
    {
        // Only accept compose messages from the LayerZero endpoint
        require(msg.sender == address(endpoint), "Only endpoint");

        // Only accept from supported OFTs
        require(supportedOFTs[_from], "OFT not supported");

        // Decode the OFT compose message
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Get the token that was received (from the OFT mapping)
        address token = _getTokenFromOFT(_from);

        // Call Base Logic
        // Note: passing srcEid as the sourceId
        _processReceivedFunds(_from, srcEid, token, amountLD, _guid, composeMsg);
    }

    // ================== ADMIN FUNCTIONS ==================

    /**
     * @notice Set supported OFT token mapping
     */
    function setSupportedOFT(address token, address oft, bool isActive) external onlyOwner {
        require(token != address(0) && oft != address(0), "Invalid address");
        tokenToOFT[token] = oft;
        oftToToken[oft] = token;
        supportedOFTs[oft] = isActive;
    }

    // ================== INTERNAL FUNCTIONS ==================

    /**
     * @notice Get token address from OFT address
     */
    function _getTokenFromOFT(address oft) internal view returns (address) {
        address token = oftToToken[oft];
        if (token != address(0)) {
            return token;
        }
        return oft;
    }

    // ================== OVERRIDES ==================

    // Conflict Resolution for Multiple Inheritance
    function _authorizeUpgrade(address newImpl) internal override(BaseCrosschainDepositAdapter, OAppUpgradeable) onlyOwner {}
    
    // OApp requires implementation of _lzReceive but we only use compose
    function _lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) internal pure override {
        revert("Does not receive standard messages");
    }

    /**
     * @notice Allow contract to receive ETH for refund gas fees
     */
    receive() external payable { }
}
