#!/usr/bin/env julia

# Script to load all necessary modules in the correct order
println("Loading modules in the correct order...")

# Add the current directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
push!(LOAD_PATH, joinpath(@__DIR__, "src", "JuliaOS"))

# Try to load the modules in the correct order
try
    println("Loading MarketData.jl...")
    include(joinpath(@__DIR__, "src", "JuliaOS", "MarketData.jl"))
    println("MarketData.jl loaded successfully!")
    
    println("\nLoading Algorithms.jl...")
    include(joinpath(@__DIR__, "src", "JuliaOS", "algorithms", "Algorithms.jl"))
    println("Algorithms.jl loaded successfully!")
    
    println("\nLoading SwarmManager.jl...")
    include(joinpath(@__DIR__, "src", "JuliaOS", "SwarmManager.jl"))
    println("SwarmManager.jl loaded successfully!")
    
    println("\nLoading AgentSystem.jl...")
    include(joinpath(@__DIR__, "src", "JuliaOS", "AgentSystem.jl"))
    println("AgentSystem.jl loaded successfully!")
    
    # Print module information
    println("\nLoaded modules:")
    println("  - MarketData")
    println("  - Algorithms")
    println("  - SwarmManager")
    println("  - AgentSystem")
    
catch e
    println("Error loading modules: $e")
    println(stacktrace(catch_backtrace()))
end
