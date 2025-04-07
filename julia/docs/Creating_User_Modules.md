# Creating Custom Modules for JuliaOS

This guide explains how to create and use your own custom modules within the JuliaOS framework.

## Quick Start

The simplest way to create a new module is to use the built-in template generator:

```julia
using JuliaOS.UserModules

# Create a new module template
create_user_module_template("MyCustomModule")
```

This will create a new directory structure with basic files for your module.

## Module Structure

A user module has the following structure:

```
user_modules/
└── MyCustomModule/
    ├── MyCustomModule.jl     # Main module file
    ├── metadata.json         # Module metadata
    └── README.md             # Documentation
```

You can also add more files and subdirectories to organize your code.

## Developing Your Module

1. Edit the main module file (`MyCustomModule.jl`) to implement your functionality:

```julia
module MyCustomModule

using JuliaOS
using JuliaOS.SwarmManager.Algorithms

# Export your public functions and types
export optimize_my_use_case

# Define a configuration struct for your module
struct MyConfig
    algorithm::String
    swarm_size::Int
    dimension::Int
    custom_parameter::Float64
end

"""
    optimize_my_use_case(data::Dict, config::MyConfig)

Run a swarm intelligence optimization for my custom use case.
"""
function optimize_my_use_case(data::Dict, config::MyConfig)
    # Create an algorithm instance
    algorithm_params = Dict(
        "inertia_weight" => 0.7,
        "cognitive_coef" => 1.5,
        "social_coef" => 1.5
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Define bounds for optimization
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function
    fitness_function = position -> evaluate_my_solution(position, data)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get best solution
    best_position = get_best_position(algorithm)
    best_fitness = get_best_fitness(algorithm)
    
    # Process results
    results = process_my_results(best_position, data)
    
    return results
end

# Helper functions
function evaluate_my_solution(position::Vector{Float64}, data::Dict)
    # Implement your evaluation logic here
    return sum(position.^2)  # Example: minimize sum of squares
end

function process_my_results(position::Vector{Float64}, data::Dict)
    # Process the optimized position into meaningful results
    return Dict(
        "optimized_parameters" => position,
        "result_metrics" => Dict(
            "metric1" => rand(),
            "metric2" => rand()
        )
    )
end

end # module
```

2. Update the metadata in `metadata.json` to provide information about your module:

```json
{
    "name": "MyCustomModule",
    "description": "Custom swarm intelligence optimizations for my use case",
    "author": "Your Name",
    "version": "0.1.0",
    "dependencies": [],
    "created_at": "2023-01-01T00:00:00"
}
```

## Using Your Module

Once your module is developed, you can use it in your Julia code:

```julia
using JuliaOS
using JuliaOS.UserModules

# Load all user modules
load_user_modules()

# Get your specific module
my_module = get_user_module("MyCustomModule")

# Create a configuration
config = my_module.MyConfig(
    "pso",  # algorithm
    30,     # swarm_size
    5,      # dimension
    0.5     # custom_parameter
)

# Prepare your data
data = Dict(
    "parameter1" => rand(10),
    "parameter2" => rand(10)
)

# Run your optimization
results = my_module.optimize_my_use_case(data, config)
println(results)
```

## Best Practices

1. **Modularity**: Keep your module focused on a specific problem domain
2. **Documentation**: Document your functions and provide usage examples
3. **Testing**: Include tests for your module functionality
4. **Dependencies**: Clearly specify any additional dependencies
5. **Error Handling**: Implement proper error checking and handling

## Examples

Check out the template modules in the `examples/user_modules/` directory for more advanced examples:

- `CustomTrading`: Example of a custom trading strategy module
- `DataAnalyzer`: Example of a data analysis module
- `OptimizationWrapper`: Example of wrapping an existing optimization algorithm

## Contribution

If you've developed a module that might be useful to others, consider submitting it for inclusion in the official JuliaOS repository!

## Troubleshooting

### Module Not Found

If your module isn't being loaded, check:
1. The directory structure matches the expected format
2. The main module file is named correctly (matching the directory name)
3. There are no syntax errors in your module code

### Loading Issues

If you're having trouble with module loading:

```julia
# Manually register your module
using JuliaOS.UserModules
using Main.MyCustomModule

register_module(
    "MyCustomModule",
    Main.MyCustomModule,
    joinpath(dirname(dirname(@__FILE__)), "user_modules", "MyCustomModule"),
    Dict("name" => "MyCustomModule", "version" => "0.1.0")
)
``` 