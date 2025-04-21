"""
    Recurrent.jl - Recurrent Neural Network Implementation

This module provides recurrent neural network implementations for JuliaOS.
"""
module Recurrent

export RecurrentNetwork, train!, predict, save_model, load_model

using Flux
using BSON: @save, @load
using Statistics
using Random
using Dates
using LinearAlgebra

"""
    RecurrentNetworkType

Enum for recurrent network types.
"""
@enum RecurrentNetworkType begin
    LSTM
    GRU
    RNN
end

"""
    RecurrentNetwork

A recurrent neural network model.

# Fields
- `model::Chain`: The Flux model
- `input_size::Int`: Number of input features
- `hidden_size::Int`: Size of hidden state
- `num_layers::Int`: Number of recurrent layers
- `output_size::Int`: Number of output features
- `network_type::RecurrentNetworkType`: Type of recurrent network
- `bidirectional::Bool`: Whether the network is bidirectional
- `optimizer::Flux.Optimise.AbstractOptimiser`: Optimizer
- `loss_history::Vector{Float32}`: History of loss values during training
- `created::DateTime`: Creation timestamp
- `last_trained::Union{DateTime, Nothing}`: Last training timestamp
"""
mutable struct RecurrentNetwork
    model::Flux.Chain
    input_size::Int
    hidden_size::Int
    num_layers::Int
    output_size::Int
    network_type::RecurrentNetworkType
    bidirectional::Bool
    optimizer::Flux.Optimise.AbstractOptimiser
    loss_history::Vector{Float32}
    created::DateTime
    last_trained::Union{DateTime, Nothing}
end

"""
    RecurrentNetwork(input_size::Int, hidden_size::Int, output_size::Int;
                    num_layers=1, network_type=LSTM, bidirectional=false,
                    optimizer=Flux.ADAM(0.001))

Create a new recurrent neural network.

# Arguments
- `input_size::Int`: Number of input features
- `hidden_size::Int`: Size of hidden state
- `output_size::Int`: Number of output features
- `num_layers=1`: Number of recurrent layers
- `network_type=LSTM`: Type of recurrent network
- `bidirectional=false`: Whether the network is bidirectional
- `optimizer=Flux.ADAM(0.001)`: Optimizer for training

# Returns
- `RecurrentNetwork`: The created network
"""
function RecurrentNetwork(input_size::Int, hidden_size::Int, output_size::Int;
                         num_layers=1, network_type=LSTM, bidirectional=false,
                         optimizer=Flux.ADAM(0.001))
    # Build the layers
    layers = []
    
    # Input size for the first layer
    current_input_size = input_size
    
    # Create recurrent layers
    for i in 1:num_layers
        # Create the recurrent layer based on the network type
        if network_type == LSTM
            if bidirectional
                # Bidirectional LSTM
                forward_lstm = Flux.LSTM(current_input_size => hidden_size)
                backward_lstm = Flux.LSTM(current_input_size => hidden_size)
                push!(layers, Flux.Parallel(vcat, forward_lstm, backward_lstm))
                current_input_size = 2 * hidden_size  # Output size is doubled for bidirectional
            else
                # Unidirectional LSTM
                push!(layers, Flux.LSTM(current_input_size => hidden_size))
                current_input_size = hidden_size
            end
        elseif network_type == GRU
            if bidirectional
                # Bidirectional GRU
                forward_gru = Flux.GRU(current_input_size => hidden_size)
                backward_gru = Flux.GRU(current_input_size => hidden_size)
                push!(layers, Flux.Parallel(vcat, forward_gru, backward_gru))
                current_input_size = 2 * hidden_size  # Output size is doubled for bidirectional
            else
                # Unidirectional GRU
                push!(layers, Flux.GRU(current_input_size => hidden_size))
                current_input_size = hidden_size
            end
        elseif network_type == RNN
            if bidirectional
                # Bidirectional RNN
                forward_rnn = Flux.RNN(current_input_size => hidden_size, Flux.relu)
                backward_rnn = Flux.RNN(current_input_size => hidden_size, Flux.relu)
                push!(layers, Flux.Parallel(vcat, forward_rnn, backward_rnn))
                current_input_size = 2 * hidden_size  # Output size is doubled for bidirectional
            else
                # Unidirectional RNN
                push!(layers, Flux.RNN(current_input_size => hidden_size, Flux.relu))
                current_input_size = hidden_size
            end
        end
    end
    
    # Add output layer
    push!(layers, Flux.Dense(current_input_size => output_size))
    
    # Create the model
    model = Flux.Chain(layers...)
    
    # Create the network
    return RecurrentNetwork(
        model,
        input_size,
        hidden_size,
        num_layers,
        output_size,
        network_type,
        bidirectional,
        optimizer,
        Float32[],
        now(),
        nothing
    )
end

