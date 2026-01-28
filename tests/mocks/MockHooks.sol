// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBalanceUpdateHook } from "../../src/interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook, RedemptionMode } from "../../src/interfaces/IRedemptionHook.sol";
import { IElitraVault } from "../../src/interfaces/IElitraVault.sol";

/**
 * @title MockBalanceUpdateHook
 * @notice Mock implementation of IBalanceUpdateHook for testing.
 */
contract MockBalanceUpdateHook is IBalanceUpdateHook {
    uint256 public override maxPercentageChange;
    bool public shouldReject;
    uint256 public fixedPPS;

    constructor(uint256 _maxPercentageChange, bool _shouldReject) {
        maxPercentageChange = _maxPercentageChange;
        shouldReject = _shouldReject;
    }

    function setMaxPercentageChange(uint256 _maxPercentageChange) external {
        maxPercentageChange = _maxPercentageChange;
    }

    function setShouldReject(bool _shouldReject) external {
        shouldReject = _shouldReject;
    }

    function setFixedPPS(uint256 _fixedPPS) external {
        fixedPPS = _fixedPPS;
    }

    function beforeBalanceUpdate(
        uint256 /*currentPPS*/,
        uint256 totalSupply,
        uint256 idleAssets,
        uint256 newAggregatedBalance
    )
        external
        view
        override
        returns (bool shouldContinue, uint256 newPPS)
    {
        if (shouldReject) {
            return (false, 0);
        }

        uint256 totalAssets = idleAssets + newAggregatedBalance;
        newPPS = totalSupply > 0
            ? (totalAssets * 1e18) / totalSupply
            : 1e18;

        if (fixedPPS > 0) {
            newPPS = fixedPPS;
        }

        return (true, newPPS);
    }

    function afterBalanceUpdate(
        uint256 /*oldBalance*/,
        uint256 /*newBalance*/,
        uint256 /*newPPS*/
    ) external view override {}
}

/**
 * @title MockRedemptionHook
 * @notice Mock implementation of IRedemptionHook for testing.
 */
contract MockRedemptionHook is IRedemptionHook {
    RedemptionMode public mode;
    bool public shouldReject;
    uint256 public assetOverride; // If > 0, return this instead of actual assets

    constructor(RedemptionMode _mode, bool _shouldReject) {
        mode = _mode;
        shouldReject = _shouldReject;
    }

    function setMode(RedemptionMode _mode) external {
        mode = _mode;
    }

    function setShouldReject(bool _shouldReject) external {
        shouldReject = _shouldReject;
    }

    function setAssetOverride(uint256 _assetOverride) external {
        assetOverride = _assetOverride;
    }

    function beforeRedeem(
        IElitraVault /*vault*/,
        uint256 /*shares*/,
        uint256 assets,
        address /*owner*/,
        address /*receiver*/
    ) external view override returns (RedemptionMode, uint256) {
        if (shouldReject) {
            return (mode, 0);
        }
        return (mode, assetOverride > 0 ? assetOverride : assets);
    }

    function afterRedeem(
        address /*receiver*/,
        uint256 /*shares*/,
        uint256 /*assets*/,
        bool /*instant*/
    ) external override {}
}
