#!/usr/bin/env python3
"""
Optimization example for the JuliaOS Python wrapper.
"""

import asyncio
import logging
import numpy as np
from juliaos import JuliaOS
from juliaos.swarms import SwarmType

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# Define objective functions
def rosenbrock(x):
    """
    Rosenbrock function.
    
    A non-convex function used as a performance test problem for optimization algorithms.
    The global minimum is at (1, 1, ..., 1) with a value of 0.
    """
    return sum(100.0 * (x[i+1] - x[i]**2)**2 + (1.0 - x[i])**2 for i in range(len(x)-1))


def rastrigin(x):
    """
    Rastrigin function.
    
    A non-convex function used as a performance test problem for optimization algorithms.
    The global minimum is at (0, 0, ..., 0) with a value of 0.
    """
    A = 10
    n = len(x)
    return A * n + sum(x[i]**2 - A * np.cos(2 * np.pi * x[i]) for i in range(n))


async def run_optimization(juliaos, algorithm, objective_func, dimensions, bounds, config):
    """
    Run an optimization with a specific algorithm and objective function.
    
    Args:
        juliaos: JuliaOS instance
        algorithm: Optimization algorithm ("DE" or "PSO")
        objective_func: Objective function to optimize
        dimensions: Number of dimensions
        bounds: List of (min, max) tuples for each dimension
        config: Algorithm configuration
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
    logger.info(f"Created {algorithm} swarm: {swarm.id}")
    
    try:
        # Register the objective function
        function_id = f"python_func_{id(objective_func)}"
        await juliaos.swarms.set_objective_function(
            function_id=function_id,
            function_code=objective_func.__name__,
            function_type="python"
        )
        logger.info(f"Registered objective function: {objective_func.__name__}")
        
        # Run the optimization
        opt_result = await swarm.run_optimization(
            function_id=function_id,
            max_iterations=100,
            max_time_seconds=30,
            tolerance=1e-6
        )
        logger.info(f"Started optimization: {opt_result['optimization_id']}")
        
        # Wait for optimization to complete
        optimization_id = opt_result["optimization_id"]
        completed = False
        start_time = asyncio.get_event_loop().time()
        
        while not completed and (asyncio.get_event_loop().time() - start_time < 60):
            result = await swarm.get_optimization_result(optimization_id)
            if result["status"] in ["completed", "failed"]:
                completed = True
            else:
                logger.info(f"Optimization status: {result['status']}")
                await asyncio.sleep(2)
        
        # Get final result
        final_result = await swarm.get_optimization_result(optimization_id)
        
        if final_result["status"] == "completed":
            if algorithm == "DE":
                best_solution = final_result["result"]["best_individual"]
                best_fitness = final_result["result"]["best_fitness"]
            else:  # PSO
                best_solution = final_result["result"]["best_position"]
                best_fitness = final_result["result"]["best_fitness"]
            
            logger.info(f"Optimization completed!")
            logger.info(f"Best solution: {best_solution}")
            logger.info(f"Best fitness: {best_fitness}")
            
            # Get optimization history
            history = await swarm.get_optimization_history()
            logger.info(f"Optimization iterations: {len(history)}")
            
            return best_solution, best_fitness
        else:
            logger.error(f"Optimization failed: {final_result.get('error', 'Unknown error')}")
            return None, None
    
    finally:
        # Clean up
        await juliaos.swarms.delete_swarm(swarm.id)
        logger.info(f"Deleted swarm: {swarm.id}")


async def main():
    """
    Main function demonstrating optimization with JuliaOS.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS(host="localhost", port=8080)
    await juliaos.connect()
    logger.info("Connected to JuliaOS server")
    
    try:
        # Get available algorithms
        algorithms = await juliaos.swarms.get_available_algorithms()
        logger.info(f"Available algorithms: {algorithms}")
        
        # Run Differential Evolution on Rosenbrock function
        logger.info("\n=== Differential Evolution on Rosenbrock function ===")
        de_config = {
            "population_size": 30,
            "crossover_probability": 0.7,
            "differential_weight": 0.8,
            "strategy": "rand/1/bin"
        }
        await run_optimization(
            juliaos=juliaos,
            algorithm="DE",
            objective_func=rosenbrock,
            dimensions=5,
            bounds=[(-5.0, 5.0)] * 5,
            config=de_config
        )
        
        # Run Particle Swarm Optimization on Rastrigin function
        logger.info("\n=== Particle Swarm Optimization on Rastrigin function ===")
        pso_config = {
            "swarm_size": 30,
            "cognitive_coefficient": 2.0,
            "social_coefficient": 2.0,
            "inertia_weight": 0.7,
            "inertia_damping": 0.99
        }
        await run_optimization(
            juliaos=juliaos,
            algorithm="PSO",
            objective_func=rastrigin,
            dimensions=5,
            bounds=[(-5.12, 5.12)] * 5,
            config=pso_config
        )
        
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        logger.info("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
