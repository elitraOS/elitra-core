// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Errors {
    /// @notice Thrown when insufficient shares balance is available to complete the operation.
    error InsufficientShares();

    /// @notice Thrown when the operation is called by a user that is not the owner of the shares.
    error NotSharesOwner();

    /// @notice Thrown when the input shares amount is zero.
    error SharesAmountZero();

    /// @notice Thrown when a claim request is fulfilled with an invalid shares amount.
    error InvalidSharesAmount();

    /// @notice Thrown when a withdraw is attempted with an amount different than the claimable assets.
    error InvalidAssetsAmount();

    /// @notice Thrown when the new max percentage is greater than the current max percentage.
    error InvalidMaxPercentage();

    /// @notice Thrown when the underlying balance has already been updated in the current block.
    error UpdateAlreadyCompletedInThisBlock();

    /// @notice Thrown when redeem() or withdraw() is called
    error UseRequestRedeem();

    /// @notice Thrown when attempting to set zero address for adapter
    error ZeroAddress();

    /// @notice Thrown when redemption strategy returns invalid mode
    error InvalidRedemptionMode();

    /// @notice Thrown when a user is not authorized to perform an operation
    error Unauthorized();

    /// @notice Thrown when the transaction validation fails for a target
    error TransactionValidationFailed(address target);

    /// @notice Thrown when NAV/PPS data is stale (not updated within threshold)
    error StaleNav();
}
