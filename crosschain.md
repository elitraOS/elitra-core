# Multichain Deposit Flow

This document explains the cross-chain deposit flow for Elitra vaults using LayerZero V2 OFT (Omnichain Fungible Token) with compose messages.

## Overview

The multichain deposit system allows users to deposit assets from any supported chain into Elitra vaults on the destination chain (e.g., SEI). The system supports optional "zapping" - executing arbitrary token conversions before depositing into the vault.

## Architecture Flow

```mermaid
sequenceDiagram
    participant User
    participant SourceChain as Source Chain<br/>(e.g., Ethereum)
    participant OFT as Token OFT<br/>(Source Chain)
    participant LZEndpointSrc as LayerZero Endpoint<br/>(Source)
    participant LZNetwork as LayerZero<br/>Network
    participant LZEndpointDst as LayerZero Endpoint<br/>(Destination)
    participant Adapter as MultichainDepositAdapter<br/>(Destination Chain)
    participant ZapTarget as Zap Contracts<br/>(DEX/WSEI/etc)
    participant Vault as ElitraVault<br/>(Destination Chain)

    Note over User,Vault: Phase 1: Initiate Cross-Chain Deposit
    User->>OFT: send(SendParam)<br/>- dstEid: destination chain<br/>- to: adapter address<br/>- amount: tokens to send<br/>- composeMsg: encode(vault, receiver, zapCalls)

    Note over OFT: User approves tokens<br/>and sends with native fee

    OFT->>OFT: Lock/Burn tokens
    OFT->>LZEndpointSrc: send(message + composeMsg)

    Note over LZEndpointSrc,LZNetwork: Phase 2: LayerZero Message Routing
    LZEndpointSrc->>LZNetwork: Route message cross-chain
    LZNetwork->>LZEndpointDst: Deliver message

    Note over LZEndpointDst,Adapter: Phase 3: Destination Token Receipt
    LZEndpointDst->>OFT: lzReceive()<br/>(Mint/Unlock tokens to adapter)

    Note over LZEndpointDst,Adapter: Phase 4: Compose Callback Execution
    LZEndpointDst->>Adapter: lzCompose(_from, _guid, _message)

    activate Adapter
    Note over Adapter: Decode compose message:<br/>- srcEid (source chain)<br/>- amountLD (tokens received)<br/>- vault address<br/>- receiver address<br/>- zapCalls[] (optional operations)

    Adapter->>Adapter: _recordDeposit()<br/>Create DepositRecord with status=Pending

    alt zapCalls.length > 0
        Note over Adapter,ZapTarget: Phase 5a: Execute Zapping Operations
        Adapter->>Adapter: _executeZapCalls(zapCalls)

        loop For each zap call
            Adapter->>ZapTarget: functionCallWithValue(target, data, value)
            Note over ZapTarget: Examples:<br/>- WSEI.deposit() to wrap SEI<br/>- DEX.swap() to convert tokens<br/>- Multi-step conversions
            ZapTarget-->>Adapter: Return
        end

        Adapter->>Adapter: Verify output balance increased
        Adapter->>Adapter: emit ZapExecuted(depositId, numCalls, amountOut)
    else No zapping needed
        Note over Adapter: Phase 5b: Direct Deposit
        Note over Adapter: Token already in vault's asset form
    end

    Note over Adapter,Vault: Phase 6: Vault Deposit
    Adapter->>Vault: approve(asset, amount)
    Adapter->>Vault: deposit(amount, receiver)
    Vault-->>Adapter: shares minted

    Adapter->>Adapter: Update DepositRecord:<br/>- sharesReceived = shares<br/>- status = Success
    Adapter->>Adapter: emit DepositSuccess(depositId, receiver, vault, shares)

    deactivate Adapter

    Note over User,Vault: ✅ Deposit Complete<br/>User receives vault shares on destination chain
```

## Detailed Component Breakdown

### 1. User Initiation (Source Chain)

The user initiates the deposit by calling the OFT contract on the source chain:

```solidity
// Build compose message with deposit parameters
bytes memory composeMsg = abi.encode(
    vaultAddress,    // Target vault on destination chain
    receiverAddress, // Who receives the vault shares
    zapCalls         // Array of operations to execute before deposit
);

// Build SendParam for LayerZero
SendParam memory sendParam = SendParam({
    dstEid: destinationChainId,           // e.g., SEI chain
    to: bytes32(adapterAddress),          // MultichainDepositAdapter
    amountLD: amount,                     // Tokens to send
    minAmountLD: amountWithSlippage,      // Slippage protection
    extraOptions: executionOptions,       // Gas settings
    composeMsg: composeMsg,               // Our custom payload
    oftCmd: ""                            // Standard send
});

// Execute with native fee
OFT.send{value: nativeFee}(sendParam, fee, refundAddress);
```

### 2. LayerZero Message Processing

- **Source Endpoint**: Validates message, locks/burns tokens
- **Network**: Routes message across chains via DVNs (Decentralized Verifier Networks)
- **Destination Endpoint**: Verifies and delivers message

