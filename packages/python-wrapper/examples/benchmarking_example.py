#!/usr/bin/env python3
"""
Example script demonstrating the use of the JuliaOS Benchmarking module.

This script shows how to benchmark and compare different swarm optimization
algorithms on a suite of standard benchmark functions.
"""

import os
import asyncio
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime

from juliaos import JuliaOS
from juliaos.benchmarking import BenchmarkFunction


async def main():
    """
    Main function demonstrating the use of the JuliaOS Benchmarking module.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS(host="localhost", port=8052)
    await juliaos.connect()
    
    try:
        print("JuliaOS Benchmarking Example")
        print("===========================")
        
        # Get available algorithms
        algorithms = await juliaos.benchmarking.get_standard_algorithms()
        print(f"\nAvailable algorithms: {', '.join(algorithms.keys())}")
        
        # Get standard benchmark functions
        functions = await juliaos.benchmarking.get_standard_benchmark_suite(difficulty="medium")
        print(f"\nBenchmark functions (medium difficulty):")
        for func in functions:
            print(f"  - {func.name} (Optimum: {func.optimum}, Bounds: {func.bounds})")
        
        # Run a benchmark for Differential Evolution
        print("\nRunning benchmark for Differential Evolution...")
        de_results = await juliaos.benchmarking.run_benchmark(
            algorithm="DE",
            functions=functions[:2],  # Use only the first two functions for this example
            dimensions=10,
            runs=5,  # Use a small number of runs for this example
            max_evaluations=5000,
            crossover_probability=0.7,
            differential_weight=0.8
        )
        
        print("\nDifferential Evolution results:")
        print(de_results.head())
        
        # Run a benchmark for Particle Swarm Optimization
        print("\nRunning benchmark for Particle Swarm Optimization...")
        pso_results = await juliaos.benchmarking.run_benchmark(
            algorithm="PSO",
            functions=functions[:2],  # Use only the first two functions for this example
            dimensions=10,
            runs=5,  # Use a small number of runs for this example
            max_evaluations=5000,
            cognitive_coefficient=2.0,
            social_coefficient=2.0,
            inertia_weight=0.7
        )
        
        print("\nParticle Swarm Optimization results:")
        print(pso_results.head())
        
        # Combine results
        de_results["Algorithm"] = "DE"
        pso_results["Algorithm"] = "PSO"
        combined_results = pd.concat([de_results, pso_results])
        
        # Calculate statistics
        stats = await juliaos.benchmarking.get_benchmark_statistics(combined_results)
        
        print("\nStatistics:")
        print(stats)
        
        # Visualize results
        print("\nGenerating visualizations...")
        
        # Create output directory
        output_dir = os.path.join(os.getcwd(), "benchmark_results", datetime.now().strftime("%Y%m%d_%H%M%S"))
        os.makedirs(output_dir, exist_ok=True)
        
        # Visualize comparison
        fig1 = await juliaos.benchmarking.visualize_comparison(
            combined_results,
            metric="BestFitness",
            save_path=os.path.join(output_dir, "comparison.png")
        )
        
        # Visualize results by function
        fig2 = await juliaos.benchmarking.visualize_results(
            combined_results,
            metric="BestFitness",
            group_by="Function",
            save_path=os.path.join(output_dir, "results_by_function.png")
        )
        
        # Visualize results by algorithm
        fig3 = await juliaos.benchmarking.visualize_results(
            combined_results,
            metric="BestFitness",
            group_by="Algorithm",
            save_path=os.path.join(output_dir, "results_by_algorithm.png")
        )
        
        # Generate benchmark report
        print("\nGenerating benchmark report...")
        report_path = await juliaos.benchmarking.generate_benchmark_report(
            combined_results,
            output_dir,
            include_plots=True
        )
        
        print(f"\nBenchmark report generated at: {report_path}")
        
        # Rank algorithms
        rankings = await juliaos.benchmarking.rank_algorithms(
            combined_results,
            metric="BestFitness",
            lower_is_better=True
        )
        
        print("\nAlgorithm rankings:")
        print(rankings)
        
        # Save results
        results_path = os.path.join(output_dir, "benchmark_results.csv")
        await juliaos.benchmarking.save_benchmark_results(combined_results, results_path)
        print(f"\nResults saved to: {results_path}")
        
        # Show plots
        plt.show()
    
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
