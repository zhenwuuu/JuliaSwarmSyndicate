using Pkg
using Test
using Logging

# Set up logging
ENV["JULIA_LOG_LEVEL"] = "INFO"
global_logger(ConsoleLogger(stderr, Logging.Info))

# Activate the project environment
Pkg.activate(".")

# Add test dependencies if not already installed
test_packages = ["Test", "HTTP", "WebSockets", "JSON", "UUIDs"]
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
include("test/test_server.jl")

# Print test summary
@info "Tests completed successfully!" 