# Elitra Core - System Architecture

A cross-chain ERC-4626 vault system with LayerZero integration for multi-chain yield strategies.

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Manage Security](#2-manage-security)
3. [Oracle System](#3-oracle-system)
4. [Deposit & Withdraw Queue](#4-deposit--withdraw-queue)
5. [Cross-chain Deposit Design](#5-cross-chain-deposit-design)

---

## 1. System Overview

```mermaid
graph TB
    subgraph "Hub Chain (SEI)"
        Users[Users]

        subgraph "Vault Layer"
            Vault[ElitraVault<br/>ERC-4626]
            Oracle[Balance Update Hook<br/>Oracle Adapter]
            Redemption[Redemption Hook<br/>Queue Strategy]
        end

        subgraph "Cross-chain Deposit"
            DepositAdapter[CrosschainDepositAdapter<br/>Receives bridged funds]
            DepositQueue[CrosschainDepositQueue<br/>Failed deposit handling]
        end

        subgraph "Cross-chain Strategy"
            StrategyAdapter[CrosschainStrategyAdapter<br/>Sends to remote chains]
        end
    end

    subgraph "Remote Chains (ETH, ARB)"
        SubVault[SubVault<br/>Holds assets]
        Strategies[Yield Strategies<br/>Aave, Compound, etc]
    end

    Users -->|deposit/redeem| Vault
    Oracle -->|updateBalance| Vault
    Vault -->|beforeRedeem| Redemption

    DepositAdapter -->|deposit| Vault
    DepositAdapter -->|failed deposits| DepositQueue

    Vault -->|manage| StrategyAdapter
    StrategyAdapter -->|LZ OFT| SubVault
    SubVault -->|manage| Strategies

    style Vault fill:#90EE90,stroke:#333,stroke-width:3px
    style DepositAdapter fill:#FFD700,stroke:#333,stroke-width:2px
    style SubVault fill:#87CEEB,stroke:#333,stroke-width:2px
```

---

## 2. Manage Security

The `manage()` function allows operators to execute vault strategy operations. A **guard-per-target architecture** ensures security through fail-closed validation.

### 2.1 Security Layers

```mermaid
graph TB
    subgraph "Security Layers"
        L1[Layer 1: Authorization<br/>requiresAuth modifier]
        L2[Layer 2: Guard Existence<br/>guards target != 0]
        L3[Layer 3: Function Whitelist<br/>selector validation]
        L4[Layer 4: Parameter Validation<br/>argument checks]
        L5[Layer 5: Protocol Rules<br/>business logic]
    end

    L1 --> L2
    L2 --> L3
    L3 --> L4
    L4 --> L5
    L5 --> EXEC[Safe Execution]

    L1 -.->|Bypass| F1[Unauthorized]
    L2 -.->|Bypass| F2[No Guard]
    L3 -.->|Bypass| F3[Wrong Function]
    L4 -.->|Bypass| F4[Invalid Params]
    L5 -.->|Bypass| F5[Rule Violation]

    style EXEC fill:#90EE90
    style F1 fill:#FF6B6B
    style F2 fill:#FF6B6B
    style F3 fill:#FF6B6B
    style F4 fill:#FF6B6B
    style F5 fill:#FF6B6B
```

### 2.2 Guard-per-Target Architecture

```mermaid
graph TB
    subgraph VaultBase
        VM[guards mapping]
    end

    subgraph "Target → Guard Mapping"
        T1[WETH Contract]
        T2[YEI Protocol]
        T3[DEX Router]
        T4[USDC Token]

        G1[AllowAllGuard<br/>All functions]
        G2[YieldGuard<br/>stake/unstake/claim]
        G3[SwapGuard<br/>swap/addLiquidity]
        G4[TokenGuard<br/>approve whitelist]
    end

    VM -.->|maps| T1
    VM -.->|maps| T2
    VM -.->|maps| T3
    VM -.->|maps| T4

    T1 --> G1
    T2 --> G2
    T3 --> G3
    T4 --> G4

    style G1 fill:#90EE90
    style G2 fill:#FFD700
    style G3 fill:#FFA500
    style G4 fill:#FF6B6B
```

### 2.3 Execution Flow

```mermaid
sequenceDiagram
    participant Operator
    participant VaultBase
    participant Guard
    participant Target

    Operator->>VaultBase: manage(target, data, value)

    VaultBase->>VaultBase: Check requiresAuth
    alt Not authorized
        VaultBase-->>Operator: Revert: Unauthorized
    end

    VaultBase->>VaultBase: Lookup guards[target]
    alt No guard exists
        VaultBase-->>Operator: Revert: No Guard (Fail-Closed)
    end

    VaultBase->>Guard: validate(msg.sender, data, value)
    Guard->>Guard: Parse function selector
    Guard->>Guard: Validate parameters
    Guard->>Guard: Check protocol rules

    alt Validation failed
        Guard-->>VaultBase: return false
        VaultBase-->>Operator: Revert: Validation Failed
    end

    Guard-->>VaultBase: return true
    VaultBase->>Target: functionCallWithValue(data, value)
    Target-->>VaultBase: result
    VaultBase-->>Operator: return result
```

### 2.4 Guard Types

| Guard Type | Purpose | Example Rules |
|------------|---------|---------------|
| `AllowAllGuard` | Trusted contracts | All functions allowed |
| `TokenGuard` | ERC20 operations | Approve only whitelisted spenders |
| `YieldGuard` | Yield protocols | stake/unstake/claim with limits |
| `SwapGuard` | DEX operations | swap/addLiquidity with slippage checks |

---

## 3. Oracle System

The oracle system aggregates balances from external protocols and updates the vault's price per share.

### 3.1 Balance Update Flow

```mermaid
sequenceDiagram
    participant Oracle as Oracle Bot
    participant Hook as BalanceUpdateHook
    participant Vault as ElitraVault

    Note over Oracle,Vault: Oracle monitors external protocol balances

    Oracle->>Vault: updateBalance(newAggregatedBalance)

    Vault->>Vault: Check block.number > lastBlockUpdated
    alt Already updated this block
        Vault-->>Oracle: Revert: Already Updated
    end

    Vault->>Hook: beforeBalanceUpdate(lastPPS, totalSupply, idleBalance, newBalance)
    Hook->>Hook: Calculate new PPS
    Hook->>Hook: Check price change threshold

    alt Price change > 1%
        Hook-->>Vault: (shouldContinue: false, newPPS)
        Vault->>Vault: _pause()
        Vault-->>Oracle: Emit VaultPausedDueToThreshold
    else Price change <= 1%
        Hook-->>Vault: (shouldContinue: true, newPPS)
        Vault->>Vault: Update aggregatedUnderlyingBalances
        Vault->>Vault: Update lastPricePerShare
        Vault->>Vault: Update lastBlockUpdated
        Vault-->>Oracle: Emit PPSUpdated
    end
```

### 3.2 Price Per Share Calculation

```mermaid
graph LR
    subgraph "Total Assets"
        Idle[Idle Balance<br/>IERC20.balanceOf vault]
        External[Aggregated External<br/>aggregatedUnderlyingBalances]
    end

    Idle --> Sum[Total Assets]
    External --> Sum

    Sum --> PPS[Price Per Share]
    Supply[Total Supply] --> PPS

    PPS --> |totalAssets / totalSupply| Result[Share Price]

    style Sum fill:#90EE90
    style Result fill:#FFD700
```

### 3.3 Auto-Pause Mechanism

The vault automatically pauses if price per share changes by more than 1% in a single update:

```
priceChange = |newPPS - lastPPS| / lastPPS

if priceChange > 1%:
    vault.pause()
    emit VaultPausedDueToThreshold
```

**Protection Against:**
- Oracle manipulation
- Sudden strategy losses
- Flash loan attacks

---

## 4. Deposit & Withdraw Queue

### 4.1 Deposit Flow

```mermaid
sequenceDiagram
    participant User
    participant Vault as ElitraVault

    Note over User,Vault: Standard ERC-4626 Deposit

    User->>Vault: approve(asset, amount)
    User->>Vault: deposit(assets, receiver)

    Vault->>Vault: Check whenNotPaused
    Vault->>Vault: Transfer assets from user
    Vault->>Vault: Calculate shares = assets / PPS
    Vault->>Vault: Mint shares to receiver

    Vault-->>User: Return shares minted
```

### 4.2 Redemption Flow

```mermaid
sequenceDiagram
    participant User
    participant Vault as ElitraVault
    participant Hook as RedemptionHook

    User->>Vault: requestRedeem(shares, receiver, owner)

    Vault->>Vault: Validate shares > 0
    Vault->>Vault: Validate owner == msg.sender
    Vault->>Vault: Calculate assets = previewRedeem(shares)

    Vault->>Hook: beforeRedeem(vault, shares, assets, owner, receiver)
    Hook->>Hook: Check available liquidity

    alt Sufficient Liquidity
        Hook-->>Vault: (INSTANT, actualAssets)
        Vault->>Vault: Burn shares
        Vault->>Vault: Transfer assets to receiver
        Vault-->>User: Return assets (instant)
    else Insufficient Liquidity
        Hook-->>Vault: (QUEUED, actualAssets)
        Vault->>Vault: Transfer shares to vault (escrow)
        Vault->>Vault: Update totalPendingAssets
        Vault->>Vault: Store pending request
        Vault-->>User: Emit RedeemRequest (queued)
    end
```

### 4.3 Queue Fulfillment

```mermaid
sequenceDiagram
    participant Operator
    participant Vault as ElitraVault
    participant User

    Note over Operator,Vault: Operator withdraws from strategies

    Operator->>Vault: manage(...) withdraw from strategy

    Note over Operator,Vault: Fulfill pending redemptions

    Operator->>Vault: fulfillRedeem(receiver, shares, assets)

    Vault->>Vault: Validate pending request exists
    Vault->>Vault: Update pending.shares -= shares
    Vault->>Vault: Update pending.assets -= assets
    Vault->>Vault: Update totalPendingAssets -= assets

    Vault->>Vault: Burn escrowed shares
    Vault->>User: Transfer assets

    Vault-->>Operator: Emit RequestFulfilled
```

### 4.4 Redemption States

```mermaid
stateDiagram-v2
    [*] --> RequestReceived: requestRedeem()

    RequestReceived --> InstantRedeem: Sufficient liquidity
    RequestReceived --> Queued: Insufficient liquidity

    InstantRedeem --> [*]: Assets transferred

    Queued --> Fulfilled: fulfillRedeem()
    Queued --> Cancelled: cancelRedeem()

    Fulfilled --> [*]: Assets transferred
    Cancelled --> [*]: Shares returned
```

---

## 5. Cross-chain Deposit Design

### 5.1 Architecture Overview

```mermaid
graph TB
    subgraph "Source Chain (Ethereum, Arbitrum, etc)"
        User[User Wallet]
        OFT[LayerZero OFT<br/>SEI Token]
    end

    Bridge[LayerZero<br/>Cross-chain Bridge]

    subgraph "Hub Chain (SEI)"
        subgraph "Deposit System"
            Adapter[CrosschainDepositAdapter<br/>Receives OFT compose]
            Queue[CrosschainDepositQueue<br/>Failed deposits]
        end

        Vault[ElitraVault]
    end

    User -->|1. Send OFT with compose msg| OFT
    OFT -->|2. Bridge tokens + payload| Bridge
    Bridge -->|3. lzCompose callback| Adapter

    Adapter -->|4a. Success: deposit| Vault
    Adapter -->|4b. Failure: queue| Queue

    Vault -->|5. Mint shares| User

    style Adapter fill:#FFD700,stroke:#333,stroke-width:2px
    style Queue fill:#FF6B6B,stroke:#333,stroke-width:2px
    style Vault fill:#90EE90,stroke:#333,stroke-width:2px
```

### 5.2 Compose Message Format

```solidity
// User sends OFT with compose message containing:
bytes memory composeMsg = abi.encode(
    vault,        // Target vault address
    receiver,     // Who receives shares
    minAmountOut, // Slippage protection
    zapCalls      // Optional zap operations (e.g., wrap WSEI)
);
```

### 5.3 Deposit Flow with Zapping

```mermaid
sequenceDiagram
    participant User
    participant OFT as LayerZero OFT
    participant LZ as LayerZero Endpoint
    participant Adapter as CrosschainDepositAdapter
    participant Zap as Zap Target (WSEI)
    participant Vault as ElitraVault
    participant Queue as DepositQueue

    User->>OFT: send(SEI, composeMsg)
    OFT->>LZ: Bridge tokens + compose message

    LZ->>Adapter: lzCompose(_from, _guid, _message)

    Adapter->>Adapter: Validate OFT supported
    Adapter->>Adapter: Decode compose message
    Adapter->>Adapter: Record deposit (Pending)

    alt Has Zap Calls
        Adapter->>Zap: Execute zap (e.g., WSEI.deposit())
        Zap-->>Adapter: Vault asset received
    end

    Adapter->>Adapter: try processDeposit()

    alt Deposit Success
        Adapter->>Vault: deposit(amount, receiver)
        Vault-->>Adapter: shares minted
        Adapter->>Adapter: Status = Success
        Adapter-->>User: Emit DepositSuccess
    else Deposit Failed
        Adapter->>Adapter: Get current share price
        Adapter->>Queue: recordFailedDeposit(user, token, amount, sharePrice)
        Queue->>Queue: Transfer tokens from adapter
        Queue->>Queue: Store failed deposit record
        Adapter->>Adapter: Status = Queued
        Adapter-->>User: Emit DepositQueued
    end
```

### 5.4 Failed Deposit Handling

```mermaid
graph TB
    subgraph "Deposit Attempt"
        Receive[Receive bridged tokens]
        Zap[Execute zap calls]
        Deposit[Deposit to vault]
    end

    subgraph "Failure Handling"
        Queue[CrosschainDepositQueue]
        Record[Record failed deposit<br/>+ share price at failure]
    end

    subgraph "Resolution"
        Operator[Operator]
        Resolve[resolveFailedDeposit]
        Refund[Refund tokens to user]
    end

    Receive --> Zap
    Zap -->|Success| Deposit
    Zap -->|Failure| Queue
    Deposit -->|Success| Success[User gets shares]
    Deposit -->|Failure| Queue

    Queue --> Record

    Operator --> Resolve
    Resolve --> Refund

    style Success fill:#90EE90
    style Queue fill:#FF6B6B
    style Refund fill:#FFD700
```

### 5.5 Queue Data Structure

```solidity
struct FailedDeposit {
    address user;           // Who should receive shares/refund
    uint32 srcEid;          // Source chain endpoint ID
    address token;          // Bridged token address
    uint256 amount;         // Amount of tokens
    address vault;          // Target vault
    bytes32 guid;           // LayerZero message GUID
    bytes failureReason;    // Why deposit failed
    uint256 timestamp;      // When failure occurred
    uint256 sharePrice;     // PPS at time of failure
    DepositStatus status;   // Failed | Resolved
}
```

### 5.6 Deployment Flow

```mermaid
sequenceDiagram
    participant Deployer
    participant Queue as CrosschainDepositQueue
    participant Adapter as CrosschainDepositAdapter

    Note over Deployer,Adapter: Step 1: Deploy Queue
    Deployer->>Queue: Deploy implementation
    Deployer->>Queue: Deploy proxy + initialize(owner)

    Note over Deployer,Adapter: Step 2: Deploy Adapter
    Deployer->>Adapter: Deploy implementation(lzEndpoint)
    Deployer->>Adapter: Deploy proxy + initialize(owner, queueAddress)

    Note over Deployer,Adapter: Step 3: Link Queue to Adapter
    Deployer->>Queue: setAdapter(adapterAddress)

    Note over Deployer,Adapter: Step 4: Configure
    Deployer->>Adapter: setSupportedOFT(token, oft, true)
    Deployer->>Adapter: setSupportedVault(vault, true)
    Deployer->>Adapter: Configure DVNs
```

### 5.7 Security Features

| Feature | Description |
|---------|-------------|
| **OFT Whitelist** | Only approved OFTs can trigger deposits |
| **Vault Whitelist** | Only approved vaults can receive deposits |
| **Slippage Protection** | `minAmountOut` prevents front-running |
| **Failed Deposit Queue** | No fund loss on failures |
| **Share Price Snapshot** | Records PPS at failure for fair resolution |
| **Pausable** | Admin can pause all operations |
| **Reentrancy Guard** | Protected against reentrancy |

---

## Project Structure

```
elitra-core/
├── src/
│   ├── ElitraVault.sol                    # Main ERC-4626 vault
│   ├── adapters/layerzero/
│   │   ├── CrosschainDepositAdapter.sol   # Receives cross-chain deposits
│   │   ├── CrosschainDepositQueue.sol     # Handles failed deposits
│   │   └── CrosschainStrategyAdapter.sol  # Sends funds to remote chains
│   ├── vault/
│   │   ├── VaultBase.sol                  # Base with auth & guards
│   │   └── SubVault.sol                   # Remote chain vault
│   ├── guards/                            # Transaction guards
│   ├── hooks/                             # Oracle & redemption hooks
│   └── interfaces/
├── script/
│   ├── crosschain-deposit/                # Deposit system scripts
│   ├── crosschain/                        # Strategy scripts
│   └── deploy/                            # Vault deployment
├── config/                                # Chain configs
└── specs/                                 # Detailed specifications
```

## License

MIT License - see [LICENSE.md](LICENSE.md)
