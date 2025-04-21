"""
Comprehensive benchmarking script for the Hybrid DE-PSO algorithm.

This script benchmarks the Hybrid DE-PSO algorithm against standard DE and PSO
algorithms on a suite of test functions with varying characteristics.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
import time
import pandas as pd
import seaborn as sns
from tabulate import tabulate
from mpl_toolkits.mplot3d import Axes3D
from matplotlib.ticker import ScalarFormatter

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
    
    Characteristics: Convex, unimodal, separable
    """
    return sum(xi**2 for xi in x)


def rosenbrock(x):
    """
    Rosenbrock function.
    
    f(x) = sum(100 * (x_{i+1} - x_i^2)^2 + (1 - x_i)^2)
    Global minimum: f(1, 1, ..., 1) = 0
    
    Characteristics: Non-convex, unimodal, non-separable
    """
    return sum(100 * (x[i+1] - x[i]**2)**2 + (1 - x[i])**2 for i in range(len(x)-1))


def rastrigin(x):
    """
    Rastrigin function.
    
    f(x) = 10n + sum(x_i^2 - 10 * cos(2 * pi * x_i))
    Global minimum: f(0, 0, ..., 0) = 0
    
    Characteristics: Non-convex, multimodal, separable
    """
    return 10 * len(x) + sum(xi**2 - 10 * np.cos(2 * np.pi * xi) for xi in x)


def ackley(x):
    """
    Ackley function.
    
    f(x) = -20 * exp(-0.2 * sqrt(0.5 * sum(x_i^2))) - exp(0.5 * sum(cos(2 * pi * x_i))) + 20 + e
    Global minimum: f(0, 0, ..., 0) = 0
    
    Characteristics: Non-convex, multimodal, non-separable
    """
    a, b, c = 20, 0.2, 2 * np.pi
    d = len(x)
    sum1 = sum(xi**2 for xi in x)
    sum2 = sum(np.cos(c * xi) for xi in x)
    
    term1 = -a * np.exp(-b * np.sqrt(sum1 / d))
    term2 = -np.exp(sum2 / d)
    
    return term1 + term2 + a + np.exp(1)


def griewank(x):
    """
    Griewank function.
    
    f(x) = 1 + sum(x_i^2 / 4000) - prod(cos(x_i / sqrt(i)))
    Global minimum: f(0, 0, ..., 0) = 0
    
    Characteristics: Non-convex, multimodal, non-separable
    """
    sum_term = sum(xi**2 / 4000 for xi in x)
    prod_term = np.prod([np.cos(x[i] / np.sqrt(i+1)) for i in range(len(x))])
    
    return 1 + sum_term - prod_term


def levy(x):
    """
    Levy function.
    
    Complex multimodal function with many local minima.
    Global minimum: f(1, 1, ..., 1) = 0
    
    Characteristics: Non-convex, multimodal, non-separable
    """
    w = [1 + (xi - 1) / 4 for xi in x]
    
    term1 = np.sin(np.pi * w[0])**2
    
    term2 = sum((w[i-1] - 1)**2 * (1 + 10 * np.sin(np.pi * w[i-1] + 1)**2) for i in range(1, len(w)))
    
    term3 = (w[-1] - 1)**2 * (1 + np.sin(2 * np.pi * w[-1])**2)
    
    return term1 + term2 + term3


def schwefel(x):
    """
    Schwefel function.
    
    f(x) = 418.9829 * n - sum(x_i * sin(sqrt(|x_i|)))
    Global minimum: f(420.9687, 420.9687, ..., 420.9687) = 0
    
    Characteristics: Non-convex, multimodal, separable, deceptive (global minimum far from next best local minimum)
    """
    return 418.9829 * len(x) - sum(xi * np.sin(np.sqrt(abs(xi))) for xi in x)


def zakharov(x):
    """
    Zakharov function.
    
    f(x) = sum(x_i^2) + (sum(0.5 * i * x_i))^2 + (sum(0.5 * i * x_i))^4
    Global minimum: f(0, 0, ..., 0) = 0
    
    Characteristics: Convex, unimodal, non-separable
    """
    sum1 = sum(xi**2 for xi in x)
    sum2 = sum(0.5 * (i+1) * xi for i, xi in enumerate(x))
    
    return sum1 + sum2**2 + sum2**4


