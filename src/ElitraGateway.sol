// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { Errors } from "./libraries/Errors.sol";
import { IElitraVault } from "./interfaces/IElitraVault.sol";
import { IElitraGateway } from "./interfaces/IElitraGateway.sol";
import { IElitraRegistry } from "./interfaces/IElitraRegistry.sol";

/// __     __    _____       _
/// @title ElitraGateway
/// @notice Single entrypoint for deposits and redemption requests across allow-listed Elitra ERC-4626 vaults.
///         - deposit(assets→shares) and redeem(shares→assets).
///         - Emits partnerId for attribution; does NOT manage partner registries or fees.
///         - Uses ElitraRegistry to manage allow-listed vaults.
///
/// Assumptions:
///  - redeem may be async (returns 0 when routed to the vault's requestRedeem). Gateway is oblivious; assets are
/// delivered by the vault.
///  - For third-party redemption (owner != sender), owner must approve the gateway to transfer shares.

contract ElitraGateway is ReentrancyGuardUpgradeable, IElitraGateway {
    using SafeERC20 for IERC20;

    IElitraRegistry public registry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _registry) public initializer {
        registry = IElitraRegistry(_registry);
    }

    function deposit(
        address elitraVault,
        uint256 assets,
        uint256 minSharesOut,
        address receiver,
        uint32 partnerId
    )
        external
        nonReentrant
        returns (uint256 sharesOut)
    {
        require(assets > 0, Errors.Gateway__ZeroAmount());
        require(receiver != address(0), Errors.Gateway__ZeroReceiver());
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());

        address asset = IERC4626(elitraVault).asset();
        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(asset).forceApprove(elitraVault, assets);

        sharesOut = IERC4626(elitraVault).deposit(assets, receiver);

        if (sharesOut < minSharesOut) {
            revert Errors.Gateway__InsufficientSharesOut(sharesOut, minSharesOut);
        }

        emit ElitraGatewayDeposit(partnerId, elitraVault, msg.sender, receiver, assets, sharesOut);
    }

    function redeem(
        address elitraVault,
        uint256 shares,
        uint256 minAssetsOut,
        address receiver,
        uint32 partnerId
    )
        external
        nonReentrant
        returns (uint256 assetsOrRequestId)
    {
        require(shares > 0, Errors.Gateway__ZeroAmount());
        require(receiver != address(0), Errors.Gateway__ZeroReceiver());
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());

        IERC20(elitraVault).safeTransferFrom(msg.sender, address(this), shares);
        assetsOrRequestId = IElitraVault(elitraVault).requestRedeem(shares, receiver, address(this));

        bool instant = assetsOrRequestId > 0;

        // If the redemption is instant, we need to check if the assets out is greater than the minimum assets out
        if (instant && assetsOrRequestId < minAssetsOut) {
            revert Errors.Gateway__InsufficientAssetsOut(assetsOrRequestId, minAssetsOut);
        }

        emit ElitraGatewayRedeem(partnerId, elitraVault, receiver, shares, assetsOrRequestId, instant);
    }

    function quoteConvertToShares(address elitraVault, uint256 assets) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(elitraVault).convertToShares(assets);
    }

    function quoteConvertToAssets(address elitraVault, uint256 shares) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(elitraVault).convertToAssets(shares);
    }

    function quotePreviewDeposit(address elitraVault, uint256 assets) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(elitraVault).previewDeposit(assets);
    }

    function quotePreviewRedeem(address elitraVault, uint256 shares) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        return IERC4626(elitraVault).previewRedeem(shares);
    }

    /// @notice Returns the current allowance of `owner` for shares of the given elitraVault to this gateway.
    function getShareAllowance(address elitraVault, address owner) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        return IERC20(elitraVault).allowance(owner, address(this));
    }

    /// @notice Returns the current allowance of `owner` for the underlying asset of the given elitraVault to this gateway.
    function getAssetAllowance(address elitraVault, address owner) external view returns (uint256) {
        require(registry.isElitraVault(elitraVault), Errors.Gateway__VaultNotAllowed());
        address asset = IERC4626(elitraVault).asset();
        return IERC20(asset).allowance(owner, address(this));
    }
}
