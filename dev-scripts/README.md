# Elitra Vault Development Scripts

This directory contains deployment and configuration scripts for the Elitra Vault system.

## Prerequisites

1. Source your environment variables:
   ```bash
   source env.sei.sh
   ```
   This will load your private key from `~/.keys/sei-mainnet.sh` and set up RPC URLs.

2. Ensure you have the required config files in `config/sei/`:
   - `authority.sh` - RolesAuthority address
   - `wsei.sh` - WSEI vault addresses
   - `usdc.sh` - USDC vault addresses

## Available Scripts

### 1. `deploy-authority.sh` - Deploy RolesAuthority (First Step!)

**Deploy this FIRST before deploying any vaults!**

Deploys the RolesAuthority contract that manages permissions for all vaults.

```bash
bash dev-scripts/deploy-authority.sh
```

**What it does:**
- Deploys RolesAuthority contract
- Sets the owner (defaults to deployer)
- Verifies contract on BlockScout

**After deployment:**
1. Copy the RolesAuthority address from the output
2. Update `config/sei/authority.sh`:
   ```bash
   export AUTHORITY_ADDRESS=0x...
   ```
3. Now you can deploy vaults

**Important:** You only need to deploy RolesAuthority ONCE. All vaults can share the same authority contract.

### 2. `deploy.sh` - Deploy Vault

Deploys a new Elitra Vault for a specific asset.

```bash
bash dev-scripts/deploy.sh [asset]
```

**Examples:**
```bash
# Deploy WSEI vault
bash dev-scripts/deploy.sh wsei

# Deploy USDC vault
bash dev-scripts/deploy.sh usdc
```

**What it does:**
- Deploys ElitraVault implementation
- Deploys ManualBalanceUpdateHook (Oracle)
- Deploys HybridRedemptionHook (Redemption)
- Deploys TransparentUpgradeableProxy
- Verifies all contracts on BlockScout

**After deployment:**
1. Copy the deployed addresses from the output
2. Update `config/sei/[asset].sh` with the new addresses
3. Run setup-auth.sh to configure permissions

### 2. `deploy-hook.sh` - Deploy Hooks

Deploys individual hooks or all hooks for a vault.

```bash
bash dev-scripts/deploy-hook.sh [asset] [hook_type]
```

**Hook types:**
- `oracle` - Deploy ManualBalanceUpdateHook only
- `redemption` - Deploy HybridRedemptionHook only
- `all` - Deploy all hooks (default)

**Examples:**
```bash
# Deploy all hooks for WSEI vault
bash dev-scripts/deploy-hook.sh wsei all

# Deploy only oracle hook for USDC vault
bash dev-scripts/deploy-hook.sh usdc oracle

# Deploy only redemption hook
bash dev-scripts/deploy-hook.sh wsei redemption
```

**After deployment:**
1. Copy the hook addresses from the output
2. Update `config/sei/[asset].sh` with the hook addresses
3. Run setup-auth.sh to configure permissions

### 3. `setup-auth.sh` - Configure Vault

Sets up roles and permissions for the vault and hooks.

```bash
bash dev-scripts/setup-auth.sh [asset]
```

**Examples:**
```bash
# Setup auth for WSEI vault
bash dev-scripts/setup-auth.sh wsei

# Switch to USDC vault configuration
bash dev-scripts/setup-auth.sh usdc
```

**What it does:**
- Configures role-based access control
- Sets up hook permissions
- Links hooks to the vault
- Configures ERC20 approvals

**Requirements:**
- Vault must be deployed first
- Hook addresses must be set in config file

## Configuration Files

### Authority Config (`config/sei/authority.sh`)

Stores the shared RolesAuthority address:

```bash
export AUTHORITY_ADDRESS=0x...
```

### Asset Configs (`config/sei/[asset].sh`)

Each asset has its own config file with vault and hook addresses:

```bash
export VAULT_ADDRESS=0x...
export ORACLE_HOOK_ADDRESS=0x...
export REDEMPTION_HOOK_ADDRESS=0x...
```

## Complete Deployment Workflow

### Fresh Deployment (First Time Setup)

1. **Source environment:**
   ```bash
   source env.sei.sh
   ```

2. **Deploy RolesAuthority (FIRST!):**
   ```bash
   bash dev-scripts/deploy-authority.sh
   ```

3. **Update authority config:**
   Edit `config/sei/authority.sh` with the deployed RolesAuthority address:
   ```bash
   export AUTHORITY_ADDRESS=0x1234...
   ```

4. **Deploy vault:**
   ```bash
   bash dev-scripts/deploy.sh wsei
   ```

5. **Update asset config:**
   Edit `config/sei/wsei.sh` with deployed addresses

6. **Setup authorization:**
   ```bash
   bash dev-scripts/setup-auth.sh wsei
   ```

### Deploy Only Hooks

If you need to redeploy hooks for an existing vault:

1. **Deploy hooks:**
   ```bash
   bash dev-scripts/deploy-hook.sh wsei all
   ```

2. **Update config:**
   Edit `config/sei/wsei.sh` with new hook addresses

3. **Setup authorization:**
   ```bash
   bash dev-scripts/setup-auth.sh wsei
   ```

### Switch Between Vaults

To switch your working context between different vaults:

```bash
# Work with WSEI vault
bash dev-scripts/setup-auth.sh wsei

# Work with USDC vault
bash dev-scripts/setup-auth.sh usdc
```

## Environment Variables

The scripts rely on these environment variables (set in `env.sei.sh`):

- `PRIVATE_KEY` - Deployer private key (from `~/.keys/sei-mainnet.sh`)
- `DEPLOYER_ADDRESS` - Deployer account address
- `RPC_URL` - SEI network RPC endpoint
- `VERIFIER_URL` - BlockScout verifier URL
- `ETHERSCAN_API_KEY` - Optional, defaults to "verify"

## Troubleshooting

### "PRIVATE_KEY not set"
Make sure you've sourced the environment file:
```bash
source env.sei.sh
```

### "No RolesAuthority deployed"
Deploy the authority first:
```bash
bash dev-scripts/deploy-authority.sh
# Then update config/sei/authority.sh with the address
```

### "VAULT_ADDRESS not set"
Update the config file with your deployed vault address:
```bash
vim config/sei/wsei.sh
```

### "Asset config file not found"
Create a config file for your asset:
```bash
cp config/sei/wsei.sh config/sei/myasset.sh
```

### Script not executable
Make scripts executable:
```bash
chmod +x dev-scripts/*.sh
```

### Authority vs Multiple Vaults
- Deploy RolesAuthority **ONCE**
- Use the same authority for **ALL** vaults
- Each vault can have different permissions configured via roles

## Notes

- All scripts use `set -e` to exit on errors
- Contracts are automatically verified on BlockScout
- Use `-vvvv` flag for detailed forge output
- Config files prevent accidental deployments to wrong addresses
