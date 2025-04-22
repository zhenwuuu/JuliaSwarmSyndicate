"""
    depso_example.jl

Example demonstrating the usage of the Hybrid DEPSO algorithm.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using LinearAlgebra

# Import JuliaOS modules
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")
include("../julia/src/swarm/algorithms/PSO.jl")
include("../julia/src/swarm/algorithms/DE.jl")

using .SwarmBase
using .DEPSO
using .PSO
using .DE

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_depso_example()

Run an example optimization using the Hybrid DEPSO algorithm.
"""
function run_depso_example()
    println("Hybrid DEPSO Algorithm Example")
    println("==============================")

    # Define test functions
    functions = Dict(
        "sphere" => (x -> sum(x.^2), "Sphere Function"),
        "rastrigin" => (x -> 10 * length(x) + sum(x.^2 - 10 * cos.(2π * x)), "Rastrigin Function"),
        "rosenbrock" => (x -> sum(100.0 * (x[2:end] .- x[1:end-1].^2).^2 .+ (x[1:end-1] .- 1.0).^2), "Rosenbrock Function")
    )

    # Define dimensions and bounds
    dimensions = 10
    bounds = [(-5.0, 5.0) for _ in 1:dimensions]

    # Create the DEPSO algorithm
    algorithm = HybridDEPSO(
        population_size = 50,
        max_iterations = 100,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true,
        tolerance = 1e-6
    )

    # Run optimization for each function
    results = Dict()

    for (func_name, (func, func_desc)) in functions
        println("\nOptimizing $(func_desc)...")

        # Create optimization problem
        problem = OptimizationProblem(
            dimensions,
            bounds,
            func;
            is_minimization = true
        )

        # Define callback function to track progress
        iteration_data = []
        function callback(iter, best_pos, best_fit, pop)
            push!(iteration_data, (iter, best_fit))
            if iter % 10 == 0
                println("  Iteration $iter: Best fitness = $best_fit")
            end
            return true  # Continue optimization
        end

        # Run optimization
        result = DEPSO.optimize(problem, algorithm; callback=callback)

        # Store results
        results[func_name] = (result, iteration_data)

        # Print results
        println("  Optimization completed in $(length(result.convergence_curve)) iterations")
        println("  Best fitness: $(result.best_fitness)")
        println("  Best position: $(round.(result.best_position, digits=4))")
        println("  Function evaluations: $(result.evaluations)")
    end

    # Print convergence data
    println("\nConvergence Data:")
    for (func_name, (result, iteration_data)) in results
        println("  $(functions[func_name][2]):")
        println("    Initial fitness: $(iteration_data[1][2])")
        println("    Final fitness: $(iteration_data[end][2])")
        println("    Improvement factor: $(iteration_data[1][2] / iteration_data[end][2])")
    end

    # Compare with other algorithms
    println("\nComparing DEPSO with other algorithms on the Sphere function...")
    compare_algorithms()

    return results
end

"""
    compare_algorithms()

Compare DEPSO with other swarm algorithms on the Sphere function.
"""
function compare_algorithms()
    # All necessary modules are already imported at the top level

    # Define problem
    dimensions = 10
    bounds = [(-5.0, 5.0) for _ in 1:dimensions]

    problem = OptimizationProblem(
        dimensions,
        bounds,
        x -> sum(x.^2);  # Sphere function
        is_minimization = true
    )

    # Define algorithms
    algorithms = [
        ("PSO", ParticleSwarmOptimization(swarm_size = 50, max_iterations = 100)),
        ("DE", DifferentialEvolution(population_size = 50, max_iterations = 100)),
        ("DEPSO", HybridDEPSO(population_size = 50, max_iterations = 100))
    ]

    # Run optimization for each algorithm
    results = Dict()

    for (name, algorithm) in algorithms
        println("  Running $name...")

        # Define callback function to track progress
        iteration_data = []
        function callback(iter, best_pos, best_fit, pop)
            push!(iteration_data, (iter, best_fit))
            return true  # Continue optimization
        end

        # Run optimization
        if name == "PSO"
            result = PSO.optimize(problem, algorithm; callback=callback)
        elseif name == "DE"
            result = DE.optimize(problem, algorithm; callback=callback)
        elseif name == "DEPSO"
            result = DEPSO.optimize(problem, algorithm; callback=callback)
        end

        # Store results
        results[name] = (result, iteration_data)

        # Print results
        println("    Best fitness: $(result.best_fitness)")
        println("    Iterations: $(length(result.convergence_curve))")
        println("    Function evaluations: $(result.evaluations)")
    end

    # Print comparison data
    println("\n  Comparison Summary:")
    println("  Algorithm | Initial Fitness | Final Fitness | Improvement Factor")
    println("  ----------|-----------------|--------------|-------------------")

    for (name, (result, iteration_data)) in results
        initial = iteration_data[1][2]
        final = iteration_data[end][2]
        improvement = initial / final

        println("  $name | $(round(initial, digits=6)) | $(round(final, digits=6)) | $(round(improvement, digits=2))")
    end

    return results
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_depso_example()
end
