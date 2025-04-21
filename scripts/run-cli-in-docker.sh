#!/bin/bash

# Run CLI in Docker
# This script builds and runs the JuliaOS CLI in Docker

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is installed
check_docker() {
  echo -e "${BLUE}Checking if Docker is installed...${NC}"
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker and try again.${NC}"
    return 1
  fi
  echo -e "${GREEN}Docker is installed.${NC}"
  return 0
}

# Build Docker image
build_docker_image() {
  echo -e "${BLUE}Building Docker image...${NC}"
  docker build -t juliaos .
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Docker image. Exiting.${NC}"
    return 1
  fi
  echo -e "${GREEN}Docker image built successfully.${NC}"
  return 0
}

# Run CLI in Docker
run_cli_in_docker() {
  echo -e "${BLUE}Running CLI in Docker...${NC}"
  docker run -it juliaos cli
  if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to run CLI in Docker. Exiting.${NC}"
    return 1
  fi
  echo -e "${GREEN}CLI ran successfully in Docker.${NC}"
  return 0
}

# Main function
main() {
  echo -e "${BLUE}Starting Docker build and run process...${NC}"
  
  # Check if Docker is installed
  check_docker
  if [ $? -ne 0 ]; then
    echo -e "${RED}Docker check failed. Exiting.${NC}"
    exit 1
  fi
  
  # Build Docker image
  build_docker_image
  if [ $? -ne 0 ]; then
    echo -e "${RED}Docker build failed. Exiting.${NC}"
    exit 1
  fi
  
  # Run CLI in Docker
  run_cli_in_docker
  if [ $? -ne 0 ]; then
    echo -e "${RED}Docker run failed. Exiting.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Docker build and run completed successfully!${NC}"
  exit 0
}

# Run the main function
main
