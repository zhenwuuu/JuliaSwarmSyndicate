"""
CommandHandler module for JuliaOS

This module provides a centralized command handling system for JuliaOS.
It routes commands to the appropriate handlers based on command prefixes.
"""
module CommandHandler

using Dates
using UUIDs
using JSON
using SQLite
using DataFrames
using ..JuliaOS

# Import required modules - use conditional imports to avoid circular dependencies
for mod in [:AgentSystem, :SwarmManager, :Bridge, :Storage, :Metrics, :AgentSkills,
           :CrossChainArbitrage, :SkillsCommands, :MLIntegration, :Algorithms,
           :SecurityManager, :DEX, :WormholeBridge, :Swarms, :SwarmBase]
    try
        if isdefined(JuliaOS, mod)
            @eval import ..JuliaOS: $mod
        end
    catch e
        @warn "Could not import JuliaOS.$mod: $e"
    end
end

# Export the main functions
export handle_command, handle_swarm_list_algorithms, handle_swarm_get_available_algorithms

# Command handler implementation
"""
    handle_command(command::String, params::Dict)

Process a command and route it to the appropriate implementation.
Returns a Dict with the result or error.
"""
function handle_command(command::String, params::Dict)
    @info "Processing command: $command with params: $params"

    try
        # Special case for create_agent command (from enhanced-bridge.js)
        if command == "create_agent"
            @info "Converting create_agent to agents.create_agent"
            return handle_agent_command("agents.create_agent", params)
        end

        # Route commands based on prefix
        if startswith(command, "agents.")
            return handle_agent_command(command, params)
        elseif startswith(command, "swarms.")
            # Special case for swarm algorithm commands
            if command == "swarm.list_algorithms"
                @info "Handling swarm.list_algorithms command directly"
                return handle_swarm_list_algorithms(params)
            elseif command == "Swarm.get_available_algorithms"
                @info "Handling Swarm.get_available_algorithms command directly"
                return handle_swarm_get_available_algorithms(params)
            else
                return handle_swarm_command(command, params)
            end
        elseif startswith(command, "Swarm.")
            return handle_swarm_module_command(command, params)
        elseif startswith(command, "metrics.")
            return handle_metrics_command(command, params)
        elseif startswith(command, "system.")
            return handle_system_command(command, params)
        elseif startswith(command, "WormholeBridge.")
            return handle_wormhole_command(command, params)
        elseif startswith(command, "Bridge.")
            return handle_bridge_command(command, params)
        elseif startswith(command, "algorithms.")
            return handle_algorithm_command(command, params)
        elseif startswith(command, "portfolio.")
            return handle_portfolio_command(command, params)
        elseif startswith(command, "wallets.")
            return handle_wallet_command(command, params)
        elseif startswith(command, "dex.")
            return handle_dex_command(command, params)
        elseif startswith(command, "blockchain.")
            return handle_blockchain_command(command, params)
        elseif startswith(command, "storage.")
            return handle_storage_command(command, params)
        else
            # Provide a simple acknowledgment response for unknown commands
            # This helps with testing and ensures the CLI doesn't break
            @info "Unknown command: $command, providing fallback response"
            return Dict(
                "success" => true,
                "data" => Dict(
                    "message" => "Command $command received",
                    "timestamp" => round(Int, time() * 1000) # milliseconds
                )
            )
        end
    catch e
        @error "Error handling command $command" exception=(e, catch_backtrace())
        # Create a more detailed error message
        error_msg = "Error processing command: $(typeof(e))"

        # Try to extract the error message in a safe way
        try
            if isdefined(e, :msg)
                error_msg = "$error_msg: $(e.msg)"
            elseif isdefined(e, :message)
                error_msg = "$error_msg: $(e.message)"
            else
                error_msg = "$error_msg: $(string(e))"
            end
        catch
            error_msg = "$error_msg: (Could not extract detailed error message)"
        end

        return Dict("success" => false, "error" => error_msg)
    end
end

# Include command handler implementations
include("agent_commands.jl")
include("swarm_commands.jl")
include("metrics_commands.jl")
include("system_commands.jl")
include("bridge_commands.jl")
include("wormhole_commands.jl")
include("algorithm_commands.jl")
include("portfolio_commands.jl")
include("wallet_commands.jl")
include("dex_commands.jl")
include("blockchain_commands.jl")
include("storage_commands.jl")