# Define test function configurations
TEST_FUNCTIONS = [
    {
        "name": "Sphere",
        "function": sphere,
        "bounds": (-5.0, 5.0),
        "global_minimum": 0.0,
        "global_minimum_position": [0.0],  # Will be expanded based on dimensions
        "characteristics": "Convex, unimodal, separable"
    },
    {
        "name": "Rosenbrock",
        "function": rosenbrock,
        "bounds": (-2.0, 2.0),
        "global_minimum": 0.0,
        "global_minimum_position": [1.0],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, unimodal, non-separable"
    },
    {
        "name": "Rastrigin",
        "function": rastrigin,
        "bounds": (-5.12, 5.12),
        "global_minimum": 0.0,
        "global_minimum_position": [0.0],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, multimodal, separable"
    },
    {
        "name": "Ackley",
        "function": ackley,
        "bounds": (-32.768, 32.768),
        "global_minimum": 0.0,
        "global_minimum_position": [0.0],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, multimodal, non-separable"
    },
    {
        "name": "Griewank",
        "function": griewank,
        "bounds": (-600.0, 600.0),
        "global_minimum": 0.0,
        "global_minimum_position": [0.0],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, multimodal, non-separable"
    },
    {
        "name": "Levy",
        "function": levy,
        "bounds": (-10.0, 10.0),
        "global_minimum": 0.0,
        "global_minimum_position": [1.0],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, multimodal, non-separable"
    },
    {
        "name": "Schwefel",
        "function": schwefel,
        "bounds": (-500.0, 500.0),
        "global_minimum": 0.0,
        "global_minimum_position": [420.9687],  # Will be expanded based on dimensions
        "characteristics": "Non-convex, multimodal, separable, deceptive"
    },
    {
        "name": "Zakharov",
        "function": zakharov,
        "bounds": (-5.0, 10.0),
        "global_minimum": 0.0,
        "global_minimum_position": [0.0],  # Will be expanded based on dimensions
        "characteristics": "Convex, unimodal, non-separable"
    }
]


async def run_benchmark(juliaos, algorithm_class, algorithm_name, objective_func, bounds, config, runs=5):
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
        "success_rate": 0.0,
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


async def run_dimension_scaling_benchmark(juliaos, dimensions_list, test_function, algorithms, config_template, runs=3):
    """
    Run a benchmark to test how algorithms scale with increasing dimensions.
    
    Args:
        juliaos: JuliaOS instance
        dimensions_list: List of dimensions to test
        test_function: Test function configuration
        algorithms: List of (algorithm_class, algorithm_name) tuples
        config_template: Template for algorithm configuration
        runs: Number of runs per dimension
    
    Returns:
        dict: Benchmark results
    """
    print(f"\n=== Dimension Scaling Benchmark: {test_function['name']} ===")
    
    results = []
    
    for dimensions in dimensions_list:
        print(f"\nTesting with {dimensions} dimensions...")
        
        # Create bounds for this dimension
        bounds = [(test_function["bounds"][0], test_function["bounds"][1])] * dimensions
        
        # Update config with dimension-specific settings
        config = config_template.copy()
        config["population_size"] = max(30, dimensions * 10)  # Scale population with dimensions
        config["max_generations"] = max(100, dimensions * 20)  # Scale generations with dimensions
        config["max_time_seconds"] = max(30, dimensions * 5)  # Scale time limit with dimensions
        
        for algorithm_class, algorithm_name in algorithms:
            # Run benchmark
            algorithm_results = await run_benchmark(
                juliaos=juliaos,
                algorithm_class=algorithm_class,
                algorithm_name=algorithm_name,
                objective_func=test_function["function"],
                bounds=bounds,
                config=config,
                runs=runs
            )
            
            # Add dimension information
            algorithm_results["dimensions"] = dimensions
            
            # Add to results
            results.append(algorithm_results)
    
    return results


