# Navigate to the protocols package directory
cd $PSScriptRoot/..

# Install dependencies if needed
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..."
    npm install
}

# Run the connection test
Write-Host "Running connection test..."
npx ts-node src/dex/test-connection.ts 