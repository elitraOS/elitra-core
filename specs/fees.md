# Fees

This document explains the fee model used by `ElitraVault` and `FeeManager` in plain language.

## Overview

There are two fee families:

1) **Vault operation fees (asset-based)**  
These are charged when users interact with the vault.
- Deposit fee (on `deposit` / `mint`)
- Withdraw fee (instant redemption only)
- Queued redeem fee (queued redemption only)
- Collected in assets and stored as “pending fees”
- Split between the vault fee recipient and the protocol receiver

2) **Management / performance fees (share-based)**  
These accrue over time and performance and are paid by minting shares.
- Management fee: time-based on net AUM
- Performance fee: based on a high-water mark (HWM)
- Minted as shares (dilution), not taken from vault assets
- Split between fee receiver and protocol receiver

The vault uses a **net AUM** model: `totalAssets()` excludes assets reserved for queued redemptions and pending asset fees.

## Protocol fee control

- The protocol fee **rate** (bps) is read from `FeeRegistry`.
- The protocol fee **receiver** is read from `FeeRegistry`.
- Vault owners control deposit/withdraw/queued fee rates and the vault fee recipient.

## Fee components

### 1) Deposit fee (asset-based)
- Applied in `_deposit`.
- Uses `feeOnDeposit` (1e18 precision; 1e18 = 100%).
- The fee is set aside as pending and excluded from `totalAssets()`.
- Formula (amount includes fee):
```text
fee = assets * feeOnDeposit / (feeOnDeposit + 1e18)
netAssets = assets - fee
```

### 2) Withdraw fee (asset-based)
- Applied only for **instant** redemptions via `_withdraw`.
- Uses `feeOnWithdraw` (1e18 precision).
- The fee is set aside as pending and excluded from `totalAssets()`.
- Management/performance fees are taken first, then the withdraw fee is applied to the resulting assets.
- Formula (amount includes fee):
```text
fee = assets * feeOnWithdraw / (feeOnWithdraw + 1e18)
netAssets = assets - fee
```

### 3) Queued redeem fee (asset-based)
- Applied in `requestRedeem` when the mode is `QUEUED`.
- Uses `feeOnQueuedRedeem` (1e18 precision).
- The fee is set aside as pending and excluded from `totalAssets()`.
- Formula (amount includes fee):
```text
fee = assets * feeOnQueuedRedeem / (feeOnQueuedRedeem + 1e18)
netAssets = assets - fee
```

### 4) Management fee (share-based)
- Time-based on net AUM.
- Computed using annual rate (bps) and time elapsed.
- Minted as shares when `takeFees` is called.
- Formula:
```text
annualFee = assets * managementRateBps / 10_000
managementFees = annualFee * timeElapsed / 365 days
```

### 5) Performance fee (share-based)
- Based on a high-water mark (HWM).
- Uses a fee-aware PPS that is adjusted for management fees.
- Minted as shares when `takeFees` is called.
- Formula:
```text
pps = shareUnit * (assetsUnderMgmt - managementFees + 1) / (totalSupply + offset)
profitPerShare = max(pps - HWM, 0)
profitAssets = profitPerShare * totalSupply / 10**shareDecimals
performanceFees = profitAssets * performanceRateBps / 10_000
```

## Pending fees and protocol split

All **asset-based** fees accumulate as pending balances in `FeeManager` storage:

- `pendingFees` (manager/feeRecipient portion)
- `pendingProtocolFees` (protocol portion)

When pending fees are added, they are split by the protocol fee rate:

```text
protocolCut = amount * protocolRateBps / 10_000
managerCut = amount - protocolCut
```

Both pending balances are **excluded** from `totalAssets()` in the vault.

## Fee share minting (management/performance)

Fees in assets are converted into shares so fee recipients are paid via dilution:

```text
feeShares = totalFeesAssets * (totalSupply + offset) / ((assetsUnderMgmt - totalFeesAssets) + 1)
```

Protocol share split:

```text
protocolShares = feeShares * protocolRateBps / 10_000
managerShares = feeShares - protocolShares
```

## Claiming pending fees

- `claimFees()` (vault owner) claims **manager** pending fees.
- `claimProtocolFees()` (vault owner) claims **protocol** pending fees.
- Fees are transferred in assets to their recipients.

## Fee rate precision

- Asset-based fee rates use `1e18` precision.
  - Example: `1e16` = 1%.
- Protocol and management/performance rates use basis points (`1e4 = 100%`).

## Quick example

If a vault has a 1% deposit fee (`feeOnDeposit = 1e16`) and a user deposits `1000`, then:
```text
fee ≈ 9.9
netAssets ≈ 990.1
```
The fee is split between manager and protocol and excluded from `totalAssets()`.

## Relevant contracts

- `src/fees/FeeManager.sol`
- `src/fees/FeeRegistry.sol`
- `src/ElitraVault.sol`
