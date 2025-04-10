"""
JuliaOS Python Wrapper

This package provides a Pythonic interface to interact with the JuliaOS Framework.
"""

from .juliaos import JuliaOS
from .bridge import JuliaBridge
from .exceptions import JuliaOSError, ConnectionError, TimeoutError
from .swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm,
    SwarmAlgorithm, AVAILABLE_ALGORITHMS
)

# Import LangChain integration
from . import langchain

# Import LLM providers
from . import llm

# Import Google ADK integration
from . import adk

__version__ = "0.1.0"
__all__ = [
    "JuliaOS", "JuliaBridge", "JuliaOSError", "ConnectionError", "TimeoutError",
    "DifferentialEvolution", "ParticleSwarmOptimization",
    "GreyWolfOptimizer", "AntColonyOptimization",
    "GeneticAlgorithm", "WhaleOptimizationAlgorithm",
    "SwarmAlgorithm", "AVAILABLE_ALGORITHMS",
    "langchain", "llm", "adk"
]
