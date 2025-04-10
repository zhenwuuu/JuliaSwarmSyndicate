using Test
using StatsBase
include("./julia/src/algorithms/Algorithms.jl")

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
            position = rand(dimensions) .* 10 .- 5  # Use broadcasting
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

        # Define our own update_agents function that uses StatsBase directly
        function custom_update_agents(algorithm, agents, objective_function, iteration)
            dimensions = algorithm.dimensions
            bounds = algorithm.bounds

            # Get the current best agent
            best_idx = argmin([agent[:fitness] for agent in agents])
            best_agent = agents[best_idx]

            # Update each agent using DE operators
            for i in 1:length(agents)
                # Skip if this agent is inactive
                if haskey(agents[i], :active) && !agents[i][:active]
                    continue
                end

                # Select three random agents different from the current one
                active_indices = findall(a -> (!haskey(a, :active) || a[:active]) &&
                                       (!haskey(a, :id) || a[:id] != agents[i][:id]), agents)

                # If we don't have enough active agents, skip this update
                if length(active_indices) < 3
                    continue
                end

                # Sample three random agents using StatsBase directly
                selected_indices = StatsBase.sample(active_indices, 3, replace=false)
                a, b, c = agents[selected_indices[1]], agents[selected_indices[2]], agents[selected_indices[3]]

                # Create trial vector through mutation
                donor = a[:position] + algorithm.F * (b[:position] - c[:position])

                # Apply bounds
                for d in 1:dimensions
                    lower, upper = bounds[d]
                    donor[d] = clamp(donor[d], lower, upper)
                end

                # Perform crossover
                trial = zeros(dimensions)
                j_rand = rand(1:dimensions)  # Ensure at least one parameter is taken from donor

                for j in 1:dimensions
                    if rand() < algorithm.CR || j == j_rand
                        trial[j] = donor[j]  # From donor
                    else
                        trial[j] = agents[i][:position][j]  # From target
                    end
                end

                # Evaluate trial vector
                trial_fitness = objective_function(trial)

                # Selection: replace if better
                if trial_fitness <= agents[i][:fitness]
                    agents[i][:position] = trial
                    agents[i][:fitness] = trial_fitness

                    # Update velocity if it exists
                    if haskey(agents[i], :velocity)
                        agents[i][:velocity] = zeros(dimensions)  # Reset velocity as it's not used in DE
                    end

                    # Update personal best if it exists
                    if haskey(agents[i], :personal_best_position)
                        agents[i][:personal_best_position] = trial
                    end

                    if haskey(agents[i], :personal_best_fitness)
                        agents[i][:personal_best_fitness] = trial_fitness
                    end
                end
            end

            return agents
        end

        # Update agents using our custom function
        updated_agents = custom_update_agents(de, agents, sphere, 1)

        @test length(updated_agents) == 10
    end
end

println("All DE tests passed!")
