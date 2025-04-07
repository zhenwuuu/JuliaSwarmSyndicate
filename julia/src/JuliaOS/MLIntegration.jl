module MLIntegration

using Statistics
using LinearAlgebra
using Random
using MLJ
using ..Algorithms # Use the module included by JuliaOS

# Check optional dependencies
const FLUX_AVAILABLE = try
    using Flux
    true
catch
    false
end

# Export functionality
export HybridMLOptimizer, optimize_hyperparameters, optimize_architecture
export initialize_model, train_model_with_swarm, feature_selection
export MLHyperConfig, NeuralArchConfig, FeatureSelectionConfig
export create_ensemble, optimize_ensemble_weights, HybridNeuralSwarm

"""
    MLHyperConfig

Configuration for hyperparameter optimization.
"""
struct MLHyperConfig
    algorithm::String
    parameters::Dict{String, Any}
    swarm_size::Int
    hyperparameters::Dict{String, Tuple{Float64, Float64}}
    cv_folds::Int
    scoring::String
    max_iterations::Int
end

"""
    NeuralArchConfig

Configuration for neural network architecture optimization.
"""
struct NeuralArchConfig
    algorithm::String
    parameters::Dict{String, Any}
    swarm_size::Int
    max_layers::Int
    min_layers::Int
    max_units_per_layer::Int
    min_units_per_layer::Int
    activation_functions::Vector{String}
    max_iterations::Int
end

"""
    FeatureSelectionConfig

Configuration for feature selection optimization.
"""
struct FeatureSelectionConfig
    algorithm::String
    parameters::Dict{String, Any}
    swarm_size::Int
    max_features::Int
    scoring::String
    cv_folds::Int
    max_iterations::Int
end

"""
    HybridMLOptimizer

Main optimizer that combines swarm intelligence with machine learning.
"""
struct HybridMLOptimizer
    algorithm::String
    swarm_size::Int
    dimension::Int
    bounds::Vector{Tuple{Float64, Float64}}
    ml_model::Any
    fitness_function::Function
    swarm::Any
    best_position::Vector{Float64}
    best_fitness::Float64
    
    function HybridMLOptimizer(algorithm::String, swarm_size::Int, dimension::Int, 
                              bounds::Vector{Tuple{Float64, Float64}}, ml_model)
        return new(algorithm, swarm_size, dimension, bounds, ml_model, x -> 0.0, nothing, [], Inf)
    end
end

"""
    HybridNeuralSwarm

Combined neural network and swarm intelligence system.
"""
struct HybridNeuralSwarm
    neural_model::Any
    swarm_optimizer::Any
    input_dimension::Int
    output_dimension::Int
    hidden_architecture::Vector{Int}
    
    function HybridNeuralSwarm(input_dim::Int, output_dim::Int, hidden_arch::Vector{Int})
        return new(nothing, nothing, input_dim, output_dim, hidden_arch)
    end
end

