// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title YeiIncentivesGuard
/// @author Elitra
/// @notice Guard for Yei Incentives Controller reward claiming operations.
/// @dev Restricts claimAllRewardsToSelf to whitelisted assets only.
contract YeiIncentivesGuard is ITransactionGuard, Ownable {
    /// @notice claimAllRewardsToSelf(address[]) selector
    bytes4 public constant CLAIM_ALL_REWARDS_TO_SELF_SELECTOR = 0xbf90f63a;

    /// @notice Mapping of allowed asset addresses for reward claiming
    mapping(address asset => bool isAllowed) public whitelistedAssets;

    /// @notice Emitted when an asset whitelist status changes
    event AssetWhitelistUpdated(address indexed asset, bool isAllowed);

    /// @notice Initializes the guard with the owner
    /// @param _owner The address of the owner
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    /// @notice Sets the whitelist status of an asset
    /// @param _asset The asset address
    /// @param _isAllowed Whether the asset is allowed
    function setAsset(address _asset, bool _isAllowed) external onlyOwner {
        whitelistedAssets[_asset] = _isAllowed;
        emit AssetWhitelistUpdated(_asset, _isAllowed);
    }

    /// @notice Batch set whitelist status for multiple assets
    /// @param _assets The asset addresses
    /// @param _isAllowed Whether the assets are allowed
    function setAssets(address[] calldata _assets, bool _isAllowed) external onlyOwner {
        for (uint256 i = 0; i < _assets.length; ++i) {
            whitelistedAssets[_assets[i]] = _isAllowed;
            emit AssetWhitelistUpdated(_assets[i], _isAllowed);
        }
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
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
            return assets.length > 0;
        }

        return false;
    }
}
