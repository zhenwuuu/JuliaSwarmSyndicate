"""
Unit tests for the HybridDEPSO algorithm.
"""

import unittest
import asyncio
from unittest.mock import MagicMock, patch

from juliaos.swarms import HybridDEPSO
from juliaos.exceptions import SwarmError


class TestHybridDEPSO(unittest.TestCase):
    """
    Test cases for the HybridDEPSO algorithm.
    """
    
    def setUp(self):
        """
        Set up test fixtures.
        """
        self.bridge = MagicMock()
        self.bridge.execute = MagicMock()
        
        # Set up test data
        self.objective_function = lambda x: sum(xi**2 for xi in x)
        self.bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        self.config = {
            "population_size": 20,
            "max_generations": 10,
            "hybrid_ratio": 0.5,
            "adaptive_hybrid": True,
            "max_time_seconds": 5
        }
        
        # Create algorithm instance
        self.hybrid_depso = HybridDEPSO(self.bridge)
    
    async def test_optimize_success(self):
        """
        Test successful optimization.
        """
        # Set up mock return value
        mock_result = {
            "success": True,
            "best_position": [0.001, -0.002],
            "best_fitness": 0.000005,
            "iterations": 10,
            "converged": True,
            "final_hybrid_ratio": 0.6,
            "history": {
                "best_fitness": [1.0, 0.5, 0.1, 0.01, 0.001, 0.0001, 0.00001, 0.000005],
                "mean_fitness": [2.0, 1.0, 0.5, 0.1, 0.05, 0.01, 0.001, 0.0001],
                "hybrid_ratio": [0.5, 0.52, 0.55, 0.58, 0.6, 0.6, 0.6, 0.6]
            }
        }
        self.bridge.execute.return_value = mock_result
        
        # Run the optimization
        result = await self.hybrid_depso.optimize(
            objective_function=self.objective_function,
            bounds=self.bounds,
            config=self.config
        )
        
        # Check that the bridge was called correctly
        self.bridge.execute.assert_called_once()
        args = self.bridge.execute.call_args[0]
        self.assertEqual(args[0], "Swarms.HybridDEPSO.optimize")
        
        # Check that the result was returned correctly
        self.assertEqual(result, mock_result)
        self.assertEqual(result["best_fitness"], 0.000005)
        self.assertEqual(len(result["best_position"]), 2)
        self.assertEqual(result["final_hybrid_ratio"], 0.6)
    
    async def test_optimize_failure(self):
        """
        Test optimization failure.
        """
        # Set up mock return value
        self.bridge.execute.return_value = {
            "success": False,
            "error": "Test error"
        }
        
        # Run the optimization and check that it raises an error
        with self.assertRaises(SwarmError):
            await self.hybrid_depso.optimize(
                objective_function=self.objective_function,
                bounds=self.bounds,
                config=self.config
            )
    
    async def test_optimize_with_callable(self):
        """
        Test optimization with a callable objective function.
        """
        # Set up mock return value
        mock_result = {
            "success": True,
            "best_position": [0.001, -0.002],
            "best_fitness": 0.000005
        }
        self.bridge.execute.return_value = mock_result
        
        # Define a test function
        def test_func(x):
            return sum(xi**2 for xi in x)
        
        # Run the optimization
        result = await self.hybrid_depso.optimize(
            objective_function=test_func,
            bounds=self.bounds,
            config=self.config
        )
        
        # Check that the bridge was called correctly
        self.assertEqual(self.bridge.execute.call_count, 2)  # Once for register, once for optimize
        
        # Check that the result was returned correctly
        self.assertEqual(result, mock_result)
    
    async def test_default_config(self):
        """
        Test that default configuration is applied correctly.
        """
        # Set up mock return value
        mock_result = {
            "success": True,
            "best_position": [0.001, -0.002],
            "best_fitness": 0.000005
        }
        self.bridge.execute.return_value = mock_result
        
        # Run the optimization with no config
        result = await self.hybrid_depso.optimize(
            objective_function=self.objective_function,
            bounds=self.bounds
        )
        
        # Check that the bridge was called correctly
        self.bridge.execute.assert_called()
        
        # Get the config that was passed to the bridge
        args = self.bridge.execute.call_args[0]
        passed_config = args[2][2]  # args[0] is the command, args[1] is the arguments list, args[2][2] is the config
        
        # Check that default values were applied
        self.assertIn("population_size", passed_config)
        self.assertIn("hybrid_ratio", passed_config)
        self.assertIn("adaptive_hybrid", passed_config)
        self.assertIn("max_time_seconds", passed_config)
    
    def test_run_tests(self):
        """
        Run all async tests.
        """
        # Create event loop
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Run async tests
            loop.run_until_complete(self.test_optimize_success())
            loop.run_until_complete(self.test_optimize_failure())
            loop.run_until_complete(self.test_optimize_with_callable())
            loop.run_until_complete(self.test_default_config())
        finally:
            # Clean up
            loop.close()


if __name__ == "__main__":
    unittest.main()