def plot_dimension_scaling(results, metric="mean_fitness", log_scale=True):
    """
    Plot how algorithms scale with increasing dimensions.
    
    Args:
        results: Benchmark results
        metric: Metric to plot
        log_scale: Whether to use log scale for y-axis
    """
    # Convert results to DataFrame
    df = pd.DataFrame(results)
    
    # Create figure
    plt.figure(figsize=(10, 6))
    
    # Plot for each algorithm
    for algorithm in df["algorithm"].unique():
        algorithm_df = df[df["algorithm"] == algorithm]
        plt.plot(
            algorithm_df["dimensions"],
            algorithm_df[metric],
            marker="o",
            label=algorithm
        )
    
    # Set log scale if requested
    if log_scale and metric in ["mean_fitness", "mean_time"]:
        plt.yscale("log")
        plt.gca().yaxis.set_major_formatter(ScalarFormatter())
    
    # Set labels and title
    plt.xlabel("Dimensions")
    
    if metric == "mean_fitness":
        plt.ylabel("Mean Best Fitness")
        plt.title("Algorithm Performance vs. Dimensions")
    elif metric == "mean_time":
        plt.ylabel("Mean Time (seconds)")
        plt.title("Algorithm Execution Time vs. Dimensions")
    elif metric == "success_rate":
        plt.ylabel("Success Rate")
        plt.title("Algorithm Success Rate vs. Dimensions")
    elif metric == "mean_iterations":
        plt.ylabel("Mean Iterations")
        plt.title("Algorithm Iterations vs. Dimensions")
    
    # Add legend
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    
    # Show plot
    plt.show()


def plot_hybrid_ratio_by_function(results):
    """
    Plot the hybrid ratio for different test functions.
    
    Args:
        results: Benchmark results
    """
    # Filter results for Hybrid DE-PSO
    hybrid_results = [r for r in results if r["algorithm"] == "Hybrid DE-PSO" and "mean_hybrid_ratio" in r]
    
    if not hybrid_results:
        print("No hybrid ratio data available.")
        return
    
    # Extract function names and hybrid ratios
    functions = [r["function"] for r in hybrid_results]
    hybrid_ratios = [r["mean_hybrid_ratio"] for r in hybrid_results]
    std_ratios = [r["std_hybrid_ratio"] for r in hybrid_results]
    
    # Create figure
    plt.figure(figsize=(12, 6))
    
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


def create_performance_table(results, metric="mean_fitness"):
    """
    Create a performance comparison table.
    
    Args:
        results: Benchmark results
        metric: Metric to compare
    
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
        best_value = min(r[metric] for r in func_results)
        
        # Add row for each algorithm
        for result in func_results:
            # Mark best result with an asterisk
            value_str = f"{result[metric]:.6f}"
            if result[metric] == best_value:
                value_str += " *"
            
            # Add row
            row = [
                function,
                result["algorithm"],
                value_str,
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
        f"{metric.replace('mean_', 'Mean ')}",
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
    
    print("=== Hybrid DE-PSO Benchmarking ===")
    
    try:
        # Define algorithms to benchmark
        algorithms = [
            (DifferentialEvolution, "DE"),
            (ParticleSwarmOptimization, "PSO"),
            (HybridDEPSO, "Hybrid DE-PSO")
        ]
        
        # Define dimensions to test
        dimensions_list = [2, 5, 10, 20, 30]
        
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
        
        # Run dimension scaling benchmarks
        all_results = []
        
        for test_function in TEST_FUNCTIONS:
            # Run benchmark for this function
            function_results = await run_dimension_scaling_benchmark(
                juliaos=juliaos,
                dimensions_list=dimensions_list,
                test_function=test_function,
                algorithms=algorithms,
                config_template=base_config,
                runs=3
            )
            
            # Add to all results
            all_results.extend(function_results)
            
            # Plot dimension scaling for this function
            print(f"\nDimension scaling for {test_function['name']}:")
            plot_dimension_scaling(function_results, metric="mean_fitness")
            plot_dimension_scaling(function_results, metric="mean_time")
            plot_dimension_scaling(function_results, metric="success_rate", log_scale=False)
        
        # Plot hybrid ratio by function
        print("\nHybrid ratio by function:")
        plot_hybrid_ratio_by_function(all_results)
        
        # Create performance tables
        print("\nPerformance comparison (Mean Fitness):")
        print(create_performance_table(all_results, metric="mean_fitness"))
        
        print("\nPerformance comparison (Success Rate):")
        print(create_performance_table(all_results, metric="success_rate"))
        
        print("\nPerformance comparison (Mean Time):")
        print(create_performance_table(all_results, metric="mean_time"))
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
