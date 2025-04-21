#!/usr/bin/env julia

# Script to install all required packages for JuliaOS

import Pkg

# Activate the project
Pkg.activate(".")

# Add required packages
packages = [
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

println("Installing packages...")
for package in packages
    println("Installing $package...")
    try
        Pkg.add(package)
    catch e
        println("Error installing $package: $e")
    end
end

println("Package installation complete!")
println("Precompiling packages...")
Pkg.precompile()
println("Precompilation complete!")