"""
    train!(network::RecurrentNetwork, X::Array{Float32, 3}, y::Matrix{Float32};
          epochs=100, batch_size=32, validation_split=0.2, shuffle=true,
          verbose=true, early_stopping=true, patience=10)

Train the recurrent neural network on the provided data.

# Arguments
- `network::RecurrentNetwork`: The network to train
- `X::Array{Float32, 3}`: Input data (features × time steps × samples)
- `y::Matrix{Float32}`: Target data (samples × outputs)
- `epochs=100`: Number of training epochs
- `batch_size=32`: Batch size
- `validation_split=0.2`: Fraction of data to use for validation
- `shuffle=true`: Whether to shuffle the data
- `verbose=true`: Whether to print progress
- `early_stopping=true`: Whether to use early stopping
- `patience=10`: Number of epochs with no improvement before early stopping

# Returns
- `Dict`: Training history
"""
function train!(network::RecurrentNetwork, X::Array{Float32, 3}, y::Matrix{Float32};
               epochs=100, batch_size=32, validation_split=0.2, shuffle=true,
               verbose=true, early_stopping=true, patience=10)
    # Check input dimensions
    n_features, n_timesteps, n_samples = size(X)
    @assert n_features == network.input_size "Input size mismatch: expected $(network.input_size), got $n_features"
    @assert size(y, 1) == n_samples "Number of samples mismatch between X and y"
    @assert size(y, 2) == network.output_size "Output size mismatch: expected $(network.output_size), got $(size(y, 2))"
    
    # Split data into training and validation sets
    if validation_split > 0
        n_val = round(Int, n_samples * validation_split)
        n_train = n_samples - n_val
        
        if shuffle
            indices = randperm(n_samples)
            train_indices = indices[1:n_train]
            val_indices = indices[(n_train+1):end]
        else
            train_indices = 1:n_train
            val_indices = (n_train+1):n_samples
        end
        
        X_train = X[:, :, train_indices]
        y_train = y[train_indices, :]
        X_val = X[:, :, val_indices]
        y_val = y[val_indices, :]
    else
        X_train = X
        y_train = y
        X_val = X[:, :, 1:min(1000, n_samples)]  # Use a small subset for validation if no split
        y_val = y[1:min(1000, n_samples), :]
    end
    
    # Create data loaders
    train_data = []
    for i in 1:n_train
        push!(train_data, (X_train[:, :, i], y_train[i, :]))
    end
    train_loader = Flux.DataLoader(train_data, batchsize=batch_size, shuffle=shuffle)
    
    # Reset model state before training
    Flux.reset!(network.model)
    
    # Define loss function
    function loss(x, y)
        # Reset state for each batch
        Flux.reset!(network.model)
        return Flux.mse(network.model(x), y)
    end
    
    # Initialize training history
    train_losses = Float32[]
    val_losses = Float32[]
    best_val_loss = Inf32
    best_params = Flux.params(network.model)
    patience_counter = 0
    
    # Training loop
    for epoch in 1:epochs
        # Train for one epoch
        epoch_losses = Float32[]
        for (x_batch, y_batch) in train_loader
            # Compute gradients and update parameters
            gs = Flux.gradient(Flux.params(network.model)) do
                batch_loss = loss(x_batch, y_batch)
                push!(epoch_losses, batch_loss)
                return batch_loss
            end
            
            Flux.Optimise.update!(network.optimizer, Flux.params(network.model), gs)
        end
        
        # Compute average training loss
        train_loss = mean(epoch_losses)
        push!(train_losses, train_loss)
        
        # Compute validation loss
        val_loss = 0.0f0
        for i in 1:n_val
            val_loss += loss(X_val[:, :, i], y_val[i, :])
        end
        val_loss /= n_val
        push!(val_losses, val_loss)
        
        # Update network loss history
        push!(network.loss_history, train_loss)
        
        # Print progress
        if verbose && (epoch == 1 || epoch % 10 == 0 || epoch == epochs)
            println("Epoch $epoch/$epochs: train_loss=$train_loss, val_loss=$val_loss")
        end
        
        # Early stopping
        if early_stopping
            if val_loss < best_val_loss
                best_val_loss = val_loss
                best_params = Flux.params(network.model)
                patience_counter = 0
            else
                patience_counter += 1
                if patience_counter >= patience
                    if verbose
                        println("Early stopping at epoch $epoch")
                    end
                    # Restore best parameters
                    Flux.loadparams!(network.model, best_params)
                    break
                end
            end
        end
    end
    
    # Update last trained timestamp
    network.last_trained = now()
    
    # Return training history
    return Dict(
        "train_loss" => train_losses,
        "val_loss" => val_losses,
        "epochs" => length(train_losses)
    )
end

"""
    predict(network::RecurrentNetwork, X::Array{Float32, 3})

Make predictions with the recurrent neural network.

# Arguments
- `network::RecurrentNetwork`: The network to use
- `X::Array{Float32, 3}`: Input data (features × time steps × samples)

# Returns
- `Matrix{Float32}`: Predicted outputs (samples × outputs)
"""
function predict(network::RecurrentNetwork, X::Array{Float32, 3})
    # Check input dimensions
    n_features, n_timesteps, n_samples = size(X)
    @assert n_features == network.input_size "Input size mismatch: expected $(network.input_size), got $n_features"
    
    # Make predictions
    predictions = zeros(Float32, n_samples, network.output_size)
    
    for i in 1:n_samples
        # Reset state for each sample
        Flux.reset!(network.model)
        predictions[i, :] = network.model(X[:, :, i])
    end
    
    return predictions
end

"""
    save_model(network::RecurrentNetwork, filepath::String)

Save the recurrent neural network to a file.

# Arguments
- `network::RecurrentNetwork`: The network to save
- `filepath::String`: Path to save the model

# Returns
- `Bool`: true if successful
"""
function save_model(network::RecurrentNetwork, filepath::String)
    try
        @save filepath network
        return true
    catch e
        println("Error saving model: $e")
        return false
    end
end

"""
    load_model(filepath::String)

Load a recurrent neural network from a file.

# Arguments
- `filepath::String`: Path to the model file

# Returns
- `RecurrentNetwork`: The loaded network
"""
function load_model(filepath::String)
    try
        network = nothing
        @load filepath network
        return network
    catch e
        println("Error loading model: $e")
        return nothing
    end
end

end # module
