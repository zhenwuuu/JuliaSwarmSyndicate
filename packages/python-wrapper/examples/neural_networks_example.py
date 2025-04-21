"""
Example script demonstrating the use of neural networks in JuliaOS.

This script shows how to create, train, and use neural network models with JuliaOS.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime

from juliaos import JuliaOS
from juliaos.neural_networks import NeuralNetworkModel, ModelType, AgentNeuralNetworks


def generate_sine_data(num_samples, sequence_length, noise_level=0.1):
    """
    Generate sine wave data for demonstration.
    
    Args:
        num_samples: Number of samples to generate
        sequence_length: Length of each sequence
        noise_level: Level of noise to add
    
    Returns:
        tuple: Input and target data
    """
    x_data = []
    y_data = []
    
    for i in range(num_samples):
        # Generate random phase
        phase = 2 * np.pi * np.random.rand()
        
        # Generate time points
        t = np.linspace(0, 2 * np.pi, sequence_length)
        
        # Generate sine wave with noise
        x = np.sin(t + phase) + noise_level * np.random.randn(sequence_length)
        
        # Target is the next value in the sequence
        y = np.sin(t[1:] + phase)
        
        x_data.append(x[:-1])
        y_data.append(y)
    
    # Convert to arrays
    x_array = np.array(x_data).T
    y_array = np.array(y_data).T
    
    return x_array, y_array


def plot_predictions(x_test, y_test, y_pred, num_samples=5):
    """
    Plot model predictions against actual values.
    
    Args:
        x_test: Test input data
        y_test: Test target data
        y_pred: Model predictions
        num_samples: Number of samples to plot
    """
    # Get random indices
    indices = np.random.randint(0, x_test.shape[1], num_samples)
    
    # Create plot
    fig, axes = plt.subplots(num_samples, 1, figsize=(10, 2 * num_samples))
    
    for i, idx in enumerate(indices):
        # Get input, target, and prediction
        x = x_test[:, idx]
        y = y_test[:, idx]
        pred = y_pred[:, idx]
        
        # Plot
        ax = axes[i] if num_samples > 1 else axes
        ax.plot(range(len(x)), x, label="Input")
        ax.plot(range(len(x), len(x) + len(y)), y, label="Target")
        ax.plot(range(len(x), len(x) + len(pred)), pred, label="Prediction")
        
        # Add title and legend
        ax.set_title(f"Sample {i+1}")
        ax.legend()
    
    plt.tight_layout()
    plt.savefig("predictions.png")
    print("Predictions plot saved to predictions.png")


async def demonstrate_neural_networks():
    """Demonstrate the neural networks functionality."""
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create neural network model
        nn_model = NeuralNetworkModel(juliaos.bridge)
        
        # Generate data
        sequence_length = 20
        num_samples = 1000
        
        print("Generating sine wave data...")
        x_data, y_data = generate_sine_data(num_samples, sequence_length)
        
        # Split data
        train_ratio = 0.8
        train_size = int(np.floor(x_data.shape[1] * train_ratio))
        
        x_train = x_data[:, :train_size]
        y_train = y_data[:, :train_size]
        x_test = x_data[:, train_size:]
        y_test = y_data[:, train_size:]
        
        print("Data shape:")
        print(f"  x_train: {x_train.shape}")
        print(f"  y_train: {y_train.shape}")
        print(f"  x_test: {x_test.shape}")
        print(f"  y_test: {y_test.shape}")
        
        # Create dense neural network
        print("\nCreating dense neural network...")
        model = await nn_model.create_dense_network(
            input_size=sequence_length - 1,
            hidden_sizes=[32, 16],
            output_size=sequence_length - 1
        )
        
        # Train model
        print("Training model...")
        result = await nn_model.train_model(
            model=model,
            x=x_train,
            y=y_train,
            epochs=50,
            batch_size=32,
            validation_split=0.2,
            verbose=True
        )
        
        # Plot training history
        history = result["history"]
        plt.figure(figsize=(10, 6))
        plt.plot(history["loss"], label="Training Loss")
        
        if "val_loss" in history:
            plt.plot(history["val_loss"], label="Validation Loss")
        
        plt.xlabel("Epoch")
        plt.ylabel("Loss")
        plt.title("Training History")
        plt.legend()
        plt.savefig("training_history.png")
        print("Training history plot saved to training_history.png")
        
        # Make predictions
        print("Making predictions...")
        predictions = await nn_model.predict(result["model"], x_test)
        
        # Calculate metrics
        mse = np.mean((predictions - y_test) ** 2)
        mae = np.mean(np.abs(predictions - y_test))
        
        print(f"Test MSE: {mse:.6f}")
        print(f"Test MAE: {mae:.6f}")
        
        # Plot predictions
        plot_predictions(x_test, y_test, predictions)
        
        # Save model
        print("Saving model...")
        save_path = "sine_predictor_model.bson"
        save_success = await nn_model.save_model(
            model=result["model"],
            file_path=save_path,
            metadata={"description": "Sine wave predictor model"}
        )
        
        if save_success:
            print(f"Model saved to {save_path}")
        else:
            print("Failed to save model")
        
        # Load model
        print("Loading model...")
        loaded = await nn_model.load_model(save_path)
        
        if loaded:
            print("Model loaded successfully")
            print(f"Metadata: {loaded['metadata']}")
        else:
            print("Failed to load model")
        
        # Demonstrate agent neural networks
        print("\n=== Agent Neural Networks ===")
        
        # Create an agent ID
        agent_id = f"agent-{hash(datetime.now()) % 10000}"
        agent_nn = AgentNeuralNetworks(juliaos.bridge, agent_id)
        
        # Create agent model
        print(f"Creating neural network for agent {agent_id}...")
        model_info = await agent_nn.create_model(
            model_name="sine_predictor",
            model_type=ModelType.DENSE,
            params={
                "input_size": sequence_length - 1,
                "hidden_sizes": [32, 16],
                "output_size": sequence_length - 1
            }
        )
        
        print(f"Created model: {model_info['model_name']}")
        
        # Train agent model
        print("Training agent model...")
        training_result = await agent_nn.train_model(
            model_name="sine_predictor",
            x=x_train,
            y=y_train,
            training_params={
                "epochs": 50,
                "batch_size": 32,
                "validation_split": 0.2,
                "verbose": True
            }
        )
        
        # Make predictions with agent model
        print("Making predictions with agent model...")
        agent_predictions = await agent_nn.predict("sine_predictor", x_test)
        
        # Calculate metrics
        agent_mse = np.mean((agent_predictions - y_test) ** 2)
        agent_mae = np.mean(np.abs(agent_predictions - y_test))
        
        print(f"Agent model Test MSE: {agent_mse:.6f}")
        print(f"Agent model Test MAE: {agent_mae:.6f}")
        
        # List agent models
        print("Listing agent models...")
        models = await agent_nn.list_models()
        
        for model in models:
            print(f"  {model['model_name']} ({model['model_type']}) - Trained: {model['trained']}")
        
        # Save agent models
        print("Saving agent models...")
        save_dir = "agent_models_backup"
        save_result = await agent_nn.save_models(save_dir)
        
        print(f"Saved {len(save_result['saved_models'])} models to {save_dir}")
        
        # Delete agent model
        print("Deleting agent model...")
        delete_result = await agent_nn.delete_model("sine_predictor")
        
        if delete_result:
            print("Model deleted successfully")
        else:
            print("Failed to delete model")
        
        # Load agent models
        print("Loading agent models...")
        load_result = await agent_nn.load_models(save_dir)
        
        print(f"Loaded {len(load_result['loaded_models'])} models")
        
        # List agent models again
        print("Listing agent models after loading...")
        models = await agent_nn.list_models()
        
        for model in models:
            print(f"  {model['model_name']} ({model['model_type']}) - Trained: {model['trained']}")
    
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS")


async def main():
    """Main function to run the example."""
    print("=== Neural Networks Example ===")
    
    # Set random seed for reproducibility
    np.random.seed(42)
    
    await demonstrate_neural_networks()
    
    print("\nExample completed successfully!")


if __name__ == "__main__":
    asyncio.run(main())
