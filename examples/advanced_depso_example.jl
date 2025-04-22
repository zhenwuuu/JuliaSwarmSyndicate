"""
    advanced_depso_example.jl

Example demonstrating the advanced capabilities of DEPSO:
- Multi-objective optimization
- Constrained optimization
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
include("../julia/src/swarm/algorithms/MultiObjectiveDEPSO.jl")
include("../julia/src/swarm/algorithms/ConstrainedDEPSO.jl")

using .SwarmBase
using .DEPSO
using .MultiObjectiveDEPSO
using .ConstrainedDEPSO

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_multi_objective_example()

Run a multi-objective optimization example using DEPSO.
"""
function run_multi_objective_example()
    println("Multi-Objective DEPSO Example")
    println("=============================")

    # Define a multi-objective problem: minimize both objectives
    # Objective 1: Sum of squares (minimize)
    # Objective 2: Sum of absolute values (minimize)
    function objective1(x)
        return sum(x.^2)
    end

    function objective2(x)
        return sum(abs.(x))
    end

    # Create the multi-objective problem
    problem = MultiObjectiveProblem(
        2,  # 2 dimensions
        [(-5.0, 5.0), (-5.0, 5.0)],  # Bounds
        [objective1, objective2];  # Objective functions
        minimize = [true, true]  # Both are minimization objectives
    )

    # Create the multi-objective DEPSO algorithm
    algorithm = MultiObjectiveHybridDEPSO(
        population_size = 100,
        max_iterations = 50,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true,
        tolerance = 1e-6,
        archive_size = 50,
        leader_selection_pressure = 0.7,
        crowding_distance_weight = 0.5
    )

    # Define callback function to track progress
    iteration_data = []
    function callback(iter, best_pos, best_obj, pop)
        push!(iteration_data, (iter, best_obj))
        if iter % 10 == 0
            println("  Iteration $iter: Best objectives = $best_obj")
        end
        return true  # Continue optimization
    end

    # Run the multi-objective optimization
    println("Running multi-objective optimization...")
    pareto_front = MultiObjectiveDEPSO.optimize(problem, algorithm; callback=callback)

    # Print results
    println("\nResults:")
    println("  Number of solutions in Pareto front: $(length(pareto_front.solutions))")

    # Print a sample of solutions
    println("\nSample solutions from Pareto front:")
    n_samples = min(5, length(pareto_front.solutions))
    for i in 1:n_samples
        println("  Solution $i:")
        println("    Position: $(round.(pareto_front.solutions[i], digits=4))")
        println("    Objectives: $(round.(pareto_front.objective_values[i], digits=4))")
        println("    Crowding distance: $(round(pareto_front.crowding_distances[i], digits=4))")
    end

    # Try with weighted sum scalarization
    println("\nRunning with weighted sum scalarization...")
    scalarization = WeightedSum([0.5, 0.5])  # Equal weights

    pareto_front_ws = MultiObjectiveDEPSO.optimize(problem, algorithm;
                                                 scalarization_method=scalarization)

    println("  Weighted sum solution:")
    println("    Position: $(round.(pareto_front_ws.solutions[1], digits=4))")
    println("    Objectives: $(round.(pareto_front_ws.objective_values[1], digits=4))")

    # Try with epsilon constraint scalarization
    println("\nRunning with epsilon constraint scalarization...")
    scalarization = EpsilonConstraint(1, [2.0])  # Minimize objective 1, subject to objective 2 <= 2.0

    pareto_front_ec = MultiObjectiveDEPSO.optimize(problem, algorithm;
                                                 scalarization_method=scalarization)

    println("  Epsilon constraint solution:")
    println("    Position: $(round.(pareto_front_ec.solutions[1], digits=4))")
    println("    Objectives: $(round.(pareto_front_ec.objective_values[1], digits=4))")

    return pareto_front
end