"""
    optimize_hyperparameters(X, y, ml_model, config::MLHyperConfig)

Optimize hyperparameters for a machine learning model using swarm intelligence.
"""
function optimize_hyperparameters(X, y, ml_model, config::MLHyperConfig)
    # Extract hyperparameter bounds
    param_names = collect(keys(config.hyperparameters))
    bounds = [config.hyperparameters[name] for name in param_names]
    
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Initialize algorithm
    dimension = length(bounds)
    initialize!(algorithm, config.swarm_size, dimension, bounds)
    
    # Define fitness function for hyperparameter optimization
    function fitness_function(position)
        # Map position to hyperparameters
        hyperparams = Dict{String, Any}()
        
        for (i, name) in enumerate(param_names)
            # Handle different parameter types
            if name == "n_estimators" || name == "max_depth" || name == "min_samples_split"
                hyperparams[name] = round(Int, position[i])
            else
                hyperparams[name] = position[i]
            end
        end
        
        # Set model hyperparameters
        model = set_hyperparameters(ml_model, hyperparams)
        
        # Evaluate using cross-validation
        try
            # Use MLJ's cross-validation
            cv = CV(nfolds=config.cv_folds)
            scores = evaluate(model, X, y, resampling=cv, measure=config.scoring)
            return -mean(scores)  # Negative because we're minimizing
        catch e
            # If there's an error with these parameters, return a bad score
            return 1000.0
        end
    end
    
    # Run optimization
    best_scores = Float64[]
    
    for i in 1:config.max_iterations
        update_positions!(algorithm, fitness_function)
        
        # Track progress
        best_score = -get_best_fitness(algorithm)  # Negate back to positive
        push!(best_scores, best_score)
        
        @info "Iteration $i: Best score = $best_score"
    end
    
    # Get best hyperparameters
    best_position = get_best_position(algorithm)
    
    # Map to hyperparameters
    best_hyperparams = Dict{String, Any}()
    
    for (i, name) in enumerate(param_names)
        # Handle different parameter types
        if name == "n_estimators" || name == "max_depth" || name == "min_samples_split"
            best_hyperparams[name] = round(Int, best_position[i])
        else
            best_hyperparams[name] = best_position[i]
        end
    end
    
    # Create best model
    best_model = set_hyperparameters(ml_model, best_hyperparams)
    
    return best_model, best_hyperparams, best_scores
end

"""
    optimize_architecture(X, y, config::NeuralArchConfig)

Optimize neural network architecture using swarm intelligence.
"""
function optimize_architecture(X, y, config::NeuralArchConfig)
    if !FLUX_AVAILABLE
        error("Flux.jl is required for neural architecture optimization but not available")
    end
    
    # Calculate dimension based on max layers
    # For each layer: number of units + activation function choice
    dimension = 2 * config.max_layers
    
    # Create bounds:
    # - For odd indices: layer units (continuous, will be rounded)
    # - For even indices: activation function index (continuous, will be rounded)
    bounds = Vector{Tuple{Float64, Float64}}(undef, dimension)
    
    for i in 1:dimension
        if i % 2 == 1
            # Layer units
            bounds[i] = (config.min_units_per_layer, config.max_units_per_layer)
        else
            # Activation function index (1 to length of activation functions)
            bounds[i] = (1.0, length(config.activation_functions))
        end
    end
    
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, dimension, bounds)
    
    # Define fitness function for architecture optimization
    function fitness_function(position)
        # Decode architecture from position
        architecture = decode_architecture(position, config)
        
        # Create and train model
        model = create_neural_network(architecture, size(X, 2), size(y, 2))
        
        # Evaluate model with cross-validation
        try
            score = evaluate_neural_network(model, X, y)
            return -score  # Negative because we're minimizing
        catch e
            # If there's an error with this architecture, return a bad score
            return 1000.0
        end
    end
    
    # Run optimization
    best_scores = Float64[]
    
    for i in 1:config.max_iterations
        update_positions!(algorithm, fitness_function)
        
        # Track progress
        best_score = -get_best_fitness(algorithm)  # Negate back to positive
        push!(best_scores, best_score)
        
        @info "Iteration $i: Best architecture score = $best_score"
    end
    
    # Get best architecture
    best_position = get_best_position(algorithm)
    best_architecture = decode_architecture(best_position, config)
    
    # Create and train final model
    best_model = create_neural_network(best_architecture, size(X, 2), size(y, 2))
    train_neural_network!(best_model, X, y)
    
    # Return results
    return Dict(
        "best_architecture" => best_architecture,
        "best_score" => best_scores[end],
        "score_history" => best_scores,
        "best_model" => best_model
    )
end

