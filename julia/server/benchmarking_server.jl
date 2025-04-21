#!/usr/bin/env julia

"""
JuliaOS Benchmarking Server

A simplified server that provides benchmarking functionality without
requiring the full JuliaOS system.
"""

using HTTP
using JSON
using Sockets
using DataFrames
using Statistics
using Random
using Dates

# Include the benchmarking module
include("src/Benchmarking/Benchmarking.jl")
using .Benchmarking

# Server configuration
const HOST = get(ENV, "SERVER_HOST", "localhost")
const PORT = parse(Int, get(ENV, "SERVER_PORT", "8052"))

# API endpoints
function handle_request(req::HTTP.Request)
    try
        # Parse the request path
        path = HTTP.URI(req.target).path
        
        # Handle different endpoints
        if req.method == "GET" && path == "/health"
            return handle_health()
        elseif req.method == "GET" && path == "/api/v1/benchmarking/algorithms"
            return handle_get_algorithms()
        elseif req.method == "GET" && path == "/api/v1/benchmarking/functions"
            return handle_get_functions(HTTP.queryparams(req.target))
        elseif req.method == "POST" && path == "/api/v1/benchmarking/run"
            return handle_run_benchmark(JSON.parse(String(req.body)))
        elseif req.method == "POST" && path == "/api/v1/benchmarking/compare"
            return handle_compare_algorithms(JSON.parse(String(req.body)))
        elseif req.method == "POST" && path == "/api/v1/benchmarking/statistics"
            return handle_get_statistics(JSON.parse(String(req.body)))
        elseif req.method == "POST" && path == "/api/v1/benchmarking/report"
            return handle_generate_report(JSON.parse(String(req.body)))
        elseif req.method == "POST" && path == "/api/v1/benchmarking/rank"
            return handle_rank_algorithms(JSON.parse(String(req.body)))
        else
            return HTTP.Response(404, "Not Found")
        end
    catch e
        @error "Error handling request" exception=(e, catch_backtrace())
        return HTTP.Response(500, "Internal Server Error: $(e)")
    end
end

# Health check endpoint
function handle_health()
    return HTTP.Response(200, JSON.json(Dict(
        "status" => "ok",
        "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
        "service" => "JuliaOS Benchmarking Server"
    )))
end

# Get available algorithms
function handle_get_algorithms()
    algorithms = Dict(
        "DE" => "Differential Evolution",
        "PSO" => "Particle Swarm Optimization",
        "GWO" => "Grey Wolf Optimizer",
        "ACO" => "Ant Colony Optimization",
        "WOA" => "Whale Optimization Algorithm",
        "GA" => "Genetic Algorithm",
        "DEPSO" => "Hybrid DE-PSO Algorithm"
    )
    
    return HTTP.Response(200, JSON.json(Dict("algorithms" => algorithms)))
end

# Get benchmark functions
function handle_get_functions(params)
    difficulty = get(params, "difficulty", "all")
    functions = get_standard_benchmark_suite(difficulty)
    
    # Convert to JSON-compatible format
    function_data = []
    for func in functions
        push!(function_data, Dict(
            "name" => func.name,
            "bounds" => [func.bounds[1], func.bounds[2]],
            "optimum" => func.optimum,
            "difficulty" => func.difficulty
        ))
    end
    
    return HTTP.Response(200, JSON.json(Dict("functions" => function_data)))
end

# Run a benchmark
function handle_run_benchmark(data)
    # Extract parameters
    algorithm = data["algorithm"]
    function_names = data["functions"]
    dimensions = data["dimensions"]
    runs = data["runs"]
    max_evaluations = data["max_evaluations"]
    parameters = get(data, "parameters", Dict())
    
    # Get the algorithm function
    algorithms = get_standard_algorithms()
    if !haskey(algorithms, algorithm)
        return HTTP.Response(400, "Algorithm not found: $(algorithm)")
    end
    algo_func = algorithms[algorithm]
    
    # Get the benchmark functions
    all_functions = get_standard_benchmark_suite("all")
    functions = []
    for name in function_names
        found = false
        for func in all_functions
            if func.name == name
                push!(functions, func)
                found = true
                break
            end
        end
        if !found
            return HTTP.Response(400, "Function not found: $(name)")
        end
    end
    
    # Run the benchmark
    results = run_benchmark(algo_func, functions, dimensions, runs, max_evaluations; parameters...)
    
    # Convert to JSON-compatible format
    result_data = []
    for row in eachrow(results)
        push!(result_data, Dict(
            "Function" => row.Function,
            "Dimension" => row.Dimension,
            "Run" => row.Run,
            "BestFitness" => row.BestFitness,
            "ExecutionTime" => row.ExecutionTime,
            "Evaluations" => row.Evaluations,
            "ConvergenceSpeed" => row.ConvergenceSpeed,
            "ErrorFromOptimum" => row.ErrorFromOptimum
        ))
    end
    
    return HTTP.Response(200, JSON.json(Dict("results" => result_data)))