"""
    run_constrained_example()

Run a constrained optimization example using DEPSO.
"""
function run_constrained_example()
    println("\nConstrained DEPSO Example")
    println("=========================")

    # Define a constrained problem: minimize sum of squares subject to constraints
    function objective(x)
        return sum(x.^2)
    end

    # Constraint 1: x[1] + x[2] >= 1 (or x[1] + x[2] - 1 >= 0)
    function constraint1(x)
        return -(x[1] + x[2] - 1)  # <= 0 for feasible solutions
    end

    # Constraint 2: x[1]^2 + x[2]^2 <= 4 (or 4 - x[1]^2 - x[2]^2 >= 0)
    function constraint2(x)
        return x[1]^2 + x[2]^2 - 4  # <= 0 for feasible solutions
    end

    # Create the constrained problem
    problem = ConstrainedOptimizationProblem(
        2,  # 2 dimensions
        [(-5.0, 5.0), (-5.0, 5.0)],  # Bounds
        objective,  # Objective function
        [constraint1, constraint2];  # Constraint functions
        is_minimization = true  # Minimization problem
    )

    # Create the constrained DEPSO algorithm with feasibility rules
    algorithm_fr = ConstrainedHybridDEPSO(
        population_size = 50,
        max_iterations = 100,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true,
        tolerance = 1e-6,
        constraint_handling = FeasibilityRules()
    )

    # Define callback function to track progress
    iteration_data_fr = []
    function callback_fr(iter, best_pos, best_fit, pop)
        push!(iteration_data_fr, (iter, best_fit))
        if iter % 10 == 0
            println("  Iteration $iter: Best fitness = $best_fit")
        end
        return true  # Continue optimization
    end

    # Run the constrained optimization with feasibility rules
    println("Running constrained optimization with feasibility rules...")
    result_fr = ConstrainedDEPSO.optimize(problem, algorithm_fr; callback=callback_fr)

    # Print results
    println("\nResults with feasibility rules:")
    println("  Success: $(result_fr.success)")
    println("  Message: $(result_fr.message)")
    println("  Best position: $(round.(result_fr.best_position, digits=4))")
    println("  Best fitness: $(round(result_fr.best_fitness, digits=4))")
    println("  Constraint violation: $(round(result_fr.constraint_violation, digits=4))")
    println("  Iterations: $(length(result_fr.convergence_curve))")
    println("  Function evaluations: $(result_fr.evaluations)")

    # Create the constrained DEPSO algorithm with penalty method
    algorithm_pm = ConstrainedHybridDEPSO(
        population_size = 50,
        max_iterations = 100,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true,
        tolerance = 1e-6,
        constraint_handling = PenaltyMethod(penalty_factor=1000.0, adaptive=true, exponent=2.0)
    )

    # Define callback function to track progress
    iteration_data_pm = []
    function callback_pm(iter, best_pos, best_fit, pop)
        push!(iteration_data_pm, (iter, best_fit))
        if iter % 10 == 0
            println("  Iteration $iter: Best fitness = $best_fit")
        end
        return true  # Continue optimization
    end

    # Run the constrained optimization with penalty method
    println("\nRunning constrained optimization with penalty method...")
    result_pm = ConstrainedDEPSO.optimize(problem, algorithm_pm; callback=callback_pm)

    # Print results
    println("\nResults with penalty method:")
    println("  Success: $(result_pm.success)")
    println("  Message: $(result_pm.message)")
    println("  Best position: $(round.(result_pm.best_position, digits=4))")
    println("  Best fitness: $(round(result_pm.best_fitness, digits=4))")
    println("  Constraint violation: $(round(result_pm.constraint_violation, digits=4))")
    println("  Iterations: $(length(result_pm.convergence_curve))")
    println("  Function evaluations: $(result_pm.evaluations)")

    # Compare the two methods
    println("\nComparison of constraint handling methods:")
    println("  Method | Best Fitness | Constraint Violation | Iterations | Evaluations")
    println("  -------|--------------|---------------------|------------|------------")
    println("  Feasibility Rules | $(round(result_fr.best_fitness, digits=4)) | $(round(result_fr.constraint_violation, digits=4)) | $(length(result_fr.convergence_curve)) | $(result_fr.evaluations)")
    println("  Penalty Method | $(round(result_pm.best_fitness, digits=4)) | $(round(result_pm.constraint_violation, digits=4)) | $(length(result_pm.convergence_curve)) | $(result_pm.evaluations)")

    return (result_fr, result_pm)