### 3. Compose Callback (lzCompose)

The adapter receives the compose callback after tokens are minted:

```solidity
function lzCompose(
    address _from,        // OFT contract address
    bytes32 _guid,        // Unique message ID
    bytes calldata _message, // OFT compose format
    address,              // executor
    bytes calldata        // extraData
) external payable {
    // Decode OFT message structure
    uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);
    uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
    bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);

    // Decode our custom payload
    (address vault, address receiver, Call[] memory zapCalls) =
        abi.decode(composeMsg, (address, address, Call[]));

    // Process the deposit...
}
```

### 4. Zapping Operations (Optional)

The adapter can execute arbitrary operations to convert received tokens into the vault's asset:

**Example 1: Wrap Native SEI to WSEI**
```solidity
zapCalls[0] = Call({
    target: WSEI_ADDRESS,
    value: amount,
    data: abi.encodeWithSignature("deposit()")
});
```

**Example 2: Swap via DEX**
```solidity
zapCalls[0] = Call({
    target: DEX_ROUTER,
    value: 0,
    data: abi.encodeCall(
        router.swap,
        (tokenIn, tokenOut, amount, minOut, deadline)
    )
});
```

**Example 3: Multi-step Conversion**
```solidity
zapCalls[0] = Call({ /* Wrap native token */ });
zapCalls[1] = Call({ /* Approve DEX */ });
zapCalls[2] = Call({ /* Swap to final asset */ });
```

### 5. Vault Deposit

After zapping (or directly if no zap needed), deposit into the vault:

```solidity
function _depositToVault(
    address vault,
    address receiver,
    uint256 amount
) internal returns (uint256 shares) {
    address asset = IElitraVault(vault).asset();

    // Approve vault
    IERC20(asset).forceApprove(vault, amount);

    // Deposit and mint shares to receiver
    shares = IElitraVault(vault).deposit(amount, receiver);
}
```

## Error Handling & Refunds

```mermaid
flowchart TD
    Start[lzCompose Received] --> Record[Record Deposit<br/>Status: Pending]
    Record --> TryZap{zapCalls.length > 0?}

    TryZap -->|Yes| ExecuteZap[Execute Zap Operations]
    TryZap -->|No| DirectDeposit[Skip to Deposit]

    ExecuteZap --> ZapSuccess{Zap Success?}
    ZapSuccess -->|Yes| DirectDeposit
    ZapSuccess -->|No| ZapFailed[Status: ZapFailed]

    DirectDeposit --> TryDeposit[Deposit to Vault]
    TryDeposit --> DepositSuccess{Deposit Success?}

    DepositSuccess -->|Yes| Success[Status: Success<br/>Emit DepositSuccess]
    DepositSuccess -->|No| DepositFailed[Status: DepositFailed]

    ZapFailed --> AutoRefund[Attempt Auto Refund]
    DepositFailed --> AutoRefund

    AutoRefund --> RefundSuccess{Refund Success?}
    RefundSuccess -->|Yes| RefundSent[Status: RefundSent<br/>Tokens sent back to user]
    RefundSuccess -->|No| RefundFailed[Status: RefundFailed<br/>Needs manual intervention]

    Success --> End[Complete]
    RefundSent --> End
    RefundFailed --> Manual[Operator calls<br/>manualRefund]
    Manual --> End

    style Success fill:#90EE90
    style RefundSent fill:#FFD700
    style RefundFailed fill:#FF6B6B
    style ZapFailed fill:#FF6B6B
    style DepositFailed fill:#FF6B6B
```

### Automatic Refund System

If any step fails, the adapter attempts to refund tokens to the user:

```solidity
function _attemptRefund(uint256 depositId) internal {
    DepositRecord storage record = depositRecords[depositId];

    // Build refund parameters
    SendParam memory sendParam = SendParam({
        dstEid: record.srcEid,        // Back to source chain
        to: record.user,               // Original user
        amountLD: record.amountIn,     // Full amount
        minAmountLD: amountWithSlippage,
        extraOptions: "",
        composeMsg: "",                // No compose on refund
        oftCmd: ""
    });

    // Send tokens back via OFT
    IOFT(oft).send{value: fee}(sendParam, fee, payable(this));
}
```

## Deposit Record Tracking

Every deposit is tracked with a complete audit trail:

```solidity
struct DepositRecord {
    address user;              // Share receiver
    uint32 srcEid;            // Source chain ID
    address tokenIn;          // Received token
    uint256 amountIn;         // Received amount
    address vault;            // Target vault
    uint256 sharesReceived;   // Vault shares (0 if failed)
    uint256 timestamp;        // Deposit time
    DepositStatus status;     // Current status
    bytes32 guid;             // LayerZero message ID
    bytes failureReason;      // Error data if failed
}
```

### Status Flow

```
Pending → Success                    (Happy path)
Pending → ZapFailed → RefundSent     (Zap fails, refund succeeds)
Pending → ZapFailed → RefundFailed   (Zap fails, refund fails - needs manual)
Pending → DepositFailed → RefundSent (Deposit fails, refund succeeds)
```