end

# Compare algorithms
function handle_compare_algorithms(data)
    # Extract parameters
    algorithm_names = data["algorithms"]
    function_names = data["functions"]
    dimensions = data["dimensions"]
    runs = data["runs"]
    max_evaluations = data["max_evaluations"]
    parameters = get(data, "parameters", Dict())
    
    # Get the algorithms
    all_algorithms = get_standard_algorithms()
    algorithms = Dict()
    for name in algorithm_names
        if !haskey(all_algorithms, name)
            return HTTP.Response(400, "Algorithm not found: $(name)")
        end
        algorithms[name] = all_algorithms[name]
    end
    
    # Get the benchmark functions
    all_functions = get_standard_benchmark_suite("all")
    functions = []
    for name in function_names
        found = false
        for func in all_functions
            if func.name == name
                push!(functions, func)
                found = true
                break
            end
        end
        if !found
            return HTTP.Response(400, "Function not found: $(name)")
        end
    end
    
    # Compare algorithms
    results = compare_algorithms(algorithms, functions, dimensions=dimensions, runs=runs, max_evaluations=max_evaluations)
    
    # Convert to JSON-compatible format
    result_data = []
    for row in eachrow(results)
        push!(result_data, Dict(
            "Function" => row.Function,
            "Dimension" => row.Dimension,
            "Run" => row.Run,
            "Algorithm" => row.Algorithm,
            "BestFitness" => row.BestFitness,
            "ExecutionTime" => row.ExecutionTime,
            "Evaluations" => row.Evaluations,
            "ConvergenceSpeed" => row.ConvergenceSpeed,
            "ErrorFromOptimum" => row.ErrorFromOptimum
        ))
    end
    
    return HTTP.Response(200, JSON.json(Dict("results" => result_data)))
end

# Calculate statistics
function handle_get_statistics(data)
    # Extract parameters
    results_data = data["results"]
    
    # Convert to DataFrame
    results = DataFrame()
    for row in results_data
        push!(results, row)
    end
    
    # Calculate statistics
    stats = get_benchmark_statistics(results)
    
    # Convert to JSON-compatible format
    stats_data = []
    for row in eachrow(stats)
        row_dict = Dict()
        for name in names(stats)
            row_dict[name] = row[name]
        end
        push!(stats_data, row_dict)
    end
    
    return HTTP.Response(200, JSON.json(Dict("statistics" => stats_data)))
end

# Generate report
function handle_generate_report(data)
    # Extract parameters
    results_data = data["results"]
    output_dir = data["output_dir"]
    include_plots = get(data, "include_plots", true)
    
    # Convert to DataFrame
    results = DataFrame()
    for row in results_data
        push!(results, row)
    end
    
    # Generate report
    report_path = generate_benchmark_report(results, output_dir, include_plots=include_plots)
    
    return HTTP.Response(200, JSON.json(Dict("report_path" => report_path)))
end

# Rank algorithms
function handle_rank_algorithms(data)
    # Extract parameters
    results_data = data["results"]
    metric = get(data, "metric", "BestFitness")
    lower_is_better = get(data, "lower_is_better", true)
    
    # Convert to DataFrame
    results = DataFrame()
    for row in results_data
        push!(results, row)
    end
    
    # Rank algorithms
    rankings = rank_algorithms(results, metric=Symbol(metric), lower_is_better=lower_is_better)
    
    # Convert to JSON-compatible format
    rankings_data = []
    for row in eachrow(rankings)
        row_dict = Dict()
        for name in names(rankings)
            row_dict[name] = row[name]
        end
        push!(rankings_data, row_dict)
    end
    
    return HTTP.Response(200, JSON.json(Dict("rankings" => rankings_data)))
end

# Start the server
function start_server()
    server = HTTP.serve(handle_request, HOST, PORT)
    println("Server running at http://$(HOST):$(PORT)")
    return server
end

# Main function
function main()
    println("Starting JuliaOS Benchmarking Server...")
    println("Host: $(HOST)")
    println("Port: $(PORT)")
    
    # Check if port is available
    try
        server = listen(IPv4(0), PORT)
        close(server)
    catch e
        if isa(e, Base.IOError) && occursin("already in use", e.msg)
            println("Error: Port $(PORT) is already in use!")
            println("Please set a different port using the SERVER_PORT environment variable.")
            exit(1)
        end
        rethrow(e)
    end
    
    # Start the server
    server = start_server()
    
    # Keep the server running
    try
        println("Press Ctrl+C to stop the server")
        while true
            sleep(1)
        end
    catch e
        if isa(e, InterruptException)
            println("\nShutting down server...")
            close(server)
        else
            rethrow(e)
        end
    end
end

# Run the main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
