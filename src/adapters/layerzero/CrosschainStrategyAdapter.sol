// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// LayerZero Official Upgradeable OApp imports
import {OAppUpgradeable, Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

// OpenZeppelin Upgradeable imports
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// OpenZeppelin standard imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Elitra imports
import {IVaultBase, Call} from "../../interfaces/IVaultBase.sol";

/**
 * @title StrategyAdapter
 * @author Elitra
 * @notice Upgradeable adapter for cross-chain strategy execution via LayerZero OFT compose
 * @dev Receives tokens via LayerZero, forwards to SubVault, and executes strategy calls
 */
contract StrategyAdapter is
    Initializable,
    OAppUpgradeable,
    IOAppComposer,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // ========================================= CONSTANTS =========================================

    /// @notice Role identifier for operators who can pause/unpause
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ========================================= ERRORS =========================================

    error InvalidOwner();
    error InvalidSubVault();
    error InvalidAddress();
    error InvalidRecipient();

    // ========================================= STATE VARIABLES =========================================

    /// @notice Mapping of token address to OFT contract address
    mapping(address token => address oft) public tokenToOFT; 
    
    /// @notice Mapping of supported OFT addresses
    mapping(address oft => bool supported) public supportedOFTs;

    // ========================================= EVENTS =========================================

    /// @notice Emitted when a strategy is executed
    /// @param subVault The address of the sub-vault receiving funds
    /// @param token The token address transferred
    /// @param amount The amount of tokens transferred
    event StrategyExecuted(address indexed subVault, address indexed token, uint256 amount);

    /// @notice Emitted when tokens are recovered via emergency function
    /// @param token The token address recovered
    /// @param to The recipient address
    /// @param amount The amount recovered
    event EmergencyRecovery(address indexed token, address indexed to, uint256 amount);

    // ========================================= INITIALIZER =========================================

    /// @notice Constructor
    /// @param _endpoint LayerZero endpoint address
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint) OAppUpgradeable(_endpoint) {
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter
     * @param _owner Contract owner
     */
    function initialize(address _owner) public initializer {
        if (_owner == address(0)) revert InvalidOwner();

        __OApp_init(_owner);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);
    }

    // ========================================= CORE FUNCTIONS =========================================

    /**
     * @notice LayerZero compose callback - receives tokens and executes strategy
     * @inheritdoc ILayerZeroComposer
     */
    function lzCompose(
        address _from,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address, // executor
        bytes calldata // extraData
    ) external payable override whenNotPaused nonReentrant {
        // Only accept compose messages from the LayerZero endpoint
        if (msg.sender != address(endpoint)) revert OnlyEndpoint(msg.sender);

        // Validate OFT is supported
        // In this context, _from is the OFT contract address on this chain
        // require(supportedOFTs[_from], "OFT not supported");

        // Decode the OFT compose message
        // uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Decode our custom compose message: (subVault)
        address subVault = abi.decode(
            composeMsg,
            (address)
        );

        if (subVault == address(0)) revert InvalidSubVault();

        // Get the token that was received (assuming _from is the OFT address)
        address token = _getTokenFromOFT(_from);
        
        // 1. Transfer the received tokens to the SubVault
        IERC20(token).safeTransfer(subVault, amountLD);

        emit StrategyExecuted(subVault, token, amountLD);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Set supported OFT for a token
     * @param token The underlying token address
     * @param oft The OFT contract address
     * @param isActive Whether the OFT is supported
     */
    function setSupportedOFT(address token, address oft, bool isActive) external onlyOwner {
        if (token == address(0) || oft == address(0)) revert InvalidAddress();
        tokenToOFT[token] = oft;
        supportedOFTs[oft] = isActive;
    }

    /**
     * @notice Pause the adapter
     */
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the adapter
     */
    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    /**
     * @notice Recover tokens or ETH accidentally sent to the contract
     * @param token The token address to recover (address(0) for ETH)
     * @param to The recipient address
     * @param amount The amount to recover
     */
    function emergencyRecover(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidRecipient();

        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyRecovery(token, to, amount);
    }

    /**
     * @notice Authorize contract upgrade
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Intentionally empty: access control handled by onlyOwner modifier
        newImplementation; // Silence unused variable warning
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Get the underlying token address from an OFT address
     * @param oft The OFT contract address
     * @return The underlying token address
     */
    function _getTokenFromOFT(address oft) internal view returns (address) {
        return oft;
    }

    /**
     * @notice Internal function to handle LayerZero receive
     * @dev This adapter uses compose messages, not direct receives
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata /*_message*/,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // This adapter uses lzCompose for receiving tokens via OFT
        // Direct lzReceive is not used in this implementation
        revert("Use lzCompose");
    }

    /**
     * @notice Allow receiving ETH
     */
    receive() external payable {}
}

