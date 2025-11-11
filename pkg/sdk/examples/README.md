# Elitra SDK Examples

This directory contains example scripts demonstrating how to use the Elitra SDK.

## Setup

### 1. Install Dependencies

Make sure you're in the SDK directory and have installed dependencies:

```bash
cd pkg/sdk
npm install
```

### 2. Configure Environment Variables

The examples use environment variables for configuration. You have two options:

#### Option A: Using .env file (Recommended)

Copy the example environment file and fill in your values:

```bash
cd examples
cp .env.example .env
# Edit .env with your values
```

Then use a tool like `dotenv` to load the environment variables:

```bash
npm install -g dotenv-cli
dotenv -e .env -- npx tsx setup.ts
```

#### Option B: Export from Shell

You can source the configuration from the project's config file:

```bash
# From the project root
source config/sei/wsei.sh
export PRIVATE_KEY=0x...  # Add your private key
```

Then run examples directly:

```bash
cd pkg/sdk/examples
npx tsx setup.ts
```

## Examples

### 1. setup.ts - Client Initialization

Learn how to set up the Elitra client with Viem.

```bash
npx tsx setup.ts
```

### 2. vault-state.ts - Reading Vault Information

View vault metrics including total assets, supply, price per share, and available balance.

```bash
npx tsx vault-state.ts
```

### 3. user-position.ts - Checking User Positions

Check your share balance, asset value, pending redemptions, and maximum actions.

```bash
npx tsx user-position.ts
```

### 4. deposit.ts - Depositing Assets

Deposit USDC into the vault to receive shares.

```bash
npx tsx deposit.ts
```

**Note:** You must approve USDC before depositing. See the example for details.

### 5. redeem.ts - Requesting Redemptions

Request to redeem shares for assets (instant or queued).

```bash
npx tsx redeem.ts
```

### 6. manage.ts - Vault Management

Use the manage function to interact with external contracts. This example demonstrates:
- How to use the `manage()` function
- Two-level authorization system (user role + target method authorization)
- How to handle authorization errors
- Commands to authorize target methods

**Requires:**
- User must have MANAGER_ROLE (role 0)
- Target method must be authorized via `setPublicCapability()`

```bash
npx tsx manage.ts
```

**Authorization Setup:**
The script will show you the exact commands needed to authorize target methods if the call fails.

### 7. strategy-management.ts - Protocol Integrations

Deploy vault funds into external yield protocols and manage strategies (requires manager role).

```bash
npx tsx strategy-management.ts
```

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `VAULT_ADDRESS` | Your Elitra Vault address | Yes | - |
| `PRIVATE_KEY` | Your private key (with 0x prefix) | Yes | - |
| `RPC_URL` | SEI RPC endpoint | No | `https://evm-rpc.sei-apis.com` |
| `AUTHORITY_ADDRESS` | RolesAuthority contract address | No | - |

**Note:** `AUTHORITY_ADDRESS` is only needed for the `manage.ts` example to display authorization commands.

## Authorization System

The Elitra Vault uses a two-level authorization system for the `manage()` function:

### Level 1: User Role (MANAGER_ROLE)

The user calling `manage()` must have the MANAGER_ROLE (role 0) assigned by the RolesAuthority contract.

**To assign MANAGER_ROLE:**
```bash
cast send $AUTHORITY_ADDRESS \
  "setUserRole(address,uint8,bool)" \
  $USER_ADDRESS 0 true \
  --private-key $OWNER_PRIVATE_KEY --rpc-url $RPC_URL
```

**To check if user has MANAGER_ROLE:**
```bash
cast call $AUTHORITY_ADDRESS \
  "doesUserHaveRole(address,uint8)" \
  $USER_ADDRESS 0 \
  --rpc-url $RPC_URL
```

### Level 2: Target Method Authorization

Each specific target contract method must be authorized via `setPublicCapability()`.

**When you call `manage(target, data, value)`:**
1. The vault extracts the function signature from `data` (first 4 bytes)
2. It checks if `authority.canCall(msg.sender, target, functionSig)` returns true
3. If not authorized, the transaction reverts with `TargetMethodNotAuthorized`

**To authorize a target method:**
```bash
cast send $AUTHORITY_ADDRESS \
  "setPublicCapability(address,bytes4,bool)" \
  $TARGET_CONTRACT \
  $FUNCTION_SIGNATURE \
  true \
  --private-key $OWNER_PRIVATE_KEY --rpc-url $RPC_URL
```

**Example - Authorizing ERC20 approve:**
```bash
# approve(address,uint256) function signature is 0x095ea7b3
cast send $AUTHORITY_ADDRESS \
  "setPublicCapability(address,bytes4,bool)" \
  0x1234... \  # Token address
  0x095ea7b3 \  # approve function signature
  true \
  --private-key $OWNER_PRIVATE_KEY --rpc-url $RPC_URL
```

### Why Two Levels?

This design provides defense-in-depth:
- **Role-based access** ensures only designated managers can use vault management functions
- **Method whitelisting** ensures managers can only call pre-approved methods on specific contracts
- This prevents a compromised manager key from draining the vault or calling arbitrary malicious contracts

The `manage.ts` example will automatically display the authorization commands you need if a call fails.

## Security Notes

- **Never commit your `.env` file** with real private keys to version control
- The `.env` file is already in `.gitignore`
- For production use, consider using a hardware wallet or secure key management system
- The `manage` functions require both MANAGER_ROLE and target method authorization (see Authorization System above)
- Regularly audit which methods are authorized using the RolesAuthority contract
- Consider using a multisig wallet as the vault owner for critical authorization changes

## Configuration Values

The default values in `.env.example` are taken from `config/sei/wsei.sh`:

- **VAULT_ADDRESS**: `0x397e97798D2b2BBe17FaD2228D84C200c9F0554D`
- **ASSET_ADDRESS** (WSEI): `0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7`
- **ROLES_AUTHORITY_ADDRESS**: `0x375D41F0eD1d4Cf891f2393725889D14Fbf59339`
- **ORACLE_HOOK_ADDRESS**: `0x156306C9Ef04Ef6d23071da4f763156D173dd56b`
- **REDEMPTION_HOOK_ADDRESS**: `0x17a51e5f38EA6008A50771Db0926468CC341bb5d`

## Troubleshooting

### "Missing required environment variables"

Make sure you've set `VAULT_ADDRESS` and `PRIVATE_KEY` in your environment:

```bash
export VAULT_ADDRESS=0x...
export PRIVATE_KEY=0x...
```

### "Cannot find module 'viem'"

Install dependencies from the SDK directory:

```bash
cd pkg/sdk
npm install
```

### "Insufficient allowance" when depositing

You need to approve USDC to the vault first. See the `deposit.ts` example for details.

### TypeScript errors about 'process'

This is expected in the IDE. The examples run fine with `tsx` which provides Node.js types.

## Next Steps

- Read the [Elitra SDK documentation](../README.md)
- Explore the [SDK source code](../src)
- Check out the [API reference](../docs/api.md)
