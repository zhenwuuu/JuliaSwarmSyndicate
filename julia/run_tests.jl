using Pkg
using Test
using Logging

# Set up logging
ENV["JULIA_LOG_LEVEL"] = "INFO"
global_logger(ConsoleLogger(stderr, Logging.Info))

# Activate the project environment
Pkg.activate(".")

# Add test dependencies if not already installed
test_packages = ["Test", "HTTP", "WebSockets", "JSON", "UUIDs", "Distributions"]
for pkg in test_packages
    if !(pkg in keys(Pkg.project().dependencies))
        @info "Installing test package: $pkg"
        Pkg.add(pkg)
    end
end

# Include the JuliaOS module
@info "Loading JuliaOS module..."
include("src/JuliaOS.jl")

# Initialize the system
@info "Initializing JuliaOS system..."
JuliaOS.initialize_system()

# Run the tests
@info "Running tests..."

@info "Running server tests..."
include("test/test_server.jl")

@info "Running WOA algorithm tests..."
include("test/test_woa.jl")

@info "Running MLIntegration tests..."
include("test/test_ml_integration.jl")

@info "Running swarm tests..."
include("test/test_swarms.jl")

@info "Running new swarm algorithm tests..."
include("test/test_new_swarm_algorithms.jl")

# Print test summary
@info "All tests completed successfully!"