// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { IBalanceUpdateHook } from "../interfaces/IBalanceUpdateHook.sol";
import { Auth, Authority } from "@solmate/auth/Auth.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title ManualBalanceUpdateHook
/// @notice Hook that validates balance updates based on price change thresholds
/// @dev Pure calculation helper - does not modify vault state
contract ManualBalanceUpdateHook is IBalanceUpdateHook, Auth {
    using Math for uint256;

    uint256 public maxPercentageChange;
    uint256 constant DENOMINATOR = 1e18;
    uint256 constant MAX_PERCENTAGE_THRESHOLD = 1e17; // 10%

    event MaxPercentageUpdated(uint256 oldMax, uint256 newMax);

    constructor(address _owner) Auth(_owner, Authority(address(0))) {
        maxPercentageChange = 1e16; // 1% default
    }

    /// @inheritdoc IBalanceUpdateHook
    function beforeBalanceUpdate(
        uint256 currentPPS,
        uint256 totalSupply,
        uint256 idleAssets,
        uint256 newAggregatedBalance
    ) external view returns (bool shouldContinue, uint256 newPPS) {
        // Calculate total assets
        uint256 totalAssets = idleAssets + newAggregatedBalance;

        // Calculate new price per share
        if (totalSupply == 0) {
            newPPS = DENOMINATOR;
            shouldContinue = true;
        } else {
            newPPS = totalAssets.mulDiv(DENOMINATOR, totalSupply, Math.Rounding.Floor);

            // Check if price change exceeds threshold
            uint256 percentageChange = _calculatePercentageChange(currentPPS, newPPS);
            shouldContinue = percentageChange <= maxPercentageChange;
        }
    }

    /// @inheritdoc IBalanceUpdateHook
    function afterBalanceUpdate(
        uint256, /* oldBalance */
        uint256, /* newBalance */
        uint256 /* newPPS */
    ) external view {
        // Empty for now - reserved for future extensibility
        // Could be used for: logging, notifications, external integrations, etc.
    }


    /// @dev Calculate percentage change between two prices
    function _calculatePercentageChange(uint256 oldPrice, uint256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) return 0;
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return diff.mulDiv(DENOMINATOR, oldPrice, Math.Rounding.Ceil);
    }
}
