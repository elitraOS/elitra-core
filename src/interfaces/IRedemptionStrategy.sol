// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IElitraVaultV2 } from "./IElitraVaultV2.sol";

/// @notice Redemption mode returned by strategy
enum RedemptionMode {
    INSTANT,   // Withdraw immediately from idle balance
    QUEUED     // Add to pending redemption queue
}

/// @title IRedemptionStrategy
/// @notice Interface for redemption strategies that determine instant vs queued withdrawals
interface IRedemptionStrategy {
    /// @notice Determine how to handle a redemption request
    /// @param vault The vault processing the redemption
    /// @param shares Amount of shares to redeem
    /// @param assets Equivalent assets for those shares
    /// @param owner Owner of the shares
    /// @param receiver Receiver of assets
    /// @return mode INSTANT or QUEUED
    /// @return actualAssets Assets to withdraw (may differ due to strategy rules)
    function processRedemption(
        IElitraVaultV2 vault,
        uint256 shares,
        uint256 assets,
        address owner,
        address receiver
    ) external returns (RedemptionMode mode, uint256 actualAssets);
}
