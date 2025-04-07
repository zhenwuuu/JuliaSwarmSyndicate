using JuliaOS
using JuliaOS.MarketData
using JuliaOS.SwarmManager
using JuliaOS.SwarmManager.Algorithms
using Plots
using Random
using Statistics
using LinearAlgebra

# Set a random seed for reproducibility
Random.seed!(42)

"""
    rosenbrock(x)

Rosenbrock function - a common benchmark for optimization algorithms.
Global minimum at (1,1,...,1) with a value of 0.
"""
function rosenbrock(x)
    sum = 0.0
    for i in 1:(length(x)-1)
        sum += 100 * (x[i+1] - x[i]^2)^2 + (x[i] - 1)^2
    end
    return sum
end

"""
    rastrigin(x)

Rastrigin function - a highly multimodal benchmark function.
Global minimum at (0,0,...,0) with a value of 0.
"""
function rastrigin(x)
    n = length(x)
    return 10*n + sum(x.^2 - 10*cos.(2π*x))
end

"""
    ackley(x)

Ackley function - another multimodal benchmark function.
Global minimum at (0,0,...,0) with a value of 0.
"""
function ackley(x)
    a, b, c = 20.0, 0.2, 2π
    n = length(x)
    
    sum1 = sum(x.^2)
    sum2 = sum(cos.(c .* x))
    
    term1 = -a * exp(-b * sqrt(sum1 / n))
    term2 = -exp(sum2 / n)
    
    return term1 + term2 + a + exp(1)
end

"""
    run_algorithm(algorithm_type, algorithm_params, fitness_function, dimension, bounds, iterations)

Run an optimization algorithm on a given fitness function and return the results.
"""
function run_algorithm(algorithm_type, algorithm_params, fitness_function, dimension, bounds, iterations)
    # Create algorithm
    algorithm = create_algorithm(algorithm_type, algorithm_params)
    
    # Initialize algorithm
    initialize!(algorithm, 30, dimension, bounds)
    
    # Run iterations
    convergence = Float64[]
    
    for i in 1:iterations
        update_positions!(algorithm, fitness_function)
        push!(convergence, get_best_fitness(algorithm))
        
        if i % 10 == 0
            println("$algorithm_type - Iteration $i: Best fitness = $(get_best_fitness(algorithm))")
        end
    end
    
    return get_best_position(algorithm), get_best_fitness(algorithm), convergence
end

"""
    compare_algorithms(fitness_function, dimension, bounds, iterations)

Compare different algorithms on a given fitness function.
"""
function compare_algorithms(fitness_function, dimension, bounds, iterations)
    # Define algorithms to compare (only our top 5)
    algorithms = [
        ("pso", Dict("inertia_weight" => 0.7, "cognitive_coef" => 1.5, "social_coef" => 1.5)),
        ("gwo", Dict("alpha_param" => 2.0, "decay_rate" => 0.01)),
        ("woa", Dict("a_decrease_factor" => 2.0, "spiral_constant" => 1.0)),
        ("genetic", Dict("crossover_rate" => 0.8, "mutation_rate" => 0.1)),
        ("aco", Dict("evaporation_rate" => 0.1, "alpha" => 1.0, "beta" => 2.0))
    ]
    
    # Run each algorithm
    results = Dict()
    
    for (algorithm_type, params) in algorithms
        println("Running $algorithm_type...")
        position, fitness, convergence = run_algorithm(algorithm_type, params, fitness_function, dimension, bounds, iterations)
        
        results[algorithm_type] = (
            position = position,
            fitness = fitness,
            convergence = convergence
        )
        
        println("$algorithm_type completed. Best fitness: $fitness")
        println("Best position: $position")
        println("--------------------------")
    end
    
    return results
end

"""
    plot_convergence(results)

Plot convergence curves for all algorithms.
"""
function plot_convergence(results, title)
    p = plot(title=title, xlabel="Iterations", ylabel="Fitness (log scale)", legend=:topright, yaxis=:log)
    
    for (algorithm, result) in results
        plot!(p, result.convergence, label=algorithm, linewidth=2)
    end
    
    return p
end

# Main script
function main()
    println("Starting algorithm comparison...")
    
    # Test settings
    dimension = 10
    iterations = 100
    bounds = [(i==1 ? (-5.0, 5.0) : (-5.0, 5.0)) for i in 1:dimension]
    
    # Run algorithms on Rosenbrock function
    println("\n===== Rosenbrock Function =====")
    results_rosenbrock = compare_algorithms(rosenbrock, dimension, bounds, iterations)
    p1 = plot_convergence(results_rosenbrock, "Convergence on Rosenbrock Function")
    
    # Run algorithms on Rastrigin function
    println("\n===== Rastrigin Function =====")
    results_rastrigin = compare_algorithms(rastrigin, dimension, bounds, iterations)
    p2 = plot_convergence(results_rastrigin, "Convergence on Rastrigin Function")
    
    # Run algorithms on Ackley function
    println("\n===== Ackley Function =====")
    results_ackley = compare_algorithms(ackley, dimension, bounds, iterations)
    p3 = plot_convergence(results_ackley, "Convergence on Ackley Function")
    
    # Save plots
    savefig(p1, "rosenbrock_comparison.png")
    savefig(p2, "rastrigin_comparison.png")
    savefig(p3, "ackley_comparison.png")
    
    # Create a combined plot
    plot(p1, p2, p3, layout=(3,1), size=(800, 1200))
    savefig("algorithm_comparison.png")
    
    println("\nComparison completed. Plots saved to current directory.")
end

# Run the main function
main() 