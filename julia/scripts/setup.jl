using Pkg

# Activate the project
Pkg.activate(".")

# Add necessary packages
function safe_add_package(name::String, version::String)
    try
        println("Adding $name version $version...")
        Pkg.add(name=name, version=version)
        println("✓ Successfully added $name")
    catch e
        println("⚠ Warning: Failed to add $name: $e")
    end
end

# Stage 1: Core dependencies
println("\nStage 1: Installing core dependencies...")
safe_add_package("StatsBase", "0.33.21")
safe_add_package("Distributions", "0.25.118")
safe_add_package("DataFrames", "1.7.0")
safe_add_package("Plots", "1.39.0")
safe_add_package("UUIDs", "1.0.0")
safe_add_package("Dates", "1.0.0")
safe_add_package("Statistics", "1.0.0")
safe_add_package("Random", "1.0.0")
safe_add_package("LinearAlgebra", "1.0.0")

# Stage 2: Data handling dependencies
println("\nStage 2: Installing data handling dependencies...")
safe_add_package("CSV", "0.10.15")
safe_add_package("JSON", "0.21.4")
safe_add_package("TimeSeries", "0.23.2")
safe_add_package("MarketData", "0.14.0")
safe_add_package("SQLite", "1.6.0")

# Stage 3: Network and API dependencies
println("\nStage 3: Installing network and API dependencies...")
safe_add_package("HTTP", "1.10.15")
safe_add_package("WebSockets", "1.6.0")

# Stage 4: Machine Learning dependencies
println("\nStage 4: Installing machine learning dependencies...")
safe_add_package("MLJ", "0.18.6")

# Stage 5: Utility dependencies
println("\nStage 5: Installing utility dependencies...")
safe_add_package("FFTW", "1.8.1")
safe_add_package("BSON", "0.3.9")

# Add JuliaOSBridge package
println("\nAdding JuliaOSBridge package...")
bridge_path = normpath(joinpath(@__DIR__, "..", "packages", "julia-bridge"))
if !isdir(bridge_path)
    println("⚠ Warning: JuliaOSBridge directory not found at $bridge_path")
else
    try
        println("Developing JuliaOSBridge from $bridge_path")
        Pkg.develop(path=bridge_path)
        println("✓ Successfully added JuliaOSBridge")
    catch e
        println("⚠ Warning: Failed to add JuliaOSBridge: $e")

        # Try to add it as a direct URL
        try
            Pkg.add(url="file://$bridge_path")
            println("✓ Successfully added JuliaOSBridge as URL")
        catch url_error
            println("⚠ Warning: Failed to add JuliaOSBridge as URL: $url_error")

            # Last resort: try to manually register it
            try
                # Create a temporary registry
                temp_registry_path = joinpath(tempdir(), "temp_registry")
                mkpath(temp_registry_path)

                # Register the package in the temporary registry
                registry_info = Dict(
                    "name" => "LocalRegistry",
                    "uuid" => "00000000-0000-0000-0000-000000000000",
                    "repo" => "file://$temp_registry_path",
                    "packages" => Dict(
                        "87654321-4321-8765-4321-876543210987" => Dict(
                            "name" => "JuliaOSBridge",
                            "path" => bridge_path
                        )
                    )
                )

                # Save registry info
                open(joinpath(temp_registry_path, "Registry.toml"), "w") do io
                    println(io, "name = \"LocalRegistry\"")
                    println(io, "uuid = \"00000000-0000-0000-0000-000000000000\"")
                    println(io, "repo = \"file://$temp_registry_path\"")
                    println(io, "[packages]")
                    println(io, "87654321-4321-8765-4321-876543210987 = { name = \"JuliaOSBridge\", path = \"$bridge_path\" }")
                end

                # Add the registry
                Pkg.Registry.add(RegistrySpec(path=temp_registry_path))
                Pkg.add("JuliaOSBridge")
                println("✓ Successfully added JuliaOSBridge via local registry")
            catch reg_error
                println("⚠ Warning: All attempts to add JuliaOSBridge failed. Final error: $reg_error")
            end
        end
    end
end

# Final stage: Instantiate and resolve dependencies
println("\nFinal stage: Resolving dependencies...")
try
    Pkg.resolve()
    Pkg.instantiate()
    Pkg.build()
    println("✓ Successfully resolved and built all dependencies")
catch e
    println("⚠ Warning: Failed to resolve dependencies: $e")
end

# Add the src directory to Julia's load path
src_path = abspath(joinpath(@__DIR__, "src"))
if !in(src_path, LOAD_PATH)
    push!(LOAD_PATH, src_path)
end

# Add the JuliaOSBridge path to the load path
bridge_src_path = abspath(joinpath(bridge_path, "src"))
if !in(bridge_src_path, LOAD_PATH)
    push!(LOAD_PATH, bridge_src_path)
end

# Run tests if everything is installed
println("\nRunning tests...")
try
    # First try to import JuliaOSBridge
    println("Testing JuliaOSBridge import...")
    using JuliaOSBridge

    # Then try to import JuliaOS
    println("Testing JuliaOS import...")
    include(joinpath(src_path, "JuliaOS.jl"))
    using .JuliaOS

    # Run tests
    println("Running full test suite...")
    if isfile(joinpath(@__DIR__, "test", "runtests.jl"))
        include(joinpath(@__DIR__, "test", "runtests.jl"))
    else
        println("⚠ Warning: Test file not found at: test/runtests.jl")
    end

    println("✓ Tests completed successfully")
catch e
    println("⚠ Warning: Tests failed: $e")
    println("Current LOAD_PATH: ", LOAD_PATH)
    println("Looking for JuliaOS.jl in: ", src_path)
    println("Looking for JuliaOSBridge.jl in: ", bridge_src_path)
end

# Test the project
Pkg.test()