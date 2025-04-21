"""
    FeedForward.jl - Feed-Forward Neural Network Implementation

This module provides a feed-forward neural network implementation for JuliaOS.
"""
module FeedForward

export FeedForwardNetwork, train!, predict, save_model, load_model

using Flux
using BSON: @save, @load
using Statistics
using Random
using Dates
using LinearAlgebra

"""
    FeedForwardNetwork

A feed-forward neural network model.

# Fields
- `model::Chain`: The Flux model
- `input_size::Int`: Number of input features
- `hidden_layers::Vector{Int}`: Sizes of hidden layers
- `output_size::Int`: Number of output features
- `activation::Function`: Activation function
- `output_activation::Function`: Output activation function
- `optimizer::Flux.Optimise.AbstractOptimiser`: Optimizer
- `loss_history::Vector{Float32}`: History of loss values during training
- `created::DateTime`: Creation timestamp
- `last_trained::Union{DateTime, Nothing}`: Last training timestamp
"""
mutable struct FeedForwardNetwork
    model::Flux.Chain
    input_size::Int
    hidden_layers::Vector{Int}
    output_size::Int
    activation::Function
    output_activation::Function
    optimizer::Flux.Optimise.AbstractOptimiser
    loss_history::Vector{Float32}
    created::DateTime
    last_trained::Union{DateTime, Nothing}
end

"""
    FeedForwardNetwork(input_size::Int, hidden_layers::Vector{Int}, output_size::Int;
                      activation=Flux.relu, output_activation=identity,
                      optimizer=Flux.ADAM(0.001))

Create a new feed-forward neural network.

# Arguments
- `input_size::Int`: Number of input features
- `hidden_layers::Vector{Int}`: Sizes of hidden layers
- `output_size::Int`: Number of output features
- `activation=Flux.relu`: Activation function for hidden layers
- `output_activation=identity`: Activation function for output layer
- `optimizer=Flux.ADAM(0.001)`: Optimizer for training

# Returns
- `FeedForwardNetwork`: The created network
"""
function FeedForwardNetwork(input_size::Int, hidden_layers::Vector{Int}, output_size::Int;
                           activation=Flux.relu, output_activation=identity,
                           optimizer=Flux.ADAM(0.001))
    # Build the layers
    layers = []
    
    # Input layer to first hidden layer
    if length(hidden_layers) > 0
        push!(layers, Flux.Dense(input_size => hidden_layers[1], activation))
        
        # Hidden layers
        for i in 1:(length(hidden_layers)-1)
            push!(layers, Flux.Dense(hidden_layers[i] => hidden_layers[i+1], activation))
        end
        
        # Last hidden layer to output layer
        push!(layers, Flux.Dense(hidden_layers[end] => output_size, output_activation))
    else
        # Direct input to output (no hidden layers)
        push!(layers, Flux.Dense(input_size => output_size, output_activation))
    end
    
    # Create the model
    model = Flux.Chain(layers...)
    
    # Create the network
    return FeedForwardNetwork(
        model,
        input_size,
        hidden_layers,
        output_size,
        activation,
        output_activation,
        optimizer,
        Float32[],
        now(),
        nothing
    )
end

"""
    train!(network::FeedForwardNetwork, X::Matrix{Float32}, y::Matrix{Float32};
          epochs=100, batch_size=32, validation_split=0.2, shuffle=true,
          verbose=true, early_stopping=true, patience=10)

Train the neural network on the provided data.

# Arguments
- `network::FeedForwardNetwork`: The network to train
- `X::Matrix{Float32}`: Input data (samples × features)
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
function train!(network::FeedForwardNetwork, X::Matrix{Float32}, y::Matrix{Float32};
               epochs=100, batch_size=32, validation_split=0.2, shuffle=true,
               verbose=true, early_stopping=true, patience=10)
    # Check input dimensions
    n_samples = size(X, 1)
    @assert size(X, 2) == network.input_size "Input size mismatch: expected $(network.input_size), got $(size(X, 2))"
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
        
        X_train = X[train_indices, :]
        y_train = y[train_indices, :]
        X_val = X[val_indices, :]
        y_val = y[val_indices, :]
    else
        X_train = X
        y_train = y
        X_val = X[1:min(1000, n_samples), :]  # Use a small subset for validation if no split
        y_val = y[1:min(1000, n_samples), :]
    end
    
    # Create data loaders
    train_data = Flux.DataLoader((X_train', y_train'), batchsize=batch_size, shuffle=shuffle)
    
    # Define loss function
    loss(x, y) = Flux.mse(network.model(x), y)
    
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
        for (x_batch, y_batch) in train_data
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
        val_loss = loss(X_val', y_val')
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
    predict(network::FeedForwardNetwork, X::Matrix{Float32})

Make predictions with the neural network.

# Arguments
- `network::FeedForwardNetwork`: The network to use
- `X::Matrix{Float32}`: Input data (samples × features)

# Returns
- `Matrix{Float32}`: Predicted outputs (samples × outputs)
"""
function predict(network::FeedForwardNetwork, X::Matrix{Float32})
    # Check input dimensions
    @assert size(X, 2) == network.input_size "Input size mismatch: expected $(network.input_size), got $(size(X, 2))"
    
    # Make predictions
    return network.model(X')'
end

"""
    save_model(network::FeedForwardNetwork, filepath::String)

Save the neural network to a file.

# Arguments
- `network::FeedForwardNetwork`: The network to save
- `filepath::String`: Path to save the model

# Returns
- `Bool`: true if successful
"""
function save_model(network::FeedForwardNetwork, filepath::String)
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

Load a neural network from a file.

# Arguments
- `filepath::String`: Path to the model file

# Returns
- `FeedForwardNetwork`: The loaded network
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
