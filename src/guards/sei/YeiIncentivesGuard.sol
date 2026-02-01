// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YeiIncentivesGuard
 * @author Elitra
 * @notice Guard for Yei Incentives Controller reward claiming operations
 * @dev Restricts claimAllRewardsToSelf to whitelisted assets only
 *
 * @dev Yei is a lending protocol on SEI with an incentives system. This guard ensures that:
 *      - Only whitelisted assets can be claimed
 *      - This prevents claiming arbitrary tokens or using the function for unintended purposes
 */
contract YeiIncentivesGuard is ITransactionGuard, Ownable {
    /// @notice Function selector for claimAllRewardsToSelf(address[]): 0xbf90f63a
    bytes4 public constant CLAIM_ALL_REWARDS_TO_SELF_SELECTOR = 0xbf90f63a;

    /// @notice Maps asset addresses to their whitelist status for reward claiming
    mapping(address asset => bool isAllowed) public whitelistedAssets;

    /// @notice Emitted when an asset's whitelist status changes
    event AssetWhitelistUpdated(address indexed asset, bool isAllowed);

    /**
     * @notice Initializes the guard with the owner
     * @param _owner Address that will own this guard and can manage the whitelist
     */
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    /**
     * @notice Sets the whitelist status for a single asset
     * @dev Only the owner can call this function
     * @param _asset The token address to whitelist or remove from whitelist
     * @param _isAllowed True to allow claiming rewards for this asset, false to disallow
     */
    function setAsset(address _asset, bool _isAllowed) external onlyOwner {
        whitelistedAssets[_asset] = _isAllowed;
        emit AssetWhitelistUpdated(_asset, _isAllowed);
    }

    /**
     * @notice Batch sets whitelist status for multiple assets
     * @dev More gas-efficient than calling setAsset multiple times
     * @param _assets Array of token addresses to update
     * @param _isAllowed Whether to allow or disallow all assets in the array
     */
    function setAssets(address[] calldata _assets, bool _isAllowed) external onlyOwner {
        for (uint256 i = 0; i < _assets.length; ++i) {
            whitelistedAssets[_assets[i]] = _isAllowed;
            emit AssetWhitelistUpdated(_assets[i], _isAllowed);
        }
    }

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Only allows claimAllRewardsToSelf() with all assets whitelisted
     * @return True if all assets are whitelisted, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        if (sig == CLAIM_ALL_REWARDS_TO_SELF_SELECTOR) {
            // claimAllRewardsToSelf(address[] assets)
            // calldata: [4 selector][dynamic array of assets]
            address[] memory assets = abi.decode(data[4:], (address[]));

            // All assets in the array must be whitelisted
            for (uint256 i = 0; i < assets.length; ++i) {
                if (!whitelistedAssets[assets[i]]) {
                    return false;
                }
            }
            // Must claim at least one asset
            return assets.length > 0;
        }

        return false;
    }
}
