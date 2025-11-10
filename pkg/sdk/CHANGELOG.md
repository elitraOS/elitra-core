# Changelog

All notable changes to the Elitra SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-11-10

### Added
- Initial release of @elitra/sdk
- `ElitraClient` class for interacting with Elitra Vaults
- Full TypeScript support with comprehensive type definitions
- Read operations:
  - `getAsset()` - Get vault's underlying asset
  - `getTotalAssets()` - Get total assets under management
  - `getTotalSupply()` - Get total shares issued
  - `getPricePerShare()` - Get current price per share
  - `previewDeposit()` - Preview shares for deposit amount
  - `previewMint()` - Preview assets for share amount
  - `previewRedeem()` - Preview assets for redemption
  - `getAvailableBalance()` - Get available withdrawal balance
  - `getPendingRedeem()` - Get user's pending redemption
  - `getVaultState()` - Get complete vault state
  - `getUserPosition()` - Get user's complete position
- Write operations:
  - `deposit()` - Deposit assets into vault
  - `mint()` - Mint specific amount of shares
  - `requestRedeem()` - Request share redemption (instant or queued)
  - `manage()` - Execute arbitrary calls from vault
  - `updateBalance()` - Update vault's aggregated balance
  - `pause()` - Pause vault operations
  - `unpause()` - Resume vault operations
- Utility functions:
  - `encodeManageCall()` - Encode function calls for manage
  - `encodeApprove()` - Encode ERC20 approve
  - `encodeTransfer()` - Encode ERC20 transfer
  - `encodeERC4626Deposit()` - Encode ERC4626 deposit
  - `encodeERC4626Withdraw()` - Encode ERC4626 withdraw
  - `convertToShares()` - Convert assets to shares
  - `convertToAssets()` - Convert shares to assets
  - `calculateAPY()` - Calculate APY from price changes
  - `formatShares()` - Format shares for display
  - `parseAmount()` - Parse user input to bigint
- Comprehensive documentation:
  - README.md with full API documentation
  - QUICK_START.md for getting started quickly
  - Complete usage examples
- TypeScript types exported:
  - `ElitraConfig`
  - `VaultState`
  - `UserPosition`
  - `PendingRedeem`
  - `DepositResult`
  - `RedeemResult`
  - `ManageResult`
  - `DepositOptions`
  - `MintOptions`
  - `RedeemOptions`
  - `ManageOptions`

### Dependencies
- viem ^2.0.0 (peer dependency)
- TypeScript ^5.0.0 (dev dependency)
- tsup ^8.0.0 (dev dependency)

## [Unreleased]

### Planned
- Batch operations support
- Event listening utilities
- Multicall support for read operations
- Gas estimation helpers
- Transaction simulation before execution
- Subgraph integration for historical data
- React hooks package (@elitra/react)
- Additional chain support
