#!/usr/bin/env julia

# Precompilation script for JuliaOS
# This script precompiles all the modules to improve startup time

println("Starting JuliaOS precompilation...")

# Add the current directory to the load path
push!(LOAD_PATH, @__DIR__)

using Logging
using Dates

# Configure logging
log_dir = joinpath(@__DIR__, "logs")
mkpath(log_dir)
log_file = joinpath(log_dir, "precompile_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")).log")
file_logger = SimpleLogger(open(log_file, "w"), Logging.Info)
global_logger(file_logger)

@info "Starting JuliaOS precompilation..."

# Record start time
start_time = now()

try
    # Import JuliaOS module
    @info "Importing JuliaOS module..."
    include("src/JuliaOS/JuliaOS.jl")
    using .JuliaOS
    
    # Initialize the system
    @info "Initializing JuliaOS system..."
    init_result = JuliaOS.initialize_system()
    
    if haskey(init_result, "status") && init_result["status"] == "success"
        @info "JuliaOS system initialized successfully"
    else
        @error "Failed to initialize JuliaOS system: $(get(init_result, "error", "Unknown error"))"
    end
    
    # Precompile common operations
    @info "Precompiling common operations..."
    
    # Precompile system health check
    JuliaOS.check_system_health()
    
    # Precompile agent operations
    @info "Precompiling agent operations..."
    agent_id = JuliaOS.AgentSystem.create_agent("PrecompileAgent", "generic", ["basic"])
    JuliaOS.AgentSystem.list_agents()
    JuliaOS.AgentSystem.update_agent(agent_id, Dict("status" => "active"))
    JuliaOS.AgentSystem.delete_agent(agent_id)
    
    # Precompile swarm operations
    @info "Precompiling swarm operations..."
    swarm_id = JuliaOS.SwarmManager.create_swarm("PrecompileSwarm", "pso", Dict("particles" => 10))
    JuliaOS.SwarmManager.list_swarms()
    JuliaOS.SwarmManager.delete_swarm(swarm_id)
    
    # Precompile bridge operations
    @info "Precompiling bridge operations..."
    JuliaOS.Bridge.is_connected()
    
    # Calculate elapsed time
    elapsed_time = Dates.value(now() - start_time) / 1000
    @info "Precompilation completed in $elapsed_time seconds"
    
    println("Precompilation completed successfully in $elapsed_time seconds")
catch e
    @error "Error during precompilation" exception=(e, catch_backtrace())
    println("Error during precompilation: $e")
end
