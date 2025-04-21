#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting JuliaOS in Docker...${NC}"

# Run verification script
if [ -f "./scripts/verify-docker-setup.sh" ]; then
    echo -e "${BLUE}Verifying Docker setup...${NC}"
    ./scripts/verify-docker-setup.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Docker setup verification failed. Please fix the issues and try again.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: Verification script not found. Skipping verification.${NC}"

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker and try again.${NC}"
        exit 1
    fi

    # Check if Docker Compose is available
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose and try again.${NC}"
        exit 1
    fi
fi

# Set compose command if not already set
if [ -z "$COMPOSE_CMD" ]; then
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
fi

# Build and start JuliaOS
echo -e "${BLUE}Building and starting JuliaOS...${NC}"
echo -e "${YELLOW}This may take a few minutes on the first run as it downloads and builds the Docker images.${NC}"
$COMPOSE_CMD up --build

echo -e "${GREEN}JuliaOS has been stopped.${NC}"
