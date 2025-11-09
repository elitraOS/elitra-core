// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { IOracleAdapter } from "../interfaces/IOracleAdapter.sol";
import { IElitraVaultV2 } from "../interfaces/IElitraVaultV2.sol";
import { Auth, Authority } from "@solmate/auth/Auth.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ManualOracleAdapter
/// @notice Oracle adapter that validates manual balance updates
contract ManualOracleAdapter is IOracleAdapter, Auth {
    using Math for uint256;

    uint256 public maxPercentageChange;
    uint256 constant DENOMINATOR = 1e18;
    uint256 constant MAX_PERCENTAGE_THRESHOLD = 1e17; // 10%

    event VaultBalanceUpdated(address indexed vault, uint256 newBalance, uint256 newPPS);
    event VaultPaused(address indexed vault, uint256 percentageChange);
    event MaxPercentageUpdated(uint256 oldMax, uint256 newMax);

    constructor(address _owner) Auth(_owner, Authority(address(0))) {
        maxPercentageChange = 1e16; // 1% default
    }

    /// @inheritdoc IOracleAdapter
    function updateVaultBalance(IElitraVaultV2 vault, uint256 newBalance)
        external
        requiresAuth
        returns (bool)
    {
        // 1. Validate block number
        uint256 lastBlock = vault.lastBlockUpdated();
        require(block.number > lastBlock, Errors.UpdateAlreadyCompletedInThisBlock());

        // 2. Read current state from vault
        uint256 lastPPS = vault.lastPricePerShare();
        uint256 totalSupply = vault.totalSupply();
        uint256 idleAssets = IERC20(vault.asset()).balanceOf(address(vault));

        // 3. Calculate new price per share
        uint256 totalAssets = idleAssets + newBalance;
        uint256 newPPS = totalAssets.mulDiv(DENOMINATOR, totalSupply, Math.Rounding.Floor);

        // 4. Check price change threshold
        uint256 percentageChange = _calculatePercentageChange(lastPPS, newPPS);

        if (percentageChange > maxPercentageChange) {
            emit VaultPaused(address(vault), percentageChange);
            return false; // Return false to indicate update rejected, caller should handle pausing
        }

        // 5. Update vault state
        vault.setAggregatedBalance(newBalance, newPPS);
        emit VaultBalanceUpdated(address(vault), newBalance, newPPS);
        return true;
    }

    /// @inheritdoc IOracleAdapter
    function updateMaxPercentageChange(uint256 newThreshold) external requiresAuth {
        require(newThreshold < MAX_PERCENTAGE_THRESHOLD, Errors.InvalidMaxPercentage());
        emit MaxPercentageUpdated(maxPercentageChange, newThreshold);
        maxPercentageChange = newThreshold;
    }

    /// @dev Calculate percentage change between two prices
    function _calculatePercentageChange(uint256 oldPrice, uint256 newPrice) private pure returns (uint256) {
        if (oldPrice == 0) return 0;
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return diff.mulDiv(DENOMINATOR, oldPrice, Math.Rounding.Ceil);
    }
}
