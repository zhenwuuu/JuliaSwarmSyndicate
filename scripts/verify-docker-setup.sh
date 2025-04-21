#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Verifying Docker setup for JuliaOS...${NC}"

# Check if required files exist
echo -e "${BLUE}Checking for required files...${NC}"

# Check for Julia server file
if [ ! -f "julia/server/julia_server.jl" ]; then
  echo -e "${RED}Error: julia_server.jl not found at julia/server/julia_server.jl${NC}"
  
  # Check if it's in a different location
  JULIA_SERVER_FILES=$(find julia -name "julia_server.jl")
  if [ -n "$JULIA_SERVER_FILES" ]; then
    echo -e "${YELLOW}Found julia_server.jl in alternative location(s):${NC}"
    echo "$JULIA_SERVER_FILES"
    echo -e "${YELLOW}Please update docker-compose.yml to use the correct path.${NC}"
  else
    echo -e "${RED}No julia_server.jl file found in the julia directory.${NC}"
  fi
  
  exit 1
else
  echo -e "${GREEN}✓ julia_server.jl found at julia/server/julia_server.jl${NC}"
fi

# Check for CLI file
if [ ! -f "packages/cli/src/interactive.cjs" ]; then
  echo -e "${RED}Error: interactive.cjs not found at packages/cli/src/interactive.cjs${NC}"
  
  # Check if it's in a different location
  CLI_FILES=$(find . -name "interactive.cjs")
  if [ -n "$CLI_FILES" ]; then
    echo -e "${YELLOW}Found interactive.cjs in alternative location(s):${NC}"
    echo "$CLI_FILES"
    echo -e "${YELLOW}Please update docker-compose.yml to use the correct path.${NC}"
  else
    echo -e "${RED}No interactive.cjs file found in the repository.${NC}"
  fi
  
  exit 1
else
  echo -e "${GREEN}✓ interactive.cjs found at packages/cli/src/interactive.cjs${NC}"
fi

# Check for mock server file
if [ ! -f "packages/cli/src/mock_server.js" ]; then
  echo -e "${YELLOW}Warning: mock_server.js not found at packages/cli/src/mock_server.js${NC}"
  
  # Check if it's in a different location
  MOCK_FILES=$(find . -name "mock_server.js")
  if [ -n "$MOCK_FILES" ]; then
    echo -e "${YELLOW}Found mock_server.js in alternative location(s):${NC}"
    echo "$MOCK_FILES"
    echo -e "${YELLOW}Please update docker-entrypoint.sh to use the correct path.${NC}"
  else
    echo -e "${YELLOW}No mock_server.js file found in the repository. Fallback to mock server will not work.${NC}"
  fi
else
  echo -e "${GREEN}✓ mock_server.js found at packages/cli/src/mock_server.js${NC}"
fi

# Check Docker and Docker Compose
echo -e "${BLUE}Checking Docker and Docker Compose...${NC}"

if ! command -v docker &> /dev/null; then
  echo -e "${RED}Error: Docker is not installed or not in PATH.${NC}"
  exit 1
else
  echo -e "${GREEN}✓ Docker is installed${NC}"
fi

if docker compose version &> /dev/null; then
  echo -e "${GREEN}✓ Docker Compose V2 is installed${NC}"
elif command -v docker-compose &> /dev/null; then
  echo -e "${YELLOW}Warning: Using legacy docker-compose. Consider upgrading to Docker Compose V2.${NC}"
else
  echo -e "${RED}Error: Docker Compose is not installed or not in PATH.${NC}"
  exit 1
fi

echo -e "${GREEN}Docker setup verification completed successfully!${NC}"
echo -e "${BLUE}You can now run JuliaOS with Docker using:${NC}"
echo -e "${GREEN}./run-juliaos.sh${NC}"
echo -e "${BLUE}or for more control:${NC}"
echo -e "${GREEN}./scripts/run-docker.sh build${NC}"
echo -e "${GREEN}./scripts/run-docker.sh start${NC}"
