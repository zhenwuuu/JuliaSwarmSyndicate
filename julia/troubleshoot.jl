#!/usr/bin/env julia

using Pkg

println("=======================================")
println("JuliaOS Server Troubleshooting Script")
println("=======================================")
println("\nThis script will diagnose issues with the JuliaOS server and JuliaOSBridge integration.\n")

# 1. Check Julia version
println("1. Checking Julia version...")
julia_version = VERSION
println("   Julia version: $julia_version")
if julia_version < v"1.8"
    println("   ❌ Julia version is less than 1.8. Upgrade Julia to at least version 1.8.")
else
    println("   ✅ Julia version is compatible.")
end

# 2. Check directory structure
println("\n2. Checking directory structure...")
current_dir = pwd()
println("   Current directory: $current_dir")

# Check if we're in the project root or julia directory
if endswith(current_dir, "JuliaOS")
    project_root = current_dir
    julia_dir = joinpath(current_dir, "julia")
    println("   ✅ Currently in project root directory.")
elseif endswith(current_dir, "julia")
    project_root = dirname(current_dir)
    julia_dir = current_dir
    println("   ✅ Currently in julia directory.")
else
    println("   ❌ Not in expected directory structure. Please run this script from JuliaOS root or julia directory.")
    project_root = nothing
    julia_dir = nothing
end

# 3. Check Project.toml
if julia_dir !== nothing
    println("\n3. Checking Julia project files...")
    
    project_file = joinpath(julia_dir, "Project.toml")
    if isfile(project_file)
        println("   ✅ Project.toml exists.")
        
        # Read Project.toml to check for JuliaOSBridge dependency
        project_content = read(project_file, String)
        if occursin("JuliaOSBridge", project_content)
            println("   ✅ JuliaOSBridge is listed in Project.toml.")
        else
            println("   ❌ JuliaOSBridge is not listed in Project.toml.")
        end
    else
        println("   ❌ Project.toml does not exist.")
    end
end

# 4. Check JuliaOSBridge package
if project_root !== nothing
    println("\n4. Checking JuliaOSBridge package...")
    
    bridge_dir = joinpath(project_root, "packages", "julia-bridge")
    if isdir(bridge_dir)
        println("   ✅ packages/julia-bridge directory exists.")
        
        # Check for Project.toml in bridge directory
        bridge_project = joinpath(bridge_dir, "Project.toml")
        if isfile(bridge_project)
            println("   ✅ JuliaOSBridge Project.toml exists.")
        else
            println("   ❌ JuliaOSBridge Project.toml does not exist.")
        end
        
        # Check for src directory and module file
        bridge_src = joinpath(bridge_dir, "src")
        if isdir(bridge_src)
            println("   ✅ JuliaOSBridge src directory exists.")
            
            bridge_module = joinpath(bridge_src, "JuliaOSBridge.jl")
            if isfile(bridge_module)
                println("   ✅ JuliaOSBridge.jl module file exists.")
            else
                println("   ❌ JuliaOSBridge.jl module file does not exist.")
            end
        else
            println("   ❌ JuliaOSBridge src directory does not exist.")
        end
    else
        println("   ❌ packages/julia-bridge directory does not exist.")
    end
end

# 5. Check package dependencies
println("\n5. Checking package dependencies...")
try
    Pkg.activate(julia_dir)
    
    # Check if Pkg.instantiate() works
    println("   Attempting to instantiate packages...")
    Pkg.instantiate()
    println("   ✅ Package instantiation successful.")
    
    # Check if required packages are installed
    required_packages = ["HTTP", "WebSockets", "JSON", "Distributions", "DataFrames", "StatsBase"]
    missing_packages = String[]
    
    for pkg in required_packages
        if !(pkg in keys(Pkg.project().dependencies))
            push!(missing_packages, pkg)
        end
    end
    
    if isempty(missing_packages)
        println("   ✅ All required packages are installed.")
    else
        println("   ❌ The following packages are missing: $(join(missing_packages, ", "))")
    end
catch e
    println("   ❌ Error during package check: $e")
end

# 6. Try to import JuliaOSBridge
println("\n6. Trying to import JuliaOSBridge...")
if project_root !== nothing
    # Add src directory to LOAD_PATH
    bridge_src = joinpath(project_root, "packages", "julia-bridge", "src")
    if isdir(bridge_src) && !in(bridge_src, LOAD_PATH)
        push!(LOAD_PATH, bridge_src)
        println("   Added bridge src path to LOAD_PATH.")
    end
    
    try
        @eval using JuliaOSBridge
        println("   ✅ Successfully imported JuliaOSBridge.")
    catch e
        println("   ❌ Failed to import JuliaOSBridge: $e")
    end
end

# 7. Try to import JuliaOS
println("\n7. Trying to import JuliaOS...")
if julia_dir !== nothing
    # Add src directory to LOAD_PATH
    juliaos_src = joinpath(julia_dir, "src")
    if isdir(juliaos_src) && !in(juliaos_src, LOAD_PATH)
        push!(LOAD_PATH, juliaos_src)
        println("   Added JuliaOS src path to LOAD_PATH.")
    end
    
    try
        include(joinpath(juliaos_src, "JuliaOS.jl"))
        @eval using .JuliaOS
        println("   ✅ Successfully imported JuliaOS.")
    catch e
        println("   ❌ Failed to import JuliaOS: $e")
    end
end

# 8. Check WebSocket server
println("\n8. Checking WebSocket server...")
using HTTP

port = 8052
try
    response = HTTP.get("http://localhost:$port/health", status_exception=false)
    if response.status == 200
        println("   ✅ WebSocket server is running at port $port.")
        println("   Server response: $(String(response.body))")
    else
        println("   ❌ WebSocket server is not responding correctly. Status: $(response.status)")
    end
catch e
    println("   ❌ WebSocket server is not running or accessible: $e")
end

# 9. Summary of findings
println("\n=======================================")
println("Troubleshooting Summary")
println("=======================================")
println("- Julia Version: $julia_version")
println("- Project Root: $project_root")
println("- Julia Directory: $julia_dir")
println("- Check LOAD_PATH for proper paths")
println("- If having issues with JuliaOSBridge, try running setup.jl")
println("- If the server won't start, check port 8052 is not in use")
println("- Make sure all required packages are installed")
println("- See logs in julia/logs directory for detailed error messages")
println("\nTo fix JuliaOSBridge issues:")
println("1. Run julia/setup.jl to install dependencies")
println("2. Check that packages/julia-bridge/src/JuliaOSBridge.jl exists")
println("3. Make sure packages/julia-bridge/Project.toml contains correct dependencies")
println("4. Try running test_bridge.jl to verify the setup")
println("\nFor more information, see documentation at docs/troubleshooting.md")
println("=======================================")