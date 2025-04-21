"""
Example script demonstrating the use of the Hybrid DE-PSO algorithm.

This script shows how to use the Hybrid DE-PSO algorithm for optimization
problems, comparing its performance with standard DE and PSO algorithms.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import time

from juliaos import JuliaOS
from juliaos.swarms import SwarmType


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


async def run_optimization(juliaos, algorithm, objective_func, dimensions, bounds, config):
    """
    Run an optimization with a specific algorithm and objective function.
    
    Args:
        juliaos: JuliaOS instance
        algorithm: Optimization algorithm ("DE", "PSO", or "HYBRID_DEPSO")
        objective_func: Objective function to optimize
        dimensions: Number of dimensions
        bounds: List of (min, max) tuples for each dimension
        config: Algorithm configuration
    
    Returns:
        dict: Optimization result
    """
    # Create a swarm
    swarm = await juliaos.swarms.create_swarm(
        name=f"{algorithm} Optimization",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm=algorithm,
        dimensions=dimensions,
        bounds=bounds,
        config=config
    )
    print(f"Created {algorithm} swarm: {swarm.id}")
    
    try:
        # Register the objective function
        function_id = f"python_func_{id(objective_func)}"
        await juliaos.swarms.set_objective_function(
            function_id=function_id,
            function_code=objective_func.__name__,
            function_type="python"
        )
        print(f"Registered objective function: {objective_func.__name__}")
        
        # Run the optimization
        start_time = time.time()
        opt_result = await swarm.run_optimization(
            function_id=function_id,
            max_iterations=100,
            max_time_seconds=30,
            tolerance=1e-6
        )
        elapsed_time = time.time() - start_time
        
        # Get the optimization result
        result = await swarm.get_optimization_result(opt_result["optimization_id"])
        
        if result["status"] == "completed":
            print(f"  Best fitness: {result['result']['best_fitness']:.6f}")
            print(f"  Best position: {[f'{x:.4f}' for x in result['result']['best_position']]}")
            print(f"  Iterations: {result['result'].get('iterations', 0)}")
            print(f"  Elapsed time: {elapsed_time:.2f} seconds")
            
            if algorithm == "HYBRID_DEPSO":
                print(f"  Final hybrid ratio: {result['result'].get('final_hybrid_ratio', 0.5):.2f}")
            
            return result["result"]
        else:
            print(f"  Optimization failed: {result.get('error', 'Unknown error')}")
            return None
    finally:
        # Delete the swarm
        await swarm.delete()


async def compare_algorithms(juliaos, objective_func, dimensions, bounds, configs):
    """
    Compare different optimization algorithms on the same problem.
    
    Args:
        juliaos: JuliaOS instance
        objective_func: Objective function to optimize
        dimensions: Number of dimensions
        bounds: List of (min, max) tuples for each dimension
        configs: Dictionary of algorithm configurations
    
    Returns:
        dict: Dictionary of results for each algorithm
    """
    results = {}
    
    # Run DE optimization
    print("\n=== Differential Evolution ===")
    de_result = await run_optimization(
        juliaos=juliaos,
        algorithm="DE",
        objective_func=objective_func,
        dimensions=dimensions,
        bounds=bounds,
        config=configs["DE"]
    )
    results["DE"] = de_result
    
    # Run PSO optimization
    print("\n=== Particle Swarm Optimization ===")
    pso_result = await run_optimization(
        juliaos=juliaos,
        algorithm="PSO",
        objective_func=objective_func,
        dimensions=dimensions,
        bounds=bounds,
        config=configs["PSO"]
    )
    results["PSO"] = pso_result
    
    # Run Hybrid DE-PSO optimization
    print("\n=== Hybrid DE-PSO ===")
    hybrid_result = await run_optimization(
        juliaos=juliaos,
        algorithm="HYBRID_DEPSO",
        objective_func=objective_func,
        dimensions=dimensions,
        bounds=bounds,
        config=configs["HYBRID_DEPSO"]
    )
    results["HYBRID_DEPSO"] = hybrid_result
    
    return results


def plot_convergence(results):
    """
    Plot convergence history for different algorithms.
    
    Args:
        results: Dictionary of results for each algorithm
    """
    plt.figure(figsize=(10, 6))
    
    for algorithm, result in results.items():
        if result and "history" in result and "best_fitness" in result["history"]:
            generations = result["history"].get("generation", range(len(result["history"]["best_fitness"])))
            plt.semilogy(generations, result["history"]["best_fitness"], label=algorithm)
    
    plt.xlabel("Iteration")
    plt.ylabel("Best Fitness (log scale)")
    plt.title("Convergence Comparison")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()


def plot_hybrid_ratio(result):
    """
    Plot the hybrid ratio evolution for the Hybrid DE-PSO algorithm.
    
    Args:
        result: Result dictionary for the Hybrid DE-PSO algorithm
    """
    if result and "history" in result and "hybrid_ratio" in result["history"]:
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
    
    print("=== Hybrid DE-PSO Algorithm Example ===")
    
    try:
        # Get available algorithms
        algorithms = await juliaos.swarms.get_available_algorithms()
        print(f"Available algorithms: {algorithms}")
        
        # Check if HYBRID_DEPSO is available
        if "HYBRID_DEPSO" not in algorithms:
            print("Error: HYBRID_DEPSO algorithm is not available.")
            return
        
        # Define common parameters
        dimensions = 5
        bounds = [(-5.0, 5.0)] * dimensions
        
        # Define algorithm-specific configurations
        configs = {
            "DE": {
                "population_size": 30,
                "crossover_probability": 0.7,
                "differential_weight": 0.8,
                "strategy": "rand/1/bin"
            },
            "PSO": {
                "swarm_size": 30,
                "cognitive_coefficient": 2.0,
                "social_coefficient": 2.0,
                "inertia_weight": 0.7,
                "inertia_damping": 0.99
            },
            "HYBRID_DEPSO": {
                "population_size": 30,
                "crossover_probability": 0.7,
                "differential_weight": 0.8,
                "cognitive_coefficient": 2.0,
                "social_coefficient": 2.0,
                "inertia_weight": 0.7,
                "hybrid_ratio": 0.5,
                "adaptive_hybrid": True,
                "phase_iterations": 5
            }
        }
        
        # Compare algorithms on the sphere function
        print("\n=== Comparing Algorithms on Sphere Function ===")
        sphere_results = await compare_algorithms(
            juliaos=juliaos,
            objective_func=sphere,
            dimensions=dimensions,
            bounds=bounds,
            configs=configs
        )
        
        # Plot convergence for sphere function
        plot_convergence(sphere_results)
        
        # Plot hybrid ratio evolution
        if "HYBRID_DEPSO" in sphere_results and sphere_results["HYBRID_DEPSO"]:
            plot_hybrid_ratio(sphere_results["HYBRID_DEPSO"])
        
        # Compare algorithms on the Rosenbrock function
        print("\n=== Comparing Algorithms on Rosenbrock Function ===")
        rosenbrock_results = await compare_algorithms(
            juliaos=juliaos,
            objective_func=rosenbrock,
            dimensions=dimensions,
            bounds=[(-2.0, 2.0)] * dimensions,
            configs=configs
        )
        
        # Plot convergence for Rosenbrock function
        plot_convergence(rosenbrock_results)
        
        # Compare algorithms on the Rastrigin function
        print("\n=== Comparing Algorithms on Rastrigin Function ===")
        rastrigin_results = await compare_algorithms(
            juliaos=juliaos,
            objective_func=rastrigin,
            dimensions=dimensions,
            bounds=[(-5.12, 5.12)] * dimensions,
            configs=configs
        )
        
        # Plot convergence for Rastrigin function
        plot_convergence(rastrigin_results)
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
