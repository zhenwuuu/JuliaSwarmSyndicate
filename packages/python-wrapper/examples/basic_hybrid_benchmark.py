"""
Basic benchmarking script for the Hybrid DE-PSO algorithm.

This script compares the performance of DE, PSO, and Hybrid DE-PSO
on a few standard test functions.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
import time
from tabulate import tabulate

from juliaos import JuliaOS
from juliaos.swarms import (
    DifferentialEvolution,
    ParticleSwarmOptimization,
    HybridDEPSO
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
    return sum(100 * (x[i+1] - x[i]**2)**2 + (1 - x[i])**2 for i in range(len(x)-1))


def rastrigin(x):
    """
    Rastrigin function.
    
    f(x) = 10n + sum(x_i^2 - 10 * cos(2 * pi * x_i))
    Global minimum: f(0, 0, ..., 0) = 0
    """
    return 10 * len(x) + sum(xi**2 - 10 * np.cos(2 * np.pi * xi) for xi in x)


# Define test function configurations
TEST_FUNCTIONS = [
    {
        "name": "Sphere",
        "function": sphere,
        "bounds": (-5.0, 5.0),
        "global_minimum": 0.0
    },
    {
        "name": "Rosenbrock",
        "function": rosenbrock,
        "bounds": (-2.0, 2.0),
        "global_minimum": 0.0
    },
    {
        "name": "Rastrigin",
        "function": rastrigin,
        "bounds": (-5.12, 5.12),
        "global_minimum": 0.0
    }
]


async def run_benchmark(juliaos, algorithm_class, algorithm_name, objective_func, bounds, config, runs=3):
    """
    Run a benchmark for a specific algorithm on a specific function.
    
    Args:
        juliaos: JuliaOS instance
        algorithm_class: Algorithm class to benchmark
        algorithm_name: Name of the algorithm
        objective_func: Objective function to optimize
        bounds: List of (min, max) tuples for each dimension
        config: Algorithm configuration
        runs: Number of runs to perform
    
    Returns:
        dict: Benchmark results
    """
    print(f"Running {algorithm_name} on {objective_func.__name__}...")
    
    # Create algorithm instance
    algorithm = algorithm_class(juliaos.bridge)
    
    # Initialize results
    results = {
        "algorithm": algorithm_name,
        "function": objective_func.__name__,
        "best_fitness": [],
        "elapsed_time": [],
        "iterations": [],
        "hybrid_ratio": [] if algorithm_name == "Hybrid DE-PSO" else None
    }
    
    # Run multiple times to get statistical significance
    for run in range(runs):
        print(f"  Run {run+1}/{runs}...")
        
        # Run optimization
        start_time = time.time()
        result = await algorithm.optimize(
            objective_function=objective_func,
            bounds=bounds,
            config=config
        )
        elapsed_time = time.time() - start_time
        
        # Store results
        results["best_fitness"].append(result["best_fitness"])
        results["elapsed_time"].append(elapsed_time)
        results["iterations"].append(result.get("iterations", 0))
        
        # Store hybrid ratio if applicable
        if algorithm_name == "Hybrid DE-PSO" and "final_hybrid_ratio" in result:
            results["hybrid_ratio"].append(result["final_hybrid_ratio"])
    
    # Calculate statistics
    results["mean_fitness"] = np.mean(results["best_fitness"])
    results["std_fitness"] = np.std(results["best_fitness"])
    results["mean_time"] = np.mean(results["elapsed_time"])
    results["std_time"] = np.std(results["elapsed_time"])
    results["mean_iterations"] = np.mean(results["iterations"])
    results["std_iterations"] = np.std(results["iterations"])
    
    # Calculate success rate (how often it gets close to the global minimum)
    tolerance = 1e-2
    successes = sum(1 for fitness in results["best_fitness"] if fitness < tolerance)
    results["success_rate"] = successes / runs
    
    # Calculate mean hybrid ratio if applicable
    if algorithm_name == "Hybrid DE-PSO" and results["hybrid_ratio"]:
        results["mean_hybrid_ratio"] = np.mean(results["hybrid_ratio"])
        results["std_hybrid_ratio"] = np.std(results["hybrid_ratio"])
    
    return results


def plot_comparison(results, metric="mean_fitness", log_scale=True):
    """
    Plot comparison of algorithms across test functions.
    
    Args:
        results: List of benchmark results
        metric: Metric to compare
        log_scale: Whether to use log scale for y-axis
    """
    # Group results by function
    function_results = {}
    for result in results:
        function = result["function"]
        if function not in function_results:
            function_results[function] = []
        function_results[function].append(result)
    
    # Create figure
    plt.figure(figsize=(12, 6))
    
    # Set width of bars
    bar_width = 0.25
    
    # Set positions of bars on x-axis
    functions = list(function_results.keys())
    positions = np.arange(len(functions))
    
    # Plot bars for each algorithm
    algorithms = ["DE", "PSO", "Hybrid DE-PSO"]
    for i, algorithm in enumerate(algorithms):
        values = []
        errors = []
        
        for function in functions:
            # Find result for this algorithm and function
            algorithm_result = next((r for r in function_results[function] if r["algorithm"] == algorithm), None)
            
            if algorithm_result:
                values.append(algorithm_result[metric])
                if f"std_{metric.replace('mean_', '')}" in algorithm_result:
                    errors.append(algorithm_result[f"std_{metric.replace('mean_', '')}"])
                else:
                    errors.append(0)
            else:
                values.append(0)
                errors.append(0)
        
        # Plot bars
        plt.bar(
            positions + i * bar_width,
            values,
            bar_width,
            yerr=errors,
            label=algorithm,
            alpha=0.7
        )
    
    # Set log scale if requested
    if log_scale and metric in ["mean_fitness", "mean_time"]:
        plt.yscale("log")
    
    # Set labels and title
    plt.xlabel("Test Function")
    
    if metric == "mean_fitness":
        plt.ylabel("Mean Best Fitness")
        plt.title("Algorithm Performance Comparison")
    elif metric == "mean_time":
        plt.ylabel("Mean Time (seconds)")
        plt.title("Algorithm Execution Time Comparison")
    elif metric == "success_rate":
        plt.ylabel("Success Rate")
        plt.title("Algorithm Success Rate Comparison")
    elif metric == "mean_iterations":
        plt.ylabel("Mean Iterations")
        plt.title("Algorithm Iterations Comparison")
    
    # Set x-tick labels
    plt.xticks(positions + bar_width, functions)
    
    # Add legend
    plt.legend()
    plt.grid(True, axis="y")
    plt.tight_layout()
    
    # Show plot
    plt.show()


def plot_hybrid_ratio(results):
    """
    Plot the hybrid ratio for different test functions.
    
    Args:
        results: List of benchmark results
    """
    # Filter results for Hybrid DE-PSO
    hybrid_results = [r for r in results if r["algorithm"] == "Hybrid DE-PSO" and "mean_hybrid_ratio" in r]
    
    if not hybrid_results:
        print("No hybrid ratio data available.")
        return
    
    # Extract function names and hybrid ratios
    functions = [r["function"] for r in hybrid_results]
    hybrid_ratios = [r["mean_hybrid_ratio"] for r in hybrid_results]
    std_ratios = [r.get("std_hybrid_ratio", 0) for r in hybrid_results]
    
    # Create figure
    plt.figure(figsize=(10, 6))
    
    # Create bar chart
    bars = plt.bar(functions, hybrid_ratios, yerr=std_ratios, alpha=0.7)
    
    # Add a horizontal line at 0.5 (equal DE and PSO)
    plt.axhline(y=0.5, color='r', linestyle='--', label="Equal DE/PSO")
    
    # Set labels and title
    plt.xlabel("Test Function")
    plt.ylabel("Mean Hybrid Ratio (DE proportion)")
    plt.title("Hybrid Ratio by Test Function")
    
    # Add annotations
    for i, bar in enumerate(bars):
        plt.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + std_ratios[i] + 0.02,
            f"{hybrid_ratios[i]:.2f}",
            ha="center"
        )
    
    # Add legend
    plt.legend()
    plt.grid(True, axis="y")
    plt.tight_layout()
    
    # Show plot
    plt.show()


def create_performance_table(results):
    """
    Create a performance comparison table.
    
    Args:
        results: List of benchmark results
    
    Returns:
        str: Formatted table
    """
    # Group results by function
    function_results = {}
    for result in results:
        function = result["function"]
        if function not in function_results:
            function_results[function] = []
        function_results[function].append(result)
    
    # Create table data
    table_data = []
    
    for function, func_results in function_results.items():
        # Find best result for this function
        best_fitness = min(r["mean_fitness"] for r in func_results)
        
        # Add row for each algorithm
        for result in func_results:
            # Mark best result with an asterisk
            fitness_str = f"{result['mean_fitness']:.6f}"
            if result["mean_fitness"] == best_fitness:
                fitness_str += " *"
            
            # Add row
            row = [
                function,
                result["algorithm"],
                fitness_str,
                f"{result['success_rate']:.2f}",
                f"{result['mean_time']:.2f}",
                f"{result['mean_iterations']:.1f}"
            ]
            
            # Add hybrid ratio if available
            if "mean_hybrid_ratio" in result:
                row.append(f"{result['mean_hybrid_ratio']:.2f}")
            else:
                row.append("N/A")
            
            table_data.append(row)
    
    # Create headers
    headers = [
        "Function",
        "Algorithm",
        "Mean Fitness",
        "Success Rate",
        "Time (s)",
        "Iterations",
        "Hybrid Ratio"
    ]
    
    # Format table
    return tabulate(table_data, headers=headers, tablefmt="grid")


async def main():
    """
    Main function to run the benchmarks.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    print("=== Basic Hybrid DE-PSO Benchmarking ===")
    
    try:
        # Define algorithms to benchmark
        algorithms = [
            (DifferentialEvolution, "DE"),
            (ParticleSwarmOptimization, "PSO"),
            (HybridDEPSO, "Hybrid DE-PSO")
        ]
        
        # Define dimensions
        dimensions = 10
        
        # Define common configuration
        base_config = {
            # Population/swarm parameters
            "population_size": 50,
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
            "hybrid_ratio": 0.5,
            "adaptive_hybrid": True,
            "phase_iterations": 5,
            
            # General parameters
            "tolerance": 1e-6,
            "max_time_seconds": 30
        }
        
        # Run benchmarks
        all_results = []
        
        for test_function in TEST_FUNCTIONS:
            # Create bounds for this dimension
            bounds = [(test_function["bounds"][0], test_function["bounds"][1])] * dimensions
            
            # Run benchmark for each algorithm
            for algorithm_class, algorithm_name in algorithms:
                # Run benchmark
                result = await run_benchmark(
                    juliaos=juliaos,
                    algorithm_class=algorithm_class,
                    algorithm_name=algorithm_name,
                    objective_func=test_function["function"],
                    bounds=bounds,
                    config=base_config,
                    runs=3
                )
                
                # Add to all results
                all_results.append(result)
        
        # Plot comparisons
        print("\nPerformance comparison:")
        plot_comparison(all_results, metric="mean_fitness")
        
        print("\nExecution time comparison:")
        plot_comparison(all_results, metric="mean_time", log_scale=False)
        
        print("\nSuccess rate comparison:")
        plot_comparison(all_results, metric="success_rate", log_scale=False)
        
        # Plot hybrid ratio
        print("\nHybrid ratio by function:")
        plot_hybrid_ratio(all_results)
        
        # Create performance table
        print("\nPerformance comparison table:")
        print(create_performance_table(all_results))
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
