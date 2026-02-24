// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IRedemptionHook, RedemptionMode } from "../interfaces/IRedemptionHook.sol";
import { IElitraVault } from "../interfaces/IElitraVault.sol";

/// @title HybridRedemptionHook
/// @notice Redemption hook: instant if liquidity available, else queue
contract HybridRedemptionHook is IRedemptionHook {
    event RedemptionProcessed(
        address indexed vault,
        address indexed owner,
        RedemptionMode mode,
        uint256 assets
    );

    /// @inheritdoc IRedemptionHook
    function beforeRedeem(
        IElitraVault vault,
        uint256, /* shares */
        uint256 assets,
        address owner
    ) external returns (RedemptionMode mode, uint256 actualAssets) {
        uint256 availableBalance = vault.getAvailableBalance();

        if (availableBalance >= assets) {
            emit RedemptionProcessed(address(vault), owner, RedemptionMode.INSTANT, assets);
            return (RedemptionMode.INSTANT, assets);
        } else {
            emit RedemptionProcessed(address(vault), owner, RedemptionMode.QUEUED, assets);
            return (RedemptionMode.QUEUED, assets);
        }
    }

    /// @inheritdoc IRedemptionHook
    function afterRedeem(
        address, /* owner */
        uint256, /* shares */
        uint256, /* assets */
        bool /* instant */
    ) external {
        // Empty for now - reserved for future extensibility
        // Could be used for: analytics, notifications, rewards distribution, etc.
    }
}
