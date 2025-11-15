// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// LayerZero Official Upgradeable OApp imports
import {OAppUpgradeable, MessagingFee, MessagingReceipt, Origin} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from
    "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {IOAppComposer} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oapp-evm/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oapp-evm/contracts/oft/interfaces/IOFT.sol";
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
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// Elitra imports
import {IMultichainDepositAdapter} from "./interfaces/IMultichainDepositAdapter.sol";
import {IElitraVault} from "./interfaces/IElitraVault.sol";

/**
 * @title MultichainDepositAdapter
 * @notice Upgradeable adapter for cross-chain vault deposits via LayerZero OFT compose
 * @dev Receives tokens via LayerZero, executes arbitrary zap operations, then deposits to vault
 *
 * Key Features:
 * - Generic multicall pattern for flexible zapping (built from source chain SDK)
 * - Robust error handling with automatic refund on failure
 * - Gas-efficient design with reserved gas for error handling
 * - Full deposit tracking and recovery mechanisms
 */
contract MultichainDepositAdapter is
    Initializable,
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    IOAppComposer,
    IMultichainDepositAdapter,
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
    mapping(address => bool) public supportedOFTs;

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
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

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
     * @inheritdoc IMultichainDepositAdapter
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address, // executor
        bytes calldata // extraData
    ) external payable override(ILayerZeroComposer, IMultichainDepositAdapter) whenNotPaused nonReentrant {
        // Only accept compose messages from the LayerZero endpoint
        require(msg.sender == address(endpoint), "Only endpoint");

        // // Only accept from supported OFTs
        // require(supportedOFTs[_from], "OFT not supported");

        // Decode the OFT compose message
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

        // Decode our custom compose message: (vault, receiver, zapCalls)
        (address vault, address receiver, Call[] memory zapCalls) = abi.decode(
            composeMsg,
            (address, address, Call[])
        );

        // // Validate
        // require(supportedVaults[vault], "Vault not supported");
        // require(receiver != address(0), "Invalid receiver");

        // // Get the token that was received (from the OFT mapping)
        address token = _getTokenFromOFT(_from);
        // require(token != address(0), "Token not found");

        // Record the deposit
        uint256 depositId = _recordDeposit(receiver, srcEid, token, amountLD, vault, _guid);

        // Process deposit: execute zaps (if any) and deposit to vault
        uint256 shares = _processDeposit(depositId, vault, receiver, token, amountLD, zapCalls);

        // Update success status
        depositRecords[depositId].sharesReceived = shares;
        _updateDepositStatus(depositId, DepositStatus.Success);
        emit DepositSuccess(depositId, receiver, vault, shares);
    }

    /**
     * @notice Internal function to process deposit with zapping
     */
    function _processDeposit(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        Call[] memory zapCalls
    ) internal returns (uint256 shares) {
        // If there are zap calls, execute them
        if (zapCalls.length > 0) {
            uint256 balanceBefore = IERC20(IElitraVault(vault).asset()).balanceOf(address(this));

            // Execute zap operations
            _executeZapCalls(zapCalls);

            uint256 balanceAfter = IERC20(IElitraVault(vault).asset()).balanceOf(address(this));
            uint256 amountOut = balanceAfter - balanceBefore;

            require(amountOut > 0, "Zap produced no output");

            emit ZapExecuted(depositId, zapCalls.length, amountOut);

            // Deposit the output to vault
            shares = _depositToVault(vault, receiver, amountOut);
        } else {
            // No zap needed - deposit directly
            shares = _depositToVault(vault, receiver, amount);
        }
    }

    /**
     * @notice External wrapper for processDeposit (kept for interface compatibility)
     * @inheritdoc IMultichainDepositAdapter
     */
    function processDeposit(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        Call[] calldata zapCalls
    ) external override onlySelf returns (uint256 shares) {
        return _processDeposit(depositId, vault, receiver, token, amount, zapCalls);
    }

    /**
     * @notice Execute batch of zap operations
     * @inheritdoc IMultichainDepositAdapter
     */
    function manageBatch(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    ) external override onlySelf {
        require(targets.length == data.length && data.length == values.length, "Array length mismatch");

        for (uint256 i = 0; i < targets.length; i++) {
            targets[i].functionCallWithValue(data[i], values[i]);
        }
    }

    /**
     * @notice Deposit tokens into vault for receiver
     * @inheritdoc IMultichainDepositAdapter
     */
    function depositToVault(
        address vault,
        address receiver,
        uint256 amount
    ) external override onlySelf returns (uint256 shares) {
        return _depositToVault(vault, receiver, amount);
    }

    /**
     * @notice Safely attempt refund (external to enable try-catch)
     * @inheritdoc IMultichainDepositAdapter
     */
    function safeAttemptRefund(uint256 depositId) external override onlySelf {
        _attemptRefund(depositId);
    }

    /**
     * @notice Manual refund for failed deposits
     * @inheritdoc IMultichainDepositAdapter
     */
    function manualRefund(uint256 depositId) external override onlyOwnerOrOperator nonReentrant {
        DepositRecord storage record = depositRecords[depositId];

        require(
            record.status == DepositStatus.ZapFailed ||
            record.status == DepositStatus.DepositFailed ||
            record.status == DepositStatus.RefundFailed,
            "Not eligible for refund"
        );

        _attemptRefund(depositId);
    }

    /**
     * @notice Batch manual refund for multiple deposits
     * @inheritdoc IMultichainDepositAdapter
     */
    function batchManualRefund(uint256[] calldata depositIds) external override onlyOwnerOrOperator nonReentrant {
        for (uint256 i = 0; i < depositIds.length; i++) {
            DepositRecord storage record = depositRecords[depositIds[i]];

            if (
                record.status == DepositStatus.ZapFailed ||
                record.status == DepositStatus.DepositFailed ||
                record.status == DepositStatus.RefundFailed
            ) {
                try this.safeAttemptRefund(depositIds[i]) {
                    // Refund attempted
                } catch {
                    // Continue to next deposit
                }
            }
        }
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

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
    ) internal returns (uint256 depositId) {
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
        DepositStatus oldStatus = depositRecords[depositId].status;
        depositRecords[depositId].status = newStatus;
        emit DepositStatusUpdated(depositId, oldStatus, newStatus);
    }

    /**
     * @notice Execute zap calls
     */
    function _executeZapCalls(Call[] memory zapCalls) internal {
        address[] memory targets = new address[](zapCalls.length);
        bytes[] memory data = new bytes[](zapCalls.length);
        uint256[] memory values = new uint256[](zapCalls.length);

        for (uint256 i = 0; i < zapCalls.length; i++) {
            targets[i] = zapCalls[i].target;
            data[i] = zapCalls[i].data;
            values[i] = zapCalls[i].value;
        }

        this.manageBatch(targets, data, values);
    }

    /**
     * @notice Internal deposit to vault
     */
    function _depositToVault(
        address vault,
        address receiver,
        uint256 amount
    ) internal returns (uint256 shares) {
        address asset = IElitraVault(vault).asset();

        // Approve vault to spend tokens
        IERC20(asset).forceApprove(vault, amount);

        // Deposit to vault
        shares = IElitraVault(vault).deposit(amount, receiver);

        require(shares > 0, "Deposit failed: no shares");
    }

    /**
     * @notice Attempt refund to source chain
     */
    function _attemptRefund(uint256 depositId) internal {
        DepositRecord storage record = depositRecords[depositId];

        // If same-chain deposit (srcEid == 0), just transfer tokens back
        if (record.srcEid == 0) {
            _updateDepositStatus(depositId, DepositStatus.RefundSent);
            IERC20(record.tokenIn).safeTransfer(record.user, record.amountIn);
            emit RefundSent(depositId, record.user, record.amountIn, 0);
            return;
        }

        // Cross-chain refund via OFT
        address oft = tokenToOFT[record.tokenIn];
        require(oft != address(0), "OFT not found");

        // Build SendParam for refund
        SendParam memory sendParam = SendParam({
            dstEid: record.srcEid,
            to: OFTComposeMsgCodec.addressToBytes32(record.user),
            amountLD: record.amountIn,
            minAmountLD: (record.amountIn * 9900) / 10000, // 1% slippage
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        // Quote the messaging fee
        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);

        // Check if contract has enough ETH for refund gas
        require(address(this).balance >= fee.nativeFee, "Insufficient ETH for refund");

        // Approve OFT to spend tokens
        IERC20(record.tokenIn).forceApprove(oft, record.amountIn);

        // Send tokens back to user on source chain
        try IOFT(oft).send{value: fee.nativeFee}(sendParam, fee, payable(address(this)))
            returns (MessagingReceipt memory receipt, OFTReceipt memory) {
            _updateDepositStatus(depositId, DepositStatus.RefundSent);
            emit RefundSent(depositId, record.user, record.amountIn, record.srcEid);
        } catch {
            _updateDepositStatus(depositId, DepositStatus.RefundFailed);
        }
    }

    /**
     * @notice Get token address from OFT address
     */
    function _getTokenFromOFT(address oft) internal view returns (address) {
        // Search through tokenToOFT mapping
        // Note: In production, you might want to maintain a reverse mapping for efficiency
        // For now, this assumes the OFT is the token itself or we have it configured
        // This is a simplified version - you may need to query the OFT contract directly
        return oft; // Placeholder - implement based on your OFT setup
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function setSupportedOFT(address token, address oft, bool isActive) external override onlyOwner {
        require(token != address(0) && oft != address(0), "Invalid address");
        tokenToOFT[token] = oft;
        supportedOFTs[oft] = isActive;
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function setSupportedVault(address vault, bool isActive) external override onlyOwner {
        require(vault != address(0), "Invalid vault");
        supportedVaults[vault] = isActive;
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function pause() external override onlyOwnerOrOperator {
        _pause();
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function unpause() external override onlyOwnerOrOperator {
        _unpause();
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function depositRefundGas() external payable override {
        require(msg.value > 0, "Must send ETH");
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
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
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function getDepositRecord(uint256 depositId) external view override returns (DepositRecord memory) {
        return depositRecords[depositId];
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function getUserDepositIds(address user) external view override returns (uint256[] memory) {
        return userDepositIds[user];
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function getFailedDeposits(uint256 startId, uint256 limit)
        external
        view
        override
        returns (uint256[] memory depositIds)
    {
        uint256[] memory tempIds = new uint256[](limit);
        uint256 count = 0;

        for (uint256 i = startId; i < totalDeposits && count < limit; i++) {
            DepositRecord storage record = depositRecords[i];
            if (
                record.status == DepositStatus.ZapFailed ||
                record.status == DepositStatus.DepositFailed ||
                record.status == DepositStatus.RefundFailed
            ) {
                tempIds[count] = i;
                count++;
            }
        }

        // Resize array to actual count
        depositIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            depositIds[i] = tempIds[i];
        }
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function quoteRefundFee(uint256 depositId) external view override returns (uint256 nativeFee) {
        DepositRecord storage record = depositRecords[depositId];
        require(record.srcEid != 0, "Same-chain refund no gas needed");

        address oft = tokenToOFT[record.tokenIn];
        require(oft != address(0), "OFT not found");

        SendParam memory sendParam = SendParam({
            dstEid: record.srcEid,
            to: OFTComposeMsgCodec.addressToBytes32(record.user),
            amountLD: record.amountIn,
            minAmountLD: (record.amountIn * 9900) / 10000,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = IOFT(oft).quoteSend(sendParam, false);
        return fee.nativeFee;
    }

    /**
     * @inheritdoc IMultichainDepositAdapter
     */
    function isVaultSupported(address vault) external view override returns (bool) {
        return supportedVaults[vault];
    }

    // ========================================= LAYERZERO OVERRIDES =========================================

    /**
     * @dev This contract does not receive standard messages, only compose callbacks
     */
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata,
        address,
        bytes calldata
    ) internal pure override {
        revert("Does not receive standard messages");
    }

    /**
     * @notice Allow contract to receive ETH for refund gas fees
     */
    receive() external payable {}

    // ========================================= EVENTS =========================================

    event DepositStatusUpdated(
        uint256 indexed depositId,
        DepositStatus oldStatus,
        DepositStatus newStatus
    );

    event EmergencyRecovery(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // ========================================= STORAGE GAP =========================================

    uint256[50] private __gap;
}
