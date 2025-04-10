using Test
using JuliaOS
using JuliaOS.SwarmManager
using JuliaOS.Algorithms
using Dates

@testset "Differential Evolution Integration Tests" begin
    @testset "DE Algorithm Creation" begin
        # Test creating a DE algorithm through the factory function
        params = Dict{String, Any}(
            "crossover_rate" => 0.8,
            "differential_weight" => 0.7,
            "strategy" => "DE/rand/1/bin"
        )
        
        de_algorithm = JuliaOS.Algorithms.create_algorithm("de", params)
        
        @test de_algorithm isa JuliaOS.Algorithms.DE.DEAlgorithm
        @test de_algorithm.crossover_rate == 0.8
        @test de_algorithm.differential_weight == 0.7
        @test de_algorithm.strategy == "DE/rand/1/bin"
    end
    
    @testset "DE Swarm Creation and Initialization" begin
        # Create a SwarmManagerConfig with DE algorithm
        config = SwarmManager.SwarmManagerConfig(
            "test_de_swarm",
            "Test DE Swarm",
            Dict{String, Any}(
                "type" => "de",
                "params" => Dict{String, Any}(
                    "crossover_rate" => 0.8,
                    "differential_weight" => 0.7,
                    "strategy" => "DE/rand/1/bin"
                )
            ),
            ["ETH/USDC", "BTC/USDC"],
            30, # num_particles
            Dict{String, Any}(
                "max_position_size" => 1000.0,
                "stop_loss" => 0.05,
                "take_profit" => 0.1
            )
        )
        
        # Create a swarm with the DE algorithm
        swarm = SwarmManager.create_swarm(config)
        
        @test swarm isa SwarmManager.Swarm
        @test swarm.algorithm isa JuliaOS.Algorithms.DE.DEAlgorithm
        
        # Test swarm initialization
        dimension = 4
        bounds = [
            (0.0, 1.0),    # entry_threshold
            (0.0, 1.0),    # exit_threshold
            (0.01, 0.2),   # stop_loss
            (0.01, 0.5)    # take_profit
        ]
        
        # Initialize the algorithm
        JuliaOS.Algorithms.initialize!(swarm.algorithm, config.num_particles, dimension, bounds)
        
        @test length(swarm.algorithm.population) == config.num_particles
        @test length(swarm.algorithm.fitness) == config.num_particles
        @test swarm.algorithm.dimension == dimension
        @test swarm.algorithm.population_size == config.num_particles
        @test swarm.algorithm.bounds == bounds
        
        # Test that all positions are within bounds
        for position in swarm.algorithm.population
            for d in 1:dimension
                @test bounds[d][1] <= position[d] <= bounds[d][2]
            end
        end
    end
    
    @testset "DE Optimization" begin
        # Create a simple fitness function (sphere function - minimize sum of squares)
        function sphere(x)
            return sum(x.^2)
        end
        
        # Create a SwarmManagerConfig with DE algorithm
        config = SwarmManager.SwarmManagerConfig(
            "test_de_opt",
            "Test DE Optimization",
            Dict{String, Any}(
                "type" => "de",
                "params" => Dict{String, Any}(
                    "crossover_rate" => 0.8,
                    "differential_weight" => 0.7,
                    "strategy" => "DE/rand/1/bin"
                )
            ),
            ["ETH/USDC"],
            20, # num_particles
            Dict{String, Any}()
        )
        
        # Create a swarm with the DE algorithm
        swarm = SwarmManager.create_swarm(config)
        
        # Initialize the algorithm
        dimension = 2
        bounds = [(−5.0, 5.0) for _ in 1:dimension]
        JuliaOS.Algorithms.initialize!(swarm.algorithm, config.num_particles, dimension, bounds)
        
        # Run optimization for a few iterations
        for i in 1:10
            JuliaOS.Algorithms.update_positions!(swarm.algorithm, sphere)
            JuliaOS.Algorithms.evaluate_fitness!(swarm.algorithm, sphere)
            JuliaOS.Algorithms.select_leaders!(swarm.algorithm)
        end
        
        # Get best position and fitness
        best_position = JuliaOS.Algorithms.get_best_position(swarm.algorithm)
        best_fitness = JuliaOS.Algorithms.get_best_fitness(swarm.algorithm)
        
        # Test that optimization improved the solution (should be close to origin)
        @test best_fitness < 1.0
        @test all(abs.(best_position) .< 1.0)
    end
    
    @testset "DE SwarmRouter Integration" begin
        # Test the SwarmRouter's differential_evolution_optimization function
        routes = [
            Dict("fee" => 0.1, "time" => 30, "security" => 0.9),
            Dict("fee" => 0.2, "time" => 20, "security" => 0.8),
            Dict("fee" => 0.3, "time" => 10, "security" => 0.7)
        ]
        
        weights = Dict("fee" => 0.5, "time" => 0.3, "security" => 0.2)
        
        result = JuliaOS.SwarmRouter.differential_evolution_optimization(
            routes, 
            weights,
            population_size=10,
            max_iterations=20
        )
        
        @test haskey(result, "ordered_indices")
        @test length(result["ordered_indices"]) == length(routes)
    end
end

println("All DE integration tests passed!")
