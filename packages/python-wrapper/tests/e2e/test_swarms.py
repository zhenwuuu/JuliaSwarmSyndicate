"""
End-to-end tests for swarm functionality.
"""

import asyncio
import pytest
import uuid
from juliaos.swarms import SwarmType


# Define test objective functions
def sphere(x):
    """
    Sphere function.
    
    A simple convex function with global minimum at (0, 0, ..., 0) with a value of 0.
    """
    return sum(xi**2 for xi in x)


def rosenbrock(x):
    """
    Rosenbrock function.
    
    A non-convex function with global minimum at (1, 1, ..., 1) with a value of 0.
    """
    return sum(100.0 * (x[i+1] - x[i]**2)**2 + (1.0 - x[i])**2 for i in range(len(x)-1))


@pytest.mark.asyncio
async def test_swarm_lifecycle(juliaos_client, clean_storage):
    """
    Test the complete lifecycle of a swarm.
    """
    # Create a swarm
    swarm_id = str(uuid.uuid4())
    swarm_name = "Test Swarm"
    swarm_type = SwarmType.OPTIMIZATION
    algorithm = "DE"
    dimensions = 2
    bounds = [(-10.0, 10.0), (-10.0, 10.0)]
    config = {
        "population_size": 20,
        "max_generations": 50
    }
    
    swarm = await juliaos_client.swarms.create_swarm(
        name=swarm_name,
        swarm_type=swarm_type,
        algorithm=algorithm,
        dimensions=dimensions,
        bounds=bounds,
        config=config,
        swarm_id=swarm_id
    )
    
    # Verify swarm was created correctly
    assert swarm.id == swarm_id
    assert swarm.name == swarm_name
    assert swarm.type == swarm_type.value
    assert swarm.algorithm == algorithm
    assert swarm.dimensions == dimensions
    assert swarm.swarm_size == 20
    
    # Get swarm status
    status = await swarm.get_status()
    assert status["success"] == True
    assert status["algorithm"] == algorithm
    
    # Update swarm config
    await swarm.update_config({"population_size": 30})
    assert swarm.config["population_size"] == 30
    
    # Delete the swarm
    await swarm.delete()
    
    # Verify swarm was deleted
    with pytest.raises(Exception):
        await juliaos_client.swarms.get_swarm(swarm_id)


@pytest.mark.asyncio
async def test_differential_evolution(juliaos_client, clean_storage):
    """
    Test Differential Evolution optimization.
    """
    # Register the objective function
    function_id = "test_sphere"
    await juliaos_client.swarms.set_objective_function(
        function_id=function_id,
        function_code="function(x) return sum(x.^2) end",
        function_type="julia"
    )
    
    # Create a DE swarm
    swarm = await juliaos_client.swarms.create_swarm(
        name="DE Test Swarm",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm="DE",
        dimensions=5,
        bounds=[(-5.0, 5.0)] * 5,
        config={
            "population_size": 20,
            "max_generations": 50,
            "crossover_probability": 0.7,
            "differential_weight": 0.8
        }
    )
    
    # Run optimization
    opt_result = await swarm.run_optimization(
        function_id=function_id,
        max_iterations=20,
        max_time_seconds=10,
        tolerance=1e-6
    )
    
    assert opt_result["success"] == True
    assert "optimization_id" in opt_result
    
    # Wait for optimization to complete (up to 15 seconds)
    optimization_id = opt_result["optimization_id"]
    completed = False
    start_time = asyncio.get_event_loop().time()
    
    while not completed and (asyncio.get_event_loop().time() - start_time < 15):
        result = await swarm.get_optimization_result(optimization_id)
        if result["status"] in ["completed", "failed"]:
            completed = True
        else:
            await asyncio.sleep(0.5)
    
    # Get final result
    final_result = await swarm.get_optimization_result(optimization_id)
    
    if final_result["status"] == "completed":
        assert "best_individual" in final_result["result"]
        assert "best_fitness" in final_result["result"]
        assert final_result["result"]["best_fitness"] < 1.0  # Should be close to 0
    
    # Clean up
    await swarm.delete()


@pytest.mark.asyncio
async def test_particle_swarm_optimization(juliaos_client, clean_storage):
    """
    Test Particle Swarm Optimization.
    """
    # Register the objective function
    function_id = "test_rosenbrock"
    await juliaos_client.swarms.set_objective_function(
        function_id=function_id,
        function_code="function(x) sum = 0; for i in 1:length(x)-1; sum += 100*(x[i+1] - x[i]^2)^2 + (1 - x[i])^2; end; return sum; end",
        function_type="julia"
    )
    
    # Create a PSO swarm
    swarm = await juliaos_client.swarms.create_swarm(
        name="PSO Test Swarm",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm="PSO",
        dimensions=5,
        bounds=[(-5.0, 5.0)] * 5,
        config={
            "swarm_size": 20,
            "max_iterations": 50,
            "cognitive_coefficient": 2.0,
            "social_coefficient": 2.0,
            "inertia_weight": 0.7
        }
    )
    
    # Run optimization
    opt_result = await swarm.run_optimization(
        function_id=function_id,
        max_iterations=20,
        max_time_seconds=10,
        tolerance=1e-6
    )
    
    assert opt_result["success"] == True
    assert "optimization_id" in opt_result
    
    # Wait for optimization to complete (up to 15 seconds)
    optimization_id = opt_result["optimization_id"]
    completed = False
    start_time = asyncio.get_event_loop().time()
    
    while not completed and (asyncio.get_event_loop().time() - start_time < 15):
        result = await swarm.get_optimization_result(optimization_id)
        if result["status"] in ["completed", "failed"]:
            completed = True
        else:
            await asyncio.sleep(0.5)
    
    # Get final result
    final_result = await swarm.get_optimization_result(optimization_id)
    
    if final_result["status"] == "completed":
        assert "best_position" in final_result["result"]
        assert "best_fitness" in final_result["result"]
    
    # Clean up
    await swarm.delete()


@pytest.mark.asyncio
async def test_swarm_with_python_function(juliaos_client, clean_storage):
    """
    Test swarm optimization with a Python function.
    """
    # Create a DE algorithm instance
    de = juliaos_client.swarms.DifferentialEvolution(juliaos_client.bridge)
    
    # Run optimization with Python function
    result = await de.optimize(
        objective_function=sphere,
        bounds=[(-5.0, 5.0)] * 3,
        config={
            "population_size": 20,
            "max_generations": 20,
            "max_time_seconds": 10
        }
    )
    
    assert "best_individual" in result
    assert "best_fitness" in result
    assert result["best_fitness"] < 1.0  # Should be close to 0
    
    # Create a PSO algorithm instance
    pso = juliaos_client.swarms.ParticleSwarmOptimization(juliaos_client.bridge)
    
    # Run optimization with Python function
    result = await pso.optimize(
        objective_function=rosenbrock,
        bounds=[(-2.0, 2.0)] * 3,
        config={
            "swarm_size": 20,
            "max_iterations": 20,
            "max_time_seconds": 10
        }
    )
    
    assert "best_position" in result
    assert "best_fitness" in result
