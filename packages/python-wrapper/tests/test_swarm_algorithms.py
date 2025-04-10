#!/usr/bin/env python3
"""
Test script for swarm algorithms in the JuliaOS Python wrapper.

This script demonstrates how to use the various swarm optimization algorithms
available in the JuliaOS Python wrapper.
"""

import asyncio
import sys
import os
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

# Add the parent directory to the path so we can import the juliaos package
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from juliaos import JuliaOS
from juliaos.swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm,
    SwarmAlgorithm, AVAILABLE_ALGORITHMS
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


async def test_algorithms():
    """
    Test all swarm algorithms on a simple optimization problem.
    """
    print("JuliaOS Swarm Algorithms Test")
    print("=============================")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Define bounds for test functions
        bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        
        # Common configuration
        config = {
            "max_iterations": 20,
            "max_time_seconds": 10,
            "tolerance": 1e-6
        }
        
        # Create algorithm instances
        de = DifferentialEvolution(juliaos.bridge)
        pso = ParticleSwarmOptimization(juliaos.bridge)
        gwo = GreyWolfOptimizer(juliaos.bridge)
        aco = AntColonyOptimization(juliaos.bridge)
        ga = GeneticAlgorithm(juliaos.bridge)
        woa = WhaleOptimizationAlgorithm(juliaos.bridge)
        
        # Test Differential Evolution
        print("\nTesting Differential Evolution...")
        try:
            de_result = await de.optimize(sphere, bounds, config)
            print(f"  Best fitness: {de_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {de_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {de_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Test Particle Swarm Optimization
        print("\nTesting Particle Swarm Optimization...")
        try:
            pso_result = await pso.optimize(sphere, bounds, config)
            print(f"  Best fitness: {pso_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {pso_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {pso_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Test Grey Wolf Optimizer
        print("\nTesting Grey Wolf Optimizer...")
        try:
            gwo_result = await gwo.optimize(sphere, bounds, config)
            print(f"  Best fitness: {gwo_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {gwo_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {gwo_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Test Ant Colony Optimization
        print("\nTesting Ant Colony Optimization...")
        try:
            aco_result = await aco.optimize(sphere, bounds, config)
            print(f"  Best fitness: {aco_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {aco_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {aco_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Test Genetic Algorithm
        print("\nTesting Genetic Algorithm...")
        try:
            ga_result = await ga.optimize(sphere, bounds, config)
            print(f"  Best fitness: {ga_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {ga_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {ga_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Test Whale Optimization Algorithm
        print("\nTesting Whale Optimization Algorithm...")
        try:
            woa_result = await woa.optimize(sphere, bounds, config)
            print(f"  Best fitness: {woa_result.get('best_fitness', 'N/A')}")
            print(f"  Best position: {woa_result.get('best_position', 'N/A')}")
            print(f"  Iterations: {woa_result.get('iterations', 'N/A')}")
        except Exception as e:
            print(f"  Error: {e}")
        
        # Print available algorithms
        print("\nAvailable algorithms:")
        print(f"  {', '.join(AVAILABLE_ALGORITHMS)}")
        
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()


if __name__ == "__main__":
    asyncio.run(test_algorithms())
