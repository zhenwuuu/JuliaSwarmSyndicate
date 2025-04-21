"""
Default benchmark configuration
"""
struct BenchmarkConfig
    dimensions::Vector{Int}
    runs::Int
    max_evaluations::Int
    algorithms::Dict{String, Function}
    functions::Vector{BenchmarkFunction}
    output_dir::String
end

"""
    default_benchmark_config()

Create a default benchmark configuration.

# Returns
- `config`: BenchmarkConfig with default settings
"""
function default_benchmark_config()
    return BenchmarkConfig(
        [10, 30, 50],  # dimensions
        30,            # runs
        10000,         # max_evaluations
        get_standard_algorithms(),
        get_standard_benchmark_suite("all"),
        joinpath(pwd(), "benchmark_results")
    )
end

"""
    load_benchmark_config(filename)

Load benchmark configuration from a JSON file.

# Arguments
- `filename`: Path to the configuration file

# Returns
- `config`: BenchmarkConfig with settings from the file
"""
function load_benchmark_config(filename)
    config_data = JSON.parsefile(filename)
    
    # Load dimensions
    dimensions = config_data["dimensions"]
    
    # Load runs
    runs = config_data["runs"]
    
    # Load max_evaluations
    max_evaluations = config_data["max_evaluations"]
    
    # Load algorithms
    algorithm_names = config_data["algorithms"]
    std_algorithms = get_standard_algorithms()
    algorithms = Dict{String, Function}()
    
    for name in algorithm_names
        if haskey(std_algorithms, name)
            algorithms[name] = std_algorithms[name]
        else
            @warn "Algorithm $name not found in standard algorithms, skipping"
        end
    end
    
    # Load functions
    function_names = config_data["functions"]
    std_functions = get_standard_benchmark_suite("all")
    functions = BenchmarkFunction[]
    
    for name in function_names
        func = nothing
        for std_func in std_functions
            if std_func.name == name
                func = std_func
                break
            end
        end
        
        if func !== nothing
            push!(functions, func)
        else
            @warn "Function $name not found in standard functions, skipping"
        end
    end
    
    # Load output directory
    output_dir = config_data["output_dir"]
    
    return BenchmarkConfig(
        dimensions,
        runs,
        max_evaluations,
        algorithms,
        functions,
        output_dir
    )
end

"""
    save_benchmark_config(config, filename)

Save benchmark configuration to a JSON file.

# Arguments
- `config`: BenchmarkConfig to save
- `filename`: Path to the output file
"""
function save_benchmark_config(config, filename)
    config_data = Dict(
        "dimensions" => config.dimensions,
        "runs" => config.runs,
        "max_evaluations" => config.max_evaluations,
        "algorithms" => collect(keys(config.algorithms)),
        "functions" => [func.name for func in config.functions],
        "output_dir" => config.output_dir
    )
    
    open(filename, "w") do io
        JSON.print(io, config_data, 4)  # Pretty print with 4-space indent
    end
    
    @info "Benchmark configuration saved to $filename"
end
