"""
Swarm optimization algorithms for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union, Tuple, Callable
import inspect

from ..bridge import JuliaBridge
from ..exceptions import SwarmError

try:
    import numpy as np
    from .numpy_utils import numpy_objective_wrapper, numpy_bounds_converter, numpy_result_converter
    NUMPY_AVAILABLE = True
except ImportError:
    NUMPY_AVAILABLE = False

# Define available algorithms
AVAILABLE_ALGORITHMS = [
    "DE",          # Differential Evolution
    "PSO",         # Particle Swarm Optimization
    "GWO",         # Grey Wolf Optimizer
    "ACO",         # Ant Colony Optimization
    "GA",          # Genetic Algorithm
    "WOA",         # Whale Optimization Algorithm
    "HYBRID_DEPSO" # Hybrid DE-PSO Algorithm
]


class OptimizationAlgorithm:
    """
    Base class for optimization algorithms.

    This class provides common functionality for all optimization algorithms.
    """

    def __init__(self, bridge: JuliaBridge):
        """
        Initialize an OptimizationAlgorithm.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run an optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        raise NotImplementedError("Subclasses must implement optimize method")


class DifferentialEvolution(OptimizationAlgorithm):
    """
    Differential Evolution optimization algorithm.

    This class provides methods for running Differential Evolution optimizations.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Differential Evolution optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "population_size": 20,
            "max_generations": 100,
            "crossover_probability": 0.7,
            "differential_weight": 0.8,
            "strategy": "rand/1/bin",
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # Handle NumPy integration if available
            if NUMPY_AVAILABLE:
                # Check if objective_function uses NumPy
                if callable(objective_function) and inspect.getsource(objective_function).find("np.") >= 0:
                    # Wrap the function to handle NumPy arrays
                    original_func = objective_function
                    objective_function = numpy_objective_wrapper(original_func)

                # Convert NumPy bounds to list of tuples if needed
                bounds = numpy_bounds_converter(bounds)

            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute DE optimization command
            result = await self.bridge.execute("Swarms.DifferentialEvolution.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run DE optimization: {result.get('error', 'Unknown error')}")

            # Convert result to include NumPy arrays if NumPy is available
            if NUMPY_AVAILABLE:
                result = numpy_result_converter(result)

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running DE optimization: {e}")
            raise


class ParticleSwarmOptimization(OptimizationAlgorithm):
    """
    Particle Swarm Optimization algorithm.

    This class provides methods for running Particle Swarm Optimization.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Particle Swarm Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "swarm_size": 20,
            "max_iterations": 100,
            "cognitive_coefficient": 2.0,
            "social_coefficient": 2.0,
            "inertia_weight": 0.7,
            "inertia_damping": 0.99,
            "min_inertia": 0.4,
            "velocity_limit_factor": 0.1,
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute PSO optimization command
            result = await self.bridge.execute("Swarms.ParticleSwarmOptimization.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run PSO optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running PSO optimization: {e}")
            raise


class GreyWolfOptimizer(OptimizationAlgorithm):
    """
    Grey Wolf Optimizer (GWO) algorithm.

    This class provides methods for running Grey Wolf Optimization.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Grey Wolf Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "pack_size": 30,
            "max_iterations": 100,
            "a_decrease_factor": 2.0,
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute GWO optimization command
            result = await self.bridge.execute("Swarms.GreyWolfOptimization.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run GWO optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running GWO optimization: {e}")
            raise


class AntColonyOptimization(OptimizationAlgorithm):
    """
    Ant Colony Optimization (ACO) algorithm for continuous domains.

    This class provides methods for running Ant Colony Optimization.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run an Ant Colony Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "colony_size": 50,
            "archive_size": 30,
            "max_iterations": 100,
            "q": 0.5,  # Locality of search parameter
            "xi": 0.7,  # Pheromone evaporation rate
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute ACO optimization command
            result = await self.bridge.execute("Swarms.AntColonyOptimization.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run ACO optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running ACO optimization: {e}")
            raise


class GeneticAlgorithm(OptimizationAlgorithm):
    """
    Genetic Algorithm (GA) optimization.

    This class provides methods for running Genetic Algorithm optimization.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Genetic Algorithm optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "population_size": 100,
            "max_generations": 100,
            "crossover_rate": 0.8,
            "mutation_rate": 0.1,
            "selection_pressure": 0.2,
            "elitism_count": 2,
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute GA optimization command
            result = await self.bridge.execute("Swarms.GeneticAlgorithm.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run GA optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running GA optimization: {e}")
            raise


class WhaleOptimizationAlgorithm(OptimizationAlgorithm):
    """
    Whale Optimization Algorithm (WOA).

    This class provides methods for running Whale Optimization Algorithm.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Whale Optimization Algorithm optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            "pod_size": 30,
            "max_iterations": 100,
            "b": 1.0,  # Spiral shape constant
            "a_decrease_factor": 2.0,
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute WOA optimization command
            result = await self.bridge.execute("Swarms.WhaleOptimizationAlgorithm.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run WOA optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running WOA optimization: {e}")
            raise


class HybridDEPSO(OptimizationAlgorithm):
    """
    Hybrid Differential Evolution and Particle Swarm Optimization algorithm.

    This class provides methods for running a hybrid optimization that combines
    the exploration capabilities of Differential Evolution with the exploitation
    efficiency of Particle Swarm Optimization.
    """

    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Hybrid DE-PSO optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        # Ensure config is a dictionary
        if config is None:
            config = {}

        # Set default configuration
        default_config = {
            # Population/swarm parameters
            "population_size": 30,
            "max_generations": 100,

            # DE parameters
            "crossover_probability": 0.7,
            "differential_weight": 0.8,
            "strategy": "rand/1/bin",

            # PSO parameters
            "cognitive_coefficient": 2.0,
            "social_coefficient": 2.0,
            "inertia_weight": 0.7,
            "inertia_damping": 0.99,
            "min_inertia": 0.4,

            # Hybrid parameters
            "hybrid_ratio": 0.5,  # Ratio of DE to PSO (0.5 means 50% DE, 50% PSO)
            "adaptive_hybrid": True,  # Adaptively adjust the hybrid ratio based on performance
            "phase_iterations": 5,  # Number of iterations before switching dominant algorithm

            # General parameters
            "tolerance": 1e-6,
            "max_time_seconds": 60
        }

        # Merge with user config
        for key, value in default_config.items():
            if key not in config:
                config[key] = value

        try:
            # If objective_function is a callable, register it
            if callable(objective_function):
                function_id = f"python_func_{id(objective_function)}"

                # Register the function with the server
                await self.bridge.execute("Swarms.register_python_function", [
                    function_id,
                    objective_function
                ])
            else:
                function_id = objective_function

            # Execute Hybrid DE-PSO optimization command
            result = await self.bridge.execute("Swarms.HybridDEPSO.optimize", [
                function_id,
                bounds,
                config
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to run Hybrid DE-PSO optimization: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running Hybrid DE-PSO optimization: {e}")
            raise