## Gas Profiling

LayerZero requires gas to be specified for both receive and compose operations:

```solidity
// lzReceive gas (token minting)
bytes memory lzReceiveOption = abi.encodePacked(
    uint128(200000),  // gas limit
    uint128(0)        // msg.value
);

// lzCompose gas (zap + deposit)
bytes memory lzComposeOption = abi.encodePacked(
    uint16(0),         // index
    uint128(1200000),  // gas limit (higher for complex operations)
    uint128(0)         // msg.value
);
```

## Security Features

1. **Pausable**: Admin can pause all operations
2. **Reentrancy Protection**: All external calls protected
3. **Vault Whitelisting**: Only approved vaults can be targeted
4. **OFT Whitelisting**: Only approved OFT contracts accepted
5. **Access Control**: Owner + Operator roles
6. **Automatic Refunds**: Failed operations trigger refunds
7. **Manual Recovery**: Operators can manually refund stuck deposits
8. **Emergency Recovery**: Owner can recover stuck tokens

## Example: Cross-Chain SEI → WSEI Vault Deposit

```mermaid
graph LR
    A[User on Ethereum] -->|"1. send() with<br/>1 ETH worth of SEI"| B[SEI OFT<br/>Ethereum]
    B -->|"2. Lock tokens<br/>Send LZ message"| C[LayerZero<br/>Network]
    C -->|"3. Deliver message"| D[SEI Chain<br/>LZ Endpoint]
    D -->|"4. Mint SEI to<br/>Adapter"| E[MultichainDepositAdapter<br/>SEI Chain]
    E -->|"5. WSEI.deposit()<br/>with 1 SEI value"| F[WSEI Contract]
    F -->|"6. Mints 1 WSEI"| E
    E -->|"7. deposit(1 WSEI)"| G[WSEI Vault]
    G -->|"8. Mint shares to<br/>user on SEI"| H[User receives<br/>vault shares]

    style H fill:#90EE90
```

## Manual Operations

### Query Failed Deposits

```solidity
// Get failed deposits needing manual intervention
uint256[] memory failed = adapter.getFailedDeposits(startId, limit);

// Get specific deposit details
DepositRecord memory record = adapter.getDepositRecord(depositId);
```

### Manual Refund

```solidity
// Single refund (operator only)
adapter.manualRefund(depositId);

// Batch refund
uint256[] memory depositIds = [1, 5, 7, 12];
adapter.batchManualRefund(depositIds);
```

### Quote Refund Fee

```solidity
// Check how much ETH needed for refund
uint256 nativeFee = adapter.quoteRefundFee(depositId);

// Deposit ETH to cover refund gas
adapter.depositRefundGas{value: 1 ether}();
```

## Integration Guide

### For Users (via SDK)

```typescript
// 1. Build zap calls based on desired conversion
const zapCalls = buildZapCalls(tokenIn, vaultAsset, amount);

// 2. Encode compose message
const composeMsg = ethers.AbiCoder.defaultAbiCoder().encode(
  ['address', 'address', 'tuple(address,uint256,bytes)[]'],
  [vaultAddress, receiverAddress, zapCalls]
);

// 3. Send via OFT
const sendParam = {
  dstEid: SEI_CHAIN_ID,
  to: adapterAddress,
  amountLD: amount,
  minAmountLD: amountWithSlippage,
  extraOptions: buildOptions(),
  composeMsg: composeMsg,
  oftCmd: '0x'
};

await oft.send(sendParam, fee, refundAddress, { value: nativeFee });
```

### For Operators

1. **Monitor Deposits**: Track deposit records and watch for failed statuses
2. **Maintain Gas Reserve**: Keep ETH in adapter for refunds via `depositRefundGas()`
3. **Handle Failed Deposits**: Use `batchManualRefund()` for stuck deposits
4. **Vault Management**: Whitelist new vaults via `setSupportedVault()`
5. **OFT Management**: Whitelist OFT contracts via `setSupportedOFT()`

## Key Contracts

- **MultichainDepositAdapter**: Main adapter contract (upgradeable)
  - Location: `src/MultichainDepositAdapter.sol`
  - Implements: `IOAppComposer`, `IMultichainDepositAdapter`

- **IMultichainDepositAdapter**: Interface
  - Location: `src/interfaces/IMultichainDepositAdapter.sol`

- **CrossChainDeposit_SEI_WSEI**: Example deployment script
  - Location: `script/CrossChainDeposit_SEI_WSEI.s.sol`

## Advantages

1. **Flexibility**: Support any token conversion via zap calls
2. **User Experience**: Single transaction from source chain
3. **Gas Efficiency**: Batch operations on destination
4. **Reliability**: Automatic refunds on failure
5. **Extensibility**: Easy to add new chains/vaults
6. **Auditability**: Complete deposit tracking
7. **Safety**: Multiple layers of error handling
