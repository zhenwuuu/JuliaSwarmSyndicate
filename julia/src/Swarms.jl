module Swarms

export create_swarm, run_optimization, get_swarm_status, get_optimization_result,
       get_available_algorithms, set_objective_function

using Random
using Statistics
using Dates
using JSON
using UUIDs

# Include swarm algorithms
include("Swarms/DifferentialEvolution.jl")
include("Swarms/ParticleSwarmOptimization.jl")
include("Swarms/GreyWolfOptimization.jl")
include("Swarms/AntColonyOptimization.jl")
include("Swarms/GeneticAlgorithm.jl")
include("Swarms/WhaleOptimizationAlgorithm.jl")

# Re-export modules
using .DifferentialEvolution
using .ParticleSwarmOptimization
using .GreyWolfOptimization
using .AntColonyOptimization
using .GeneticAlgorithm
using .WhaleOptimizationAlgorithm

# Global storage for swarms and optimizations
const SWARMS = Dict{String, Dict}()
const OPTIMIZATIONS = Dict{String, Dict}()
const OBJECTIVE_FUNCTIONS = Dict{String, Function}()

"""
    create_swarm(algorithm::String, dimensions::Int, bounds::Vector{Tuple{Float64, Float64}}, parameters::Dict)

Create a swarm for optimization.

# Arguments
- `algorithm::String`: The algorithm to use (DE, PSO, etc.)
- `dimensions::Int`: Number of dimensions
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension
- `parameters::Dict`: Algorithm parameters

# Returns
- `Dict`: Swarm creation result
"""
function create_swarm(algorithm::String, dimensions::Int, bounds::Vector{Tuple{Float64, Float64}}, parameters::Dict=Dict())
    # Validate algorithm
    if !(algorithm in get_available_algorithms())
        return Dict(
            "success" => false,
            "error" => "Unknown algorithm: $algorithm"
        )
    end

    # Validate dimensions and bounds
    if length(bounds) != dimensions
        return Dict(
            "success" => false,
            "error" => "Number of bounds must match dimensions"
        )
    end

    # Generate swarm ID
    swarm_id = string(uuid4())

    # Create swarm based on algorithm
    swarm_result = Dict()

    if algorithm == "DE"
        population_size = get(parameters, "population_size", 50)
        swarm_result = DifferentialEvolution.create_population(bounds, population_size)
    elseif algorithm == "PSO"
        swarm_size = get(parameters, "swarm_size", 50)
        swarm_result = ParticleSwarmOptimization.create_swarm(bounds, swarm_size)
    elseif algorithm == "GWO"
        pack_size = get(parameters, "pack_size", 30)
        swarm_result = GreyWolfOptimization.create_pack(bounds, pack_size)
    elseif algorithm == "ACO"
        colony_size = get(parameters, "colony_size", 50)
        swarm_result = AntColonyOptimization.create_colony(bounds, colony_size)
    elseif algorithm == "GA"
        population_size = get(parameters, "population_size", 100)
        swarm_result = GeneticAlgorithm.create_population(bounds, population_size)
    elseif algorithm == "WOA"
        pod_size = get(parameters, "pod_size", 30)
        swarm_result = WhaleOptimizationAlgorithm.create_pod(bounds, pod_size)
    end

    if !swarm_result["success"]
        return swarm_result
    end

    # Store swarm
    SWARMS[swarm_id] = Dict(
        "id" => swarm_id,
        "algorithm" => algorithm,
        "dimensions" => dimensions,
        "bounds" => bounds,
        "parameters" => parameters,
        "swarm" => swarm_result["swarm"],
        "created_at" => string(now()),
        "status" => "created"
    )

    return Dict(
        "success" => true,
        "swarm_id" => swarm_id,
        "algorithm" => algorithm,
        "dimensions" => dimensions,
        "swarm_size" => algorithm == "DE" ? swarm_result["population_size"] : swarm_result["swarm_size"]
    )
end

"""
    set_objective_function(function_id::String, objective_function::Function)

Set an objective function for optimization.

# Arguments
- `function_id::String`: ID for the objective function
- `objective_function::Function`: The function to minimize

# Returns
- `Dict`: Result of setting the objective function
"""
function set_objective_function(function_id::String, objective_function::Function)
    OBJECTIVE_FUNCTIONS[function_id] = objective_function

    return Dict(
        "success" => true,
        "function_id" => function_id
    )
end

