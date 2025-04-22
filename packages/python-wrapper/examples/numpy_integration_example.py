"""
Example script demonstrating NumPy integration with JuliaOS swarm algorithms.

This script shows how to use NumPy arrays and functions with the JuliaOS swarm algorithms.
"""

import asyncio
import time
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

from juliaos import JuliaOS
from juliaos.swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, NUMPY_AVAILABLE
)


# Define test functions using NumPy
def sphere(x: np.ndarray) -> float:
    """
    Sphere function using NumPy.
    
    f(x) = sum(x_i^2)
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return np.sum(x**2)


def rosenbrock(x: np.ndarray) -> float:
    """
    Rosenbrock function using NumPy.
    
    f(x) = sum_{i=1}^{n-1} [100(x_{i+1} - x_i^2)^2 + (1 - x_i)^2]
    Global minimum: f(1, 1, ..., 1) = 0
    """
    return np.sum(100.0 * (x[1:] - x[:-1]**2)**2 + (1 - x[:-1])**2)


def rastrigin(x: np.ndarray) -> float:
    """
    Rastrigin function using NumPy.
    
    f(x) = 10n + sum_{i=1}^{n} [x_i^2 - 10cos(2πx_i)]
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return 10 * len(x) + np.sum(x**2 - 10 * np.cos(2 * np.pi * x))


def ackley(x: np.ndarray) -> float:
    """
    Ackley function using NumPy.
    
    f(x) = -20exp(-0.2sqrt(1/n sum_{i=1}^{n} x_i^2)) - exp(1/n sum_{i=1}^{n} cos(2πx_i)) + 20 + e
    Global minimum: f(0, 0, ..., 0) = 0
    """
    a, b, c = 20, 0.2, 2 * np.pi
    d = len(x)
    sum1 = np.sum(x**2)
    sum2 = np.sum(np.cos(c * x))
    term1 = -a * np.exp(-b * np.sqrt(sum1 / d))
    term2 = -np.exp(sum2 / d)
    return term1 + term2 + a + np.exp(1)


def plot_convergence(results, title):
    """
    Plot convergence curves for different algorithms.
    
    Args:
        results: Dictionary of algorithm results
        title: Plot title
    """
    plt.figure(figsize=(10, 6))
    
    for alg_name, result in results.items():
        if "convergence_history_np" in result:
            plt.plot(result["convergence_history_np"], label=alg_name)
        elif "convergence_history" in result:
            plt.plot(result["convergence_history"], label=alg_name)
    
    plt.title(f"Convergence Curves for {title}")
    plt.xlabel("Iteration")
    plt.ylabel("Best Fitness")
    plt.yscale("log")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    
    # Save the plot
    plt.savefig(f"convergence_{title.lower().replace(' ', '_')}.png")
    plt.close()


async def compare_algorithms(juliaos, func, func_name, bounds_np, dimensions=2):
    """
    Compare different algorithms on the same function.
    
    Args:
        juliaos: JuliaOS instance
        func: Objective function
        func_name: Function name
        bounds_np: NumPy array of bounds
        dimensions: Number of dimensions
    
    Returns:
        dict: Results for each algorithm
    """
    print(f"\nComparing algorithms on {func_name} function ({dimensions}D)...")
    
    # Common configuration
    config = {
        "max_generations": 100,
        "max_iterations": 100,
        "population_size": 30,
        "swarm_size": 30,
        "pack_size": 30,
        "max_time_seconds": 30,
        "tolerance": 1e-6
    }
    
    # Create algorithm instances
    de = DifferentialEvolution(juliaos.bridge)
    pso = ParticleSwarmOptimization(juliaos.bridge)
    gwo = GreyWolfOptimizer(juliaos.bridge)
    
    # Run optimizations
    results = {}
    
    # Differential Evolution
    print(f"  Running DE on {func_name}...")
    start_time = time.time()
    de_result = await de.optimize(func, bounds_np, config)
    de_time = time.time() - start_time
    
    print(f"    Best fitness: {de_result['best_fitness']:.6f}")
    print(f"    Time: {de_time:.2f} seconds")
    results["DE"] = de_result
    
    # Particle Swarm Optimization
    print(f"  Running PSO on {func_name}...")
    start_time = time.time()
    pso_result = await pso.optimize(func, bounds_np, config)
    pso_time = time.time() - start_time
    
    print(f"    Best fitness: {pso_result['best_fitness']:.6f}")
    print(f"    Time: {pso_time:.2f} seconds")
    results["PSO"] = pso_result
    
    # Grey Wolf Optimizer
    print(f"  Running GWO on {func_name}...")
    start_time = time.time()
    gwo_result = await gwo.optimize(func, bounds_np, config)
    gwo_time = time.time() - start_time
    
    print(f"    Best fitness: {gwo_result['best_fitness']:.6f}")
    print(f"    Time: {gwo_time:.2f} seconds")
    results["GWO"] = gwo_result
    
    return results


async def main():
    """
    Main function.
    """
    if not NUMPY_AVAILABLE:
        print("NumPy is not available. Please install NumPy to run this example.")
        return
    
    # Create JuliaOS instance
    async with JuliaOS(host="localhost", port=8052) as juliaos:
        print("Connected to JuliaOS server")
        
        # Define bounds using NumPy arrays
        sphere_bounds = np.array([[-5.0, 5.0]] * 2)
        rosenbrock_bounds = np.array([[-2.0, 2.0]] * 2)
        rastrigin_bounds = np.array([[-5.12, 5.12]] * 2)
        ackley_bounds = np.array([[-32.768, 32.768]] * 2)
        
        # Compare algorithms on different functions
        sphere_results = await compare_algorithms(juliaos, sphere, "Sphere", sphere_bounds)
        plot_convergence(sphere_results, "Sphere")
        
        rosenbrock_results = await compare_algorithms(juliaos, rosenbrock, "Rosenbrock", rosenbrock_bounds)
        plot_convergence(rosenbrock_results, "Rosenbrock")
        
        rastrigin_results = await compare_algorithms(juliaos, rastrigin, "Rastrigin", rastrigin_bounds)
        plot_convergence(rastrigin_results, "Rastrigin")
        
        ackley_results = await compare_algorithms(juliaos, ackley, "Ackley", ackley_bounds)
        plot_convergence(ackley_results, "Ackley")
        
        # Higher dimensional problem
        high_dim_bounds = np.array([[-5.0, 5.0]] * 10)
        high_dim_results = await compare_algorithms(juliaos, sphere, "Sphere", high_dim_bounds, dimensions=10)
        plot_convergence(high_dim_results, "Sphere (10D)")
        
        print("\nAll optimizations completed successfully!")


if __name__ == "__main__":
    asyncio.run(main())
