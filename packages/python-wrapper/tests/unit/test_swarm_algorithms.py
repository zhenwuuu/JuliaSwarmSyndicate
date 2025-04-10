"""
Unit tests for swarm algorithms.
"""

import unittest
import asyncio
from unittest.mock import MagicMock, patch

from juliaos.swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm,
    AVAILABLE_ALGORITHMS
)
from juliaos.exceptions import SwarmError


class TestSwarmAlgorithms(unittest.TestCase):
    """
    Test cases for swarm algorithms.
    """
    
    def setUp(self):
        """
        Set up test fixtures.
        """
        self.bridge = MagicMock()
        self.bridge.execute = MagicMock()
        
        # Set up test data
        self.objective_function = "test_function"
        self.bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        self.config = {"max_iterations": 10, "max_time_seconds": 5}
        
        # Create algorithm instances
        self.de = DifferentialEvolution(self.bridge)
        self.pso = ParticleSwarmOptimization(self.bridge)
        self.gwo = GreyWolfOptimizer(self.bridge)
        self.aco = AntColonyOptimization(self.bridge)
        self.ga = GeneticAlgorithm(self.bridge)
        self.woa = WhaleOptimizationAlgorithm(self.bridge)
    
    def test_available_algorithms(self):
        """
        Test that all expected algorithms are available.
        """
        expected_algorithms = ["DE", "PSO", "GWO", "ACO", "GA", "WOA"]
        self.assertEqual(set(AVAILABLE_ALGORITHMS), set(expected_algorithms))
    
    async def _test_algorithm(self, algorithm, algorithm_name, method_name):
        """
        Helper method to test an algorithm.
        
        Args:
            algorithm: Algorithm instance to test
            algorithm_name: Name of the algorithm
            method_name: Name of the method to call on the bridge
        """
        # Set up mock return value
        self.bridge.execute.return_value = {"success": True, "best_position": [0.0, 0.0], "best_fitness": 0.0}
        
        # Run the algorithm
        result = await algorithm.optimize(self.objective_function, self.bounds, self.config)
        
        # Check that the bridge was called correctly
        self.bridge.execute.assert_called_once()
        args = self.bridge.execute.call_args[0]
        self.assertEqual(args[0], method_name)
        self.assertEqual(args[1][0], self.objective_function)
        self.assertEqual(args[1][1], self.bounds)
        
        # Check that the result was returned correctly
        self.assertTrue(result["success"])
        self.assertEqual(result["best_position"], [0.0, 0.0])
        self.assertEqual(result["best_fitness"], 0.0)
    
    def test_differential_evolution(self):
        """
        Test Differential Evolution algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.de, "DE", "Swarms.DifferentialEvolution.optimize"
        ))
    
    def test_particle_swarm_optimization(self):
        """
        Test Particle Swarm Optimization algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.pso, "PSO", "Swarms.ParticleSwarmOptimization.optimize"
        ))
    
    def test_grey_wolf_optimizer(self):
        """
        Test Grey Wolf Optimizer algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.gwo, "GWO", "Swarms.GreyWolfOptimization.optimize"
        ))
    
    def test_ant_colony_optimization(self):
        """
        Test Ant Colony Optimization algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.aco, "ACO", "Swarms.AntColonyOptimization.optimize"
        ))
    
    def test_genetic_algorithm(self):
        """
        Test Genetic Algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.ga, "GA", "Swarms.GeneticAlgorithm.optimize"
        ))
    
    def test_whale_optimization_algorithm(self):
        """
        Test Whale Optimization Algorithm.
        """
        asyncio.run(self._test_algorithm(
            self.woa, "WOA", "Swarms.WhaleOptimizationAlgorithm.optimize"
        ))
    
    async def _test_algorithm_error(self, algorithm):
        """
        Helper method to test algorithm error handling.
        
        Args:
            algorithm: Algorithm instance to test
        """
        # Set up mock return value
        self.bridge.execute.return_value = {"success": False, "error": "Test error"}
        
        # Run the algorithm and check that it raises an error
        with self.assertRaises(SwarmError):
            await algorithm.optimize(self.objective_function, self.bounds, self.config)
    
    def test_algorithm_error_handling(self):
        """
        Test error handling for all algorithms.
        """
        for algorithm in [self.de, self.pso, self.gwo, self.aco, self.ga, self.woa]:
            asyncio.run(self._test_algorithm_error(algorithm))


if __name__ == "__main__":
    unittest.main()
