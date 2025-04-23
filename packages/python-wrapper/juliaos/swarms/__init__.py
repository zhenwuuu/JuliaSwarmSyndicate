"""
Swarms module for the JuliaOS Python wrapper.
"""

from .swarm_manager import SwarmManager
from .swarm import Swarm
from .swarm_types import SwarmType, SwarmStatus, SwarmAlgorithm
from .algorithms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm,
    HybridDEPSO, AVAILABLE_ALGORITHMS, NUMPY_AVAILABLE
)

# Import NumPy utilities if NumPy is available
if NUMPY_AVAILABLE:
    from .numpy_utils import numpy_objective_wrapper, numpy_bounds_converter, numpy_result_converter

__all__ = [
    "SwarmManager",
    "Swarm",
    "SwarmType",
    "SwarmStatus",
    "SwarmAlgorithm",
    "DifferentialEvolution",
    "ParticleSwarmOptimization",
    "GreyWolfOptimizer",
    "AntColonyOptimization",
    "GeneticAlgorithm",
    "WhaleOptimizationAlgorithm",
    "HybridDEPSO",
    "AVAILABLE_ALGORITHMS",
    "NUMPY_AVAILABLE"
]

# Add NumPy utilities to __all__ if NumPy is available
if NUMPY_AVAILABLE:
    __all__.extend([
        "numpy_objective_wrapper",
        "numpy_bounds_converter",
        "numpy_result_converter"
    ])
