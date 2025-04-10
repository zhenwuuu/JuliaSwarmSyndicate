#!/usr/bin/env julia

# Script to inspect the AgentSystem module
println("Inspecting AgentSystem module...")

# Add the current directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
push!(LOAD_PATH, joinpath(@__DIR__, "src", "JuliaOS"))

# Try to load the module
try
    include(joinpath(@__DIR__, "src", "AgentSystem.jl"))
    println("AgentSystem.jl loaded successfully!")
    
    # Print module information
    println("\nModule name: AgentSystem")
    
    # Print exported names
    println("\nExported names:")
    for name in names(AgentSystem)
        println("  - $name")
    end
    
    # Print module structure
    println("\nModule structure:")
    for name in names(AgentSystem, all=true)
        if !startswith(string(name), "#")
            value = getfield(AgentSystem, name)
            type_str = string(typeof(value))
            println("  - $name: $type_str")
        end
    end
    
catch e
    println("Error loading AgentSystem.jl: $e")
end
