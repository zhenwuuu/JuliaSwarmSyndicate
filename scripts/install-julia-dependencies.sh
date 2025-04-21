#!/bin/bash

# Install Julia dependencies for JuliaOS
# This script installs all the required Julia packages for JuliaOS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find Julia executable
find_julia_executable() {
  # Check common paths based on OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    for path in "/Applications/Julia-1.9.app/Contents/Resources/julia/bin/julia" "/usr/local/bin/julia" "/opt/homebrew/bin/julia"; do
      if [ -x "$path" ]; then
        echo "$path"
        return 0
      fi
    done
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    for path in "/usr/bin/julia" "/usr/local/bin/julia"; do
      if [ -x "$path" ]; then
        echo "$path"
        return 0
      fi
    done
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows
    for path in "C:\\Program Files\\Julia\\bin\\julia.exe" "C:\\Program Files (x86)\\Julia\\bin\\julia.exe"; do
      if [ -x "$path" ]; then
        echo "$path"
        return 0
      fi
    done
  fi

  # Check if Julia is in PATH
  if command -v julia &> /dev/null; then
    echo "julia"
    return 0
  fi

  echo ""
  return 1
}

# Install Julia packages
install_julia_packages() {
  echo -e "${BLUE}Installing Julia packages...${NC}"
  
  # Find Julia executable
  JULIA_PATH=$(find_julia_executable)
  if [ -z "$JULIA_PATH" ]; then
    echo -e "${RED}Error: Julia executable not found${NC}"
    return 1
  fi
  echo -e "${GREEN}Using Julia executable: $JULIA_PATH${NC}"
  
  # Create a temporary Julia script to install packages
  TEMP_SCRIPT=$(mktemp)
  cat > $TEMP_SCRIPT << EOF
using Pkg

# List of packages to install
packages = [
    "JSON",
    "HTTP",
    "Dates",
    "Statistics",
    "Random",
    "DataFrames",
    "Distributions",
    "LinearAlgebra",
    "WebSockets",
    "Plots",
    "Logging",
    "MarketData",
    "TimeSeries",
    "Sockets",
    "UUIDs",
    "MbedTLS"
]

# Install packages
for pkg in packages
    println("Installing \$pkg...")
    try
        Pkg.add(pkg)
    catch e
        println("Error installing \$pkg: \$e")
    end
end

# Precompile packages
println("Precompiling packages...")
Pkg.precompile()

println("Package installation complete!")
EOF
  
  # Run the Julia script
  echo -e "${BLUE}Running Julia package installation script...${NC}"
  $JULIA_PATH $TEMP_SCRIPT
  
  # Clean up
  rm $TEMP_SCRIPT
  
  echo -e "${GREEN}Julia packages installed successfully${NC}"
  return 0
}

# Main function
main() {
  echo -e "${BLUE}Installing Julia dependencies for JuliaOS...${NC}"
  
  # Install Julia packages
  install_julia_packages
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install Julia packages. Exiting.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}All dependencies installed successfully!${NC}"
  exit 0
}

# Run the main function
main
