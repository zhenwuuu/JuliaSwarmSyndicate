using Test
include("../src/MLIntegration.jl")

@testset "MLIntegration Module Tests" begin
    # Test MLHyperConfig constructor
    @testset "MLHyperConfig Constructor" begin
        param_ranges = Dict(
            "learning_rate" => (0.001, 0.1),
            "regularization" => (0.0, 0.1),
            "hidden_units_int" => (10.0, 100.0)
        )
        
        config = MLIntegration.MLHyperConfig("pso", param_ranges)
        
        @test config.algorithm == "pso"
        @test config.param_ranges == param_ranges
        @test config.swarm_size == 30  # Default value
        @test config.cv_folds == 5     # Default value
        @test config.scoring == "accuracy"  # Default value
        @test config.max_iterations == 100  # Default value
        
        # Test with custom parameters
        custom_config = MLIntegration.MLHyperConfig(
            "gwo", 
            param_ranges, 
            swarm_size=50, 
            cv_folds=3, 
            scoring="mse", 
            max_iterations=200
        )
        
        @test custom_config.algorithm == "gwo"
        @test custom_config.param_ranges == param_ranges
        @test custom_config.swarm_size == 50
        @test custom_config.cv_folds == 3
        @test custom_config.scoring == "mse"
        @test custom_config.max_iterations == 200
    end

    # Test initialize_model function
    @testset "initialize_model" begin
        # Test linear regression model initialization
        lr_config = Dict(
            "input_dim" => 5,
            "learning_rate" => 0.01,
            "regularization" => 0.001
        )
        
        lr_model = MLIntegration.initialize_model("linear_regression", lr_config)
        
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
            "learning_rate" => 0.001,
            "batch_size" => 64,
            "epochs" => 50
        )
        
        nn_model = MLIntegration.initialize_model("neural_network", nn_config)
        
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
    end

    # Test feature_selection function with synthetic data
    @testset "feature_selection" begin
        # Create synthetic data with 10 features, but only the first 3 are relevant
        n_samples = 100
        n_features = 10
        n_relevant = 3
        
        # Generate random data
        X = randn(n_samples, n_features)
        
        # Generate target variable that depends only on the first 3 features
        y = 2 * X[:, 1] - 3 * X[:, 2] + 0.5 * X[:, 3] + 0.1 * randn(n_samples)
        
        # Create a simple model
        model = MLIntegration.initialize_model("linear_regression", Dict("input_dim" => n_features))
        
        # Create feature selection configuration
        config = MLIntegration.FeatureSelectionConfig(
            "pso",
            Dict(),
            20,  # swarm_size
            5,   # max_features
            "mse",
            3,   # cv_folds
            30   # max_iterations
        )
        
        # Run feature selection
        result = MLIntegration.feature_selection(X, y, model, config)
        
        # Check that the result contains the expected keys
        @test haskey(result, "selected_features")
        @test haskey(result, "selection_mask")
        @test haskey(result, "best_score")
        @test haskey(result, "score_history")
        
        # Check that the number of selected features is at most max_features
        @test length(result["selected_features"]) <= config.max_features
        
        # Check that the selection mask has the right length
        @test length(result["selection_mask"]) == n_features
        
        # Check that the score history has the right length
        @test length(result["score_history"]) == config.max_iterations
        
        # Check that at least some of the relevant features are selected
        relevant_selected = sum(result["selection_mask"][1:n_relevant])
        @test relevant_selected > 0
    end

    # Test train_model_with_swarm function with synthetic data
    @testset "train_model_with_swarm" begin
        # Create synthetic data
        n_samples = 100
        n_features = 5
        
        # Generate random data
        X = randn(n_samples, n_features)
        
        # Generate target variable (simple linear relationship)
        true_weights = [0.5, -0.3, 0.2, -0.1, 0.4]
        y = X * true_weights + 0.1 * randn(n_samples)
        
        # Create a linear regression model
        model = MLIntegration.initialize_model("linear_regression", Dict("input_dim" => n_features))
        
        # Define parameter bounds for optimization
        param_bounds = Dict(
            "learning_rate" => (0.001, 0.1),
            "regularization" => (0.0, 0.01)
        )
        
        # Create configuration
        config = Dict(
            "algorithm" => "pso",
            "swarm_size" => 10,
            "max_iterations" => 20,
            "param_bounds" => param_bounds,
            "validation_split" => 0.2,
            "scoring" => "mse"
        )
        
        # Train the model with swarm optimization
        result = MLIntegration.train_model_with_swarm(model, X, y, config)
        
        # Check that the result contains the expected keys
        @test haskey(result, "model")
        @test haskey(result, "best_params")
        @test haskey(result, "score_history")
        @test haskey(result, "best_score")
        
        # Check that the best parameters are within bounds
        @test result["best_params"]["learning_rate"] >= param_bounds["learning_rate"][1]
        @test result["best_params"]["learning_rate"] <= param_bounds["learning_rate"][2]
        @test result["best_params"]["regularization"] >= param_bounds["regularization"][1]
        @test result["best_params"]["regularization"] <= param_bounds["regularization"][2]
        
        # Check that the score history has the right length
        @test length(result["score_history"]) == config["max_iterations"]
        
        # Check that the trained model can make predictions
        trained_model = result["model"]
        predictions = trained_model["predict"](X)
        @test length(predictions) == n_samples
    end
end
