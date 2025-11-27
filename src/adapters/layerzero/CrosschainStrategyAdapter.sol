// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// LayerZero imports
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";

// OpenZeppelin imports
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CrosschainStrategyAdapter
 * @author Elitra
 * @notice Simple adapter for cross-chain token transfers via LayerZero OFT
 * @dev Only the registered vault can send tokens.
 */
contract CrosschainStrategyAdapter is Ownable {
    using SafeERC20 for IERC20;

    // ========================================= STATE =========================================

    /// @notice The vault address that is allowed to call sendStrategy
    address public vault;

    /// @notice The wrapped native token address (e.g. WSEI)
    address public immutable wrappedNative;

    /// @notice Mapping of token address to its corresponding OFT contract address
    mapping(address token => address oft) public tokenToOft;

    /// @notice Mapping of destination Endpoint ID to the allowed Vault address on that chain
    mapping(uint32 dstEid => address remoteVault) public dstEidToVault;

    // ========================================= ERRORS =========================================

    error OnlyVault();
    error InvalidVault();
    error InvalidRecipient();
    error InvalidFee();
    error VaultNotAllowed();
    error InvalidAddress();
    error TokenNotSupported();

    // ========================================= EVENTS =========================================

    /// @notice Emitted when tokens are sent to another chain
    /// @param dstEid The destination endpoint ID
    /// @param recipient The recipient address on the destination chain
    /// @param token The token address sent
    /// @param amount The amount of tokens sent
    event MessageSent(uint32 indexed dstEid, address indexed recipient, address indexed token, uint256 amount);

    /// @notice Emitted when a token configuration is set
    /// @param token The token address
    /// @param oft The OFT contract address
    event TokenConfigSet(address indexed token, address indexed oft);

    /// @notice Emitted when the vault address is updated
    /// @param oldVault The previous vault address
    /// @param newVault The new vault address
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    /// @notice Emitted when a remote vault address is set
    /// @param dstEid The destination endpoint ID
    /// @param remoteVault The allowed remote vault address
    event RemoteVaultSet(uint32 indexed dstEid, address indexed remoteVault);

    /// @notice Emitted when tokens are recovered via emergency function
    /// @param token The token address recovered
    /// @param to The recipient address
    /// @param amount The amount recovered
    event EmergencyRecovery(address indexed token, address indexed to, uint256 amount);

    // ========================================= MODIFIERS =========================================

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    // ========================================= CONSTRUCTOR =========================================

    /**
     * @notice Constructor
     * @param _owner Contract owner
     * @param _vault The vault address allowed to send messages
     * @param _wrappedNative The address of the wrapped native token (e.g., WSEI)
     */
    constructor(address _owner, address _vault, address _wrappedNative) Ownable(_owner) {
        if (_vault == address(0)) revert InvalidVault();
        
        vault = _vault;
        wrappedNative = _wrappedNative;
    }

    // ========================================= CORE FUNCTIONS =========================================

    /**
     * @notice Send tokens to vault on another chain
     * @param _dstEid Destination endpoint ID
     * @param _recipient Address of the recipient on the destination chain
     * @param _token Address of the token to send
     * @param _amount Amount of tokens to send
     * @param _options LayerZero message options
     * @return receipt The messaging receipt
     * @return oftReceipt The OFT receipt
     */
    function sendToVault(
        uint32 _dstEid,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes calldata _options
    ) external payable onlyVault returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt) {
        // pull fund from the vault 
        IERC20(_token).safeTransferFrom(vault, address(this), _amount);

        // Verify the recipient is the allowed vault for this chain
        if (dstEidToVault[_dstEid] != _recipient) revert VaultNotAllowed();

        address oft = tokenToOft[_token];
        if (oft == address(0)) revert TokenNotSupported();

        // Build SendParam
        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: OFTComposeMsgCodec.addressToBytes32(_recipient),
            amountLD: _amount,
            minAmountLD: (_amount * 9900) / 10000, // 1% slippage tolerance
            extraOptions: _options,
            composeMsg: "",
            oftCmd: ""
        });

        // Quote the messaging fee
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

        if (_token == wrappedNative) {
            // Unwrap WSEI to Native SEI
            IWETH9(_token).withdraw(_amount);
            
            // Ensure we have enough native balance (fee from msg.value + amount from unwrap)
            if (address(this).balance < fee.nativeFee + _amount) revert InvalidFee();

            // Send Native SEI (fee + amount)
            (receipt, oftReceipt) = IOFT(oft).send{value: fee.nativeFee + _amount}(sendParam, fee, payable(msg.sender));
        } else {
            if (msg.value < fee.nativeFee) revert InvalidFee();

            // Approve OFT to spend tokens
            IERC20(_token).safeIncreaseAllowance(oft, _amount);

            // Send tokens
            (receipt, oftReceipt) = IOFT(oft).send{value: fee.nativeFee}(sendParam, fee, payable(msg.sender));

            // Reset allowance if any remaining
            uint256 remaining = IERC20(_token).allowance(address(this), oft);
            if (remaining > 0) {
                IERC20(_token).safeDecreaseAllowance(oft, remaining);
            }
        }

        emit MessageSent(_dstEid, _recipient, _token, _amount);
    }

    /**
     * @notice Quote the fee for sending tokens
     * @param _dstEid Destination endpoint ID
     * @param _recipient Address of the recipient on the destination chain
     * @param _token Address of the token to send
     * @param _amount Amount of tokens to send
     * @param _options LayerZero message options
     * @param _payInLzToken Whether to pay in LZ token
     * @return fee The messaging fee
     */
    function quoteSendToVault(
        uint32 _dstEid,
        address _recipient,
        address _token,
        uint256 _amount,
        bytes calldata _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee) {
        address oft = tokenToOft[_token];
        if (oft == address(0)) revert TokenNotSupported();

        SendParam memory sendParam = SendParam({
            dstEid: _dstEid,
            to: OFTComposeMsgCodec.addressToBytes32(_recipient),
            amountLD: _amount,
            minAmountLD: (_amount * 9900) / 10000, // 1% slippage tolerance
            extraOptions: _options,
            composeMsg: "",
            oftCmd: ""
        });
        
        return IOFT(oft).quoteSend(sendParam, _payInLzToken);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Update the vault address
     * @param _newVault The new vault address
     */
    function setVault(address _newVault) external onlyOwner {
        if (_newVault == address(0)) revert InvalidVault();
        address oldVault = vault;
        vault = _newVault;
        emit VaultUpdated(oldVault, _newVault);
    }

    /**
     * @notice Set the allowed remote vault for a specific destination chain
     * @param _dstEid The destination endpoint ID
     * @param _remoteVault The address of the vault on the destination chain
     */
    function setRemoteVault(uint32 _dstEid, address _remoteVault) external onlyOwner {
        if (_remoteVault == address(0)) revert InvalidVault();
        dstEidToVault[_dstEid] = _remoteVault;
        emit RemoteVaultSet(_dstEid, _remoteVault);
    }

    /**
     * @notice Set the configuration for a supported token
     * @param _token The token address
     * @param _oft The OFT contract address for this token
     */
    function setTokenConfig(address _token, address _oft) external onlyOwner {
        if (_token == address(0) || _oft == address(0)) revert InvalidAddress();
        tokenToOft[_token] = _oft;
        emit TokenConfigSet(_token, _oft);
    }

    /**
     * @notice Recover tokens or ETH accidentally sent to the contract
     * @param _token The token address to recover (address(0) for ETH)
     * @param _to The recipient address
     * @param _amount The amount to recover
     */
    function emergencyRecover(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert InvalidRecipient();

        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }

        emit EmergencyRecovery(_token, _to, _amount);
    }

    /**
     * @notice Allow receiving ETH
     */
    receive() external payable {}
}
