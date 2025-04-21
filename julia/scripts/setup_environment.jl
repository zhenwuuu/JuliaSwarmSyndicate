#!/usr/bin/env julia

"""
JuliaOS Environment Setup Script

This script:
1. Installs all required dependencies
2. Fixes common issues with the JuliaOS package
3. Ensures proper precompilation
4. Checks for port conflicts
"""

using Pkg

println("JuliaOS Environment Setup")
println("=========================")

# Activate the project
println("\n📦 Activating project...")
Pkg.activate(".")

# Install required packages
println("\n📦 Installing required packages...")
required_packages = [
    "HTTP",
    "JSON",
    "SQLite",
    "DataFrames",
    "Dates",
    "UUIDs",
    "Random",
    "Statistics",
    "LinearAlgebra",
    "Distributed",
    "Sockets",
    "Base64",
    "SHA",
    "LRUCache",
    "WebSockets",
    "Plots",
    "CSV",
    "BenchmarkTools",
    "ProgressMeter"
]

for package in required_packages
    println("  - Installing $package...")
    try
        Pkg.add(package)
    catch e
        println("    ⚠️ Error installing $package: $e")
    end
end

# Check for port conflicts
println("\n🔌 Checking for port conflicts...")
using Sockets

function is_port_available(port)
    try
        server = listen(IPv4(0), port)
        close(server)
        return true
    catch e
        if isa(e, Base.IOError) && occursin("already in use", e.msg)
            return false
        end
        rethrow(e)
    end
end

default_port = 8052
if !is_port_available(default_port)
    println("  ⚠️ Port $default_port is already in use!")
    println("  ℹ️ You can:")
    println("    1. Kill the process using this port")
    println("    2. Use a different port by setting SERVER_PORT in .env")
    
    # Find an available port
    for test_port in (8053:8060)
        if is_port_available(test_port)
            println("  ✅ Port $test_port is available and can be used instead")
            break
        end
    end
else
    println("  ✅ Port $default_port is available")
end

# Fix common issues with the JuliaOS package
println("\n🔧 Fixing common issues...")

# Check if AgentSystem.jl exists
agent_system_path = joinpath("src", "JuliaOS", "AgentSystem.jl")
if !isfile(agent_system_path)
    println("  ⚠️ AgentSystem.jl not found, creating a minimal version...")
    
    # Create a minimal AgentSystem.jl
    agent_system_content = """
    module AgentSystem
    
    export Agent, create_agent, start_agent, stop_agent, get_agent_status
    
    struct Agent
        id::String
        name::String
        status::Symbol  # :idle, :running, :stopped, :error
        config::Dict{String, Any}
    end
    
    function create_agent(name, config=Dict{String, Any}())
        id = string(UUIDs.uuid4())
        return Agent(id, name, :idle, config)
    end
    
    function start_agent(agent)
        # Placeholder for actual implementation
        return Agent(agent.id, agent.name, :running, agent.config)
    end
    
    function stop_agent(agent)
        # Placeholder for actual implementation
        return Agent(agent.id, agent.name, :stopped, agent.config)
    end
    
    function get_agent_status(agent)
        # Placeholder for actual implementation
        return agent.status
    end
    
    end # module
    """
    
    try
        mkpath(dirname(agent_system_path))
        open(agent_system_path, "w") do io
            write(io, agent_system_content)
        end
        println("  ✅ Created minimal AgentSystem.jl")
    catch e
        println("  ❌ Failed to create AgentSystem.jl: $e")
    end
else
    println("  ✅ AgentSystem.jl exists")
end

# Create a minimal server.jl if it doesn't exist
server_path = joinpath("src", "JuliaOS", "server.jl")
if !isfile(server_path)
    println("  ⚠️ server.jl not found, creating a minimal version...")
    
    # Create a minimal server.jl
    server_content = """
    module Server
    
    export start_server, stop_server, get_status
    
    using HTTP
    using Sockets
    using JSON
    
    function start_server(host="localhost", port=8052)
        server = HTTP.serve(host, port) do request
            try
                # Parse the request
                if request.method == "POST" && occursin("/api/v1", request.target)
                    body = JSON.parse(String(request.body))
                    
                    # Handle different API endpoints
                    if occursin("/api/v1/benchmarking", request.target)
                        return handle_benchmarking_request(request.target, body)
                    else
                        return HTTP.Response(404, "Endpoint not found")
                    end
                elseif request.method == "GET" && request.target == "/health"
                    return HTTP.Response(200, JSON.json(Dict("status" => "ok")))
                else
                    return HTTP.Response(404, "Not found")
                end
            catch e
                return HTTP.Response(500, "Internal server error: \$(e)")
            end
        end
        
        return server
    end
    
    function stop_server(server)
        close(server)
    end
    
    function get_status()
        return Dict("status" => "running")
    end
    
    function handle_benchmarking_request(endpoint, body)
        # This is a placeholder for the actual implementation
        if occursin("/algorithms", endpoint)
            algorithms = Dict(
                "DE" => "Differential Evolution",
                "PSO" => "Particle Swarm Optimization",
                "GWO" => "Grey Wolf Optimizer"
            )
            return HTTP.Response(200, JSON.json(Dict("algorithms" => algorithms)))
        elseif occursin("/functions", endpoint)
            functions = [
                Dict("name" => "Sphere", "bounds" => [-100.0, 100.0], "optimum" => 0.0, "difficulty" => "easy"),
                Dict("name" => "Rastrigin", "bounds" => [-5.12, 5.12], "optimum" => 0.0, "difficulty" => "medium"),
                Dict("name" => "Rosenbrock", "bounds" => [-30.0, 30.0], "optimum" => 0.0, "difficulty" => "medium")
            ]
            return HTTP.Response(200, JSON.json(Dict("functions" => functions)))
        else
            return HTTP.Response(404, "Benchmarking endpoint not found")
        end
    end
    
    end # module
    """
    
    try
        mkpath(dirname(server_path))
        open(server_path, "w") do io
            write(io, server_content)
        end
        println("  ✅ Created minimal server.jl")
    catch e
        println("  ❌ Failed to create server.jl: $e")
    end
else
    println("  ✅ server.jl exists")
end

# Precompile the project
println("\n🔄 Precompiling project...")
try
    Pkg.precompile()
    println("  ✅ Precompilation completed")
catch e
    println("  ⚠️ Precompilation had issues: $e")
end

println("\n✅ Setup completed!")
println("You can now start the JuliaOS server with:")
println("julia julia_server.jl")
