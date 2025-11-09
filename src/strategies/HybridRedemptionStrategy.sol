// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IRedemptionStrategy, RedemptionMode } from "../interfaces/IRedemptionStrategy.sol";
import { IElitraVaultV2 } from "../interfaces/IElitraVaultV2.sol";

/// @title HybridRedemptionStrategy
/// @notice Redemption strategy: instant if liquidity available, else queue
contract HybridRedemptionStrategy is IRedemptionStrategy {
    event RedemptionProcessed(
        address indexed vault,
        address indexed receiver,
        RedemptionMode mode,
        uint256 assets
    );

    /// @inheritdoc IRedemptionStrategy
    function processRedemption(
        IElitraVaultV2 vault,
        uint256 shares,
        uint256 assets,
        address owner,
        address receiver
    ) external returns (RedemptionMode mode, uint256 actualAssets) {
        uint256 availableBalance = vault.getAvailableBalance();

        if (availableBalance >= assets) {
            emit RedemptionProcessed(address(vault), receiver, RedemptionMode.INSTANT, assets);
            return (RedemptionMode.INSTANT, assets);
        } else {
            emit RedemptionProcessed(address(vault), receiver, RedemptionMode.QUEUED, assets);
            return (RedemptionMode.QUEUED, assets);
        }
    }
}
