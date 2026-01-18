// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Call } from "./IVaultBase.sol";

interface ICrosschainDepositQueue {
    // ========================================= STRUCTS =========================================

    enum DepositStatus {
        Failed,         // Initial state when recorded in queue
        Resolved        // Handled (retried or returned)
    }

    struct FailedDeposit {
        address user;
        uint32 srcEid;
        address token;
        uint256 amount;
        address vault;
        address adapter; // The bridge adapter that recorded this failure
        bytes32 guid;
        bytes failureReason;
        uint256 timestamp;
        uint256 sharePrice; // PPS at the time of failure
        uint256 minAmountOut; // Original attested minAmountOut
        bytes32 zapCallsHash; // Hash of original attested zapCalls for verification
        DepositStatus status;
    }

    // ========================================= EVENTS =========================================

    event FailedDepositRecorded(
        uint256 indexed depositId,
        address indexed user,
        address indexed token,
        address adapter,
        uint256 amount,
        uint256 sharePrice,
        bytes reason
    );

    event AdapterRegistered(address indexed adapter, bool registered);

    event DepositResolved(
        uint256 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 amount,
        bool retried
    );

    // ========================================= CORE FUNCTIONS =========================================

    /**
     * @notice Record a failed deposit and hold funds
     * @param user User address
     * @param srcEid Source endpoint ID
     * @param token Token address
     * @param amount Amount of tokens
     * @param vault Vault address
     * @param guid LayerZero GUID
     * @param reason Failure reason
     * @param sharePrice Price per share at time of failure
     * @param minAmountOut Original attested minAmountOut for zap
     * @param zapCalls Original attested zapCalls for zap
     */
    function recordFailedDeposit(
        address user,
        uint32 srcEid,
        address token,
        uint256 amount,
        address vault,
        bytes32 guid,
        bytes calldata reason,
        uint256 sharePrice,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external;

    /**
     * @notice Refund a failed deposit to the original user
     * @dev Only callable by operator/admin
     */
    function refundFailedDeposit(uint256 depositId) external;

    /**
     * @notice Fulfill a failed deposit in one step. If the failed token matches the vault asset, deposit directly.
     *         Otherwise, use ZapExecutor to swap then deposit using the originally attested zapCalls.
     * @param depositId The failed deposit id
     * @param minSharesOut Minimum shares the user must receive
     * @param zapCalls Original attested zapCalls (verified against stored hash)
     * @return sharesOut Shares minted to the user
     */
    function fulfillFailedDeposit(
        uint256 depositId,
        uint256 minSharesOut,
        Call[] calldata zapCalls
    ) external returns (uint256 sharesOut);

    /**
     * @notice Set the zap executor used for fulfillment
     */
    function setZapExecutor(address exec) external;

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Register or unregister a bridge adapter
     * @param _adapter Address of the adapter
     * @param _registered True to register, false to unregister
     */
    function setAdapterRegistration(address _adapter, bool _registered) external;

    // ========================================= VIEW FUNCTIONS =========================================

    function getFailedDeposit(uint256 depositId) external view returns (FailedDeposit memory);
    function getUserFailedDeposits(address user) external view returns (uint256[] memory);
    function isAdapterRegistered(address _adapter) external view returns (bool);
}
