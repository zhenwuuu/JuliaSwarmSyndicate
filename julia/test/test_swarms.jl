using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Swarms
using Swarms.DifferentialEvolution
using Swarms.ParticleSwarmOptimization

function run_swarm_tests()
    @testset "Swarm Creation and Management" begin
        # Test swarm creation with Differential Evolution
        de_result = Swarms.create_swarm(
            "DE",
            2,
            [(-10.0, 10.0), (-10.0, 10.0)],
            Dict("population_size" => 20)
        )
        
        @test de_result["success"] == true
        @test de_result["algorithm"] == "DE"
        @test de_result["dimensions"] == 2
        @test de_result["swarm_size"] == 20
        
        # Test swarm creation with Particle Swarm Optimization
        pso_result = Swarms.create_swarm(
            "PSO",
            3,
            [(-5.0, 5.0), (-5.0, 5.0), (-5.0, 5.0)],
            Dict("swarm_size" => 30)
        )
        
        @test pso_result["success"] == true
        @test pso_result["algorithm"] == "PSO"
        @test pso_result["dimensions"] == 3
        @test pso_result["swarm_size"] == 30
        
        # Test getting swarm status
        de_status = Swarms.get_swarm_status(de_result["swarm_id"])
        @test de_status["success"] == true
        @test de_status["algorithm"] == "DE"
        @test de_status["status"] == "created"
        
        pso_status = Swarms.get_swarm_status(pso_result["swarm_id"])
        @test pso_status["success"] == true
        @test pso_status["algorithm"] == "PSO"
        @test pso_status["status"] == "created"
    end
    
    @testset "Differential Evolution" begin
        # Test population creation
        bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        population_size = 20
        
        pop_result = DifferentialEvolution.create_population(bounds, population_size)
        @test pop_result["success"] == true
        @test length(pop_result["population"]) == population_size
        @test length(pop_result["population"][1]) == 2
        
        # Test mutation
        population = pop_result["population"]
        mutant = DifferentialEvolution.mutate(population, 1, bounds, 0.8, "rand/1/bin")
        @test length(mutant) == 2
        @test all(bounds[i][1] <= mutant[i] <= bounds[i][2] for i in 1:2)
        
        # Test crossover
        target = population[1]
        trial = DifferentialEvolution.crossover(target, mutant, 0.7, "rand/1/bin")
        @test length(trial) == 2
        
        # Test selection
        # Define a simple objective function (sphere function)
        function sphere(x)
            return sum(x.^2)
        end
        
        target_fitness = sphere(target)
        selected, fitness = DifferentialEvolution.select(target, trial, target_fitness, sphere)
        @test length(selected) == 2
        @test fitness >= 0.0
        
        # Test optimization
        result = DifferentialEvolution.optimize(
            sphere,
            bounds,
            Dict(
                "population_size" => 20,
                "max_generations" => 50,
                "crossover_probability" => 0.7,
                "differential_weight" => 0.8,
                "strategy" => "rand/1/bin",
                "tolerance" => 1e-6,
                "max_time_seconds" => 5,
                "seed" => 42
            )
        )
        
        @test haskey(result, "best_individual")
        @test haskey(result, "best_fitness")
        @test haskey(result, "history")
        @test result["best_fitness"] < 1.0  # Should converge close to zero
    end
    
    @testset "Particle Swarm Optimization" begin
        # Test swarm creation
        bounds = [(-5.0, 5.0), (-5.0, 5.0)]
        swarm_size = 20
        
        swarm_result = ParticleSwarmOptimization.create_swarm(bounds, swarm_size)
        @test swarm_result["success"] == true
        @test length(swarm_result["swarm"]) == swarm_size
        @test haskey(swarm_result["swarm"][1], "position")
        @test haskey(swarm_result["swarm"][1], "velocity")
        
        # Test velocity update
        swarm = swarm_result["swarm"]
        particle = swarm[1]
        global_best_position = [0.0, 0.0]
        velocity_limits = [1.0, 1.0]
        
        new_velocity = ParticleSwarmOptimization.update_velocity(
            particle,
            global_best_position,
            0.7,
            2.0,
            2.0,
            velocity_limits
        )
        
        @test length(new_velocity) == 2
        @test all(-velocity_limits[i] <= new_velocity[i] <= velocity_limits[i] for i in 1:2)
        
        # Test position update
        new_position = ParticleSwarmOptimization.update_position(
            Dict("position" => particle["position"], "velocity" => new_velocity),
            bounds
        )
        
        @test length(new_position) == 2
        @test all(bounds[i][1] <= new_position[i] <= bounds[i][2] for i in 1:2)
        
        # Test optimization
        # Define a simple objective function (sphere function)
        function sphere(x)
            return sum(x.^2)
        end
        
        result = ParticleSwarmOptimization.optimize(
            sphere,
            bounds,
            Dict(
                "swarm_size" => 20,
                "max_iterations" => 50,
                "cognitive_coefficient" => 2.0,
                "social_coefficient" => 2.0,
                "inertia_weight" => 0.7,
                "inertia_damping" => 0.99,
                "min_inertia" => 0.4,
                "velocity_limit_factor" => 0.1,
                "tolerance" => 1e-6,
                "max_time_seconds" => 5,
                "seed" => 42
            )
        )
        
        @test haskey(result, "best_position")
        @test haskey(result, "best_fitness")
        @test haskey(result, "history")
        @test result["best_fitness"] < 1.0  # Should converge close to zero
    end
    
    @testset "Optimization with Objective Function" begin
        # Define a test objective function (Rosenbrock function)
        function rosenbrock(x)
            return sum(100.0 * (x[i+1] - x[i]^2)^2 + (1.0 - x[i])^2 for i in 1:length(x)-1)
        end
        
        # Set objective function
        function_id = "rosenbrock"
        Swarms.set_objective_function(function_id, rosenbrock)
        
        # Create swarm
        bounds = [(-2.0, 2.0), (-2.0, 2.0)]
        swarm_result = Swarms.create_swarm("DE", 2, bounds)
        @test swarm_result["success"] == true
        
        # Run optimization
        opt_result = Swarms.run_optimization(
            swarm_result["swarm_id"],
            function_id,
            Dict(
                "population_size" => 30,
                "max_generations" => 100,
                "max_time_seconds" => 5
            )
        )
        
        @test opt_result["success"] == true
        @test opt_result["status"] == "running"
        
        # Wait for optimization to complete (up to 10 seconds)
        optimization_id = opt_result["optimization_id"]
        completed = false
        start_time = now()
        
        while !completed && (now() - start_time).value / 1000 < 10
            result = Swarms.get_optimization_result(optimization_id)
            if result["success"] && (result["status"] == "completed" || result["status"] == "failed")
                completed = true
            else
                sleep(0.5)
            end
        end
        
        # Get final result
        final_result = Swarms.get_optimization_result(optimization_id)
        @test final_result["success"] == true
        
        if final_result["status"] == "completed"
            @test haskey(final_result["result"], "best_individual") || haskey(final_result["result"], "best_position")
            @test haskey(final_result["result"], "best_fitness")
        end
    end
    
    @testset "Available Algorithms" begin
        algorithms = Swarms.get_available_algorithms()
        @test "DE" in algorithms
        @test "PSO" in algorithms
    end
end
