"""
Neural network models for JuliaOS.

This module provides classes for working with neural network models in JuliaOS.
"""

from enum import Enum
from typing import Dict, List, Optional, Tuple, Union, Any
import numpy as np
from datetime import datetime
import json

from ..bridge import JuliaBridge


class ModelType(str, Enum):
    """Neural network model types."""
    DENSE = "dense"
    RECURRENT = "recurrent"
    CONVOLUTIONAL = "convolutional"


class NeuralNetworkModel:
    """Neural network model for JuliaOS."""
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a neural network model.
        
        Args:
            bridge: JuliaBridge instance
        """
        self.bridge = bridge
    
    async def create_dense_network(
        self,
        input_size: int,
        hidden_sizes: List[int],
        output_size: int,
        activation: str = "relu",
        output_activation: str = "identity"
    ) -> Dict[str, Any]:
        """
        Create a dense neural network.
        
        Args:
            input_size: Number of input features
            hidden_sizes: Number of neurons in each hidden layer
            output_size: Number of output features
            activation: Activation function for hidden layers
            output_activation: Activation function for output layer
        
        Returns:
            Dict: Information about the created model
        """
        params = {
            "input_size": input_size,
            "hidden_sizes": hidden_sizes,
            "output_size": output_size,
            "activation": activation,
            "output_activation": output_activation
        }
        
        result = await self.bridge.execute("NeuralNetworks.create_model", [
            "dense",
            params
        ])
        
        return result
    
    async def create_recurrent_network(
        self,
        input_size: int,
        hidden_size: int,
        output_size: int,
        cell_type: str = "lstm"
    ) -> Dict[str, Any]:
        """
        Create a recurrent neural network.
        
        Args:
            input_size: Number of input features
            hidden_size: Number of hidden units in the recurrent layer
            output_size: Number of output features
            cell_type: Type of recurrent cell (lstm, gru, or rnn)
        
        Returns:
            Dict: Information about the created model
        """
        params = {
            "input_size": input_size,
            "hidden_size": hidden_size,
            "output_size": output_size,
            "cell_type": cell_type
        }
        
        result = await self.bridge.execute("NeuralNetworks.create_model", [
            "recurrent",
            params
        ])
        
        return result
    
    async def create_convolutional_network(
        self,
        input_shape: Tuple[int, int, int],
        num_filters: List[int],
        kernel_sizes: List[Tuple[int, int]],
        output_size: int
    ) -> Dict[str, Any]:
        """
        Create a convolutional neural network.
        
        Args:
            input_shape: Shape of input (channels, height, width)
            num_filters: Number of filters in each convolutional layer
            kernel_sizes: Kernel sizes for each convolutional layer
            output_size: Number of output features
        
        Returns:
            Dict: Information about the created model
        """
        params = {
            "input_shape": input_shape,
            "num_filters": num_filters,
            "kernel_sizes": kernel_sizes,
            "output_size": output_size
        }
        
        result = await self.bridge.execute("NeuralNetworks.create_model", [
            "convolutional",
            params
        ])
        
        return result
    
    async def train_model(
        self,
        model: Any,
        x: np.ndarray,
        y: np.ndarray,
        epochs: int = 10,
        batch_size: int = 32,
        optimizer: str = "ADAM",
        loss: str = "mse",
        validation_split: float = 0.0,
        shuffle: bool = True,
        verbose: bool = True
    ) -> Dict[str, Any]:
        """
        Train a neural network model.
        
        Args:
            model: The neural network model to train
            x: Input data
            y: Target data
            epochs: Number of training epochs
            batch_size: Batch size for training
            optimizer: Optimizer to use for training
            loss: Loss function to minimize
            validation_split: Fraction of data to use for validation
            shuffle: Whether to shuffle the data before training
            verbose: Whether to print training progress
        
        Returns:
            Dict: Training history and the trained model
        """
        training_params = {
            "epochs": epochs,
            "batch_size": batch_size,
            "optimizer": optimizer,
            "loss": loss,
            "validation_split": validation_split,
            "shuffle": shuffle,
            "verbose": verbose
        }
        
        result = await self.bridge.execute("NeuralNetworks.train_model", [
            model,
            x.tolist(),
            y.tolist(),
            training_params
        ])
        
        return result
    
    async def save_model(
        self,
        model: Any,
        file_path: str,
        include_metadata: bool = True,
        metadata: Dict[str, Any] = None
    ) -> bool:
        """
        Save a neural network model to a file.
        
        Args:
            model: The neural network model to save
            file_path: Path to save the model
            include_metadata: Whether to include metadata
            metadata: Additional metadata to save with the model
        
        Returns:
            bool: Whether the save was successful
        """
        if metadata is None:
            metadata = {}
        
        result = await self.bridge.execute("NeuralNetworks.save_model", [
            model,
            file_path,
            include_metadata,
            metadata
        ])
        
        return result
    
    async def load_model(self, file_path: str) -> Dict[str, Any]:
        """
        Load a neural network model from a file.
        
        Args:
            file_path: Path to load the model from
        
        Returns:
            Dict: The loaded model and metadata
        """
        result = await self.bridge.execute("NeuralNetworks.load_model", [file_path])
        
        return result
    
    async def predict(self, model: Any, x: np.ndarray) -> np.ndarray:
        """
        Make predictions using a neural network model.
        
        Args:
            model: The neural network model
            x: Input data
        
        Returns:
            np.ndarray: The model's predictions
        """
        result = await self.bridge.execute("NeuralNetworks.predict", [
            model,
            x.tolist()
        ])
        
        return np.array(result)