"""
    feature_selection(X, y, ml_model, config::FeatureSelectionConfig)

Perform feature selection for a machine learning model using swarm intelligence.
"""
function feature_selection(X, y, ml_model, config::FeatureSelectionConfig)
    # The dimension is the number of features
    n_features = size(X, 2)
    
    # Set max features to consider
    max_features = min(config.max_features, n_features)
    
    # Create binary bounds (0-1, will be thresholded)
    bounds = [(0.0, 1.0) for _ in 1:n_features]
    
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, n_features, bounds)
    
    # Define fitness function for feature selection
    function fitness_function(position)
        # Convert continuous position to binary feature selection
        # Sort position values and take top max_features indices
        sorted_indices = sortperm(position, rev=true)
        selected_indices = sorted_indices[1:max_features]
        
        # Create mask
        mask = zeros(Int, n_features)
        mask[selected_indices] .= 1
        
        # If no features selected, select at least one
        if sum(mask) == 0
            mask[1] = 1
        end
        
        # Select features
        X_selected = X[:, mask .== 1]
        
        # Evaluate model with selected features
        try
            score = cross_validate(ml_model, X_selected, y, config.cv_folds, config.scoring)
            
            # Add penalty for using more features (small penalty factor)
            penalty = 0.001 * sum(mask) / n_features
            
            return -(score - penalty)  # Negative because we're minimizing
        catch e
            # If there's an error with these features, return a bad score
            return 1000.0
        end
    end
    
    # Run optimization
    best_scores = Float64[]
    
    for i in 1:config.max_iterations
        update_positions!(algorithm, fitness_function)
        
        # Track progress
        best_score = -get_best_fitness(algorithm)  # Negate back to positive
        push!(best_scores, best_score)
        
        @info "Iteration $i: Best feature selection score = $best_score"
    end
    
    # Get best feature selection
    best_position = get_best_position(algorithm)
    
    # Convert to binary selection
    sorted_indices = sortperm(best_position, rev=true)
    selected_indices = sorted_indices[1:max_features]
    
    mask = zeros(Int, n_features)
    mask[selected_indices] .= 1
    
    # Return results
    return Dict(
        "selected_features" => findall(x -> x == 1, mask),
        "selection_mask" => mask,
        "best_score" => best_scores[end],
        "score_history" => best_scores
    )
end

"""
    initialize_model(model_type::String, config::Dict)

Initialize a machine learning model of specified type with given configuration.
"""
function initialize_model(model_type::String, config::Dict)
    if model_type == "neural_network" && FLUX_AVAILABLE
        # Initialize a neural network using Flux
        input_dim = config["input_dim"]
        output_dim = config["output_dim"]
        hidden_dims = config["hidden_dims"]
        
        # Create layers
        layers = []
        
        # Input layer to first hidden layer
        push!(layers, Flux.Dense(input_dim, hidden_dims[1], Flux.relu))
        
        # Hidden layers
        for i in 1:(length(hidden_dims)-1)
            push!(layers, Flux.Dense(hidden_dims[i], hidden_dims[i+1], Flux.relu))
        end
        
        # Output layer
        push!(layers, Flux.Dense(hidden_dims[end], output_dim))
        
        # Create model
        model = Flux.Chain(layers...)
        
        return model
    elseif model_type == "random_forest" && SCIKIT_LEARN_PY_AVAILABLE
        # Initialize a random forest using scikit-learn via PyCall
        n_estimators = get(config, "n_estimators", 100)
        max_depth = get(config, "max_depth", nothing)
        
        sklearn_ensemble = PyCall.pyimport("sklearn.ensemble")
        model = sklearn_ensemble.RandomForestRegressor(
            n_estimators=n_estimators,
            max_depth=max_depth
        )
        
        return model
    else
        error("Unsupported model type or required library not available")
    end
end

