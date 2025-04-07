# Navigate to the protocols package directory
cd $PSScriptRoot/..

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..."
    npm install --legacy-peer-deps
}

# Run the Raydium integration test
Write-Host "Running Raydium integration test..."
npx ts-node src/dex/test-raydium.ts 