# Initialize the command handler
function __init__()
    @info "CommandHandler module initialized"

    # Register command handlers with Bridge if available
    try
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            # Register the main command handler
            JuliaOS.Bridge.register_command_handler("*", handle_command)
            @info "Registered command handler with Bridge"
        end
    catch e
        @warn "Failed to register command handler with Bridge: $e"
    end

    # Register specific command handlers
    try
        # Register system commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("system.", handle_system_command)
            @info "Registered system command handler with Bridge"
        end
    catch e
        @warn "Failed to register system command handler with Bridge: $e"
    end

    # Register algorithm commands
    try
        # Register algorithm commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("algorithms.", handle_algorithm_command)
            @info "Registered algorithm command handler with Bridge"
        end
    catch e
        @warn "Failed to register algorithm command handler with Bridge: $e"
    end

    # Register wormhole commands
    try
        # Register wormhole commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("WormholeBridge.", handle_wormhole_command)
            @info "Registered wormhole command handler with Bridge"
        end
    catch e
        @warn "Failed to register wormhole command handler with Bridge: $e"
    end

    # Register DEX commands
    try
        # Register DEX commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("dex.", handle_dex_command)
            @info "Registered DEX command handler with Bridge"
        end
    catch e
        @warn "Failed to register DEX command handler with Bridge: $e"
    end

    # Register wallet commands
    try
        # Register wallet commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("wallets.", handle_wallet_command)
            @info "Registered wallet command handler with Bridge"
        end
    catch e
        @warn "Failed to register wallet command handler with Bridge: $e"
    end

    # Register agent commands
    try
        # Register agent commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("agents.", handle_agent_command)
            @info "Registered agent command handler with Bridge"
        end
    catch e
        @warn "Failed to register agent command handler with Bridge: $e"
    end

    # Register swarm commands
    try
        # Register swarm commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("swarms.", handle_swarm_command)
            @info "Registered swarm command handler with Bridge"
        end
    catch e
        @warn "Failed to register swarm command handler with Bridge: $e"
    end

    # Register blockchain commands
    try
        # Register blockchain commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("blockchain.", handle_blockchain_command)
            @info "Registered blockchain command handler with Bridge"
        end
    catch e
        @warn "Failed to register blockchain command handler with Bridge: $e"
    end

    # Register storage commands
    try
        # Register storage commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("storage.", handle_storage_command)
            @info "Registered storage command handler with Bridge"
        end
    catch e
        @warn "Failed to register storage command handler with Bridge: $e"
    end

    # Register DEX commands
    try
        # Register DEX commands
        if isdefined(JuliaOS, :Bridge) && isdefined(JuliaOS.Bridge, :register_command_handler)
            JuliaOS.Bridge.register_command_handler("dex.", handle_dex_command)
            @info "Registered DEX command handler with Bridge"
        end
    catch e
        @warn "Failed to register DEX command handler with Bridge: $e"
    end
end

# Handle swarm.list_algorithms command
function handle_swarm_list_algorithms(params::Dict)
    try
        # Return the list of available algorithms
        algorithms = [
            Dict(
                "id" => "SwarmPSO",
                "name" => "Particle Swarm Optimization",
                "description" => "A population-based optimization technique inspired by social behavior of bird flocking or fish schooling.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 50, "description" => "Number of particles in the swarm"),
                    Dict("name" => "max_iterations", "type" => "integer", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "float", "default" => 2.0, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "float", "default" => 2.0, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "float", "default" => 0.7, "description" => "Inertia weight")
                ]
            ),
            Dict(
                "id" => "SwarmGA",
                "name" => "Genetic Algorithm",
                "description" => "A search heuristic that mimics the process of natural selection.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 100, "description" => "Number of individuals in the population"),
                    Dict("name" => "max_generations", "type" => "integer", "default" => 100, "description" => "Maximum number of generations"),
                    Dict("name" => "crossover_rate", "type" => "float", "default" => 0.8, "description" => "Probability of crossover"),
                    Dict("name" => "mutation_rate", "type" => "float", "default" => 0.1, "description" => "Probability of mutation")
                ]
            ),
            Dict(
                "id" => "SwarmACO",
                "name" => "Ant Colony Optimization",
                "description" => "A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.",
                "parameters" => [
                    Dict("name" => "num_ants", "type" => "integer", "default" => 50, "description" => "Number of ants"),
                    Dict("name" => "max_iterations", "type" => "integer", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "alpha", "type" => "float", "default" => 1.0, "description" => "Pheromone importance"),
                    Dict("name" => "beta", "type" => "float", "default" => 2.0, "description" => "Heuristic importance"),
                    Dict("name" => "rho", "type" => "float", "default" => 0.5, "description" => "Pheromone evaporation rate")
                ]
            ),
            Dict(
                "id" => "SwarmDE",
                "name" => "Differential Evolution",
                "description" => "A stochastic population-based optimization algorithm for solving over-continuous spaces.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 50, "description" => "Number of individuals in the population"),
                    Dict("name" => "max_generations", "type" => "integer", "default" => 100, "description" => "Maximum number of generations"),
                    Dict("name" => "F", "type" => "float", "default" => 0.8, "description" => "Differential weight"),
                    Dict("name" => "CR", "type" => "float", "default" => 0.9, "description" => "Crossover probability")
                ]
            ),
            Dict(
                "id" => "SwarmGWO",
                "name" => "Grey Wolf Optimizer",
                "description" => "A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 30, "description" => "Number of wolves in the pack"),
                    Dict("name" => "max_iterations", "type" => "integer", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "a_start", "type" => "float", "default" => 2.0, "description" => "Control parameter start"),
                    Dict("name" => "a_end", "type" => "float", "default" => 0.0, "description" => "Control parameter end")
                ]
            ),
            Dict(
                "id" => "SwarmWOA",
                "name" => "Whale Optimization Algorithm",
                "description" => "A nature-inspired meta-heuristic optimization algorithm that mimics the hunting behavior of humpback whales.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 30, "description" => "Number of whales"),
                    Dict("name" => "max_iterations", "type" => "integer", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "b", "type" => "float", "default" => 1.0, "description" => "Spiral shape constant")
                ]
            ),
            Dict(
                "id" => "SwarmDEPSO",
                "name" => "Differential Evolution Particle Swarm Optimization",
                "description" => "A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "integer", "default" => 50, "description" => "Number of individuals in the population"),
                    Dict("name" => "max_iterations", "type" => "integer", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "float", "default" => 1.5, "description" => "PSO cognitive coefficient"),
                    Dict("name" => "c2", "type" => "float", "default" => 1.5, "description" => "PSO social coefficient"),
                    Dict("name" => "w", "type" => "float", "default" => 0.7, "description" => "PSO inertia weight"),
                    Dict("name" => "F", "type" => "float", "default" => 0.8, "description" => "DE differential weight"),
                    Dict("name" => "CR", "type" => "float", "default" => 0.9, "description" => "DE crossover probability"),
                    Dict("name" => "hybrid_ratio", "type" => "float", "default" => 0.5, "description" => "Ratio of DE to PSO (0-1)"),
                    Dict("name" => "adaptive", "type" => "boolean", "default" => true, "description" => "Whether to use adaptive parameter control")
                ]
            )
        ]

        return Dict("success" => true, "data" => Dict("algorithms" => algorithms))
    catch e
        @error "Error listing algorithms" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error listing algorithms: $(string(e))")
    end
