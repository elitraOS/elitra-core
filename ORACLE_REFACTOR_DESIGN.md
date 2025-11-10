# Pull-Based Oracle Adapter Refactor

## Overview
Refactor oracle adapter from push-based to pull-based model to match the redemption strategy pattern.

## Current Architecture (Push-Based)

```solidity
// Off-chain keeper calls oracle adapter
oracleAdapter.updateVaultBalance(vault, newBalance)
  ├─ Validates block number
  ├─ Reads vault state
  ├─ Calculates new PPS
  ├─ Checks threshold
  └─ PUSHES update: vault.setAggregatedBalance()

// Vault trusts oracle adapter
function setAggregatedBalance(uint256 newBalance, uint256 newPPS) external {
    require(msg.sender == address(oracleAdapter), ...);
    aggregatedUnderlyingBalances = newBalance;
    lastPricePerShare = newPPS;
}
```

**Issues:**
- Inconsistent with redemption strategy (pull-based)
- Oracle has write permission to vault
- Vault must trust oracle to calculate PPS correctly

## Proposed Architecture (Pull-Based)

```solidity
// Anyone can call vault to update (permissionless trigger)
vault.updateBalance(newAggregatedBalance)
  ├─ Validates block number
  ├─ PULLS calculation from oracle: (newPPS, shouldPause) = oracleAdapter.validateUpdate()
  ├─ If shouldPause: pause vault
  ├─ Updates own state: aggregatedUnderlyingBalances = newBalance
  └─ Emits event

// Oracle adapter is pure calculation (no write access to vault)
function validateUpdate(
    uint256 currentPPS,
    uint256 totalSupply,
    uint256 idleAssets,
    uint256 newAggregatedBalance
) external view returns (uint256 newPPS, bool shouldPause) {
    // Pure calculation - no state changes
    uint256 totalAssets = idleAssets + newAggregatedBalance;
    newPPS = totalAssets * DENOMINATOR / totalSupply;

    uint256 percentageChange = calculateChange(currentPPS, newPPS);
    shouldPause = percentageChange > maxPercentageChange;
}
```

**Benefits:**
- ✅ Consistent with redemption strategy pattern
- ✅ Oracle has no write permissions (safer)
- ✅ Vault controls its own state updates
- ✅ Permissionless trigger (anyone can call vault.updateBalance)
- ✅ Oracle becomes pure calculation helper

## Implementation Changes

### 1. New IOracleAdapter Interface

```solidity
interface IOracleAdapter {
    /// @notice Calculate new PPS and validate if update should proceed
    /// @param currentPPS Current price per share
    /// @param totalSupply Total vault shares
    /// @param idleAssets Idle assets in vault
    /// @param newAggregatedBalance New aggregated balance from strategies
    /// @return newPPS Calculated new price per share
    /// @return shouldPause Whether vault should pause due to threshold breach
    function validateUpdate(
        uint256 currentPPS,
        uint256 totalSupply,
        uint256 idleAssets,
        uint256 newAggregatedBalance
    ) external view returns (uint256 newPPS, bool shouldPause);

    /// @notice Update max percentage change threshold
    function updateMaxPercentageChange(uint256 newThreshold) external;

    /// @notice Get current max percentage threshold
    function maxPercentageChange() external view returns (uint256);
}
```

### 2. Updated Vault Oracle Integration

```solidity
// In ElitraVault.sol

/// @notice Update vault balance by pulling calculation from oracle adapter
/// @param newAggregatedBalance New aggregated balance from off-chain strategies
function updateBalance(uint256 newAggregatedBalance) external requiresAuth {
    // 1. Validate not already updated this block
    require(block.number > lastBlockUpdated, Errors.UpdateAlreadyCompletedInThisBlock());

    // 2. Pull calculation from oracle adapter (read-only)
    (uint256 newPPS, bool shouldPause) = oracleAdapter.validateUpdate(
        lastPricePerShare,
        totalSupply(),
        IERC20(asset()).balanceOf(address(this)),
        newAggregatedBalance
    );

    // 3. Check if should pause
    if (shouldPause) {
        _pause();
        emit VaultPausedDueToThreshold(lastPricePerShare, newPPS);
        return;
    }

    // 4. Update own state
    emit UnderlyingBalanceUpdated(aggregatedUnderlyingBalances, newAggregatedBalance);
    aggregatedUnderlyingBalances = newAggregatedBalance;
    lastPricePerShare = newPPS;
    lastBlockUpdated = block.number;
}

// Remove old setAggregatedBalance() - no longer needed
```

