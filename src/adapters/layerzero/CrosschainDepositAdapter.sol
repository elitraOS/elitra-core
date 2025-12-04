// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// LayerZero Official Upgradeable OApp imports
import {
    OAppUpgradeable,
    MessagingFee,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {
    OAppOptionsType3Upgradeable
} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { IOAppComposer } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oapp-evm/contracts/oft/interfaces/IOFT.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

// OpenZeppelin Upgradeable imports
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

// OpenZeppelin standard imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

// Elitra imports
import { ICrosschainDepositAdapter } from "../../interfaces/ICrosschainDepositAdapter.sol";
import { ICrosschainDepositQueue } from "../../interfaces/ICrosschainDepositQueue.sol";
import { IElitraVault, Call } from "../../interfaces/IElitraVault.sol";

/**
 * @title CrosschainDepositAdapter
 * @notice Upgradeable adapter for cross-chain vault deposits via LayerZero OFT compose
 * @dev Receives tokens via LayerZero, executes arbitrary zap operations, then deposits to vault.
 *      Failed deposits are forwarded to a CrosschainDepositQueue for manual handling.
 */
contract CrosschainDepositAdapter is
    Initializable,
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    IOAppComposer,
    ICrosschainDepositAdapter,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;

    // ========================================= CONSTANTS =========================================

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ========================================= STATE VARIABLES =========================================

    uint256 public totalDeposits;

    // Mappings
    mapping(uint256 => DepositRecord) public depositRecords;
    mapping(address => uint256[]) public userDepositIds;
    mapping(address => bool) public supportedVaults;
    mapping(address => address) public tokenToOFT; // token => OFT contract
    mapping(address => address) public oftToToken; // OFT => token contract
    mapping(address => bool) public supportedOFTs;

    address public depositQueue;

    // ========================================= INITIALIZER =========================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint) OAppUpgradeable(_endpoint) {
        _disableInitializers();
    }

    /**
     * @notice Initialize the adapter
     * @param _owner Contract owner
     */
    function initialize(address _owner) public initializer {
        require(_owner != address(0), "Invalid owner");

        __OApp_init(_owner);
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _transferOwnership(_owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);
    }

    // ========================================= MODIFIERS =========================================

    modifier onlyOwnerOrOperator() {
        require(owner() == msg.sender || hasRole(OPERATOR_ROLE, msg.sender), "Not owner or operator");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Only self");
        _;
    }

    // ========================================= CORE FUNCTIONS =========================================

    /**
     * @notice LayerZero compose callback - receives tokens and processes deposit
     * @inheritdoc ILayerZeroComposer
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
        override(ILayerZeroComposer)
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

        // Decode our custom compose message: (vault, receiver, minAmountOut, zapCalls)
        (address vault, address receiver, uint256 minAmountOut, Call[] memory zapCalls) = abi.decode(composeMsg, (address, address, uint256, Call[]));

        // Validate
        require(supportedVaults[vault], "Vault not supported");
        require(receiver != address(0), "Invalid receiver");

        // Get the token that was received (from the OFT mapping)
        address token = _getTokenFromOFT(_from);

        // Record the deposit
        uint256 depositId = _recordDeposit(receiver, srcEid, token, amountLD, vault, _guid);

        // Process deposit: execute zaps (if any) and deposit to vault
        try this.processDeposit(depositId, vault, receiver, token, amountLD, minAmountOut, zapCalls) returns (uint256 shares) {
            // Update success status
            depositRecords[depositId].sharesReceived = shares;
            _updateDepositStatus(depositId, DepositStatus.Success);
            emit DepositSuccess(depositId, receiver, vault, shares);
        } catch (bytes memory reason) {
            // Handle failure: Record reason and send to queue
            depositRecords[depositId].failureReason = reason;
            _handleDepositFailure(depositId, token, amountLD, reason);
        }
    }

    /**
     * @notice External function to process deposit with zapping (public for try/catch)
     * @dev Only callable by this contract
     */
    function processDeposit(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        uint256 minAmountOut,
        Call[] memory zapCalls
    )
        external
        onlySelf
        returns (uint256 shares)
    {   
        // If there are zap calls, execute them
        if (zapCalls.length > 0) {
            uint256 balanceBefore = IERC20(IElitraVault(vault).asset()).balanceOf(address(this));

            // Execute zap operations
            this.manageBatch(zapCalls);

            uint256 balanceAfter = IERC20(IElitraVault(vault).asset()).balanceOf(address(this));
            uint256 amountOut = balanceAfter - balanceBefore;

            require(amountOut >= minAmountOut, "Slippage exceeded");
            require(amountOut > 0, "Zap produced no output");

            emit ZapExecuted(depositId, zapCalls.length, amountOut);

            // Deposit the output to vault
            shares = _depositToVault(vault, receiver, amountOut);
        } else {
            // No zap needed - deposit directly
            if (token == IElitraVault(vault).asset()) {
                shares = _depositToVault(vault, receiver, amount);
            } else {
                // emit TokenMismatch(depositId, token, IElitraVault(vault).asset());
                revert("Token mismatch");
            }
        }
    }

    /**
     * @notice Execute batch of zap operations
     * @inheritdoc ICrosschainDepositAdapter
     */
    function manageBatch(Call[] calldata calls) external override onlySelf {
        for (uint256 i = 0; i < calls.length; i++) {
            calls[i].target.functionCallWithValue(calls[i].data, calls[i].value);
        }
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function depositToVault(
        address vault,
        address receiver,
        uint256 amount
    ) external override onlySelf returns (uint256 shares) {
        return _depositToVault(vault, receiver, amount);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    function _handleDepositFailure(uint256 depositId, address token, uint256 amount, bytes memory reason) internal {
        if (depositQueue == address(0)) {
            // If no queue is set, just mark as failed and leave tokens in adapter (emergency recover needed)

            // transfer bridge token to the user for safety 
            IERC20(token).safeTransfer(depositRecords[depositId].user, amount);

            _updateDepositStatus(depositId, DepositStatus.DepositFailed);
            emit DepositFailed(depositId, depositRecords[depositId].user, reason);
            return;
        }

        // Approve tokens to queue
        IERC20(token).forceApprove(depositQueue, amount);

        // Send to queue
        try ICrosschainDepositQueue(depositQueue).recordFailedDeposit(
            depositRecords[depositId].user,
            depositRecords[depositId].srcEid,
            token,
            amount,
            depositRecords[depositId].vault,
            depositRecords[depositId].guid,
            reason
        ) {
            _updateDepositStatus(depositId, DepositStatus.Queued);
            emit DepositQueued(depositId, depositRecords[depositId].user, reason);
        } catch {
             // If queue push fails, just mark as failed locally
            _updateDepositStatus(depositId, DepositStatus.DepositFailed);

            // transfer bridge token to the user for safety 
            IERC20(token).safeTransfer(depositRecords[depositId].user, amount);

            emit DepositFailed(depositId, depositRecords[depositId].user, reason);
        }
    }

    /**
     * @notice Record a deposit attempt
     */
    function _recordDeposit(
        address user,
        uint32 srcEid,
        address token,
        uint256 amount,
        address vault,
        bytes32 guid
    )
        internal
        returns (uint256 depositId)
    {
        depositId = totalDeposits;

        depositRecords[depositId] = DepositRecord({
            user: user,
            srcEid: srcEid,
            tokenIn: token,
            amountIn: amount,
            vault: vault,
            sharesReceived: 0,
            timestamp: block.timestamp,
            status: DepositStatus.Pending,
            guid: guid,
            failureReason: ""
        });

        userDepositIds[user].push(depositId);
        totalDeposits++;

        emit DepositRecorded(depositId, user, vault, amount, srcEid);
    }

    /**
     * @notice Update deposit status
     */
    function _updateDepositStatus(uint256 depositId, DepositStatus newStatus) internal {
        depositRecords[depositId].status = newStatus;
    }

    /**
     * @notice Internal deposit to vault
     */
    function _depositToVault(address vault, address receiver, uint256 amount) internal returns (uint256 shares) {
        address asset = IElitraVault(vault).asset();

        // Approve vault to spend tokens
        IERC20(asset).forceApprove(vault, amount);

        // Deposit to vault
        shares = IElitraVault(vault).deposit(amount, receiver);

        require(shares > 0, "Deposit failed: no shares");
    }

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

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function setDepositQueue(address _queue) external onlyOwner {
        require(_queue != address(0), "Invalid queue");
        depositQueue = _queue;
    }

    /**
     * @notice Set supported OFT token mapping
     */
    function setSupportedOFT(address token, address oft, bool isActive) external onlyOwner {
        require(token != address(0) && oft != address(0), "Invalid address");
        tokenToOFT[token] = oft;
        oftToToken[oft] = token;
        supportedOFTs[oft] = isActive;
    }

    /**
     * @notice Set supported vault
     */
    function setSupportedVault(address vault, bool isActive) external onlyOwner {
        require(vault != address(0), "Invalid vault");
        supportedVaults[vault] = isActive;
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function pause() external override onlyOwnerOrOperator {
        _pause();
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function unpause() external override onlyOwnerOrOperator {
        _unpause();
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function emergencyRecover(address token, address to, uint256 amount) external override onlyOwner {
        require(to != address(0), "Invalid recipient");

        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyRecovery(token, to, amount);
    }

    /**
     * @notice Set operator role
     */
    function setOperator(address operator) external onlyOwner {
        grantRole(OPERATOR_ROLE, operator);
    }

    /**
     * @notice Remove operator role
     */
    function removeOperator(address operator) external onlyOwner {
        revokeRole(OPERATOR_ROLE, operator);
    }

    /**
     * @notice Authorize upgrade (required by UUPS)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function getDepositRecord(uint256 depositId) external view override returns (DepositRecord memory) {
        return depositRecords[depositId];
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function getUserDepositIds(address user) external view override returns (uint256[] memory) {
        return userDepositIds[user];
    }

    /**
     * @inheritdoc ICrosschainDepositAdapter
     */
    function isVaultSupported(address vault) external view override returns (bool) {
        return supportedVaults[vault];
    }

    // ========================================= LAYERZERO OVERRIDES =========================================

    /**
     * @dev This contract does not receive standard messages, only compose callbacks
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) internal pure override {
        revert("Does not receive standard messages");
    }

    /**
     * @notice Allow contract to receive ETH for refund gas fees
     */
    receive() external payable { }

    // ========================================= EVENTS =========================================

    event EmergencyRecovery(address indexed token, address indexed to, uint256 amount);

    // ========================================= STORAGE GAP =========================================

    uint256[50] private __gap;
}
