# Elitra Audit Doc

Last updated: 2026-02-01

## ELI5

Elitra is a smart vault that lets people put tokens in one place and earn yield, even when the yield happens on other chains. Bots move the money to approved strategies, and the vault only allows safe, pre-approved actions. If anything looks risky, the vault can pause or queue withdrawals so funds are protected.

## High-Level Overview

- **Main idea**: ERC-4626 vault on a hub chain (SEI) with controlled strategy execution and optional cross-chain deposits.
- **Safety model**: `manage()` calls are guarded per target (fail-closed); swap/zap entrypoints are limited to approved adapters.
- **Oracle updates**: balance updates adjust PPS and can auto-pause if changes exceed thresholds.
- **Redemptions**: instant if liquid; otherwise queued and later fulfilled.
- **Cross-chain deposits**: bridged funds arrive via adapters, can be zapped into vault assets, then deposited or queued on failure.

## Actors (Roles + Capabilities)

- **LP / Depositor**: deposits and redeems vault shares; no privileged rights.
- **Strategy Operator / Bot**: authorized to call `manage()`/`manageBatch()` to execute whitelisted strategy actions.
- **Admin / Governance**: configures vault risk params, fees, guards, whitelists; can pause/unpause.
- **Guardian (optional)**: emergency pause actions only.
- **Oracle / Updater**: posts balance updates (hooked into PPS logic).

## System Components (Non-Actors)

- **Bridge protocols**: deliver cross-chain tokens and payloads to destination adapters.
- **Adapters**: whitelisted contracts that process bridged deposits and zaps; not user roles.

## Contract Map (Purpose + Relationships)

- **Vault core**:
  - `src/ElitraVault.sol`: ERC-4626 vault, fees, redemptions, oracle updates.
  - `src/vault/VaultBase.sol`: auth + guarded `manage()` execution.
  - `src/vault/AuthUpgradeable.sol`, `src/vault/Compatible.sol`: base utilities.
  - `src/ElitraVaultFactory.sol`: deploys vaults.
- **Hooks**:
  - `src/hooks/ManualBalanceUpdateHook.sol`
  - `src/hooks/HybridRedemptionHook.sol`
- **Fees**:
  - `src/fees/FeeManager.sol`: tracks pending asset fees and mints fee shares.
  - `src/fees/FeeRegistry.sol`: stores protocol fee rate and receiver.
- **Cross-chain adapters**:
  - `src/adapters/BaseCrosschainDepositAdapter.sol`: base receiver + deposit flow.
  - `src/adapters/CrosschainDepositQueue.sol`: records and resolves failed deposits.
  - `src/adapters/cctp/CCTPCrosschainDepositAdapter.sol`: CCTP-specific adapter.
- **Zap / swap helpers**:
  - `src/adapters/ZapExecutor.sol`
  - `src/adapters/Api3SwapAdapter.sol`: swap adapter used by zaps (SEI).
- **Guards (contract-level call validators)**:
  - `src/guards/base/TokenGuard.sol`
  - `src/guards/base/WNativeGuard.sol`
  - `src/guards/sei/YeiPoolGuard.sol`
  - `src/guards/sei/YeiIncentivesGuard.sol`
  - `src/guards/sei/TakaraPoolGuard.sol`
  - `src/guards/sei/TakaraControllerGuard.sol`
  - `src/guards/sei/MerklDistributorGuard.sol`
  - `src/guards/sei/MorphoVaultGuard.sol`

## Component Relationships (How Things Connect)

- `ElitraVault` is the user-facing ERC-4626 vault. It delegates auth and guarded execution to `VaultBase`.
- `VaultBase` enforces role-based access and target guards for strategy execution (`manage`/`manageBatch`).
- `FeeManager` and `FeeRegistry` control asset-based and share-based fees, and the protocol fee split.
- Hooks plug into the vault:
  - **Balance update hook** updates PPS based on external balances and can pause the vault on large changes.
  - **Redemption hook** decides instant vs queued redemptions and tracks pending withdrawals.
- Cross-chain adapters receive bridged assets and deposit into the vault, optionally via zaps. Failures go to a queue.
- Guards define what external protocol calls are allowed for strategy operations and validate call data.

## Key Flows (Summary)

### 1) Local deposit (ERC-4626)

1. User calls `deposit`/`mint` on `ElitraVault`.
2. Vault applies deposit fee (if configured) and mints shares to receiver.
3. Fees are tracked in `FeeManager` and excluded from `totalAssets()`.

### 2) Redemption

