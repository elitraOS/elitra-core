// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YeiPoolGuard
 * @author Elitra
 * @notice Guard for Yei lending pool operations (supply/withdraw)
 * @dev Restricts supply to whitelisted assets and ensures receiver is the vault
 *
 * @dev Yei is a lending protocol on SEI. This guard ensures that:
 *      - Only whitelisted assets can be supplied/withdrawn
 *      - Supply operations must have onBehalfOf = vault (no supplying for others)
 *      - Withdraw operations must have to = vault (no withdrawing to others)
 */
contract YeiPoolGuard is ITransactionGuard, Ownable {
    /// @notice Function selector for supply(address,uint256,address,uint16): 0x617ba037
    bytes4 public constant SUPPLY_SELECTOR = 0x617ba037;

    /// @notice Function selector for withdraw(address,uint256,address): 0x69328dec
    bytes4 public constant WITHDRAW_SELECTOR = 0x69328dec;

    /// @notice The vault address that this guard protects
    address public immutable vault;

    /// @notice Maps asset addresses to whether they are allowed for supply/withdraw
    mapping(address asset => bool isAllowed) public whitelistedAssets;

    /// @notice Emitted when an asset's whitelist status changes
    event AssetWhitelistUpdated(address indexed asset, bool isAllowed);

    /**
     * @notice Initializes the guard with owner and vault address
     * @param _owner Address that will own this guard and can manage the whitelist
     * @param _vault The vault address that must be the receiver in all operations
     */
    constructor(address _owner, address _vault) {
        _transferOwnership(_owner);
        vault = _vault;
    }

    /**
     * @notice Sets the whitelist status for a single asset
     * @dev Only the owner can call this function
     * @param _asset The token address to whitelist or remove from whitelist
     * @param _isAllowed True to allow operations with this asset, false to disallow
     */
    function setAsset(address _asset, bool _isAllowed) external onlyOwner {
        whitelistedAssets[_asset] = _isAllowed;
        emit AssetWhitelistUpdated(_asset, _isAllowed);
    }

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Allows supply/withdraw only for whitelisted assets with vault as recipient
     * @return True if the operation is allowed, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
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
