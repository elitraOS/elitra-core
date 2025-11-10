// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IElitraVault } from "./IElitraVault.sol";

/// @notice Redemption mode returned by hook
enum RedemptionMode {
    INSTANT,   // Withdraw immediately from idle balance
    QUEUED     // Add to pending redemption queue
}

/// @title IRedemptionHook
/// @notice Hook interface for determining redemption mode and processing
interface IRedemptionHook {
    /// @notice Called before redemption to determine mode and validate
    /// @param vault The vault processing the redemption
    /// @param shares Amount of shares to redeem
    /// @param assets Equivalent assets for those shares
    /// @param owner Owner of the shares
    /// @param receiver Receiver of assets
    /// @return mode INSTANT or QUEUED
    /// @return actualAssets Assets to withdraw (may differ due to strategy rules)
    function beforeRedeem(
        IElitraVault vault,
        uint256 shares,
        uint256 assets,
        address owner,
        address receiver
    ) external returns (RedemptionMode mode, uint256 actualAssets);

    /// @notice Called after redemption completes (for future extensibility)
    /// @param receiver Receiver of assets
    /// @param shares Amount of shares redeemed
    /// @param assets Amount of assets withdrawn
    /// @param instant Whether it was instant or queued
    function afterRedeem(
        address receiver,
        uint256 shares,
        uint256 assets,
        bool instant
    ) external;
}