### 3. Refactored ManualOracleAdapter

```solidity
contract ManualOracleAdapter is IOracleAdapter, Auth {
    uint256 public maxPercentageChange;
    uint256 constant DENOMINATOR = 1e18;

    constructor(address _owner) Auth(_owner, Authority(address(0))) {
        maxPercentageChange = 1e16; // 1% default
    }

    /// @inheritdoc IOracleAdapter
    function validateUpdate(
        uint256 currentPPS,
        uint256 totalSupply,
        uint256 idleAssets,
        uint256 newAggregatedBalance
    ) external view returns (uint256 newPPS, bool shouldPause) {
        // Pure calculation - no state changes
        uint256 totalAssets = idleAssets + newAggregatedBalance;

        if (totalSupply == 0) {
            newPPS = DENOMINATOR;
            shouldPause = false;
        } else {
            newPPS = totalAssets.mulDiv(DENOMINATOR, totalSupply, Math.Rounding.Floor);
            uint256 percentageChange = _calculatePercentageChange(currentPPS, newPPS);
            shouldPause = percentageChange > maxPercentageChange;
        }
    }

    /// @inheritdoc IOracleAdapter
    function updateMaxPercentageChange(uint256 newThreshold) external requiresAuth {
        require(newThreshold < MAX_PERCENTAGE_THRESHOLD, Errors.InvalidMaxPercentage());
        emit MaxPercentageUpdated(maxPercentageChange, newThreshold);
        maxPercentageChange = newThreshold;
    }

    function _calculatePercentageChange(uint256 oldPrice, uint256 newPrice)
        private pure returns (uint256)
    {
        if (oldPrice == 0) return 0;
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return diff.mulDiv(DENOMINATOR, oldPrice, Math.Rounding.Ceil);
    }
}
```

## Call Flow Comparison

### Before (Push):
```
Keeper → ManualOracleAdapter.updateVaultBalance(vault, 1000000)
         ├─ Reads vault state
         ├─ Calculates newPPS = 1.05e18
         ├─ Checks: 5% change > 1% threshold
         └─ Returns false (doesn't push update)

Keeper sees false → manually pauses vault
```

### After (Pull):
```
Keeper → ElitraVault.updateBalance(1000000)
         ├─ Calls: oracleAdapter.validateUpdate(1e18, 1000, 500, 1000000)
         ├─ Oracle returns: (newPPS=1.05e18, shouldPause=true)
         ├─ Vault auto-pauses itself
         └─ Emits VaultPausedDueToThreshold event
```

## Migration Path

1. Deploy new IOracleAdapter interface
2. Deploy updated ManualOracleAdapter
3. Update ElitraVault with new updateBalance() function
4. Remove old setAggregatedBalance() function
5. Update off-chain keeper to call vault.updateBalance() instead
6. Update tests

## Security Considerations

**Improved:**
- Oracle adapter has no write access to vault state
- Vault controls when and how updates happen
- Permissionless trigger (anyone can propose update)

**New Considerations:**
- updateBalance() needs auth (only trusted keeper can call)
- Or make it permissionless but charge gas token to prevent spam

## Open Questions

1. Should updateBalance() be permissionless or require auth?
   - Permissionless: Anyone can trigger update (more decentralized)
   - requiresAuth: Only keeper can trigger (prevents spam)

2. Should we keep auto-pause or return shouldPause to caller?
   - Auto-pause: Vault handles it automatically (simpler)
   - Return bool: Caller decides what to do (more flexible)

My recommendation: Keep requiresAuth and auto-pause for simplicity and safety.
