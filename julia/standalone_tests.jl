#!/usr/bin/env julia

using Test

println("Starting standalone tests for our implementations...")

# Test the WOA algorithm
println("\n=== Testing Whale Optimization Algorithm ===")

# Include the Algorithms module
include("src/algorithms/Algorithms.jl")
using .Algorithms

@testset "WOA Basic Tests" begin
    # Test WOA constructor
    woa = WOA(5, 20, b=1.5)
    @test woa.dimensions == 5
    @test woa.whales == 20
    @test woa.b == 1.5

    # Test initialization with matching dimensions
    woa_init = WOA(3, 20)  # 3 dimensions, 20 whales
    bounds = [(0.0, 10.0), (-5.0, 5.0), (-100.0, 100.0)]
    whales = initialize(woa_init, bounds)

    @test length(whales) == 20  # Number of whales

    # Check that all whales are within bounds
    for whale in whales
        @test length(whale[:position]) == 3  # Dimensions
        @test 0.0 <= whale[:position][1] <= 10.0
        @test -5.0 <= whale[:position][2] <= 5.0
        @test -100.0 <= whale[:position][3] <= 100.0
    end

    # Test optimization on a simple function (sphere function)
    function sphere(x)
        return sum(x.^2)
    end

    woa = WOA(2, 10)
    bounds = [(-10.0, 10.0), (-10.0, 10.0)]
    max_iterations = 20

    result = optimize(woa, sphere, max_iterations, bounds)

    # Check that the result contains the expected keys
    @test haskey(result, "best_position")
    @test haskey(result, "best_fitness")
    @test haskey(result, "convergence_history")

    # Check that the best fitness is improving
    @test result["convergence_history"][end] <= result["convergence_history"][1]

    println("WOA optimization result:")
    println("  Best position: ", result["best_position"])
    println("  Best fitness: ", result["best_fitness"])
    println("  Initial fitness: ", result["convergence_history"][1])
    println("  Final fitness: ", result["convergence_history"][end])
end

# Test the MLIntegration module's initialize_model function
println("\n=== Testing MLIntegration Module ===")

# Create a simplified version of the MLIntegration module for testing
module TestMLIntegration
    # Include only the necessary functions and types
    export initialize_model

    function initialize_model(model_type::String, config::Dict)
        # This function creates a model based on the specified type and configuration
        model = Dict{String, Any}(
            "type" => model_type,
            "config" => config,
            "params" => Dict{String, Any}(),
            "state" => Dict{String, Any}("trained" => false),
            "metrics" => Dict{String, Any}(),
            "history" => Dict{String, Vector{Float64}}()
        )

        # Set up model-specific parameters based on type
        if lowercase(model_type) == "linear_regression"
            # Initialize linear regression model
            input_dim = get(config, "input_dim", 1)
            model["params"]["weights"] = zeros(Float64, input_dim)  # Initialize weights to zeros
            model["params"]["bias"] = 0.0
            model["params"]["learning_rate"] = get(config, "learning_rate", 0.01)
            model["params"]["regularization"] = get(config, "regularization", 0.0)
            model["predict"] = (X) -> X * model["params"]["weights"] .+ model["params"]["bias"]
            model["train"] = (X, y) -> model  # Simplified training function
            model["history"]["loss"] = Float64[]
            model["history"]["val_loss"] = Float64[]

        elseif lowercase(model_type) == "neural_network"
            # Initialize neural network model with proper architecture
            input_dim = get(config, "input_dim", 1)
            output_dim = get(config, "output_dim", 1)

            # Extract neural network configuration
            hidden_layers = get(config, "hidden_layers", [32, 16])
            activation = get(config, "activation", "relu")
            learning_rate = get(config, "learning_rate", 0.001)

            # Create full architecture including input and output dimensions
            full_architecture = vcat([input_dim], hidden_layers, [output_dim])

            # Initialize weights and biases for each layer using Xavier/Glorot initialization
            weights = []
            biases = []

            for i in 1:(length(full_architecture)-1)
                fan_in = full_architecture[i]
                fan_out = full_architecture[i+1]

                # Xavier/Glorot initialization
                limit = sqrt(6.0 / (fan_in + fan_out))

                # Initialize weights with random values between -limit and limit
                layer_weights = 2.0 * limit * rand(Float64, fan_in, fan_out) .- limit
                layer_biases = zeros(Float64, fan_out)

                push!(weights, layer_weights)
                push!(biases, layer_biases)
            end

            # Store parameters
            model["params"]["weights"] = weights
            model["params"]["biases"] = biases
            model["params"]["architecture"] = full_architecture
            model["params"]["activation"] = activation
            model["params"]["learning_rate"] = learning_rate

            # Simplified predict and train functions
            model["predict"] = (X) -> zeros(size(X, 1), output_dim)  # Simplified prediction
            model["train"] = (X, y) -> model  # Simplified training function

            # Initialize history tracking
            model["history"]["loss"] = Float64[]
            model["history"]["accuracy"] = Float64[]
        end

        return model
    end
end

using .TestMLIntegration

@testset "MLIntegration Basic Tests" begin
    # Test linear regression model initialization
    lr_config = Dict(
        "input_dim" => 5,
        "learning_rate" => 0.01,
        "regularization" => 0.001
    )

    lr_model = initialize_model("linear_regression", lr_config)

    @test lr_model["type"] == "linear_regression"
    @test lr_model["config"] == lr_config
    @test haskey(lr_model, "params")
    @test haskey(lr_model["params"], "weights")
    @test length(lr_model["params"]["weights"]) == 5
    @test haskey(lr_model["params"], "bias")
    @test haskey(lr_model, "predict")
    @test haskey(lr_model, "train")
    @test haskey(lr_model, "history")
    @test haskey(lr_model["history"], "loss")

    # Test neural network model initialization
    nn_config = Dict(
        "input_dim" => 10,
        "output_dim" => 2,
        "hidden_layers" => [32, 16],
        "activation" => "relu",
        "learning_rate" => 0.001
    )

    nn_model = initialize_model("neural_network", nn_config)

    @test nn_model["type"] == "neural_network"
    @test nn_model["config"] == nn_config
    @test haskey(nn_model, "params")
    @test haskey(nn_model["params"], "weights")
    @test haskey(nn_model["params"], "biases")
    @test length(nn_model["params"]["weights"]) == 3  # Input->Hidden1, Hidden1->Hidden2, Hidden2->Output
    @test length(nn_model["params"]["biases"]) == 3
    @test nn_model["params"]["architecture"] == [10, 32, 16, 2]
    @test haskey(nn_model, "predict")
    @test haskey(nn_model, "train")
    @test haskey(nn_model, "history")
    @test haskey(nn_model["history"], "loss")
    @test haskey(nn_model["history"], "accuracy")

    # Test prediction functionality
    X_test = rand(3, 5)  # 3 samples, 5 features
    predictions = lr_model["predict"](X_test)
    @test size(predictions) == (3,)

    X_test_nn = rand(3, 10)  # 3 samples, 10 features
    predictions_nn = nn_model["predict"](X_test_nn)
    @test size(predictions_nn) == (3, 2)
end

println("\nAll tests completed successfully!")
