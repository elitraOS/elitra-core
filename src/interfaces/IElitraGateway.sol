// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IElitraGateway {
    // ========= Events =========
    event ElitraGatewayDeposit(
        uint32 indexed partnerId,
        address indexed elitraVault,
        address indexed sender,
        address receiver,
        uint256 assets,
        uint256 shares
    );

    event ElitraGatewayRedeem(
        uint32 indexed partnerId,
        address indexed elitraVault,
        address indexed receiver,
        uint256 shares,
        uint256 assetsOrRequestId,
        bool instant
    );
}
