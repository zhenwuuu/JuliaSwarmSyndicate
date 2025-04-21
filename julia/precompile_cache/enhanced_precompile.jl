#!/usr/bin/env julia

# Enhanced Precompilation Script for JuliaOS
# This script performs comprehensive precompilation of all modules to significantly improve startup time

println("Starting JuliaOS enhanced precompilation...")

# Add the current directory to the load path
push!(LOAD_PATH, @__DIR__)

using Logging
using Dates
using Base.Threads

# Configure logging
log_dir = joinpath(@__DIR__, "logs")
mkpath(log_dir)
log_file = joinpath(log_dir, "precompile_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")).log")
file_logger = SimpleLogger(open(log_file, "w"), Logging.Info)
global_logger(file_logger)

@info "Starting JuliaOS enhanced precompilation with $(Threads.nthreads()) threads..."

# Record start time
start_time = now()

# Create precompilation cache directory if it doesn't exist
precompile_cache_dir = joinpath(@__DIR__, "precompile_cache")
mkpath(precompile_cache_dir)

# Function to precompile a module and its dependencies
function precompile_module(module_name, module_path)
    try
        @info "Precompiling module: $module_name"
        include(module_path)

        # Generate precompile statements
        precompile_file = joinpath(precompile_cache_dir, "$(module_name)_precompile.jl")
        @info "Generating precompile statements for $module_name"

        # This is a placeholder - in a real implementation, you would use SnoopCompile or similar
        # to generate actual precompile statements
        open(precompile_file, "w") do f
            println(f, "# Precompile statements for $module_name")
            println(f, "# Generated on $(now())")
        end

        @info "Successfully precompiled $module_name"
        return true
    catch e
        @error "Error precompiling $module_name" exception=(e, catch_backtrace())
        return false
    end
end

