#!/usr/bin/env julia

# Install dependencies for the enhanced Agents.jl
using Pkg

# List of packages to install
packages = [
    "DataStructures",  # For OrderedDict and PriorityQueue
    "JSON3",           # For persistence
    "UUIDs",           # For generating UUIDs
    "OpenAI"           # For LLM integration (optional)
]

# Install each package
for pkg in packages
    println("Installing $pkg...")
    try
        Pkg.add(pkg)
        println("✓ Successfully installed $pkg")
    catch e
        println("✗ Failed to install $pkg: $e")
    end
end

println("\nAll dependencies installed!")
