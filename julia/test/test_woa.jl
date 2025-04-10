using Test
include("../src/algorithms/Algorithms.jl")

@testset "Whale Optimization Algorithm Tests" begin
    # Test WOA constructor
    @testset "WOA Constructor" begin
        woa = Algorithms.WOA(5, 20, b=1.5)
        @test woa.dimensions == 5
        @test woa.whales == 20
        @test woa.b == 1.5
    end

    # Test initialization
    @testset "WOA Initialization" begin
        woa = Algorithms.WOA(3, 10)
        bounds = [(0.0, 10.0), (-5.0, 5.0), (-100.0, 100.0)]
        whales = Algorithms.initialize(woa, bounds)
        
        @test length(whales) == 10  # Number of whales
        
        # Check that all whales are within bounds
        for whale in whales
            @test length(whale[:position]) == 3  # Dimensions
            @test 0.0 <= whale[:position][1] <= 10.0
            @test -5.0 <= whale[:position][2] <= 5.0
            @test -100.0 <= whale[:position][3] <= 100.0
            @test whale[:fitness] == Inf  # Initial fitness
        end
    end

    # Test optimization on a simple function (sphere function)
    @testset "WOA Optimization - Sphere Function" begin
        # Sphere function (minimum at origin)
        function sphere(x)
            return sum(x.^2)
        end
        
        woa = Algorithms.WOA(5, 20)
        bounds = [(-10.0, 10.0) for _ in 1:5]
        max_iterations = 50
        
        result = Algorithms.optimize(woa, sphere, max_iterations, bounds)
        
        # Check that the result contains the expected keys
        @test haskey(result, "best_position")
        @test haskey(result, "best_fitness")
        @test haskey(result, "convergence_history")
        @test haskey(result, "final_population")
        
        # Check that the best position is close to the origin
        @test all(abs.(result["best_position"]) .< 1.0)
        
        # Check that the best fitness is close to zero
        @test result["best_fitness"] < 1.0
        
        # Check that the convergence history has the right length
        @test length(result["convergence_history"]) == max_iterations
        
        # Check that the final population has the right size
        @test length(result["final_population"]) == 20
    end

    # Test update_agents function
    @testset "WOA update_agents" begin
        woa = Algorithms.WOA(2, 5)
        
        # Create some test agents
        agents = [
            Dict(:position => [1.0, 2.0], :fitness => 5.0),
            Dict(:position => [0.0, 0.0], :fitness => 0.0),  # Best agent
            Dict(:position => [3.0, 4.0], :fitness => 25.0),
            Dict(:position => [-1.0, -2.0], :fitness => 5.0),
            Dict(:position => [5.0, 6.0], :fitness => 61.0)
        ]
        
        # Simple objective function
        obj_func = x -> sum(x.^2)
        
        # Update agents
        updated_agents = Algorithms.update_agents(woa, agents, obj_func, 1)
        
        # Check that we still have the same number of agents
        @test length(updated_agents) == 5
        
        # Check that positions have been updated
        for i in 1:5
            @test updated_agents[i][:position] != agents[i][:position]
            @test length(updated_agents[i][:position]) == 2
            
            # Check that fitness has been updated
            @test updated_agents[i][:fitness] == obj_func(updated_agents[i][:position])
        end
    end
end
