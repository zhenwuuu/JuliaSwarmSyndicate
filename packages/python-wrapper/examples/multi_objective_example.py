"""
Example script demonstrating the use of multi-objective optimization.

This script shows how to use the Multi-Objective Hybrid DE-PSO algorithm
to solve problems with multiple competing objectives.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

from juliaos import JuliaOS
from juliaos.swarms import SwarmType


# Define test multi-objective functions
def portfolio_return(weights):
    """
    Calculate the expected return of a portfolio.

    This is a simplified model where we assume the expected returns
    of assets are [0.05, 0.1, 0.15, 0.2, 0.25].

    Args:
        weights: Portfolio weights

    Returns:
        float: Negative expected return (for minimization)
    """
    # Expected returns of assets
    returns = np.array([0.05, 0.1, 0.15, 0.2, 0.25])

    # Calculate portfolio return
    portfolio_return = np.sum(weights * returns)

    # Return negative value for minimization
    return -portfolio_return


def sum_constraint(weights):
    """
    Constraint function to ensure weights sum to 1.

    Args:
        weights: Portfolio weights

    Returns:
        float: Constraint violation (should be <= 0 for feasible solutions)
    """
    return abs(np.sum(weights) - 1.0) - 0.001  # Allow small tolerance


def min_weight_constraint(weights):
    """
    Constraint function to ensure minimum weight for each asset.

    Args:
        weights: Portfolio weights

    Returns:
        float: Constraint violation (should be <= 0 for feasible solutions)
    """
    min_weight = 0.05  # Minimum 5% allocation to each asset
    return min_weight - np.min(weights)


def portfolio_risk(weights):
    """
    Calculate the risk (standard deviation) of a portfolio.

    This is a simplified model where we use a predefined covariance matrix.

    Args:
        weights: Portfolio weights

    Returns:
        float: Portfolio risk
    """
    # Simplified covariance matrix
    cov_matrix = np.array([
        [0.0100, 0.0018, 0.0011, 0.0014, 0.0016],
        [0.0018, 0.0109, 0.0026, 0.0012, 0.0023],
        [0.0011, 0.0026, 0.0199, 0.0036, 0.0027],
        [0.0014, 0.0012, 0.0036, 0.0289, 0.0031],
        [0.0016, 0.0023, 0.0027, 0.0031, 0.0399]
    ])

    # Calculate portfolio variance
    portfolio_variance = np.dot(weights.T, np.dot(cov_matrix, weights))

    # Return portfolio risk (standard deviation)
    return np.sqrt(portfolio_variance)


def plot_pareto_front(pareto_front, objective_names):
    """
    Plot the Pareto front for a bi-objective problem.

    Args:
        pareto_front: Dictionary containing solutions and objective values
        objective_names: Names of the objectives
    """
    # Use feasible solutions if available
    if "feasible_solutions" in pareto_front and len(pareto_front["feasible_solutions"]) > 0:
        solutions = pareto_front["feasible_solutions"]
        objective_values = pareto_front["feasible_objective_values"]
        title = "Feasible Pareto Front"
    else:
        solutions = pareto_front["solutions"]
        objective_values = pareto_front["objective_values"]
        title = "Pareto Front"

    # Convert to numpy array
    objective_values = np.array(objective_values)

    # For portfolio optimization, negate the first objective to get positive returns
    objective_values[:, 0] = -objective_values[:, 0]

    # Create figure
    plt.figure(figsize=(10, 6))

    # Plot Pareto front
    plt.scatter(
        objective_values[:, 0],
        objective_values[:, 1],
        c="blue",
        marker="o",
        s=50,
        alpha=0.7
    )

    # Connect points to show the front
    sorted_indices = np.argsort(objective_values[:, 0])
    plt.plot(
        objective_values[sorted_indices, 0],
        objective_values[sorted_indices, 1],
        "b--",
        alpha=0.3
    )

    # Set labels and title
    plt.xlabel(objective_names[0])
    plt.ylabel(objective_names[1])
    plt.title(title)

    # Add grid
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    # Show plot
    plt.show()


def plot_weights_distribution(pareto_front, asset_names=None):
    """
    Plot the distribution of weights for solutions in the Pareto front.

    Args:
        pareto_front: Dictionary containing solutions and objective values
        asset_names: Names of the assets
    """
    # Use feasible solutions if available
    if "feasible_solutions" in pareto_front and len(pareto_front["feasible_solutions"]) > 0:
        solutions = pareto_front["feasible_solutions"]
        title = "Distribution of Portfolio Weights in Feasible Pareto Front"
    else:
        solutions = pareto_front["solutions"]
        title = "Distribution of Portfolio Weights in Pareto Front"

    # Convert to numpy array
    solutions = np.array(solutions)

    # Set asset names if not provided
    if asset_names is None:
        asset_names = [f"Asset {i+1}" for i in range(solutions.shape[1])]

    # Create figure
    plt.figure(figsize=(12, 6))

    # Create box plot
    plt.boxplot(
        solutions,
        labels=asset_names,
        patch_artist=True,
        boxprops=dict(facecolor="lightblue", alpha=0.7)
    )

    # Add reference lines for constraints
    plt.axhline(y=0.05, color='r', linestyle='--', label="Min Weight Constraint (0.05)")
    plt.axhline(y=1.0/len(asset_names), color='g', linestyle='--', label="Equal Weight")

    # Set labels and title
    plt.xlabel("Assets")
    plt.ylabel("Weight")
    plt.title(title)
    plt.legend()

    # Add grid
    plt.grid(True, axis="y", alpha=0.3)
    plt.tight_layout()

    # Show plot
    plt.show()


async def run_portfolio_optimization(juliaos):
    """
    Run a portfolio optimization using multi-objective optimization.

    Args:
        juliaos: JuliaOS instance

    Returns:
        dict: Optimization result
    """
    print("=== Portfolio Optimization ===")

    # Define problem parameters
    num_assets = 5
    bounds = [(0.0, 1.0)] * num_assets  # Weights between 0 and 1

    # Create a swarm
    swarm = await juliaos.swarms.create_swarm(
        name="Portfolio Optimization",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm="MULTI_HYBRID_DEPSO",
        dimensions=num_assets,
        bounds=bounds,
        config={
            "population_size": 100,
            "max_generations": 100,
            "hybrid_ratio": 0.5,
            "adaptive_hybrid": True,
            "max_time_seconds": 60,
            "constraint_method": "feasibility",  # Use feasibility rules for constraints
            "penalty_factor": 1e6  # High penalty for constraint violations if using penalty method
        }
    )
    print(f"Created swarm: {swarm.id}")

    try:
        # Register objective functions
        return_id = "portfolio_return"
        risk_id = "portfolio_risk"
        sum_constraint_id = "sum_constraint"
        min_weight_constraint_id = "min_weight_constraint"

        await juliaos.swarms.set_objective_function(
            function_id=return_id,
            function_code=portfolio_return.__name__,
            function_type="python"
        )

        await juliaos.swarms.set_objective_function(
            function_id=risk_id,
            function_code=portfolio_risk.__name__,
            function_type="python"
        )

        # Register constraint functions
        await juliaos.swarms.set_objective_function(
            function_id=sum_constraint_id,
            function_code=sum_constraint.__name__,
            function_type="python"
        )

        await juliaos.swarms.set_objective_function(
            function_id=min_weight_constraint_id,
            function_code=min_weight_constraint.__name__,
            function_type="python"
        )

        print("Registered objective and constraint functions")

        # Run optimization
        print("Running optimization...")
        opt_result = await swarm.run_optimization(
            function_id=return_id,  # This will be used as the first objective
            max_iterations=100,
            max_time_seconds=60,
            parameters={
                "objective_functions": [return_id, risk_id],  # Specify both objectives
                "constraints": [sum_constraint_id, min_weight_constraint_id]  # Specify constraints
            }
        )

        # Get optimization result
        result = await swarm.get_optimization_result(opt_result["optimization_id"])

        if result["status"] == "completed":
            print("Optimization completed")

            # Extract Pareto front
            pareto_front = result["result"]["pareto_front"]

            # Print constraint satisfaction information
            if "constraint_satisfaction" in result["result"]:
                cs = result["result"]["constraint_satisfaction"]
                print(f"Constraint satisfaction: {cs['feasible_count']} / {cs['total_count']} solutions are feasible ({cs['feasible_percentage']:.2f}%)")

            # Use feasible solutions if available
            if "feasible_solutions" in pareto_front and len(pareto_front["feasible_solutions"]) > 0:
                print(f"Number of feasible solutions in Pareto front: {len(pareto_front['feasible_solutions'])}")
                solutions = pareto_front["feasible_solutions"]
                objective_values = pareto_front["feasible_objective_values"]
            else:
                print(f"Number of solutions in Pareto front: {len(pareto_front['solutions'])}")
                solutions = pareto_front["solutions"]
                objective_values = pareto_front["objective_values"]

            # Print a few example solutions
            print("\nExample solutions:")
            for i in range(min(3, len(solutions))):
                weights = solutions[i]
                objectives = objective_values[i]

                # Convert objectives to more intuitive values
                expected_return = -objectives[0]  # Negate to get positive return
                risk = objectives[1]

                # Calculate sum of weights to check constraint satisfaction
                weight_sum = sum(weights)
                min_weight = min(weights)

                print(f"Solution {i+1}:")
                print(f"  Weights: {[f'{w:.4f}' for w in weights]}")
                print(f"  Sum of weights: {weight_sum:.4f} (should be close to 1.0)")
                print(f"  Minimum weight: {min_weight:.4f} (should be >= 0.05)")
                print(f"  Expected Return: {expected_return:.4f}")
                print(f"  Risk: {risk:.4f}")
                print(f"  Sharpe Ratio: {expected_return/risk:.4f}")

            # Plot Pareto front
            plot_pareto_front(
                pareto_front,
                ["Expected Return", "Risk"]
            )

            # Plot weights distribution
            plot_weights_distribution(
                pareto_front,
                [f"Asset {i+1}" for i in range(num_assets)]
            )

            return result
        else:
            print(f"Optimization failed: {result.get('error', 'Unknown error')}")
            return None
    finally:
        # Delete the swarm
        await swarm.delete()


async def main():
    """
    Main function to run the example.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()

    print("=== Multi-Objective Optimization Example ===")

    try:
        # Check if MULTI_HYBRID_DEPSO is available
        algorithms = await juliaos.swarms.get_available_algorithms()

        if "MULTI_HYBRID_DEPSO" not in algorithms:
            print("Error: MULTI_HYBRID_DEPSO algorithm is not available.")
            return

        # Run portfolio optimization
        await run_portfolio_optimization(juliaos)

    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
