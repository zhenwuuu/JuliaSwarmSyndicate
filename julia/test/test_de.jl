using Test
include("../src/algorithms/Algorithms.jl")

# Test function: Sphere function (global minimum at origin)
function sphere(x)
    return sum(x.^2)
end

# Test function: Rosenbrock function (global minimum at [1,1,...,1])
function rosenbrock(x)
    sum = 0.0
    for i in 1:length(x)-1
        sum += 100 * (x[i+1] - x[i]^2)^2 + (x[i] - 1)^2
    end
    return sum
end

# Test function: Rastrigin function (global minimum at origin)
function rastrigin(x)
    n = length(x)
    return 10*n + sum(x.^2 - 10*cos.(2π*x))
end

@testset "Differential Evolution Tests" begin
    # Test DE initialization
    @testset "DE Initialization" begin
        dimensions = 5
        bounds = [(-5.0, 5.0) for _ in 1:dimensions]
        de = Algorithms.DE(
            dimensions,
            30,
            F=0.8,
            CR=0.9,
            bounds=bounds
        )

        population = Algorithms.initialize(de, bounds)

        @test length(population) == 30
        @test length(population[1][:position]) == dimensions

        # Test that all positions are within bounds
        for ind in population
            for d in 1:dimensions
                @test ind[:position][d] >= bounds[d][1]
                @test ind[:position][d] <= bounds[d][2]
            end
        end
    end

    # Test DE optimization on sphere function
    @testset "DE Optimization - Sphere Function" begin
        dimensions = 5
        bounds = [(-5.0, 5.0) for _ in 1:dimensions]
        de = Algorithms.DE(
            dimensions,
            30,
            F=0.8,
            CR=0.9,
            bounds=bounds
        )

        result = Algorithms.optimize(de, sphere, 100, bounds)

        @test haskey(result, "best_position")
        @test haskey(result, "best_fitness")
        @test haskey(result, "convergence_history")
        @test haskey(result, "final_population")

        # Test that optimization improved the solution
        @test result["best_fitness"] < 1.0

        # Test that convergence history is decreasing
        for i in 2:length(result["convergence_history"])
            @test result["convergence_history"][i] <= result["convergence_history"][i-1]
        end
    end

    # Test DE optimization on Rosenbrock function
    @testset "DE Optimization - Rosenbrock Function" begin
        dimensions = 2
        bounds = [(-5.0, 10.0) for _ in 1:dimensions]
        de = Algorithms.DE(
            dimensions,
            50,
            F=0.8,
            CR=0.9,
            bounds=bounds
        )

        result = Algorithms.optimize(de, rosenbrock, 200, bounds)

        # Test that optimization found a good solution
        # Rosenbrock is harder, so we use a more relaxed threshold
        @test result["best_fitness"] < 10.0

        # Check if the solution is close to the known optimum [1,1]
        for i in 1:dimensions
            @test isapprox(result["best_position"][i], 1.0, atol=0.5)
        end
    end

    # Test DE optimization on Rastrigin function
    @testset "DE Optimization - Rastrigin Function" begin
        dimensions = 5
        bounds = [(-5.12, 5.12) for _ in 1:dimensions]
        de = Algorithms.DE(
            dimensions,
            50,
            F=0.8,
            CR=0.9,
            bounds=bounds
        )

        result = Algorithms.optimize(de, rastrigin, 300, bounds)

        # Test that optimization found a reasonable solution
        # Rastrigin is multimodal and difficult, so we use a relaxed threshold
        @test result["best_fitness"] < 50.0
    end

    # Test DE agent update
    @testset "DE Agent Update" begin
        dimensions = 2
        bounds = [(-5.0, 5.0) for _ in 1:dimensions]
        de = Algorithms.DE(
            dimensions,
            10,
            F=0.8,
            CR=0.9,
            bounds=bounds
        )

        # Create test agents
        agents = []
        for i in 1:10
            position = rand(dimensions) * 10 - 5
            agent = Dict(
                :id => i,
                :position => position,
                :velocity => zeros(dimensions),
                :fitness => sphere(position),
                :personal_best_position => position,
                :personal_best_fitness => sphere(position),
                :active => true
            )
            push!(agents, agent)
        end

        # Update agents
        updated_agents = Algorithms.update_agents(de, agents, sphere, 1)

        @test length(updated_agents) == 10

        # Test that at least some agents improved
        improved_count = 0
        for i in 1:10
            if updated_agents[i][:fitness] < agents[i][:fitness]
                improved_count += 1
            end
        end

        @test improved_count > 0
    end
end

println("All DE tests passed!")
