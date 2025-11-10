# Development Guide

## Setup

1. **Install dependencies:**
   ```bash
   cd pkg/sdk
   npm install
   ```

2. **Generate ABIs:**
   ```bash
   # From project root
   forge build
   cat out/ElitraVault.sol/ElitraVault.json | jq -r '.abi' > pkg/sdk/src/abis/ElitraVault.json
   ```

## Development Workflow

### Build

```bash
npm run build
```

This generates:
- `dist/index.js` - CommonJS bundle
- `dist/index.mjs` - ES Module bundle
- `dist/index.d.ts` - TypeScript declarations

### Watch Mode

For active development:
```bash
npm run dev
```

### Type Checking

```bash
npm run typecheck
```

## Project Structure

```
pkg/sdk/
├── src/
│   ├── index.ts          # Main entry point, exports
│   ├── types.ts          # TypeScript type definitions
│   ├── client.ts         # ElitraClient implementation
│   ├── utils.ts          # Utility functions
│   └── abis/             # Contract ABIs (generated)
│       ├── ElitraVault.json
│       └── ERC20.json
├── examples/
│   └── basic-usage.ts    # Usage examples
├── package.json
├── tsconfig.json
└── README.md
```

## Testing Locally

### Link for Local Testing

```bash
# In pkg/sdk
npm link

# In your test project
npm link @elitra/sdk
```

### Test with Examples

```bash
# Update examples/basic-usage.ts with your config
# Then run with ts-node
npx ts-node examples/basic-usage.ts
```

## Publishing

1. **Update version:**
   ```bash
   npm version patch|minor|major
   ```

2. **Build:**
   ```bash
   npm run build
   ```

3. **Publish:**
   ```bash
   npm publish
   ```

## Updating ABIs

When contracts are updated:

```bash
# From project root
forge build

# Extract ABIs
cat out/ElitraVault.sol/ElitraVault.json | jq -r '.abi' > pkg/sdk/src/abis/ElitraVault.json
cat out/ERC20.sol/ERC20.json | jq -r '.abi' > pkg/sdk/src/abis/ERC20.json

# Rebuild SDK
cd pkg/sdk
npm run build
```

## Code Style

- Use TypeScript strict mode
- Follow existing code style
- Add JSDoc comments for public APIs
- Export types for all public interfaces

## Adding New Features

1. **Add types** in `src/types.ts`
2. **Implement methods** in `src/client.ts`
3. **Add utilities** in `src/utils.ts` if needed
4. **Export** from `src/index.ts`
5. **Document** in README.md
6. **Update** CHANGELOG.md

## Example: Adding a New Method

```typescript
// 1. Add types (types.ts)
export interface NewFeatureResult {
  hash: Hash;
  data: string;
}

// 2. Implement in client (client.ts)
export class ElitraClient {
  // ...
  async newFeature(param: bigint): Promise<NewFeatureResult> {
    // Implementation
  }
}

// 3. Export (index.ts)
export type { NewFeatureResult } from './types';

// 4. Document in README.md
```

## Dependencies

### Peer Dependencies
- `viem` ^2.0.0 - Required by consumers

### Dev Dependencies
- `typescript` ^5.0.0 - TypeScript compiler
- `tsup` ^8.0.0 - Bundler
- `@types/node` ^20.0.0 - Node.js types

## Troubleshooting

### "Module not found"
- Ensure you've run `npm install`
- Check that imports use correct paths
- Verify tsconfig.json paths are correct

### "ABI not found"
- Run `forge build` in project root
- Extract ABIs using jq commands above
- Check that ABI files exist in `src/abis/`

### Type errors
- Run `npm run typecheck`
- Ensure viem is installed
- Check TypeScript version compatibility

## Best Practices

1. **Type Safety**: Always use proper TypeScript types
2. **Error Handling**: Provide clear error messages
3. **Documentation**: Keep JSDoc comments up to date
4. **Testing**: Test with real contracts before releasing
5. **Versioning**: Follow semantic versioning

## Release Checklist

- [ ] Update CHANGELOG.md
- [ ] Update version in package.json
- [ ] Rebuild ABIs if contracts changed
- [ ] Run `npm run build`
- [ ] Run `npm run typecheck`
- [ ] Test examples
- [ ] Update README.md if needed
- [ ] Commit changes
- [ ] Create git tag
- [ ] Push to repository
- [ ] Publish to npm
