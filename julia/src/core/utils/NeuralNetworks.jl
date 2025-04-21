module NeuralNetworks

# Include neural network modules
include("NeuralNetworks/FluxModels.jl")
include("NeuralNetworks/AgentNeuralNetworks.jl")

# Re-export modules
using .FluxModels
using .AgentNeuralNetworks

# Export main functions
export create_model, train_model, save_model, load_model, predict
export create_dense_network, create_recurrent_network, create_convolutional_network
export create_agent_model, train_agent_model, get_agent_model, predict_with_agent_model
export list_agent_models, delete_agent_model, save_agent_models, load_agent_models

# Function to get all model types
function get_model_types()
    return [:dense, :recurrent, :convolutional]
end

# Export the function
export get_model_types

end # module
