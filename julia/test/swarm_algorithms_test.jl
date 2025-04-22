"""
    swarm_algorithms_test.jl

Simple test for the swarm optimization algorithms.
"""

using Test
using Random
using Statistics
using LinearAlgebra

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import the modules
include("../src/swarm/SwarmBase.jl")
include("../src/swarm/algorithms/PSO.jl")
include("../src/swarm/algorithms/DE.jl")
include("../src/swarm/algorithms/GWO.jl")
include("../src/swarm/algorithms/ACO.jl")
include("../src/swarm/algorithms/GA.jl")
include("../src/swarm/algorithms/WOA.jl")
include("../src/swarm/algorithms/DEPSO.jl")

using .SwarmBase
using .PSO
using .DE
using .GWO
using .ACO
using .GA
using .WOA
using .DEPSO

# Set random seed for reproducibility
Random.seed!(42)

@testset "Swarm Algorithms Test" begin
    # Define test problems
    @testset "Test Problems" begin
        # Sphere function (minimum at origin)
        sphere_problem = OptimizationProblem(
            2,                          # 2 dimensions
            [(-10.0, 10.0), (-10.0, 10.0)], # Bounds
            x -> sum(x.^2),            # Objective function
            is_minimization = true
        )

        # Test that the problem is correctly defined
        @test sphere_problem.dimensions == 2
        @test length(sphere_problem.bounds) == 2
        @test sphere_problem.objective_function([0.0, 0.0]) ≈ 0.0
        @test sphere_problem.is_minimization == true
    end

    # Test each algorithm on the sphere function
    @testset "Algorithm Tests - Sphere Function" begin
        problem = OptimizationProblem(
            2,                          # 2 dimensions
            [(-10.0, 10.0), (-10.0, 10.0)], # Bounds
            x -> sum(x.^2),            # Objective function
            is_minimization = true
        )

        # PSO
        @testset "PSO" begin
            algorithm = ParticleSwarmOptimization(
                swarm_size = 20,
                max_iterations = 50,
                c1 = 2.0,
                c2 = 2.0,
                w = 0.7,
                w_damp = 0.99
            )

            result = PSO.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1  # Should be close to 0
            @test norm(result.best_position) < 0.5  # Should be close to origin
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end

        # DE
        @testset "DE" begin
            algorithm = DifferentialEvolution(
                population_size = 20,
                max_iterations = 50,
                F = 0.8,
                CR = 0.9,
                strategy = :rand_1_bin
            )

            result = DE.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end

        # GWO
        @testset "GWO" begin
            algorithm = GreyWolfOptimizer(
                population_size = 20,
                max_iterations = 50,
                a_decrease_factor = 2.0
            )

            result = GWO.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end

        # ACO
        @testset "ACO" begin
            algorithm = AntColonyOptimizer(
                colony_size = 20,
                max_iterations = 50,
                archive_size = 10,
                q = 0.5,
                xi = 0.7
            )

            result = ACO.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end

        # GA
        @testset "GA" begin
            algorithm = GeneticAlgorithm(
                population_size = 20,
                max_generations = 50,
                crossover_rate = 0.8,
                mutation_rate = 0.1,
                selection_pressure = 0.2,
                elitism_count = 2
            )

            result = GA.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_generations
        end

        # WOA
        @testset "WOA" begin
            algorithm = WhaleOptimizer(
                population_size = 20,
                max_iterations = 50,
                b = 1.0,
                a_decrease_factor = 2.0
            )

            result = WOA.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end

        # DEPSO
        @testset "DEPSO" begin
            algorithm = HybridDEPSO(
                population_size = 20,
                max_iterations = 50,
                F = 0.8,
                CR = 0.9,
                w = 0.7,
                c1 = 1.5,
                c2 = 1.5,
                hybrid_ratio = 0.5,
                adaptive = true,
                tolerance = 1e-6
            )

            result = DEPSO.optimize(problem, algorithm)

            @test result.success == true
            @test result.best_fitness < 0.1
            @test norm(result.best_position) < 0.5
            @test length(result.convergence_curve) <= algorithm.max_iterations
        end
    end

    # Test algorithm performance comparison
    @testset "Algorithm Performance Comparison" begin
        problem = OptimizationProblem(
            10,                          # 10 dimensions
            [(-10.0, 10.0) for _ in 1:10], # Bounds
            x -> sum(x.^2),            # Objective function
            is_minimization = true
        )

        # Define algorithms with same population size and iterations
        algorithms = [
            ("PSO", ParticleSwarmOptimization(swarm_size = 30, max_iterations = 100)),
            ("DE", DifferentialEvolution(population_size = 30, max_iterations = 100)),
            ("GWO", GreyWolfOptimizer(population_size = 30, max_iterations = 100)),
            ("ACO", AntColonyOptimizer(colony_size = 30, max_iterations = 100)),
            ("GA", GeneticAlgorithm(population_size = 30, max_generations = 100)),
            ("WOA", WhaleOptimizer(population_size = 30, max_iterations = 100)),
            ("DEPSO", HybridDEPSO(population_size = 30, max_iterations = 100))
        ]

        # Run each algorithm and collect results
        results = []
        for (name, algorithm) in algorithms
            local result
            if name == "PSO"
                result = PSO.optimize(problem, algorithm)
            elseif name == "DE"
                result = DE.optimize(problem, algorithm)
            elseif name == "GWO"
                result = GWO.optimize(problem, algorithm)
            elseif name == "ACO"
                result = ACO.optimize(problem, algorithm)
            elseif name == "GA"
                result = GA.optimize(problem, algorithm)
            elseif name == "WOA"
                result = WOA.optimize(problem, algorithm)
            elseif name == "DEPSO"
                result = DEPSO.optimize(problem, algorithm)
            end

            push!(results, (name, result.best_fitness, result.evaluations))

            # All algorithms should find a reasonable solution
            # For a 10D problem, we'll be more lenient
            @test result.best_fitness < 50.0
        end

        # Print performance comparison
        println("Algorithm Performance Comparison (10D Sphere Function):")
        println("Algorithm | Best Fitness | Function Evaluations")
        println("----------|--------------|---------------------")
        for (name, fitness, evals) in results
            println("$name | $(round(fitness, digits=6)) | $evals")
        end
    end
end

println("All tests completed successfully!")
