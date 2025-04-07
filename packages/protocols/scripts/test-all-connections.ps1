# Navigate to the protocols package directory
cd $PSScriptRoot/..

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..."
    npm install --legacy-peer-deps
}

# Run the comprehensive connection test
Write-Host "Running comprehensive connection tests..."
npx ts-node src/dex/test-all-connections.ts 