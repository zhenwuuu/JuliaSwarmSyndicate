#!/bin/bash

# Script to run JuliaOS in Docker

# Create necessary directories
mkdir -p data examples config

# Function to display help
show_help() {
    echo "JuliaOS Docker Runner"
    echo "====================="
    echo "Usage: ./run-juliaos.sh [command]"
    echo ""
    echo "Commands:"
    echo "  server    - Start the JuliaOS server"
    echo "  cli       - Start the JuliaOS interactive CLI"
    echo "  build     - Build the Docker image"
    echo "  stop      - Stop all running containers"
    echo "  clean     - Remove all containers and images"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run-juliaos.sh server    # Start the server"
    echo "  ./run-juliaos.sh cli       # Start the CLI"
    echo ""
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Process command
case "$1" in
    server)
        echo "Starting JuliaOS server..."
        docker-compose up -d juliaos
        echo "Server started! Access it at http://localhost:8052"
        ;;
    cli)
        echo "Starting JuliaOS CLI..."
        docker-compose up -d juliaos  # Make sure server is running
        docker-compose run --rm juliaos-cli
        ;;
    build)
        echo "Building JuliaOS Docker image..."
        docker-compose build
        echo "Build completed!"
        ;;
    stop)
        echo "Stopping JuliaOS containers..."
        docker-compose down
        echo "Containers stopped!"
        ;;
    clean)
        echo "Removing JuliaOS containers and images..."
        docker-compose down --rmi all
        echo "Cleanup completed!"
        ;;
    help|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

exit 0