"""
    train_model_with_swarm(model, X, y, config::Dict)

Train a machine learning model using swarm intelligence for optimization.
"""
function train_model_with_swarm(model, X, y, config::Dict)
    if FLUX_AVAILABLE && model isa Flux.Chain
        # Training Flux models with swarm intelligence
        
        # Extract parameters
        algorithm = get(config, "algorithm", "pso")
        swarm_size = get(config, "swarm_size", 30)
        max_iterations = get(config, "max_iterations", 100)
        learning_rate = get(config, "learning_rate", 0.01)
        
        # Get total number of parameters
        params = Flux.params(model)
        flat_params, unflatten = Flux.destructure(model)
        n_params = length(flat_params)
        
        # Create bounds for parameters
        bounds = [(-5.0, 5.0) for _ in 1:n_params]
        
        # Create algorithm instance
        algorithm_params = Dict(
            "inertia_weight" => get(config, "inertia_weight", 0.7),
            "cognitive_coef" => get(config, "cognitive_coef", 1.5),
            "social_coef" => get(config, "social_coef", 1.5)
        )
        
        alg = create_algorithm(algorithm, algorithm_params)
        
        # Initialize algorithm
        initialize!(alg, swarm_size, n_params, bounds)
        
        # Define fitness function (loss function)
        function fitness_function(position)
            # Restructure model with new parameters
            new_model = unflatten(position)
            
            # Calculate loss
            loss = 0.0
            
            # For regression
            if size(y, 2) == 1
                preds = new_model(X')
                loss = mean((preds .- y').^2)
            else
                # For classification
                preds = new_model(X')
                loss = -sum(y' .* log.(preds .+ 1e-10)) / size(X, 1)
            end
            
            return loss
        end
        
        # Run optimization
        best_losses = Float64[]
        
        for i in 1:max_iterations
            update_positions!(alg, fitness_function)
            
            # Track progress
            best_loss = get_best_fitness(alg)
            push!(best_losses, best_loss)
            
            @info "Iteration $i: Best loss = $best_loss"
        end
        
        # Get best parameters
        best_position = get_best_position(alg)
        
        # Update model with best parameters
        best_model = unflatten(best_position)
        
        return Dict(
            "model" => best_model,
            "loss_history" => best_losses,
            "best_loss" => best_losses[end]
        )
    else
        error("Unsupported model type or required library not available")
    end
end

"""
    create_ensemble(models::Vector, weights::Vector{Float64})

Create an ensemble of machine learning models with given weights.
"""
function create_ensemble(models::Vector, weights::Vector{Float64})
    if length(models) != length(weights)
        error("Number of models must match number of weights")
    end
    
    # Normalize weights
    normalized_weights = weights ./ sum(weights)
    
    # Create ensemble function
    function ensemble_predict(X)
        predictions = []
        
        for (i, model) in enumerate(models)
            if model isa Flux.Chain && FLUX_AVAILABLE
                # Flux model
                pred = model(X')
                push!(predictions, Array(pred'))
            elseif SCIKIT_LEARN_PY_AVAILABLE
                # scikit-learn model
                pred = model.predict(X)
                push!(predictions, pred)
            else
                error("Unsupported model type in ensemble")
            end
        end
        
        # Weighted sum of predictions
        weighted_preds = zeros(size(predictions[1]))
        
        for i in 1:length(models)
            weighted_preds .+= normalized_weights[i] .* predictions[i]
        end
        
        return weighted_preds
    end
    
    return Dict(
        "predict" => ensemble_predict,
        "models" => models,
        "weights" => normalized_weights
    )
end

"""
    optimize_ensemble_weights(models::Vector, X, y, config::Dict)

Optimize the weights of an ensemble of models using swarm intelligence.
"""
function optimize_ensemble_weights(models::Vector, X, y, config::Dict)
    # Extract parameters
    algorithm = get(config, "algorithm", "pso")
    swarm_size = get(config, "swarm_size", 30)
    max_iterations = get(config, "max_iterations", 100)
    
    n_models = length(models)
    
    # Create bounds for weights (0 to 1)
    bounds = [(0.0, 1.0) for _ in 1:n_models]
    
    # Create algorithm instance
    algorithm_params = Dict(
        "inertia_weight" => get(config, "inertia_weight", 0.7),
        "cognitive_coef" => get(config, "cognitive_coef", 1.5),
        "social_coef" => get(config, "social_coef", 1.5)
    )
    
    alg = create_algorithm(algorithm, algorithm_params)
    
    # Initialize algorithm
    initialize!(alg, swarm_size, n_models, bounds)
    
    # Define fitness function (loss function)
    function fitness_function(position)
        # Normalize weights
        weights = position ./ sum(position)
        
        # Create predictions for each model
        predictions = []
        
        for model in models
            if model isa Flux.Chain && FLUX_AVAILABLE
                # Flux model
                pred = model(X')
                push!(predictions, Array(pred'))
            elseif SCIKIT_LEARN_PY_AVAILABLE
                # scikit-learn model
                pred = model.predict(X)
                push!(predictions, pred)
            else
                error("Unsupported model type in ensemble")
            end
        end
        
        # Weighted sum of predictions
        weighted_preds = zeros(size(predictions[1]))
        
        for i in 1:n_models
            weighted_preds .+= weights[i] .* predictions[i]
        end
        
        # Calculate loss
        if size(y, 2) == 1 || length(size(y)) == 1
            # Regression
            loss = mean((weighted_preds .- y).^2)
        else
            # Classification
            loss = -sum(y .* log.(weighted_preds .+ 1e-10)) / size(X, 1)
        end
        
        return loss
    end
    
    # Run optimization
    best_losses = Float64[]
    
    for i in 1:max_iterations
        update_positions!(alg, fitness_function)
        
        # Track progress
        best_loss = get_best_fitness(alg)
        push!(best_losses, best_loss)
        
        @info "Iteration $i: Best ensemble loss = $best_loss"
    end
    
    # Get best weights
    best_position = get_best_position(alg)
    
    # Normalize weights
    best_weights = best_position ./ sum(best_position)
    
    # Create ensemble with best weights
    ensemble = create_ensemble(models, best_weights)
    
    return Dict(
        "ensemble" => ensemble,
        "weights" => best_weights,
        "loss_history" => best_losses,
        "best_loss" => best_losses[end]
    )
end

# Helper functions

"""
    decode_architecture(position, config::NeuralArchConfig)

Decode a neural network architecture from a position vector.
"""
function decode_architecture(position, config::NeuralArchConfig)
    architecture = []
    
    # Determine actual number of layers
    num_layers = config.min_layers
    
    for i in 1:2:length(position)
        if i > 2 * config.min_layers
            # Check if this layer is active (based on thresholding)
            layer_threshold = 0.5 * (config.max_units_per_layer - config.min_units_per_layer) + config.min_units_per_layer
            
            if position[i] >= layer_threshold
                num_layers += 1
            else
                break
            end
        end
    end
    
    # Limit to max layers
    num_layers = min(num_layers, config.max_layers)
    
    # Decode each layer
    for i in 1:num_layers
        pos_idx = 2 * i - 1
        
        if pos_idx > length(position)
            break
        end
        
        # Decode units
        units = round(Int, max(config.min_units_per_layer, min(position[pos_idx], config.max_units_per_layer)))
        
        # Decode activation function
        activation_idx = min(length(config.activation_functions), max(1, round(Int, position[pos_idx + 1])))
        activation = config.activation_functions[activation_idx]
        
        push!(architecture, (units, activation))
    end
    
    return architecture
end

"""
    create_neural_network(architecture, input_dim, output_dim)

Create a neural network with the specified architecture using Flux.
"""
function create_neural_network(architecture, input_dim, output_dim)
    if !FLUX_AVAILABLE
        error("Flux.jl is required but not available")
    end
    
    # Create layers
    layers = []
    
    # Input layer to first hidden layer
    activation_func = getfield(Flux, Symbol(architecture[1][2]))
    push!(layers, Flux.Dense(input_dim, architecture[1][1], activation_func))
    
    # Hidden layers
    for i in 2:length(architecture)
        prev_units = architecture[i-1][1]
        units = architecture[i][1]
        activation_func = getfield(Flux, Symbol(architecture[i][2]))
        
        push!(layers, Flux.Dense(prev_units, units, activation_func))
    end
    
    # Output layer
    push!(layers, Flux.Dense(architecture[end][1], output_dim))
    
    # Create model
    model = Flux.Chain(layers...)
    
    return model
end

"""
    train_neural_network!(model, X, y)

Train a neural network using standard methods.
"""
function train_neural_network!(model, X, y)
    if !FLUX_AVAILABLE
        error("Flux.jl is required but not available")
    end
    
    # Define loss function
    loss(x, y) = Flux.mse(model(x), y)
    
    # Prepare data
    data = [(X', y')]
    
    # Define optimizer
    opt = Flux.ADAM(0.01)
    
    # Train for 100 epochs
    for epoch in 1:100
        Flux.train!(loss, Flux.params(model), data, opt)
    end
    
    return model
end

"""
    evaluate_neural_network(model, X, y)

Evaluate a neural network on given data.
"""
function evaluate_neural_network(model, X, y)
    if !FLUX_AVAILABLE
        error("Flux.jl is required but not available")
    end
    
    # Make predictions
    predictions = model(X')
    
    # Calculate MSE loss
    mse = Flux.mse(predictions, y')
    
    return -mse  # Return negative MSE (higher is better for optimizer)
end

"""
    set_hyperparameters(model, hyperparams::Dict)

Set hyperparameters for a machine learning model.
"""
function set_hyperparameters(model, hyperparams::Dict)
    if SCIKIT_LEARN_PY_AVAILABLE && PyCall.pyisinstance(model, sklearn_py[].__class__)
        # Handle scikit-learn models
        model_class = model.__class__
        params = Dict{String, Any}(string(k) => v for (k, v) in hyperparams)
        
        # Create a new instance with the parameters
        new_model = model_class(; params...)
        
        return new_model
    else
        # For other model types, just return the original
        # This would need to be implemented for specific libraries
        @warn "Setting hyperparameters for this model type is not implemented"
        return model
    end
end

"""
    cross_validate(model, X, y, cv_folds::Int, scoring::String)

Perform cross-validation on a machine learning model.
"""
function cross_validate(model, X, y, cv_folds::Int, scoring::String)
    if SCIKIT_LEARN_PY_AVAILABLE && PyCall.pyisinstance(model, sklearn_py[].__class__)
        # Use scikit-learn's cross-validation
        sklearn_model_selection = PyCall.pyimport("sklearn.model_selection")
        
        scores = sklearn_model_selection.cross_val_score(
            model, X, y, cv=cv_folds, scoring=scoring
        )
        
        return mean(scores)
    else
        # Simple k-fold cross-validation for other models
        indices = collect(1:size(X, 1))
        fold_size = div(length(indices), cv_folds)
        
        scores = []
        
        for fold in 1:cv_folds
            # Get test indices for this fold
            start_idx = (fold - 1) * fold_size + 1
            end_idx = fold == cv_folds ? length(indices) : fold * fold_size
            
            test_indices = indices[start_idx:end_idx]
            train_indices = setdiff(indices, test_indices)
            
            # Split data
            X_train, y_train = X[train_indices, :], y[train_indices, :]
            X_test, y_test = X[test_indices, :], y[test_indices, :]
            
            # Train model
            if model isa Flux.Chain && FLUX_AVAILABLE
                # Train Flux model
                model_clone = deepcopy(model)
                train_neural_network!(model_clone, X_train, y_train)
                
                # Evaluate
                preds = model_clone(X_test')
                
                if scoring == "mse"
                    score = -Flux.mse(preds, y_test')
                elseif scoring == "accuracy"
                    preds_class = Flux.onecold(preds)
                    y_test_class = Flux.onecold(y_test')
                    score = mean(preds_class .== y_test_class)
                else
                    error("Unsupported scoring metric: $scoring")
                end
            else
                # Fall back to a simple scoring for other model types
                score = 0.0
            end
            
            push!(scores, score)
        end
        
        return mean(scores)
    end
end

end # module 