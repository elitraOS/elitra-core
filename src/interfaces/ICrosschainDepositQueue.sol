// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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
        bytes32 guid;
        bytes failureReason;
        uint256 timestamp;
        uint256 sharePrice; // PPS at the time of failure
        DepositStatus status;
    }

    // ========================================= EVENTS =========================================

    event FailedDepositRecorded(
        uint256 indexed depositId,
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 sharePrice,
        bytes reason
    );

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
     */
    function recordFailedDeposit(
        address user,
        uint32 srcEid,
        address token,
        uint256 amount,
        address vault,
        bytes32 guid,
        bytes calldata reason,
        uint256 sharePrice
    ) external;

    /**
     * @notice Resolve a failed deposit (withdraw to user or retry)
     * @dev Only callable by operator/admin
     */
    function resolveFailedDeposit(uint256 depositId, address recipient) external;

    // ========================================= ADMIN FUNCTIONS =========================================

    function setAdapter(address _adapter) external;

    // ========================================= VIEW FUNCTIONS =========================================

    function getFailedDeposit(uint256 depositId) external view returns (FailedDeposit memory);
    function getUserFailedDeposits(address user) external view returns (uint256[] memory);
}
