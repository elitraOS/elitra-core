# Scripts Directory

Utility scripts for the Elitra project.

## Available Scripts

### `build-sdk.sh`

Builds the TypeScript SDK by:
1. Building contracts with Forge
2. Extracting ABIs from compiled contracts
3. Building the SDK with tsup

**Usage:**
```bash
bash scripts/build-sdk.sh
```

**Requirements:**
- forge (Foundry)
- jq (JSON processor)
- npm

**Output:**
- `pkg/sdk/src/abis/ElitraVault.json` - Vault ABI
- `pkg/sdk/src/abis/ERC20.json` - ERC20 ABI
- `pkg/sdk/dist/*` - Built SDK files

## Related Scripts

### Deployment Scripts (in `dev-scripts/`)

- `deploy.sh` - Deploy vault for an asset
- `deploy-hook.sh` - Deploy hooks for a vault
- `setup-auth.sh` - Configure vault permissions

See `dev-scripts/README.md` for details.

## Adding New Scripts

When adding new scripts:

1. Create the script in this directory
2. Make it executable: `chmod +x scripts/your-script.sh`
3. Add usage instructions to this README
4. Use consistent error handling (set -e)
5. Add helpful output messages
