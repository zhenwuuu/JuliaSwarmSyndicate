"""
Neural Networks module for JuliaOS.

This module provides classes and functions for working with neural networks in JuliaOS.
"""

from .models import NeuralNetworkModel, ModelType
from .agent_models import AgentNeuralNetworks

__all__ = [
    "NeuralNetworkModel",
    "ModelType",
    "AgentNeuralNetworks"
]
