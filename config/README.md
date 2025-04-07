# Configuration Directory

This directory contains configuration files for the JuliaOS Framework.

## Files

- `default.env` - Default environment variables template
- `tsconfig.base.json` - Base TypeScript configuration
- `hardhat.config.js` - Hardhat configuration for contract development

## Environment Configuration

For development, copy the default.env to your project root:

```bash
cp config/default.env .env
```

Then edit the `.env` file with your specific settings:

```env
# API keys
INFURA_API_KEY=your-infura-key
ALCHEMY_API_KEY=your-alchemy-key

# Private keys (never commit these to version control)
PRIVATE_KEY=your-private-key

# Network RPC URLs
BASE_RPC_URL=https://sepolia.base.org
SOLANA_RPC_URL=https://api.devnet.solana.com

# Feature flags
ENABLE_SWARM=true
ENABLE_MONITORING=true
```

## TypeScript Configuration

To use the base TypeScript configuration in a package:

```json
{
  "extends": "../../config/tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"]
}
``` 