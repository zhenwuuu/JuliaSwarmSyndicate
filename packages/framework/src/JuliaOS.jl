module JuliaOS

export Agents, Swarms, Wallet, Bridge, Blockchain, Utils, Skills, NeuralNetworks, Finance, Algorithms
export TradingAgent, ResearchAgent, DevAgent

# Re-export all public symbols from each submodule
using Reexports

# Import and re-export submodules
@reexport module Agents
    include("../agents/src/Agents.jl")
    using .Agents
end

@reexport module Swarms
    include("../swarms/src/Swarms.jl")
    using .Swarms
end

@reexport module Bridge
    include("../bridge/src/JuliaBridge.jl")
    using .JuliaBridge
end

@reexport module Wallet
    include("../wallet/src/Wallets.jl")
    using .Wallets
end

@reexport module Blockchain
    include("../blockchain/src/Blockchain.jl")
    using .Blockchain
end

@reexport module Utils
    include("../utils/src/Utils.jl")
    using .Utils
end

@reexport module Skills
    include("../skills/src/Skills.jl")
    using .Skills
end

@reexport module NeuralNetworks
    include("../neural-networks/src/NeuralNetworks.jl")
    using .NeuralNetworks
end

@reexport module Finance
    include("../finance/src/Finance.jl")
    using .Finance
end

@reexport module Algorithms
    include("../algorithms/src/Algorithms.jl")
    using .Algorithms
end

function __init__()
    println("JuliaOS Framework v0.1.0 initialized")
    println("To connect to the JuliaOS backend: JuliaOS.Bridge.connect()")
end

end # module