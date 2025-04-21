module Algorithms

export HybridDEPSO, MultiObjective
export optimize, initialize, create_hybrid_swarm, run_generation

# Import from JuliaOS core
using JuliaOS.Algorithms

# Re-export all public symbols
for name in names(JuliaOS.Algorithms, all=true)
    if !startswith(string(name), "#") && name != :Algorithms
        @eval export $name
    end
end

end # module
