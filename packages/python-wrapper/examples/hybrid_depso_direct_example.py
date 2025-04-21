"""
Example script demonstrating direct use of the HybridDEPSO class.

This script shows how to use the HybridDEPSO class directly without going through
the SwarmManager, which provides more control over the optimization process.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import time

from juliaos import JuliaOS
from juliaos.swarms import HybridDEPSO


# Define test functions
def sphere(x):
    """
    Sphere function.
    
    f(x) = sum(x_i^2)
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return sum(xi**2 for xi in x)


def rosenbrock(x):
    """
    Rosenbrock function.
    
    f(x) = sum(100 * (x_{i+1} - x_i^2)^2 + (1 - x_i)^2)
    Global minimum: f(1, 1, ..., 1) = 0
    """
    return sum(100 * (x[i+1] - x[i]**2)**2 + (1 - x[i])**2 for i in range(len(x)-1))


def rastrigin(x):
    """
    Rastrigin function.
    
    f(x) = 10n + sum(x_i^2 - 10 * cos(2 * pi * x_i))
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return 10 * len(x) + sum(xi**2 - 10 * np.cos(2 * np.pi * xi) for xi in x)


async def optimize_function(juliaos, objective_func, dimensions, bounds, config=None):
    """
    Optimize a function using the HybridDEPSO algorithm.
    
    Args:
        juliaos: JuliaOS instance
        objective_func: Objective function to optimize
        dimensions: Number of dimensions
        bounds: List of (min, max) tuples for each dimension
        config: Algorithm configuration
    
    Returns:
        dict: Optimization result
    """
    # Create a HybridDEPSO instance
    hybrid_depso = HybridDEPSO(juliaos.bridge)
    
    # Run the optimization
    start_time = time.time()
    result = await hybrid_depso.optimize(
        objective_function=objective_func,
        bounds=bounds,
        config=config
    )
    elapsed_time = time.time() - start_time
    
    # Print results
    print(f"Optimization completed in {elapsed_time:.2f} seconds")
    print(f"Best fitness: {result['best_fitness']:.6f}")
    print(f"Best position: {[f'{x:.4f}' for x in result['best_position']]}")
    print(f"Iterations: {result.get('iterations', 0)}")
    print(f"Final hybrid ratio: {result.get('final_hybrid_ratio', 0.5):.2f}")
    
    return result


def plot_convergence(result):
    """
    Plot convergence history.
    
    Args:
        result: Optimization result
    """
    if "history" in result and "best_fitness" in result["history"]:
        generations = result["history"].get("generation", range(len(result["history"]["best_fitness"])))
        
        plt.figure(figsize=(10, 6))
        plt.semilogy(generations, result["history"]["best_fitness"], label="Best Fitness")
        plt.semilogy(generations, result["history"]["mean_fitness"], label="Mean Fitness")
        plt.xlabel("Iteration")
        plt.ylabel("Fitness (log scale)")
        plt.title("Convergence History")
        plt.legend()
        plt.grid(True)
        plt.tight_layout()
        plt.show()


def plot_hybrid_ratio(result):
    """
    Plot the hybrid ratio evolution.
    
    Args:
        result: Optimization result
    """
    if "history" in result and "hybrid_ratio" in result["history"]:
        generations = result["history"].get("generation", range(len(result["history"]["hybrid_ratio"])))
        
        plt.figure(figsize=(10, 6))
        plt.plot(generations, result["history"]["hybrid_ratio"])
        plt.xlabel("Iteration")
        plt.ylabel("Hybrid Ratio (DE proportion)")
        plt.title("Hybrid Ratio Evolution")
        plt.grid(True)
        plt.axhline(y=0.5, color='r', linestyle='--', label="Equal DE/PSO")
        plt.legend()
        plt.tight_layout()
        plt.show()


async def main():
    """
    Main function to run the example.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    print("=== Hybrid DE-PSO Direct Usage Example ===")
    
    try:
        # Define problem parameters
        dimensions = 5
        bounds = [(-5.0, 5.0)] * dimensions
        
        # Define algorithm configuration
        config = {
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
            "max_time_seconds": 30
        }
        
        # Optimize the sphere function
        print("\n=== Optimizing Sphere Function ===")
        sphere_result = await optimize_function(
            juliaos=juliaos,
            objective_func=sphere,
            dimensions=dimensions,
            bounds=bounds,
            config=config
        )
        
        # Plot convergence and hybrid ratio evolution
        plot_convergence(sphere_result)
        plot_hybrid_ratio(sphere_result)
        
        # Optimize the Rosenbrock function
        print("\n=== Optimizing Rosenbrock Function ===")
        rosenbrock_result = await optimize_function(
            juliaos=juliaos,
            objective_func=rosenbrock,
            dimensions=dimensions,
            bounds=[(-2.0, 2.0)] * dimensions,
            config=config
        )
        
        # Plot convergence and hybrid ratio evolution
        plot_convergence(rosenbrock_result)
        plot_hybrid_ratio(rosenbrock_result)
        
        # Optimize the Rastrigin function
        print("\n=== Optimizing Rastrigin Function ===")
        rastrigin_result = await optimize_function(
            juliaos=juliaos,
            objective_func=rastrigin,
            dimensions=dimensions,
            bounds=[(-5.12, 5.12)] * dimensions,
            config=config
        )
        
        # Plot convergence and hybrid ratio evolution
        plot_convergence(rastrigin_result)
        plot_hybrid_ratio(rastrigin_result)
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
