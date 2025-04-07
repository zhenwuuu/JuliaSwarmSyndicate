# createSwarm.jl - Script to create and initialize a swarm in JuliaOS
using JSON
using ..JuliaOS
using ..JuliaOS.SwarmManager
using ..JuliaOS.Algorithms

"""
    create_swarm_from_params()

Creates and initializes a swarm based on parameters passed from the CLI.
Takes parameters as a JSON file path passed as command line argument.
"""
function create_swarm_from_params()
    # Ensure we have the right number of arguments
    if length(ARGS) < 1
        error("Missing parameter file argument")
    end
    
    # Get parameters from command line args
    params_file = ARGS[1]
    
    # Check if file exists
    if !isfile(params_file)
        error("Parameter file not found: $params_file")
    end
    
    # Read and parse the parameters
    params_json = read(params_file, String)
    params = JSON.parse(params_json)
    
    # Extract parameters
    algorithm_type = get(params, "algorithm", "pso")
    swarm_size = get(params, "swarm_size", 10)
    trading_pairs = get(params, "trading_pairs", ["ETH/USDT"])
    networks = get(params, "networks", ["ethereum"])
    algorithm_params = get(params, "algorithm_params", Dict())
    
    # Log the parameters
    @info "Creating swarm with algorithm: $algorithm_type"
    @info "Swarm size: $swarm_size"
    @info "Trading pairs: $trading_pairs"
    @info "Networks: $networks"
    
    # Create the algorithm instance
    algorithm = create_algorithm(algorithm_type, algorithm_params)
    
    # Initialize swarm with progress feedback
    @info "Initializing swarm..."
    swarm = initialize_swarm(
        algorithm,
        swarm_size,
        trading_pairs,
        networks
    )
    
    # Generate a unique ID for the swarm
    swarm_id = "swarm-$(hash(string(now())))"
    
    # Save swarm configuration to disk
    @info "Saving swarm configuration..."
    save_path = save_swarm_config(swarm, swarm_id)
    
    # Return swarm ID and status to the CLI
    result = Dict(
        "id" => swarm_id,
        "status" => "created",
        "message" => "Swarm created successfully",
        "save_path" => save_path,
        "config" => Dict(
            "algorithm" => algorithm_type,
            "size" => swarm_size,
            "trading_pairs" => trading_pairs,
            "networks" => networks
        )
    )
    
    # Write result to stdout as JSON for the CLI to parse
    println(JSON.json(result))
end

"""
    initialize_swarm(algorithm, size, pairs, networks)

Initialize a swarm with the given parameters.
"""
function initialize_swarm(algorithm, size, pairs, networks)
    # This would be implemented with actual swarm initialization logic
    # For now, we'll return a simple dictionary representing the swarm
    
    return Dict(
        "algorithm" => algorithm,
        "size" => size,
        "pairs" => pairs,
        "networks" => networks,
        "agents" => [Dict("id" => "agent-$i", "status" => "initialized") for i in 1:size]
    )
end

"""
    save_swarm_config(swarm, id)

Save the swarm configuration to disk for persistence.
"""
function save_swarm_config(swarm, id)
    # Create the swarms directory if it doesn't exist
    swarms_dir = joinpath(dirname(@__FILE__), "..", "..", "data", "swarms")
    mkpath(swarms_dir)
    
    # Create a file for this swarm
    swarm_file = joinpath(swarms_dir, "$id.json")
    
    # Add metadata
    swarm_with_meta = merge(swarm, Dict(
        "id" => id,
        "created_at" => string(now()),
        "status" => "created"
    ))
    
    # Write to file
    open(swarm_file, "w") do f
        write(f, JSON.json(swarm_with_meta))
    end
    
    return swarm_file
end

# Execute the main function when script is run
if abspath(PROGRAM_FILE) == @__FILE__
    create_swarm_from_params()
end 