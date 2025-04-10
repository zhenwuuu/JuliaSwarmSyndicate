# Swarm Intelligence Algorithms for DeFi Trading

This directory contains implementations of nature-inspired swarm intelligence algorithms optimized for DeFi trading applications. These algorithms are specifically selected for their performance in financial optimization tasks.

## Available Algorithms

The following algorithms are implemented:

1. **Differential Evolution (DE)** - A powerful evolutionary algorithm that excels at finding global optima in complex, multimodal landscapes. DE is particularly effective for portfolio optimization and trading strategy development due to its robustness and ability to handle non-differentiable objective functions.

2. **Particle Swarm Optimization (PSO)** - A widely used algorithm that excels in exploring continuous solution spaces. PSO is particularly effective for trading strategy optimization due to its ability to balance exploration and exploitation.

3. **Grey Wolf Optimizer (GWO)** - Simulates the hunting behavior of grey wolves, with distinct leadership hierarchy. GWO is excellent for capturing market regimes and adapting to changing market conditions.

4. **Ant Colony Optimization (ACO)** - Inspired by the foraging behavior of ants. ACO is well-suited for path-dependent strategies and sequential decision making in trading.

5. **Genetic Algorithm (GA)** - Mimics natural selection through evolutionary processes. Genetic algorithms are excellent for complex trading rules with many interdependent parameters.

6. **Whale Optimization Algorithm (WOA)** - Based on the bubble-net hunting strategy of humpback whales. WOA handles market volatility well with its spiral hunting technique and is effective for finding global optima.

## Usage

### Basic Usage

```julia
using JuliaOS.SwarmManager.Algorithms

# Create an algorithm instance
algorithm_params = Dict(
    "inertia_weight" => 0.7,
    "cognitive_coef" => 1.5,
    "social_coef" => 1.5
)
algorithm = create_algorithm("pso", algorithm_params)

# Define search space
dimension = 4  # Number of parameters to optimize
bounds = [
    (0.0, 1.0),    # Parameter 1 bounds
    (0.0, 1.0),    # Parameter 2 bounds
    (0.01, 0.2),   # Parameter 3 bounds
    (0.01, 0.5)    # Parameter 4 bounds
]

# Initialize algorithm
swarm_size = 30
initialize!(algorithm, swarm_size, dimension, bounds)

# Define fitness function
function fitness_function(position)
    # Implement your evaluation logic here
    # Return a scalar value to minimize
    return sum(position.^2)  # Example: minimize sum of squares
end

# Run optimization for a number of iterations
iterations = 100
for i in 1:iterations
    update_positions!(algorithm, fitness_function)

    # Track progress
    best_fitness = get_best_fitness(algorithm)
    println("Iteration $i: Best fitness = $best_fitness")
end

# Get best solution
best_position = get_best_position(algorithm)
best_fitness = get_best_fitness(algorithm)
```

### Algorithm-Specific Parameters

Each algorithm accepts different parameters:

#### DE
- `population_size` (50) - Number of individuals in the population
- `crossover_rate` (0.7) - Probability of crossover
- `differential_weight` (0.8) - Scaling factor for the difference vector
- `strategy` ("rand/1/bin") - Mutation strategy

#### PSO
- `inertia_weight` (0.7) - Controls influence of previous velocity
- `cognitive_coef` (1.5) - Weight for personal best attraction
- `social_coef` (1.5) - Weight for global best attraction
- `max_velocity` (1.0) - Maximum velocity scaling factor

#### GWO
- `pack_size` (30) - Number of wolves in the pack
- `a_decrease_factor` (2.0) - Controls the search range decrease

#### ACO
- `colony_size` (50) - Number of ants in the colony
- `archive_size` (30) - Size of the solution archive
- `q` (0.5) - Locality of search parameter
- `xi` (0.7) - Pheromone evaporation rate

#### Genetic Algorithm
- `population_size` (100) - Number of individuals in the population
- `crossover_rate` (0.8) - Probability of crossover
- `mutation_rate` (0.1) - Probability of mutation
- `elitism_count` (2) - Number of best individuals to preserve
- `selection_pressure` (0.2) - Selection pressure (tournament size as fraction of population)

#### WOA
- `pod_size` (30) - Number of whales in the pod
- `a_decrease_factor` (2.0) - Controls the search range decrease
- `b` (1.0) - Spiral shape constant

## Example for Trading Strategy Optimization

See `julia/examples/trading_optimization.jl` for a complete example of using these algorithms to optimize trading strategies with:

- Entry/exit threshold parameters
- Stop loss and take profit levels
- Multiple technical indicators
- Performance metrics like Sharpe ratio and drawdown

## Performance Comparison

Different algorithms excel in different trading scenarios:

- **DE** is robust for portfolio optimization and handles noisy market data well
- **PSO** is usually fastest to converge and works well for most trading problems
- **GWO** adapts well to changing market regimes and has good exploration
- **ACO** works well for order execution optimization and path-dependent strategies
- **GA** can discover novel trading rule combinations through evolutionary processes
- **WOA** handles noisy fitness landscapes well (like real market data) with its spiral hunting technique

## References

- Storn, R., & Price, K. (1997). Differential Evolution – A Simple and Efficient Heuristic for Global Optimization over Continuous Spaces. Journal of Global Optimization.
- Kennedy, J., & Eberhart, R. (1995). Particle swarm optimization. IEEE.
- Mirjalili, S., Mirjalili, S. M., & Lewis, A. (2014). Grey wolf optimizer. Advances in engineering software.
- Dorigo, M., & Stützle, T. (2004). Ant colony optimization. MIT Press.
- Holland, J. H. (1992). Genetic algorithms. Scientific American.
- Mirjalili, S., & Lewis, A. (2016). The whale optimization algorithm. Advances in engineering software.