end

"""
    run_engineering_example()

Run an engineering optimization example using constrained DEPSO.
"""
function run_engineering_example()
    println("\nEngineering Optimization Example: Pressure Vessel Design")
    println("======================================================")

    # Pressure Vessel Design Problem
    # Variables:
    # x[1] = thickness of the shell (inches)
    # x[2] = thickness of the head (inches)
    # x[3] = inner radius (inches)
    # x[4] = length of the cylindrical section (inches)

    # Objective: Minimize the total cost
    function objective(x)
        x1, x2, x3, x4 = x
        return 0.6224 * x1 * x3 * x4 + 1.7781 * x2 * x3^2 + 3.1661 * x1^2 * x4 + 19.84 * x1^2 * x3
    end

    # Constraint 1: g1(x) = -x1 + 0.0193*x3 <= 0
    function constraint1(x)
        return -x[1] + 0.0193 * x[3]
    end

    # Constraint 2: g2(x) = -x2 + 0.00954*x3 <= 0
    function constraint2(x)
        return -x[2] + 0.00954 * x[3]
    end

    # Constraint 3: g3(x) = -pi*x3^2*x4 - (4/3)*pi*x3^3 + 1296000 <= 0
    function constraint3(x)
        return -π * x[3]^2 * x[4] - (4/3) * π * x[3]^3 + 1296000
    end

    # Constraint 4: g4(x) = x4 - 240 <= 0
    function constraint4(x)
        return x[4] - 240
    end

    # Create the constrained problem
    problem = ConstrainedOptimizationProblem(
        4,  # 4 dimensions
        [(0.1, 99.0), (0.1, 99.0), (10.0, 200.0), (10.0, 200.0)],  # Bounds
        objective,  # Objective function
        [constraint1, constraint2, constraint3, constraint4];  # Constraint functions
        is_minimization = true  # Minimization problem
    )

    # Create the constrained DEPSO algorithm
    algorithm = ConstrainedHybridDEPSO(
        population_size = 50,
        max_iterations = 200,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true,
        tolerance = 1e-6,
        constraint_handling = FeasibilityRules()
    )

    # Define callback function to track progress
    iteration_data = []
    function callback(iter, best_pos, best_fit, pop)
        push!(iteration_data, (iter, best_fit))
        if iter % 20 == 0
            println("  Iteration $iter: Best fitness = $best_fit")
        end
        return true  # Continue optimization
    end

    # Run the constrained optimization
    println("Running pressure vessel design optimization...")
    result = ConstrainedDEPSO.optimize(problem, algorithm; callback=callback)

    # Print results
    println("\nResults:")
    println("  Success: $(result.success)")
    println("  Message: $(result.message)")
    println("  Best solution:")
    println("    Thickness of shell (x1): $(round(result.best_position[1], digits=4)) inches")
    println("    Thickness of head (x2): $(round(result.best_position[2], digits=4)) inches")
    println("    Inner radius (x3): $(round(result.best_position[3], digits=4)) inches")
    println("    Length of cylindrical section (x4): $(round(result.best_position[4], digits=4)) inches")
    println("  Total cost: \$$(round(result.best_fitness, digits=2))")
    println("  Constraint violation: $(round(result.constraint_violation, digits=4))")
    println("  Iterations: $(length(result.convergence_curve))")
    println("  Function evaluations: $(result.evaluations)")

    # Compare with known optimal solution
    println("\nComparison with known optimal solution:")
    println("  Known optimal solution: x = [0.8125, 0.4375, 42.0984, 176.6366]")
    println("  Known optimal cost: \$6059.7143")

    known_optimal = [0.8125, 0.4375, 42.0984, 176.6366]
    known_cost = 6059.7143

    println("  Cost difference: \$$(round(abs(result.best_fitness - known_cost), digits=2))")
    println("  Solution difference: $(round(norm(result.best_position - known_optimal), digits=4))")

    return result
end

# Run all examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    pareto_front = run_multi_objective_example()
    constrained_results = run_constrained_example()
    engineering_result = run_engineering_example()
end
