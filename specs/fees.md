# Fees

This document describes the fee model used by `ElitraVault` and `FeeManager`.

## Overview

There are two fee families:

1) **Vault operation fees (asset-based)**
- Applied on deposit, instant withdraw, and queued redeem.
- Collected in assets and held as pending balances.
- Split between the vault fee recipient and the protocol fee receiver.

2) **Management / performance fees (share-based)**
- Accrued over time and on performance using a high-water mark (HWM).
- Minted as shares (dilution), not taken from vault assets.
- Split between fee receiver and protocol fee receiver.

The vault uses a **net AUM** model: `totalAssets()` excludes assets reserved for queued redemptions and pending asset fees.

## Protocol fee control

- The protocol fee **rate** (bps) is read from `FeeRegistry` via `IFeeRegistry.protocolFeeRateBps()`.
- The protocol fee **receiver** is set per-vault in `FeeManager` (`protocolFeeReceiver`).
- Vault owners control deposit/withdraw/queued fee rates and the fee recipient for their vault.

## Fee components

### 1) Deposit fee (asset-based)
- Applied in `_deposit`.
- Uses `feeOnDeposit` (1e18 precision; 1e18 = 100%).
- Fee portion is added to pending fees and excluded from `totalAssets()`.

### 2) Withdraw fee (asset-based)
- Applied only for **instant** redemptions via `_withdraw`.
- Uses `feeOnWithdraw` (1e18 precision).
- Fee portion is added to pending fees and excluded from `totalAssets()`.
- Management/performance fees are taken first, then the withdraw fee is applied to the resulting assets.

### 3) Queued redeem fee (asset-based)
- Applied in `requestRedeem` when the mode is `QUEUED`.
- Uses `feeOnQueuedRedeem` (1e18 precision).
- Fee portion is added to pending fees and excluded from `totalAssets()`.

### 4) Management fee (share-based)
- Time-based on net AUM.
- Computed in `_calculateManagementFee` using annual rate (bps) and time elapsed.
- Minted as shares when `takeFees` is called.

### 5) Performance fee (share-based)
- Based on a high-water mark (HWM).
- Uses a fee-aware PPS that is adjusted for management fees.
- Minted as shares when `takeFees` is called.

## Pending fees and protocol split

All **asset-based** fees accumulate as pending balances in `FeeManager` storage:

- `pendingFees` (manager/feeRecipient portion)
- `pendingProtocolFees` (protocol portion)

When pending fees are added, they are split by the protocol fee rate:

```
protocolCut = amount * protocolRateBps / 10_000
managerCut  = amount - protocolCut
```

Both pending balances are **excluded** from `totalAssets()` in the vault.

## Claiming pending fees

- `claimFees()` (vault owner) claims **manager** pending fees.
- `claimProtocolFees()` (vault owner) claims **protocol** pending fees.
- Fees are transferred in assets to their recipients.

## Fee rate precision

- Asset-based fee rates use `1e18` precision.
  - Example: `1e16` = 1%.
- Protocol and management/performance rates use basis points (`1e4 = 100%`).

## Relevant contracts

- `src/fees/FeeManager.sol`
- `src/fees/FeeRegistry.sol`
- `src/ElitraVault.sol`
