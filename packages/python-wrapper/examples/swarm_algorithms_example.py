"""
Example script demonstrating the use of different swarm algorithms.

This script shows how to use the various swarm optimization algorithms
available in the JuliaOS Python wrapper.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

from juliaos import JuliaOS
from juliaos.swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm
)


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
    return sum(100 * (x[i+1] - x[i]**2)**2 + (1 - x[i])**2 for i in range(len(x) - 1))


def rastrigin(x):
    """
    Rastrigin function.
    
    f(x) = 10n + sum(x_i^2 - 10 * cos(2 * pi * x_i))
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return 10 * len(x) + sum(xi**2 - 10 * np.cos(2 * np.pi * xi) for xi in x)


def ackley(x):
    """
    Ackley function.
    
    f(x) = -20 * exp(-0.2 * sqrt(0.5 * sum(x_i^2))) - exp(0.5 * sum(cos(2 * pi * x_i))) + 20 + e
    Global minimum: f(0, 0, ..., 0) = 0
    """
    a, b, c = 20, 0.2, 2 * np.pi
    d = len(x)
    
    sum1 = sum(xi**2 for xi in x)
    sum2 = sum(np.cos(c * xi) for xi in x)
    
    term1 = -a * np.exp(-b * np.sqrt(sum1 / d))
    term2 = -np.exp(sum2 / d)
    
    return term1 + term2 + a + np.exp(1)


# Plot a 2D function
def plot_function(func, bounds, title):
    """
    Plot a 2D function.
    
    Args:
        func: Function to plot
        bounds: Bounds for each dimension
        title: Plot title
    """
    x = np.linspace(bounds[0][0], bounds[0][1], 100)
    y = np.linspace(bounds[1][0], bounds[1][1], 100)
    X, Y = np.meshgrid(x, y)
    Z = np.zeros_like(X)
    
    for i in range(X.shape[0]):
        for j in range(X.shape[1]):
            Z[i, j] = func([X[i, j], Y[i, j]])
    
    fig = plt.figure(figsize=(12, 5))
    
    # 3D surface plot
    ax1 = fig.add_subplot(121, projection='3d')
    surf = ax1.plot_surface(X, Y, Z, cmap='viridis', alpha=0.8)
    ax1.set_xlabel('x')
    ax1.set_ylabel('y')
    ax1.set_zlabel('f(x, y)')
    ax1.set_title(f'{title} - 3D View')
    
    # 2D contour plot
    ax2 = fig.add_subplot(122)
    contour = ax2.contourf(X, Y, Z, 50, cmap='viridis')
    ax2.set_xlabel('x')
    ax2.set_ylabel('y')
    ax2.set_title(f'{title} - Contour View')
    plt.colorbar(contour, ax=ax2)
    
    plt.tight_layout()
    plt.show()


# Compare algorithms on a function
async def compare_algorithms(juliaos, func, func_name, bounds, dimensions=2):
    """
    Compare different algorithms on a function.
    
    Args:
        juliaos: JuliaOS instance
        func: Function to optimize
        func_name: Name of the function
        bounds: Bounds for each dimension
        dimensions: Number of dimensions
    
    Returns:
        dict: Results for each algorithm
    """
    print(f"\nComparing algorithms on {func_name} function ({dimensions}D)...")
    
    # Create bounds for all dimensions
    all_bounds = bounds * dimensions
    
    # Common configuration
    config = {
        "max_iterations": 50,
        "max_time_seconds": 30,
        "tolerance": 1e-6
    }
    
    # Create algorithm instances
    de = DifferentialEvolution(juliaos.bridge)
    pso = ParticleSwarmOptimization(juliaos.bridge)
    gwo = GreyWolfOptimizer(juliaos.bridge)
    aco = AntColonyOptimization(juliaos.bridge)
    ga = GeneticAlgorithm(juliaos.bridge)
    woa = WhaleOptimizationAlgorithm(juliaos.bridge)
    
    # Run optimizations
    results = {}
    
    print("Running Differential Evolution...")
    de_result = await de.optimize(func, all_bounds, config)
    results["DE"] = de_result
    print(f"  Best fitness: {de_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in de_result['best_position']]}")
    print(f"  Iterations: {de_result['iterations']}")
    
    print("Running Particle Swarm Optimization...")
    pso_result = await pso.optimize(func, all_bounds, config)
    results["PSO"] = pso_result
    print(f"  Best fitness: {pso_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in pso_result['best_position']]}")
    print(f"  Iterations: {pso_result['iterations']}")
    
    print("Running Grey Wolf Optimizer...")
    gwo_result = await gwo.optimize(func, all_bounds, config)
    results["GWO"] = gwo_result
    print(f"  Best fitness: {gwo_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in gwo_result['best_position']]}")
    print(f"  Iterations: {gwo_result['iterations']}")
    
    print("Running Ant Colony Optimization...")
    aco_result = await aco.optimize(func, all_bounds, config)
    results["ACO"] = aco_result
    print(f"  Best fitness: {aco_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in aco_result['best_position']]}")
    print(f"  Iterations: {aco_result['iterations']}")
    
    print("Running Genetic Algorithm...")
    ga_result = await ga.optimize(func, all_bounds, config)
    results["GA"] = ga_result
    print(f"  Best fitness: {ga_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in ga_result['best_position']]}")
    print(f"  Iterations: {ga_result['iterations']}")
    
    print("Running Whale Optimization Algorithm...")
    woa_result = await woa.optimize(func, all_bounds, config)
    results["WOA"] = woa_result
    print(f"  Best fitness: {woa_result['best_fitness']:.6f}")
    print(f"  Best position: {[f'{x:.4f}' for x in woa_result['best_position']]}")
    print(f"  Iterations: {woa_result['iterations']}")
    
    return results


# Plot convergence curves
def plot_convergence(results, func_name):
    """
    Plot convergence curves for different algorithms.
    
    Args:
        results: Results for each algorithm
        func_name: Name of the function
    """
    plt.figure(figsize=(10, 6))
    
    for algorithm, result in results.items():
        plt.plot(result["convergence_curve"], label=algorithm)
    
    plt.xlabel("Iteration")
    plt.ylabel("Best Fitness")
    plt.title(f"Convergence Curves for {func_name} Function")
    plt.legend()
    plt.grid(True)
    plt.yscale("log")  # Log scale for better visualization
    plt.tight_layout()
    plt.show()


async def main():
    """
    Main function.
    """
    print("JuliaOS Swarm Algorithms Example")
    print("================================")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Define bounds for test functions
        sphere_bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        rosenbrock_bounds = [(-2.0, 2.0), (-2.0, 2.0)]
        rastrigin_bounds = [(-5.12, 5.12), (-5.12, 5.12)]
        ackley_bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        
        # Plot test functions
        print("\nPlotting test functions...")
        plot_function(sphere, sphere_bounds, "Sphere Function")
        plot_function(rosenbrock, rosenbrock_bounds, "Rosenbrock Function")
        plot_function(rastrigin, rastrigin_bounds, "Rastrigin Function")
        plot_function(ackley, ackley_bounds, "Ackley Function")
        
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
        high_dim_results = await compare_algorithms(juliaos, sphere, "Sphere", sphere_bounds, dimensions=10)
        plot_convergence(high_dim_results, "Sphere (10D)")
        
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
