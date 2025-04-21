module NeuralNetworks

export FluxModels, AgentNeuralNetworks
export create_model, train_model, save_model, load_model, predict
export create_dense_network, create_recurrent_network, create_convolutional_network
export create_agent_model, train_agent_model, get_agent_model, predict_with_agent_model
export list_agent_models, delete_agent_model, save_agent_models, load_agent_models

# Import required packages
using Flux
using BSON
using Statistics
using Random
using Dates
using LinearAlgebra

# Include model implementations
include("models/FeedForward.jl")
include("models/Recurrent.jl")

# Export model modules
export FeedForward, Recurrent

# Re-export specific model types and functions
export FeedForwardNetwork, RecurrentNetwork, RecurrentNetworkType
export LSTM, GRU, RNN  # RecurrentNetworkType enum values
export train!, predict, save_model, load_model

# Import from JuliaOS core if available
@static if isdefined(Main, :JuliaOS) && isdefined(JuliaOS, :NeuralNetworks)
    using JuliaOS.NeuralNetworks

    # Re-export all public symbols
    for name in names(JuliaOS.NeuralNetworks, all=true)
        if !startswith(string(name), "#") && name != :NeuralNetworks
            @eval export $name
        end
    end
end

"""
    create_model(model_type::String, config::Dict)

Create a neural network model of the specified type.

# Arguments
- `model_type::String`: Type of model ("feedforward", "recurrent", "convolutional")
- `config::Dict`: Configuration for the model

# Returns
- Model object of the appropriate type
"""
function create_model(model_type::String, config::Dict)
    if lowercase(model_type) == "feedforward"
        return FeedForward.FeedForwardNetwork(
            config["input_size"],
            config["hidden_layers"],
            config["output_size"];
            activation=get(config, "activation", Flux.relu),
            output_activation=get(config, "output_activation", identity),
            optimizer=get(config, "optimizer", Flux.ADAM(0.001))
        )
    elseif lowercase(model_type) == "recurrent"
        # Convert string to enum for network_type
        network_type_str = get(config, "network_type", "LSTM")
        network_type = if uppercase(network_type_str) == "LSTM"
            Recurrent.LSTM
        elseif uppercase(network_type_str) == "GRU"
            Recurrent.GRU
        elseif uppercase(network_type_str) == "RNN"
            Recurrent.RNN
        else
            Recurrent.LSTM  # Default
        end

        return Recurrent.RecurrentNetwork(
            config["input_size"],
            config["hidden_size"],
            config["output_size"];
            num_layers=get(config, "num_layers", 1),
            network_type=network_type,
            bidirectional=get(config, "bidirectional", false),
            optimizer=get(config, "optimizer", Flux.ADAM(0.001))
        )
    elseif lowercase(model_type) == "convolutional"
        error("Convolutional networks not yet implemented")
    else
        error("Unknown model type: $model_type")
    end
end

# Dictionary to store agent models
const agent_models = Dict{String, Any}()

"""
    create_agent_model(agent_id::String, model_type::String, config::Dict)

Create a neural network model for an agent.

# Arguments
- `agent_id::String`: ID of the agent
- `model_type::String`: Type of model
- `config::Dict`: Configuration for the model

# Returns
- `Bool`: true if successful
"""
function create_agent_model(agent_id::String, model_type::String, config::Dict)
    try
        model = create_model(model_type, config)
        agent_models[agent_id] = model
        return true
    catch e
        println("Error creating agent model: $e")
        return false
    end
end

"""
    train_agent_model(agent_id::String, X::Array, y::Array; kwargs...)

Train an agent's neural network model.

# Arguments
- `agent_id::String`: ID of the agent
- `X::Array`: Input data
- `y::Array`: Target data
- `kwargs...`: Additional training parameters

# Returns
- `Dict`: Training history or error
"""
function train_agent_model(agent_id::String, X::Array, y::Array; kwargs...)
    if !haskey(agent_models, agent_id)
        return Dict("success" => false, "error" => "Agent model not found")
    end

    try
        model = agent_models[agent_id]
        history = train!(model, X, y; kwargs...)
        return Dict("success" => true, "history" => history)
    catch e
        return Dict("success" => false, "error" => "Training error: $e")
    end
end

"""
    get_agent_model(agent_id::String)

Get an agent's neural network model.

# Arguments
- `agent_id::String`: ID of the agent

# Returns
- The agent's model or nothing if not found
"""
function get_agent_model(agent_id::String)
    return get(agent_models, agent_id, nothing)
end

"""
    predict_with_agent_model(agent_id::String, X::Array)

Make predictions with an agent's neural network model.

# Arguments
- `agent_id::String`: ID of the agent
- `X::Array`: Input data

# Returns
- `Dict`: Predictions or error
"""
function predict_with_agent_model(agent_id::String, X::Array)
    if !haskey(agent_models, agent_id)
        return Dict("success" => false, "error" => "Agent model not found")
    end

    try
        model = agent_models[agent_id]
        predictions = predict(model, X)
        return Dict("success" => true, "predictions" => predictions)
    catch e
        return Dict("success" => false, "error" => "Prediction error: $e")
    end
end

"""
    list_agent_models()

List all agent models.

# Returns
- `Vector{String}`: List of agent IDs with models
"""
function list_agent_models()
    return collect(keys(agent_models))
end

"""
    delete_agent_model(agent_id::String)

Delete an agent's neural network model.

# Arguments
- `agent_id::String`: ID of the agent

# Returns
- `Bool`: true if successful
"""
function delete_agent_model(agent_id::String)
    if haskey(agent_models, agent_id)
        delete!(agent_models, agent_id)
        return true
    else
        return false
    end
end

"""
    save_agent_models(directory::String)

Save all agent models to a directory.

# Arguments
- `directory::String`: Directory to save models

# Returns
- `Dict`: Results of save operations
"""
function save_agent_models(directory::String)
    results = Dict{String, Bool}()

    # Create directory if it doesn't exist
    if !isdir(directory)
        mkpath(directory)
    end

    # Save each model
    for (agent_id, model) in agent_models
        filepath = joinpath(directory, "$(agent_id).bson")
        results[agent_id] = save_model(model, filepath)
    end

    return results
end

"""
    load_agent_models(directory::String)

Load agent models from a directory.

# Arguments
- `directory::String`: Directory containing models

# Returns
- `Dict`: Results of load operations
"""
function load_agent_models(directory::String)
    results = Dict{String, Bool}()

    # Check if directory exists
    if !isdir(directory)
        return results
    end

    # Load each model
    for file in readdir(directory)
        if endswith(file, ".bson")
            agent_id = replace(file, ".bson" => "")
            filepath = joinpath(directory, file)
            model = load_model(filepath)
            if model !== nothing
                agent_models[agent_id] = model
                results[agent_id] = true
            else
                results[agent_id] = false
            end
        end
    end

    return results
end

end # module
