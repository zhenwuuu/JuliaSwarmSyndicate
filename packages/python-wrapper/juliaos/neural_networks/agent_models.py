"""
Agent neural network models for JuliaOS.

This module provides classes for working with agent neural network models in JuliaOS.
"""

from enum import Enum
from typing import Dict, List, Optional, Tuple, Union, Any
import numpy as np
from datetime import datetime
import json

from ..bridge import JuliaBridge
from .models import ModelType


class AgentNeuralNetworks:
    """Neural network models for agents in JuliaOS."""
    
    def __init__(self, bridge: JuliaBridge, agent_id: str):
        """
        Initialize agent neural networks.
        
        Args:
            bridge: JuliaBridge instance
            agent_id: ID of the agent
        """
        self.bridge = bridge
        self.agent_id = agent_id
    
    async def create_model(
        self,
        model_name: str,
        model_type: ModelType,
        params: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Create a neural network model for the agent.
        
        Args:
            model_name: Name of the model
            model_type: Type of model
            params: Parameters for the model
        
        Returns:
            Dict: Information about the created model
        """
        result = await self.bridge.execute("NeuralNetworks.create_agent_model", [
            self.agent_id,
            model_name,
            model_type.value,
            params
        ])
        
        return result
    
    async def train_model(
        self,
        model_name: str,
        x: np.ndarray,
        y: np.ndarray,
        training_params: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Train a neural network model for the agent.
        
        Args:
            model_name: Name of the model
            x: Input data
            y: Target data
            training_params: Parameters for training
        
        Returns:
            Dict: Training results
        """
        if training_params is None:
            training_params = {}
        
        result = await self.bridge.execute("NeuralNetworks.train_agent_model", [
            self.agent_id,
            model_name,
            x.tolist(),
            y.tolist(),
            training_params
        ])
        
        return result
    
    async def get_model(self, model_name: str) -> Dict[str, Any]:
        """
        Get a neural network model for the agent.
        
        Args:
            model_name: Name of the model
        
        Returns:
            Dict: The model and its metadata
        """
        result = await self.bridge.execute("NeuralNetworks.get_agent_model", [
            self.agent_id,
            model_name
        ])
        
        return result
    
    async def predict(self, model_name: str, x: np.ndarray) -> np.ndarray:
        """
        Make predictions using an agent's neural network model.
        
        Args:
            model_name: Name of the model
            x: Input data
        
        Returns:
            np.ndarray: The model's predictions
        """
        result = await self.bridge.execute("NeuralNetworks.predict_with_agent_model", [
            self.agent_id,
            model_name,
            x.tolist()
        ])
        
        return np.array(result)
    
    async def list_models(self) -> List[Dict[str, Any]]:
        """
        List all neural network models for the agent.
        
        Returns:
            List[Dict]: Information about the models
        """
        result = await self.bridge.execute("NeuralNetworks.list_agent_models", [self.agent_id])
        
        return result
    
    async def delete_model(self, model_name: str) -> bool:
        """
        Delete a neural network model for the agent.
        
        Args:
            model_name: Name of the model
        
        Returns:
            bool: Whether the deletion was successful
        """
        result = await self.bridge.execute("NeuralNetworks.delete_agent_model", [
            self.agent_id,
            model_name
        ])
        
        return result
    
    async def save_models(self, directory: str) -> Dict[str, Any]:
        """
        Save all neural network models for the agent to a directory.
        
        Args:
            directory: Directory to save the models to
        
        Returns:
            Dict: Information about the saved models
        """
        result = await self.bridge.execute("NeuralNetworks.save_agent_models", [
            self.agent_id,
            directory
        ])
        
        return result
    
    async def load_models(self, directory: str) -> Dict[str, Any]:
        """
        Load neural network models for the agent from a directory.
        
        Args:
            directory: Directory to load the models from
        
        Returns:
            Dict: Information about the loaded models
        """
        result = await self.bridge.execute("NeuralNetworks.load_agent_models", [
            self.agent_id,
            directory
        ])
        
        return result
