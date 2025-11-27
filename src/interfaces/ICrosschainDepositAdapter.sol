// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Call } from "./IElitraVault.sol";
/**
 * @title IMultichainDepositAdapter
 * @notice Bridge adapter, for handling crosschain fund movements
 *
 */
interface ICrosschainDepositAdapter {
    // ========================================= STRUCTS =========================================

    /**
     * @notice Single call operation for batch execution
     * @param target Contract to call
     * @param value Native value to send
     * @param data Calldata for the call
     */

    /**
     * @notice Deposit status tracking
     */
    enum DepositStatus {
        Pending,        // Recorded, being processed
        Success,        // Successfully deposited to vault
        ZapFailed,      // Zap execution failed
        DepositFailed,  // Vault deposit failed
        RefundSent,     // Refunded to source chain
        RefundFailed    // Refund failed, needs manual intervention
    }

    /**
     * @notice Record of a cross-chain deposit attempt
     * @param user Receiver of vault shares
     * @param srcEid Source chain endpoint ID
     * @param tokenIn Token received from bridge
     * @param amountIn Amount received
     * @param vault Target vault
     * @param sharesReceived Vault shares minted (0 if failed)
     * @param timestamp Deposit time
     * @param status Current status
     * @param guid LayerZero message GUID
     * @param failureReason Error data if failed
     */
    struct DepositRecord {
        address user;
        uint32 srcEid;
        address tokenIn;
        uint256 amountIn;
        address vault;
        uint256 sharesReceived;
        uint256 timestamp;
        DepositStatus status;
        bytes32 guid;
        bytes failureReason;
    }

    // ========================================= EVENTS =========================================

    event DepositRecorded(
        uint256 indexed depositId,
        address indexed user,
        address indexed vault,
        uint256 amountIn,
        uint32 srcEid
    );

    event DepositSuccess(
        uint256 indexed depositId,
        address indexed user,
        address indexed vault,
        uint256 sharesReceived
    );

    event DepositFailed(
        uint256 indexed depositId,
        address indexed user,
        bytes reason
    );

    event RefundSent(
        uint256 indexed depositId,
        address indexed user,
        uint256 amount,
        uint32 dstEid
    );

    event ZapExecuted(
        uint256 indexed depositId,
        uint256 numCalls,
        uint256 amountOut
    );

    // ========================================= CORE FUNCTIONS =========================================
    /**
     * @notice Execute batch operations (zapping)
     * @param calls Array of Call structs containing target, data, and value
     * @dev Only callable by this contract during deposit processing
     * @dev Similar to ElitraVault.manageBatch but without auth restrictions
     */
    function manageBatch(
        Call[] calldata calls
    ) external;

    /**
     * @notice Deposit tokens into vault for receiver
     * @param vault Vault address
     * @param receiver Address to receive vault shares
     * @param amount Amount to deposit
     * @return shares Vault shares received
     * @dev Only callable by this contract during deposit processing
     */
    function depositToVault(
        address vault,
        address receiver,
        uint256 amount
    ) external returns (uint256 shares);

    /**
     * @notice Process deposit with zapping (external for try-catch)
     * @param depositId Deposit record ID
     * @param vault Target vault
     * @param receiver Share receiver
     * @param token Token to deposit (after zap)
     * @param amount Amount received
     * @param zapCalls Zap operations to execute
     * @return shares Vault shares received
     * @dev Only callable by this contract
     */
    function processDeposit(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        Call[] calldata zapCalls
    ) external returns (uint256 shares);

    /**
     * @notice Attempt automatic refund (external for try-catch)
     * @param depositId Deposit record ID
     * @dev Only callable by this contract
     */
    function safeAttemptRefund(uint256 depositId) external;

    /**
     * @notice Manual refund for failed deposits (operator only)
     * @param depositId Deposit record ID
     */
    function manualRefund(uint256 depositId) external;

    /**
     * @notice Batch manual refund
     * @param depositIds Array of deposit IDs to refund
     */
    function batchManualRefund(uint256[] calldata depositIds) external;

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause the adapter
     */
    function pause() external;

    /**
     * @notice Unpause the adapter
     */
    function unpause() external;

    /**
     * @notice Deposit ETH for refund gas fees
     */
    function depositRefundGas() external payable;

    /**
     * @notice Emergency recover stuck tokens
     * @param token Token address (address(0) for native)
     * @param to Recipient
     * @param amount Amount to recover
     */
    function emergencyRecover(address token, address to, uint256 amount) external;

    /**
     * @notice Set supported OFT token mapping
     * @param token Token address
     * @param oft OFT contract address
     * @param isActive Whether to activate or deactivate
     */
    function setSupportedOFT(address token, address oft, bool isActive) external;

    /**
     * @notice Set supported vault
     * @param vault Vault address
     * @param isActive Whether to activate or deactivate
     */
    function setSupportedVault(address vault, bool isActive) external;

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Get deposit record
     * @param depositId Deposit ID
     * @return Deposit record details
     */
    function getDepositRecord(uint256 depositId) external view returns (DepositRecord memory);

    /**
     * @notice Get user's deposit IDs
     * @param user User address
     * @return Array of deposit IDs
     */
    function getUserDepositIds(address user) external view returns (uint256[] memory);

    /**
     * @notice Get failed deposits needing manual intervention
     * @param startId Start scanning from this ID
     * @param limit Max records to return
     * @return depositIds Array of failed deposit IDs
     */
    function getFailedDeposits(uint256 startId, uint256 limit)
        external
        view
        returns (uint256[] memory depositIds);

    /**
     * @notice Quote refund fee
     * @param depositId Deposit ID
     * @return nativeFee ETH needed for refund
     */
    function quoteRefundFee(uint256 depositId) external view returns (uint256 nativeFee);

    /**
     * @notice Check if vault is supported
     * @param vault Vault address
     * @return Whether vault is supported
     */
    function isVaultSupported(address vault) external view returns (bool);

    /**
     * @notice Total number of deposits
     * @return Total deposit count
     */
    function totalDeposits() external view returns (uint256);
}