try
    # Load configuration
    @info "Loading configuration..."
    include("config.jl")

    # Precompile core modules
    core_modules = [
        ("JuliaOS", "src/JuliaOS/JuliaOS.jl"),
        ("AgentSystem", "src/JuliaOS/AgentSystem.jl"),
        ("SwarmManager", "src/JuliaOS/SwarmManager.jl"),
        ("Storage", "src/JuliaOS/Storage.jl"),
        ("Server", "src/JuliaOS/server.jl"),
        ("Bridge", "src/JuliaOS/Bridge.jl"),
        ("CommandHandler", "src/JuliaOS/CommandHandler.jl"),
        ("Metrics", "src/Metrics.jl"),
        ("WormholeBridge", "src/JuliaOS/WormholeBridge.jl"),
        ("DEX", "src/JuliaOS/DEX.jl"),
        ("Algorithms", "src/JuliaOS/Algorithms.jl")
    ]

    # Precompile modules in parallel if multiple threads are available
    if Threads.nthreads() > 1
        @info "Using parallel precompilation with $(Threads.nthreads()) threads"
        results = Vector{Bool}(undef, length(core_modules))

        Threads.@threads for i in 1:length(core_modules)
            module_name, module_path = core_modules[i]
            results[i] = precompile_module(module_name, module_path)
        end

        success_count = count(results)
        @info "Parallel precompilation completed: $success_count of $(length(core_modules)) modules successfully precompiled"
    else
        @info "Using sequential precompilation"
        success_count = 0

        for (module_name, module_path) in core_modules
            if precompile_module(module_name, module_path)
                success_count += 1
            end
        end

        @info "Sequential precompilation completed: $success_count of $(length(core_modules)) modules successfully precompiled"
    end

    # Import JuliaOS module to ensure it's fully loaded
    @info "Importing JuliaOS module..."
    include("src/JuliaOS/JuliaOS.jl")
    using .JuliaOS

    # Initialize the system to precompile initialization code
    @info "Initializing JuliaOS system for precompilation..."
    init_result = JuliaOS.initialize_system()

    if haskey(init_result, "status") && init_result["status"] == "success"
        @info "JuliaOS system initialized successfully during precompilation"
    else
        @error "Failed to initialize JuliaOS system during precompilation: $(get(init_result, "error", "Unknown error"))"
    end

    # Precompile common operations
    @info "Precompiling common operations..."

    # System operations
    JuliaOS.check_system_health()

    # Agent operations
    @info "Precompiling agent operations..."
    agent_id = JuliaOS.AgentSystem.create_agent("PrecompileAgent", "generic", ["basic"])
    JuliaOS.AgentSystem.list_agents()
    JuliaOS.AgentSystem.get_agent(agent_id)
    JuliaOS.AgentSystem.update_agent(agent_id, Dict("status" => "active"))
    JuliaOS.AgentSystem.delete_agent(agent_id)

    # Swarm operations
    @info "Precompiling swarm operations..."
    swarm_id = JuliaOS.SwarmManager.create_swarm("PrecompileSwarm", "pso", Dict("particles" => 10))
    JuliaOS.SwarmManager.list_swarms()
    JuliaOS.SwarmManager.get_swarm(swarm_id)
    JuliaOS.SwarmManager.delete_swarm(swarm_id)

    # Storage operations
    @info "Precompiling storage operations..."
    JuliaOS.Storage.initialize_storage()
    JuliaOS.Storage.get_storage()

    # Bridge operations
    @info "Precompiling bridge operations..."
    JuliaOS.Bridge.is_connected()

    # Server operations
    @info "Precompiling server operations..."
    # Don't actually start the server, just precompile the functions

    # Generate precompile directives file
    @info "Generating precompile directives file..."
    precompile_directives_file = joinpath(precompile_cache_dir, "precompile_directives.jl")

    open(precompile_directives_file, "w") do f
        println(f, "# JuliaOS Precompile Directives")
        println(f, "# Generated on $(now())")
        println(f, "")
        println(f, "# Include this file at the beginning of julia_server.jl to improve startup time")
        println(f, "")
        println(f, "# Core module precompilation")
        println(f, "precompile(JuliaOS.initialize_system, ())")
        println(f, "precompile(JuliaOS.check_system_health, ())")
        println(f, "precompile(JuliaOS.Server.start_server, (String, Int))")
        println(f, "precompile(JuliaOS.Server.stop_server, (Bool, Int))")
        println(f, "precompile(JuliaOS.Server.api_handler, (HTTP.Request,))")
        println(f, "precompile(JuliaOS.Server.handle_command, (Dict{String, Any},))")
        println(f, "")
        println(f, "# Command handler operations")
        println(f, "precompile(JuliaOS.CommandHandler.handle_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_agent_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_swarm_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_metrics_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_system_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_bridge_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_wormhole_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_algorithm_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_portfolio_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_wallet_command, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.CommandHandler.handle_dex_command, (String, Dict{String, Any}))")
        println(f, "")
        println(f, "# Agent operations")
        println(f, "precompile(JuliaOS.AgentSystem.create_agent, (String, String, Vector{String}))")
        println(f, "precompile(JuliaOS.AgentSystem.list_agents, ())")
        println(f, "precompile(JuliaOS.AgentSystem.get_agent, (String,))")
        println(f, "precompile(JuliaOS.AgentSystem.update_agent, (String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.AgentSystem.delete_agent, (String,))")
        println(f, "")
        println(f, "# Swarm operations")
        println(f, "precompile(JuliaOS.SwarmManager.create_swarm, (String, String, Dict{String, Any}))")
        println(f, "precompile(JuliaOS.SwarmManager.list_swarms, ())")
        println(f, "precompile(JuliaOS.SwarmManager.get_swarm, (String,))")
        println(f, "precompile(JuliaOS.SwarmManager.delete_swarm, (String,))")
        println(f, "")
        println(f, "# Bridge operations")
        println(f, "precompile(JuliaOS.Bridge.check_health, ())")
        println(f, "precompile(JuliaOS.Bridge.check_connections, ())")
        println(f, "precompile(JuliaOS.WormholeBridge.get_available_chains, ())")
        println(f, "precompile(JuliaOS.WormholeBridge.get_available_tokens, (String,))")
        println(f, "")
        println(f, "# DEX operations")
        println(f, "precompile(JuliaOS.DEX.list_dexes, ())")
        println(f, "precompile(JuliaOS.DEX.list_aggregators, ())")
        println(f, "precompile(JuliaOS.DEX.get_quote, (String, String, String, String, Float64))")
        println(f, "")
        println(f, "# Algorithm operations")
        println(f, "precompile(JuliaOS.Algorithms.list_algorithms, ())")
        println(f, "precompile(JuliaOS.Algorithms.get_algorithm_info, (String,))")
    end

    # Calculate elapsed time
    elapsed_time = Dates.value(now() - start_time) / 1000
    @info "Enhanced precompilation completed in $elapsed_time seconds"

    println("Enhanced precompilation completed successfully in $elapsed_time seconds")
    println("Precompilation cache generated in $precompile_cache_dir")
catch e
    @error "Error during enhanced precompilation" exception=(e, catch_backtrace())
    println("Error during enhanced precompilation: $e")
end
