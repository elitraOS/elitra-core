#!/bin/bash

# Build SDK script - rebuilds contracts and SDK
# Usage: bash scripts/build-sdk.sh

set -e

echo "================================================================"
echo "Building Elitra SDK"
echo "================================================================"

# 1. Build contracts
echo ""
echo "Step 1/3: Building contracts..."
forge build

# 2. Extract ABIs
echo ""
echo "Step 2/3: Extracting ABIs..."
mkdir -p pkg/sdk/src/abis

if [ -f "out/ElitraVault.sol/ElitraVault.json" ]; then
    cat out/ElitraVault.sol/ElitraVault.json | jq -r '.abi' > pkg/sdk/src/abis/ElitraVault.json
    echo "✓ Extracted ElitraVault ABI"
else
    echo "✗ ElitraVault.json not found. Make sure forge build succeeded."
    exit 1
fi

if [ -f "out/ERC20.sol/ERC20.json" ]; then
    cat out/ERC20.sol/ERC20.json | jq -r '.abi' > pkg/sdk/src/abis/ERC20.json
    echo "✓ Extracted ERC20 ABI"
else
    echo "⚠ ERC20.json not found (optional)"
fi

# 3. Build SDK
echo ""
echo "Step 3/3: Building SDK..."
cd pkg/sdk

if [ ! -d "node_modules" ]; then
    echo "Installing SDK dependencies..."
    npm install
fi

npm run build

echo ""
echo "================================================================"
echo "SDK build complete!"
echo "================================================================"
echo ""
echo "Output:"
echo "  - dist/index.js      (CommonJS)"
echo "  - dist/index.mjs     (ES Module)"
echo "  - dist/index.d.ts    (TypeScript declarations)"
echo ""
echo "To test locally:"
echo "  cd pkg/sdk && npm link"
echo "  (in your project) npm link @elitra/sdk"
echo ""
echo "To publish:"
echo "  cd pkg/sdk"
echo "  npm version patch|minor|major"
echo "  npm publish"
echo "================================================================"
