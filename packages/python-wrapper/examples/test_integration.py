#!/usr/bin/env python3
"""
Test script for the JuliaOS Python wrapper integration.
"""

import os
import sys
import json
import time
from pathlib import Path

# Add the parent directory to the Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from juliaos import JuliaOS

def main():
    """
    Main function to test the JuliaOS Python wrapper integration.
    """
    print("Testing JuliaOS Python wrapper integration...")
    
    # Initialize JuliaOS
    juliaos = JuliaOS(host="localhost", port=8052)
    
    # Check health
    print("\nChecking health...")
    health = juliaos.check_health()
    print(f"Health status: {health.get('status', 'unknown')}")
    
    # List available swarm algorithms
    print("\nListing available swarm algorithms...")
    swarms_health = juliaos.swarms.check_health()
    algorithms = swarms_health.get("algorithms", [])
    print(f"Available algorithms: {', '.join(algorithms)}")
    
    # Create a swarm
    print("\nCreating a swarm...")
    swarm = juliaos.swarms.create_swarm(
        name="Test Swarm",
        algorithm="DE",
        config={}
    )
    swarm_id = swarm.get("id")
    print(f"Created swarm with ID: {swarm_id}")
    
    # Define a simple objective function
    objective_function = """
    function(x)
        return x[1]^2 + x[2]^2
    end
    """
    
    # Run optimization
    print("\nRunning optimization...")
    result = juliaos.swarms.run_optimization(
        swarm_id=swarm_id,
        objective_function=objective_function,
        parameters={
            "bounds": [(-5.0, 5.0), (-5.0, 5.0)],
            "population_size": 20,
            "max_iterations": 50
        }
    )
    
    # Get the result
    print("\nGetting optimization result...")
    result_id = result.get("id")
    optimization_result = juliaos.swarms.get_result(swarm_id, result_id)
    
    # Print the result
    print(f"Best fitness: {optimization_result.get('best_fitness')}")
    print(f"Best solution: {optimization_result.get('best_solution')}")
    print(f"Iterations: {optimization_result.get('iterations')}")
    
    print("\nTest completed successfully!")

if __name__ == "__main__":
    main()
