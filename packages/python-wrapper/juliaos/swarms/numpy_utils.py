"""
NumPy utilities for swarm algorithms.

This module provides utilities for integrating NumPy with swarm algorithms.
"""

import numpy as np
from typing import List, Tuple, Dict, Any, Callable, Union


def numpy_objective_wrapper(func: Callable) -> Callable:
    """
    Wrap a NumPy-based objective function to make it compatible with JuliaOS swarm algorithms.
    
    Args:
        func: NumPy-based objective function that takes a numpy array and returns a scalar
        
    Returns:
        Callable: Wrapped function that takes a list and returns a scalar
    """
    def wrapped(x: List[float]) -> float:
        """
        Convert list to numpy array, call the original function, and return the result.
        
        Args:
            x: List of parameters
            
        Returns:
            float: Objective function value
        """
        return float(func(np.array(x)))
    
    return wrapped


def numpy_bounds_converter(bounds: Union[List[Tuple[float, float]], np.ndarray]) -> List[Tuple[float, float]]:
    """
    Convert NumPy-style bounds to JuliaOS-compatible bounds.
    
    Args:
        bounds: NumPy-style bounds (n x 2 array) or list of tuples
        
    Returns:
        List[Tuple[float, float]]: JuliaOS-compatible bounds
    """
    if isinstance(bounds, np.ndarray):
        if bounds.ndim == 2 and bounds.shape[1] == 2:
            return [(float(low), float(high)) for low, high in bounds]
        else:
            raise ValueError("NumPy bounds must be a 2D array with shape (n, 2)")
    else:
        return bounds


def numpy_result_converter(result: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert JuliaOS optimization result to include NumPy arrays.
    
    Args:
        result: JuliaOS optimization result
        
    Returns:
        Dict[str, Any]: Result with NumPy arrays
    """
    numpy_result = result.copy()
    
    # Convert best position to numpy array
    if "best_position" in result:
        numpy_result["best_position_np"] = np.array(result["best_position"])
    elif "best_individual" in result:
        numpy_result["best_individual_np"] = np.array(result["best_individual"])
    
    # Convert convergence history to numpy array if present
    if "convergence_history" in result:
        numpy_result["convergence_history_np"] = np.array(result["convergence_history"])
    
    # Convert population/swarm to numpy array if present
    if "final_population" in result:
        numpy_result["final_population_np"] = np.array(result["final_population"])
    elif "final_swarm" in result:
        numpy_result["final_swarm_np"] = np.array(result["final_swarm"])
    
    return numpy_result
