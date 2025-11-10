# Elitra Deployment Flow

Visual guide to deploying the Elitra Vault system.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RolesAuthority                           │
│  (Deploy ONCE - Manages permissions for ALL vaults)         │
└────────────┬─────────────────────────────────┬──────────────┘
             │                                 │
             │                                 │
    ┌────────▼──────────┐            ┌────────▼──────────┐
    │   WSEI Vault      │            │   USDC Vault      │
    │   ┌──────────┐    │            │   ┌──────────┐    │
    │   │ Vault    │    │            │   │ Vault    │    │
    │   │ Proxy    │    │            │   │ Proxy    │    │
    │   └────┬─────┘    │            │   └────┬─────┘    │
    │        │          │            │        │          │
    │   ┌────▼─────┐    │            │   ┌────▼─────┐    │
    │   │Oracle    │    │            │   │Oracle    │    │
    │   │Hook      │    │            │   │Hook      │    │
    │   └──────────┘    │            │   └──────────┘    │
    │   ┌──────────┐    │            │   ┌──────────┐    │
    │   │Redemption│    │            │   │Redemption│    │
    │   │Hook      │    │            │   │Hook      │    │
    │   └──────────┘    │            │   └──────────┘    │
    └───────────────────┘            └───────────────────┘
```

## Step-by-Step Deployment

### Step 1: Deploy RolesAuthority (ONCE!)

```bash
# Deploy authority contract
bash dev-scripts/deploy-authority.sh

# Save address to config
echo "export AUTHORITY_ADDRESS=0x..." > config/sei/authority.sh
```

**Result:** One RolesAuthority contract that controls permissions for all vaults.

### Step 2: Deploy First Vault (e.g., WSEI)

```bash
# Deploy vault
bash dev-scripts/deploy.sh wsei

# Update config with deployed addresses
vim config/sei/wsei.sh
```

**What gets deployed:**
- ElitraVault Implementation
- TransparentUpgradeableProxy
- ManualBalanceUpdateHook (Oracle)
- HybridRedemptionHook (Redemption)

### Step 3: Configure Permissions

```bash
# Setup roles and permissions
bash dev-scripts/setup-auth.sh wsei
```

**What happens:**
- Vault links to RolesAuthority
- Roles configured for vault operations
- Hooks get necessary permissions
- Vault can execute manage() calls

### Step 4: Deploy Additional Vaults (Optional)

```bash
# Deploy USDC vault (uses SAME authority!)
bash dev-scripts/deploy.sh usdc

# Update config
vim config/sei/usdc.sh

# Configure permissions
bash dev-scripts/setup-auth.sh usdc
```

## Configuration Files

```
config/sei/
├── authority.sh      # RolesAuthority address (shared by all vaults)
├── wsei.sh          # WSEI vault addresses
├── usdc.sh          # USDC vault addresses
└── [asset].sh       # More assets...
```

### authority.sh
```bash
export AUTHORITY_ADDRESS=0x1234...
```

### wsei.sh
```bash
export VAULT_ADDRESS=0xabcd...
export ORACLE_HOOK_ADDRESS=0xef01...
export REDEMPTION_HOOK_ADDRESS=0x2345...
```

## Quick Reference

### Deploy Everything Fresh

```bash
# 1. Setup
source env.sei.sh

# 2. Deploy authority (ONCE)
bash dev-scripts/deploy-authority.sh
# -> Update config/sei/authority.sh

# 3. Deploy vaults (as many as needed)
bash dev-scripts/deploy.sh wsei
# -> Update config/sei/wsei.sh

bash dev-scripts/deploy.sh usdc
# -> Update config/sei/usdc.sh

# 4. Configure each vault
bash dev-scripts/setup-auth.sh wsei
bash dev-scripts/setup-auth.sh usdc
```

### Add New Vault to Existing System

```bash
# Authority already exists, just deploy new vault
source env.sei.sh
bash dev-scripts/deploy.sh mytoken
# -> Update config/sei/mytoken.sh
bash dev-scripts/setup-auth.sh mytoken
```

### Redeploy Hooks

```bash
# If you need to upgrade hooks for a vault
bash dev-scripts/deploy-hook.sh wsei all
# -> Update config/sei/wsei.sh
bash dev-scripts/setup-auth.sh wsei
```

## Permission Model

```
RolesAuthority
├── Owner (full control)
├── Role 0: Vault Manager
│   ├── Can call manage()
│   ├── Can updateBalance()
│   └── Can pause/unpause
├── Role 1: Oracle
│   └── Can updateBalance()
├── Role 2: Keeper
│   ├── Can fulfillRedeem()
│   └── Can cancelRedeem()
└── Role N: Custom roles...
```

## Common Patterns

### Single Vault Deployment
```bash
deploy-authority.sh → deploy.sh → setup-auth.sh
```

### Multi-Vault Deployment
```bash
deploy-authority.sh (once)
  ↓
deploy.sh wsei → setup-auth.sh wsei
  ↓
deploy.sh usdc → setup-auth.sh usdc
  ↓
deploy.sh dai → setup-auth.sh dai
```

### Upgrade Hook
```bash
deploy-hook.sh wsei oracle → setup-auth.sh wsei
```

## Important Notes

1. **RolesAuthority is shared**: Deploy once, use for all vaults
2. **Each vault has its own hooks**: Hooks are vault-specific
3. **Config files**: Keep them updated after each deployment
4. **Verification**: All contracts auto-verify on BlockScout
5. **Order matters**: Authority → Vault → Setup
6. **Testing**: Test on testnet first!

## Verification

After deployment, verify:

```bash
# Check authority is set
cast call $VAULT_ADDRESS "authority()" --rpc-url $RPC_URL

# Check owner
cast call $AUTHORITY_ADDRESS "owner()" --rpc-url $RPC_URL

# Check vault works
cast call $VAULT_ADDRESS "totalAssets()" --rpc-url $RPC_URL
```

## Troubleshooting

**Problem:** Vault deployment fails with "authority not set"
**Solution:** Deploy authority first, update config/sei/authority.sh

**Problem:** Can't call manage() - unauthorized
**Solution:** Run setup-auth.sh to configure roles

**Problem:** Multiple vaults with different authorities
**Solution:** Use ONE authority for all vaults, configure different roles

## Security Checklist

- [ ] RolesAuthority owner is secure (multisig recommended)
- [ ] Each vault has correct hooks configured
- [ ] Roles properly assigned (principle of least privilege)
- [ ] Contracts verified on block explorer
- [ ] Config files backed up
- [ ] Test all operations before mainnet
- [ ] Emergency pause works (test on testnet)

## Next Steps

After successful deployment:

1. **Test deposits**: Use SDK or cast commands
2. **Configure strategies**: Use manage() to deploy to protocols
3. **Setup monitoring**: Track vault balances and APY
4. **Enable frontend**: Update frontend with vault addresses
5. **Documentation**: Document vault-specific configs
