// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title IERC4626Router
/// @notice Interface for ERC4626 router with slippage protection
interface IERC4626Router {
    /// @notice Emitted when a deposit is made
    event Deposit(
        address indexed vault,
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when a mint is made
    event Mint(
        address indexed vault,
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /// @notice Thrown when slippage exceeds the allowed amount
    error SlippageExceeded(uint256 actual, uint256 expected);

    /// @notice Thrown when zero address is provided
    error ZeroAddress();

    /// @notice Thrown when zero amount is provided
    error ZeroAmount();

    /// @notice Deposit assets into vault with minimum shares expected
    /// @param vault The ERC4626 vault to deposit into
    /// @param assets The amount of assets to deposit
    /// @param receiver The address to receive the shares
    /// @param minSharesOut The minimum amount of shares expected
    /// @return shares The actual amount of shares received
    function depositWithSlippage(
        IERC4626 vault,
        uint256 assets,
        address receiver,
        uint256 minSharesOut
    ) external returns (uint256 shares);

    /// @notice Mint shares from vault with maximum assets willing to spend
    /// @param vault The ERC4626 vault to mint from
    /// @param shares The amount of shares to mint
    /// @param receiver The address to receive the shares
    /// @param maxAssetsIn The maximum amount of assets willing to spend
    /// @return assets The actual amount of assets spent
    function mintWithSlippage(
        IERC4626 vault,
        uint256 shares,
        address receiver,
        uint256 maxAssetsIn
    ) external returns (uint256 assets);
}