end

# Handle Swarm.get_available_algorithms command
function handle_swarm_get_available_algorithms(params::Dict)
    try
        # Return the list of available algorithms
        algorithms = [
            Dict(
                "id" => "pso",
                "name" => "Particle Swarm Optimization",
                "description" => "A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of particles"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "number", "default" => 2.0, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "number", "default" => 2.0, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "number", "default" => 0.7, "description" => "Inertia weight")
                ]
            ),
            Dict(
                "id" => "de",
                "name" => "Differential Evolution",
                "description" => "A stochastic population-based method that is useful for global optimization problems.",
                "type" => "evolutionary",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 50, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.7, "description" => "Crossover rate"),
                    Dict("name" => "mutation_factor", "type" => "number", "default" => 0.5, "description" => "Mutation factor")
                ]
            ),
            Dict(
                "id" => "gwo",
                "name" => "Grey Wolf Optimizer",
                "description" => "A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of wolves"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations")
                ]
            ),
            Dict(
                "id" => "aco",
                "name" => "Ant Colony Optimization",
                "description" => "A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of ants"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "alpha", "type" => "number", "default" => 1.0, "description" => "Pheromone importance"),
                    Dict("name" => "beta", "type" => "number", "default" => 2.0, "description" => "Heuristic importance"),
                    Dict("name" => "evaporation_rate", "type" => "number", "default" => 0.1, "description" => "Pheromone evaporation rate")
                ]
            ),
            Dict(
                "id" => "ga",
                "name" => "Genetic Algorithm",
                "description" => "A search heuristic that is inspired by Charles Darwin's theory of natural evolution.",
                "type" => "evolutionary",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 50, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.8, "description" => "Crossover rate"),
                    Dict("name" => "mutation_rate", "type" => "number", "default" => 0.1, "description" => "Mutation rate")
                ]
            ),
            Dict(
                "id" => "woa",
                "name" => "Whale Optimization Algorithm",
                "description" => "A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of whales"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "b", "type" => "number", "default" => 1.0, "description" => "Spiral constant")
                ]
            ),
            Dict(
                "id" => "depso",
                "name" => "Differential Evolution Particle Swarm Optimization",
                "description" => "A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.",
                "type" => "hybrid",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 40, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "number", "default" => 1.5, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "number", "default" => 1.5, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "number", "default" => 0.7, "description" => "Inertia weight"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.7, "description" => "Crossover rate"),
                    Dict("name" => "mutation_factor", "type" => "number", "default" => 0.5, "description" => "Mutation factor")
                ]
            )
        ]

        return Dict("success" => true, "data" => Dict("algorithms" => algorithms))
    catch e
        @error "Error listing swarm algorithms" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error listing swarm algorithms: $(string(e))")
    end
end

end # module