1. User calls `requestRedeem` (or equivalent).
2. Hook checks liquidity:
   - **Instant**: shares are burned and assets transferred.
   - **Queued**: shares are escrowed and later fulfilled by an operator.
3. Operator fulfills queued withdrawals after unwinding strategies.

### 3) Strategy execution (`manage`/`manageBatch`)

1. Operator submits call(s) to `VaultBase`.
2. Vault verifies caller role and that each target has an assigned guard.
3. Guard validates selector and parameters; invalid calls revert (fail-closed).
4. Approved calls execute against allowed protocols.

### 4) Oracle balance updates

1. Oracle/updater submits new aggregated balances derived from external protocol positions (vault stores only aggregate).
2. Hook computes new PPS and validates change against a configured threshold.
3. If change is too large, vault can pause; otherwise PPS and balance snapshots update.

### 5) Cross-chain deposit

1. User sends tokens via a bridge to the adapter (optionally with zap calls).
2. Adapter optionally zaps bridged tokens into the vault asset.
3. Adapter deposits into the vault; on failure, deposit is recorded and queued.
4. Operator later resolves failed deposits (refund or fulfill).

## Fees (Summary)

- **Asset-based fees**: deposit, instant withdraw, and queued redeem fees are taken in assets and stored as pending.
- **Share-based fees**: management/performance fees are minted as shares, using a high-water mark.
- **Protocol fee split**: protocol cut is defined by `FeeRegistry`; remainder goes to the vault fee recipient.
- **Net AUM model**: `totalAssets()` excludes pending fees and assets reserved for queued redemptions.

## Access Control (Summary)

- **Admins**: configure fees, guards, and whitelists; can pause/unpause.
- **Operators**: execute strategy calls and resolve queued withdrawals/deposits.
- **Guardians**: emergency pause actions (if enabled).
- **Adapters**: only approved adapters/bridges can call into vault deposit flows.

## External Systems / Dependencies (Non-Exhaustive)

- Bridge protocols (e.g., LayerZero, CCTP) via adapters.
- Yield protocols guarded on SEI (e.g., Takara, Yei, Morpho, Merkl).
- DEXes or wrappers used by zaps (via `ZapExecutor` and swap adapters).

## Upgrade / Deployment Notes (Summary)

- Contracts are designed to support upgradeable deployments; confirm proxy usage and admin roles per deployment.
- Ensure guard assignments and adapter whitelists are set before any strategy operations.

## Audit Scope (must match mainnet deploy set)

Commit hash (freeze 3 days pre‑audit): **TBD**

In scope (current code units used in deployed bytecode; update to exact mainnet deploy list):

- `src/ElitraVault.sol`
- `src/vault/VaultBase.sol`
- `src/vault/AuthUpgradeable.sol`
- `src/vault/Compatible.sol`
- `src/ElitraVaultFactory.sol`
- `src/hooks/ManualBalanceUpdateHook.sol`
- `src/hooks/HybridRedemptionHook.sol`
- `src/fees/FeeManager.sol`
- `src/fees/FeeRegistry.sol`
- `src/adapters/BaseCrosschainDepositAdapter.sol`
- `src/adapters/CrosschainDepositQueue.sol`
- `src/adapters/cctp/CCTPCrosschainDepositAdapter.sol`
- `src/adapters/ZapExecutor.sol`
- `src/adapters/Api3SwapAdapter.sol`
- `src/guards/base/TokenGuard.sol`
- `src/guards/base/WNativeGuard.sol`
- `src/guards/sei/YeiPoolGuard.sol`
- `src/guards/sei/YeiIncentivesGuard.sol`
- `src/guards/sei/TakaraPoolGuard.sol`
- `src/guards/sei/TakaraControllerGuard.sol`
- `src/guards/sei/MerklDistributorGuard.sol`
- `src/guards/sei/MorphoVaultGuard.sol`

Out of scope (interfaces/libraries only, unless explicitly requested):

- `src/interfaces/*`
- `src/libraries/Errors.sol`

## Build / Compile

Prereqs:
- Foundry installed (`forge`, `cast`)
- Submodules initialized

Commands:

```bash
git submodule update --init --recursive
forge build
forge test
```

Config:
- `foundry.toml`: `solc_version = 0.8.28`, `via_ir = true`

Known compiler warnings/errors: **TBD** (run `forge build` and document any).

## Past Audits

- **TBD** (add links or files for prior audit reports)

## Detailed Specs (for auditors)

- `specs/crosschain.md`
- `specs/guardrail.md`
- `specs/manage-security.md`
- `specs/fees.md`
