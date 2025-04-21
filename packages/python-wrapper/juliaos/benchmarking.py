"""
Python wrapper for the JuliaOS Benchmarking module.

This module provides a Pythonic interface to the JuliaOS Benchmarking module,
allowing users to run benchmarks, compare algorithms, and visualize results.
"""

import os
import json
import asyncio
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from typing import List, Dict, Any, Optional, Tuple, Union

from .bridge import JuliaBridge
from .exceptions import JuliaOSError


class BenchmarkFunction:
    """
    Represents a benchmark function for optimization algorithms.
    """
    
    def __init__(
        self,
        name: str,
        bounds: Tuple[float, float],
        optimum: float,
        difficulty: str = "medium"
    ):
        """
        Initialize a benchmark function.
        
        Args:
            name: Name of the benchmark function
            bounds: Tuple of (lower_bound, upper_bound) for each dimension
            optimum: Known optimum value of the function
            difficulty: Difficulty level ("easy", "medium", "hard")
        """
        self.name = name
        self.bounds = bounds
        self.optimum = optimum
        self.difficulty = difficulty
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the benchmark function to a dictionary.
        
        Returns:
            Dictionary representation of the benchmark function
        """
        return {
            "name": self.name,
            "bounds": self.bounds,
            "optimum": self.optimum,
            "difficulty": self.difficulty
        }


class BenchmarkingModule:
    """
    Python wrapper for the JuliaOS Benchmarking module.
    """
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the benchmarking module.
        
        Args:
            bridge: JuliaBridge instance for communication with the Julia backend
        """
        self.bridge = bridge
    
    async def get_standard_algorithms(self) -> Dict[str, str]:
        """
        Get the standard algorithms available for benchmarking.
        
        Returns:
            Dictionary mapping algorithm names to their descriptions
        """
        response = await self.bridge.request(
            "GET",
            "/benchmarking/algorithms"
        )
        
        return response["algorithms"]
    
    async def get_standard_benchmark_suite(
        self,
        difficulty: str = "all"
    ) -> List[BenchmarkFunction]:
        """
        Get a standard suite of benchmark functions.
        
        Args:
            difficulty: Difficulty level of benchmark functions ("easy", "medium", "hard", or "all")
        
        Returns:
            List of benchmark functions
        """
        response = await self.bridge.request(
            "GET",
            f"/benchmarking/functions?difficulty={difficulty}"
        )
        
        functions = []
        for func_data in response["functions"]:
            functions.append(BenchmarkFunction(
                name=func_data["name"],
                bounds=(func_data["bounds"][0], func_data["bounds"][1]),
                optimum=func_data["optimum"],
                difficulty=func_data["difficulty"]
            ))
        
        return functions
    
    async def run_benchmark(
        self,
        algorithm: str,
        functions: List[Union[str, BenchmarkFunction]],
        dimensions: int = 30,
        runs: int = 30,
        max_evaluations: int = 10000,
        **kwargs
    ) -> pd.DataFrame:
        """
        Run a benchmark for a specific algorithm on the given benchmark functions.
        
        Args:
            algorithm: Name of the optimization algorithm to benchmark
            functions: List of benchmark functions or function names to test
            dimensions: Dimensionality of the benchmark functions
            runs: Number of independent runs for statistical significance
            max_evaluations: Maximum number of function evaluations per run
            **kwargs: Additional parameters to pass to the algorithm
        
        Returns:
            DataFrame containing benchmark results
        """
        # Convert functions to names if they are BenchmarkFunction objects
        function_names = []
        for func in functions:
            if isinstance(func, BenchmarkFunction):
                function_names.append(func.name)
            else:
                function_names.append(func)
        
        response = await self.bridge.request(
            "POST",
            "/benchmarking/run",
            {
                "algorithm": algorithm,
                "functions": function_names,
                "dimensions": dimensions,
                "runs": runs,
                "max_evaluations": max_evaluations,
                "parameters": kwargs
            }
        )
        
        # Convert results to DataFrame
        results = pd.DataFrame(response["results"])
        
        return results
    
    async def compare_algorithms(
        self,
        algorithms: List[str],
        functions: List[Union[str, BenchmarkFunction]],
        dimensions: int = 30,
        runs: int = 30,
        max_evaluations: int = 10000,
        **kwargs
    ) -> pd.DataFrame:
        """
        Compare multiple algorithms on the given benchmark functions.
        
        Args:
            algorithms: List of algorithm names to compare
            functions: List of benchmark functions or function names to test
            dimensions: Dimensionality of the benchmark functions
            runs: Number of independent runs for statistical significance
            max_evaluations: Maximum number of function evaluations per run
            **kwargs: Additional parameters to pass to all algorithms
        
        Returns:
            DataFrame containing comparison results
        """
        # Convert functions to names if they are BenchmarkFunction objects
        function_names = []
        for func in functions:
            if isinstance(func, BenchmarkFunction):
                function_names.append(func.name)
            else:
                function_names.append(func)
        
        response = await self.bridge.request(
            "POST",
            "/benchmarking/compare",
            {
                "algorithms": algorithms,
                "functions": function_names,
                "dimensions": dimensions,
                "runs": runs,
                "max_evaluations": max_evaluations,
                "parameters": kwargs
            }
        )
        
        # Convert results to DataFrame
        results = pd.DataFrame(response["results"])
        
        return results
    
    async def get_benchmark_statistics(
        self,
        results: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Calculate statistics from benchmark results.
        
        Args:
            results: DataFrame containing benchmark results
        
        Returns:
            DataFrame containing statistical summaries
        """
        # Convert DataFrame to JSON
        results_json = results.to_json(orient="records")
        
        response = await self.bridge.request(
            "POST",
            "/benchmarking/statistics",
            {
                "results": json.loads(results_json)
            }
        )
        
        # Convert statistics to DataFrame
        stats = pd.DataFrame(response["statistics"])
        
        return stats
    
    async def save_benchmark_results(
        self,
        results: pd.DataFrame,
        filename: str
    ) -> None:
        """
        Save benchmark results to a CSV file.
        
        Args:
            results: DataFrame containing benchmark results
            filename: Output filename
        """
        # Save locally using pandas
        results.to_csv(filename, index=False)
    
    async def load_benchmark_results(
        self,
        filename: str
    ) -> pd.DataFrame:
        """
        Load benchmark results from a CSV file.
        
        Args:
            filename: Input filename
        
        Returns:
            DataFrame containing benchmark results
        """
        # Load locally using pandas
        results = pd.read_csv(filename)
        
        return results
    
    async def visualize_results(
        self,
        results: pd.DataFrame,
        metric: str = "BestFitness",
        group_by: str = "Function",
        log_scale: bool = False,
        save_path: Optional[str] = None
    ) -> plt.Figure:
        """
        Visualize benchmark results.
        
        Args:
            results: DataFrame containing benchmark results
            metric: The metric to visualize ("BestFitness", "ExecutionTime", "Evaluations", etc.)
            group_by: Column to group by ("Function" or "Algorithm")
            log_scale: Whether to use logarithmic scale for the y-axis
            save_path: Path to save the plot (optional)
        
        Returns:
            Matplotlib figure containing the visualization
        """
        # Check if we have algorithm information
        has_algorithm = "Algorithm" in results.columns
        
        if not has_algorithm and group_by == "Algorithm":
            raise ValueError("Cannot group by Algorithm as it's not present in the results")
        
        # Create figure
        fig, ax = plt.subplots(figsize=(12, 8))
        
        # Group data
        if group_by == "Function":
            # Group by function
            functions = results["Function"].unique()
            
            if has_algorithm:
                # Create a grouped boxplot
                sns.boxplot(
                    x="Function",
                    y=metric,
                    hue="Algorithm",
                    data=results,
                    ax=ax
                )
                
                # Rotate x-axis labels
                plt.xticks(rotation=45, ha="right")
                
                # Set title and labels
                ax.set_title(f"{metric} by Function")
                ax.set_xlabel("Function")
                ax.set_ylabel(metric)
                
                # Add legend
                ax.legend(title="Algorithm")
            else:
                # Create a boxplot for each function
                sns.boxplot(
                    x="Function",
                    y=metric,
                    data=results,
                    ax=ax
                )
                
                # Rotate x-axis labels
                plt.xticks(rotation=45, ha="right")
                
                # Set title and labels
                ax.set_title(f"{metric} by Function")
                ax.set_xlabel("Function")
                ax.set_ylabel(metric)
        else:  # group_by == "Algorithm"
            # Group by algorithm
            sns.boxplot(
                x="Algorithm",
                y=metric,
                hue="Function",
                data=results,
                ax=ax
            )
            
            # Set title and labels
            ax.set_title(f"{metric} by Algorithm")
            ax.set_xlabel("Algorithm")
            ax.set_ylabel(metric)
            
            # Add legend
            ax.legend(title="Function", bbox_to_anchor=(1.05, 1), loc="upper left")
        
        # Apply log scale if requested
        if log_scale and results[metric].min() > 0:
            ax.set_yscale("log")
        
        # Adjust layout
        plt.tight_layout()
        
        # Save plot if requested
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches="tight")
        
        return fig
    
    async def visualize_comparison(
        self,
        results: pd.DataFrame,
        metric: str = "BestFitness",
        log_scale: bool = False,
        save_path: Optional[str] = None
    ) -> plt.Figure:
        """
        Visualize a comparison of algorithms across benchmark functions.
        
        Args:
            results: DataFrame containing benchmark results with Algorithm column
            metric: The metric to visualize ("BestFitness", "ExecutionTime", "Evaluations", etc.)
            log_scale: Whether to use logarithmic scale for the y-axis
            save_path: Path to save the plot (optional)
        
        Returns:
            Matplotlib figure containing the visualization
        """
        if "Algorithm" not in results.columns:
            raise ValueError("Results must contain an Algorithm column for comparison")
        
        # Calculate statistics by Function and Algorithm
        stats = results.groupby(["Function", "Algorithm"])[metric].agg(["mean", "std"]).reset_index()
        
        # Create figure
        fig, ax = plt.subplots(figsize=(14, 8))
        
        # Create a grouped bar plot
        sns.barplot(
            x="Function",
            y="mean",
            hue="Algorithm",
            data=stats,
            ax=ax
        )
        
        # Rotate x-axis labels
        plt.xticks(rotation=45, ha="right")
        
        # Set title and labels
        ax.set_title(f"Algorithm Comparison - Mean {metric}")
        ax.set_xlabel("Benchmark Function")
        ax.set_ylabel(f"Mean {metric}")
        
        # Add legend
        ax.legend(title="Algorithm", bbox_to_anchor=(1.05, 1), loc="upper left")
        
        # Apply log scale if requested
        if log_scale and stats["mean"].min() > 0:
            ax.set_yscale("log")
        
        # Adjust layout
        plt.tight_layout()
        
        # Save plot if requested
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches="tight")
        
        return fig
    
    async def generate_benchmark_report(
        self,
        results: pd.DataFrame,
        output_dir: str,
        include_plots: bool = True
    ) -> str:
        """
        Generate a comprehensive benchmark report in HTML format.
        
        Args:
            results: DataFrame containing benchmark results
            output_dir: Directory to save the report and associated files
            include_plots: Whether to include plots in the report
        
        Returns:
            Path to the generated report
        """
        # Convert DataFrame to JSON
        results_json = results.to_json(orient="records")
        
        response = await self.bridge.request(
            "POST",
            "/benchmarking/report",
            {
                "results": json.loads(results_json),
                "output_dir": output_dir,
                "include_plots": include_plots
            }
        )
        
        return response["report_path"]
    
    async def rank_algorithms(
        self,
        results: pd.DataFrame,
        metric: str = "BestFitness",
        lower_is_better: bool = True
    ) -> pd.DataFrame:
        """
        Rank algorithms based on their performance across benchmark functions.
        
        Args:
            results: DataFrame containing benchmark results with Algorithm column
            metric: The metric to use for ranking ("BestFitness", "ExecutionTime", etc.)
            lower_is_better: Whether lower values of the metric are better
        
        Returns:
            DataFrame containing algorithm rankings
        """
        if "Algorithm" not in results.columns:
            raise ValueError("Results must contain an Algorithm column for ranking")
        
        # Convert DataFrame to JSON
        results_json = results.to_json(orient="records")
        
        response = await self.bridge.request(
            "POST",
            "/benchmarking/rank",
            {
                "results": json.loads(results_json),
                "metric": metric,
                "lower_is_better": lower_is_better
            }
        )
        
        # Convert rankings to DataFrame
        rankings = pd.DataFrame(response["rankings"])
        
        return rankings