"""
    run_optimization(swarm_id::String, function_id::String, parameters::Dict)

Run an optimization using a swarm.

# Arguments
- `swarm_id::String`: ID of the swarm to use
- `function_id::String`: ID of the objective function
- `parameters::Dict`: Additional optimization parameters

# Returns
- `Dict`: Optimization initialization result
"""
function run_optimization(swarm_id::String, function_id::String, parameters::Dict=Dict())
    # Validate swarm
    if !haskey(SWARMS, swarm_id)
        return Dict(
            "success" => false,
            "error" => "Swarm not found: $swarm_id"
        )
    end

    # Validate objective function
    if !haskey(OBJECTIVE_FUNCTIONS, function_id)
        return Dict(
            "success" => false,
            "error" => "Objective function not found: $function_id"
        )
    end

    # Get swarm and objective function
    swarm = SWARMS[swarm_id]
    objective_function = OBJECTIVE_FUNCTIONS[function_id]

    # Generate optimization ID
    optimization_id = string(uuid4())

    # Merge parameters
    merged_parameters = merge(swarm["parameters"], parameters)

    # Store optimization
    OPTIMIZATIONS[optimization_id] = Dict(
        "id" => optimization_id,
        "swarm_id" => swarm_id,
        "function_id" => function_id,
        "parameters" => merged_parameters,
        "created_at" => string(now()),
        "status" => "running",
        "result" => nothing
    )

    # Update swarm status
    SWARMS[swarm_id]["status"] = "optimizing"

    # Run optimization in a separate task
    @async begin
        try
            result = Dict()

            if swarm["algorithm"] == "DE"
                result = DifferentialEvolution.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            elseif swarm["algorithm"] == "PSO"
                result = ParticleSwarmOptimization.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            elseif swarm["algorithm"] == "GWO"
                result = GreyWolfOptimization.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            elseif swarm["algorithm"] == "ACO"
                result = AntColonyOptimization.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            elseif swarm["algorithm"] == "GA"
                result = GeneticAlgorithm.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            elseif swarm["algorithm"] == "WOA"
                result = WhaleOptimizationAlgorithm.optimize(
                    objective_function,
                    swarm["bounds"],
                    merged_parameters
                )
            end

            # Store result
            OPTIMIZATIONS[optimization_id]["result"] = result
            OPTIMIZATIONS[optimization_id]["status"] = "completed"
            OPTIMIZATIONS[optimization_id]["completed_at"] = string(now())

            # Update swarm
            SWARMS[swarm_id]["status"] = "optimized"
        catch e
            # Handle error
            OPTIMIZATIONS[optimization_id]["status"] = "failed"
            OPTIMIZATIONS[optimization_id]["error"] = string(e)
            SWARMS[swarm_id]["status"] = "error"
        end
    end

    return Dict(
        "success" => true,
        "optimization_id" => optimization_id,
        "swarm_id" => swarm_id,
        "function_id" => function_id,
        "status" => "running"
    )
end

"""
    get_swarm_status(swarm_id::String)

Get the status of a swarm.

# Arguments
- `swarm_id::String`: ID of the swarm

# Returns
- `Dict`: Swarm status
"""
function get_swarm_status(swarm_id::String)
    # Validate swarm
    if !haskey(SWARMS, swarm_id)
        return Dict(
            "success" => false,
            "error" => "Swarm not found: $swarm_id"
        )
    end

    # Get swarm
    swarm = SWARMS[swarm_id]

    return Dict(
        "success" => true,
        "swarm_id" => swarm_id,
        "algorithm" => swarm["algorithm"],
        "dimensions" => swarm["dimensions"],
        "status" => swarm["status"],
        "created_at" => swarm["created_at"]
    )
end

"""
    get_optimization_result(optimization_id::String)

Get the result of an optimization.

# Arguments
- `optimization_id::String`: ID of the optimization

# Returns
- `Dict`: Optimization result
"""
function get_optimization_result(optimization_id::String)
    # Validate optimization
    if !haskey(OPTIMIZATIONS, optimization_id)
        return Dict(
            "success" => false,
            "error" => "Optimization not found: $optimization_id"
        )
    end

    # Get optimization
    optimization = OPTIMIZATIONS[optimization_id]

    return Dict(
        "success" => true,
        "optimization_id" => optimization_id,
        "swarm_id" => optimization["swarm_id"],
        "function_id" => optimization["function_id"],
        "status" => optimization["status"],
        "created_at" => optimization["created_at"],
        "completed_at" => get(optimization, "completed_at", nothing),
        "result" => optimization["result"],
        "error" => get(optimization, "error", nothing)
    )
end

"""
    get_available_algorithms()

Get the list of available swarm algorithms.

# Returns
- `Vector{String}`: List of available algorithms
"""
function get_available_algorithms()
    return ["DE", "PSO", "GWO", "ACO", "GA", "WOA"]
end

end # module
