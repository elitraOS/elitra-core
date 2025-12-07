// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title YeiPoolGuard
/// @author Elitra
/// @notice Guard for Yei lending pool operations (supply/withdraw).
/// @dev Restricts supply to whitelisted assets and ensures receiver is the vault.
contract YeiPoolGuard is ITransactionGuard, Ownable {
    /// @notice supply(address,uint256,address,uint16) selector
    bytes4 public constant SUPPLY_SELECTOR = 0x617ba037;

    /// @notice withdraw(address,uint256,address) selector
    bytes4 public constant WITHDRAW_SELECTOR = 0x69328dec;

    /// @notice The vault address that this guard protects
    address public immutable vault;

    /// @notice Mapping of allowed asset addresses for supply/withdraw
    mapping(address asset => bool isAllowed) public whitelistedAssets;

    /// @notice Emitted when an asset whitelist status changes
    event AssetWhitelistUpdated(address indexed asset, bool isAllowed);

    /// @notice Initializes the guard with the owner and vault
    /// @param _owner The address of the owner
    /// @param _vault The vault address that must be the receiver
    constructor(address _owner, address _vault) {
        _transferOwnership(_owner);
        vault = _vault;
    }

    /// @notice Sets the whitelist status of an asset
    /// @param _asset The asset address
    /// @param _isAllowed Whether the asset is allowed
    function setAsset(address _asset, bool _isAllowed) external onlyOwner {
        whitelistedAssets[_asset] = _isAllowed;
        emit AssetWhitelistUpdated(_asset, _isAllowed);
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        bytes4 sig = bytes4(data);

        if (sig == SUPPLY_SELECTOR) {
            // supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
            // calldata: [4 selector][32 asset][32 amount][32 onBehalfOf][32 referralCode]
            (address asset,, address onBehalfOf,) = abi.decode(data[4:], (address, uint256, address, uint16));

            // Asset must be whitelisted and onBehalfOf must be the vault
            return whitelistedAssets[asset] && onBehalfOf == vault;
        }

        if (sig == WITHDRAW_SELECTOR) {
            // withdraw(address asset, uint256 amount, address to)
            // calldata: [4 selector][32 asset][32 amount][32 to]
            (address asset,, address to) = abi.decode(data[4:], (address, uint256, address));

            // Asset must be whitelisted and recipient must be the vault
            return whitelistedAssets[asset] && to == vault;
        }


        return false;
    }
}
