using Pkg

println("Testing JuliaOSBridge Package Setup")
println("===================================")

# Activate the project
println("\n1. Activating project...")
Pkg.activate(".")

# Check if JuliaOSBridge is in dependencies
println("\n2. Checking for JuliaOSBridge in dependencies...")
project = Pkg.project()
if haskey(project.dependencies, "JuliaOSBridge")
    println("✓ JuliaOSBridge found in dependencies")
    uuid = project.dependencies["JuliaOSBridge"]
    println("  UUID: $uuid")
else
    println("✗ JuliaOSBridge not found in dependencies")
end

# Check if JuliaOSBridge source exists
println("\n3. Checking for JuliaOSBridge source files...")
bridge_path = normpath(joinpath(@__DIR__, "..", "packages", "julia-bridge"))
if isdir(bridge_path)
    println("✓ JuliaOSBridge directory exists at: $bridge_path")
    
    # Check for Project.toml
    if isfile(joinpath(bridge_path, "Project.toml"))
        println("✓ Project.toml exists")
    else
        println("✗ Project.toml does not exist")
    end
    
    # Check for source files
    src_path = joinpath(bridge_path, "src")
    if isdir(src_path)
        println("✓ src directory exists")
        if isfile(joinpath(src_path, "JuliaOSBridge.jl"))
            println("✓ JuliaOSBridge.jl exists")
        else
            println("✗ JuliaOSBridge.jl does not exist")
        end
    else
        println("✗ src directory does not exist")
    end
else
    println("✗ JuliaOSBridge directory does not exist at: $bridge_path")
end

# Try to use the package
println("\n4. Attempting to use JuliaOSBridge package...")
try
    # Add the src directory to Julia's load path first
    bridge_src_path = abspath(joinpath(bridge_path, "src"))
    if !in(bridge_src_path, LOAD_PATH)
        push!(LOAD_PATH, bridge_src_path)
        println("Added bridge source path to LOAD_PATH")
    end
    
    # Try to import the module
    @eval using JuliaOSBridge
    println("✓ Successfully imported JuliaOSBridge")
    
    # Check if core functions exist
    if isdefined(JuliaOSBridge, :deserialize_command) && 
       isdefined(JuliaOSBridge, :serialize_response) && 
       isdefined(JuliaOSBridge, :handle_ts_request)
        println("✓ Core functions exist in JuliaOSBridge")
    else
        println("✗ Some core functions are missing from JuliaOSBridge")
    end
catch e
    println("✗ Failed to import JuliaOSBridge: $e")
end

# Try to start the JuliaOS environment
println("\n5. Attempting to import JuliaOS module...")
try
    # Add the src directory to Julia's load path
    juliaos_src_path = abspath(joinpath(@__DIR__, "src"))
    if !in(juliaos_src_path, LOAD_PATH)
        push!(LOAD_PATH, juliaos_src_path)
        println("Added JuliaOS source path to LOAD_PATH")
    end
    
    # Try to import the JuliaOS module
    include(joinpath(juliaos_src_path, "JuliaOS.jl"))
    @eval using .JuliaOS
    println("✓ Successfully imported JuliaOS")
catch e
    println("✗ Failed to import JuliaOS: $e")
end

println("\n===================================")
println("Test complete. Check the results above for any issues.") 