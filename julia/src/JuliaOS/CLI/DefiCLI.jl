module DefiCLI

using JuliaOS
using LiquidityProvider
using CrossChainArbitrage
using JSON
using Printf
using REPL.TerminalMenus

# Types for CLI configuration
struct AgentConfig
    name::String
    type::String  # "arbitrage" or "liquidity"
    strategy::String
    chains::Vector{String}
    risk_params::Dict{String, Any}
    strategy_params::Dict{String, Any}
end

struct SwarmConfig
    name::String
    coordination_type::String  # "independent", "coordinated", "hierarchical"
    agents::Vector{AgentConfig}
    shared_risk_params::Dict{String, Any}
end

# CLI menu options
const AGENT_TYPES = ["Arbitrage Agent", "Liquidity Provider Agent"]
const STRATEGY_TYPES = Dict(
    "Arbitrage Agent" => ["Momentum", "Mean Reversion", "Trend Following"],
    "Liquidity Provider Agent" => ["Concentrated", "Full Range", "Dynamic Range"]
)
const COORDINATION_TYPES = ["Independent", "Coordinated", "Hierarchical"]
const AVAILABLE_CHAINS = ["Ethereum", "Polygon", "Arbitrum", "Optimism", "Base"]

# Helper functions for CLI interaction
function get_user_input(prompt::String)
    print(prompt)
    return readline()
end

function select_from_menu(title::String, options::Vector{String})
    menu = RadioMenu(options)
    choice = request("Select $title:", menu)
    return options[choice]
end

function select_multiple_from_menu(title::String, options::Vector{String})
    menu = MultiSelectMenu(options)
    choices = request("Select $title (space to select, enter to confirm):", menu)
    return options[choices]
end

function configure_risk_params(agent_type::String)
    params = Dict{String, Any}()
    
    if agent_type == "Arbitrage Agent"
        params["max_position_size"] = parse(Float64, get_user_input("Enter max position size (as % of portfolio): "))
        params["min_profit_threshold"] = parse(Float64, get_user_input("Enter minimum profit threshold (%): ")) / 100
        params["max_gas_price"] = parse(Float64, get_user_input("Enter maximum gas price to consider: "))
        params["confidence_threshold"] = parse(Float64, get_user_input("Enter minimum confidence threshold (0-1): "))
    else  # Liquidity Provider Agent
        params["max_position_size"] = parse(Float64, get_user_input("Enter max position size per pool (%): ")) / 100
        params["min_liquidity_depth"] = parse(Float64, get_user_input("Enter minimum pool TVL ($): "))
        params["max_il_threshold"] = parse(Float64, get_user_input("Enter maximum impermanent loss threshold (%): ")) / 100
        params["min_apy_threshold"] = parse(Float64, get_user_input("Enter minimum APY threshold (%): ")) / 100
        params["rebalance_threshold"] = parse(Float64, get_user_input("Enter rebalance threshold (%): ")) / 100
    end
    
    return params
end

function configure_strategy_params(agent_type::String, strategy::String)
    params = Dict{String, Any}()
    
    if agent_type == "Liquidity Provider Agent"
        params["price_range_multiplier"] = parse(Float64, get_user_input("Enter price range width (%): ")) / 100
        params["concentration_factor"] = parse(Float64, get_user_input("Enter concentration factor (0-1): "))
        params["rebalance_frequency"] = parse(Int, get_user_input("Enter rebalance frequency (hours): "))
        params["fee_tier_preference"] = [0.003, 0.001, 0.0005]  # Default fee tiers
    end
    
    return params
end

function create_agent_config()
    # Select agent type
    agent_type = select_from_menu("Agent Type", AGENT_TYPES)
    
    # Select strategy
    strategy = select_from_menu("Strategy", STRATEGY_TYPES[agent_type])
    
    # Select chains
    chains = select_multiple_from_menu("Chains", AVAILABLE_CHAINS)
    
    # Configure risk parameters
    risk_params = configure_risk_params(agent_type)
    
    # Configure strategy parameters
    strategy_params = configure_strategy_params(agent_type, strategy)
    
    return AgentConfig(
        get_user_input("Enter agent name: "),
        lowercase(replace(agent_type, " Agent" => "")),
        lowercase(replace(strategy, " " => "_")),
        lowercase.(chains),
        risk_params,
        strategy_params
    )
end

function create_swarm_config()
    # Get swarm name
    name = get_user_input("Enter swarm name: ")
    
    # Select coordination type
    coordination_type = lowercase(select_from_menu("Coordination Type", COORDINATION_TYPES))
    
    # Get number of agents
    n_agents = parse(Int, get_user_input("Enter number of agents: "))
    
    # Create agent configs
    agents = AgentConfig[]
    for i in 1:n_agents
        println("\nConfiguring Agent $i:")
        push!(agents, create_agent_config())
    end
    
    # Configure shared risk parameters
    shared_risk_params = Dict{String, Any}(
        "max_total_exposure" => parse(Float64, get_user_input("Enter maximum total exposure (%): ")) / 100,
        "max_drawdown" => parse(Float64, get_user_input("Enter maximum drawdown (%): ")) / 100,
        "max_daily_loss" => parse(Float64, get_user_input("Enter maximum daily loss (%): ")) / 100
    )
    
    return SwarmConfig(name, coordination_type, agents, shared_risk_params)
end

function save_config(config::SwarmConfig, filename::String)
    config_dict = Dict(
        "name" => config.name,
        "coordination_type" => config.coordination_type,
        "agents" => [
            Dict(
                "name" => agent.name,
                "type" => agent.type,
                "strategy" => agent.strategy,
                "chains" => agent.chains,
                "risk_params" => agent.risk_params,
                "strategy_params" => agent.strategy_params
            ) for agent in config.agents
        ],
        "shared_risk_params" => config.shared_risk_params
    )
    
    open(filename, "w") do f
        JSON.print(f, config_dict, 2)
    end
end

function load_config(filename::String)
    config_dict = JSON.parsefile(filename)
    agents = [
        AgentConfig(
            agent["name"],
            agent["type"],
            agent["strategy"],
            agent["chains"],
            agent["risk_params"],
            agent["strategy_params"]
        ) for agent in config_dict["agents"]
    ]
    
    return SwarmConfig(
        config_dict["name"],
        config_dict["coordination_type"],
        agents,
        config_dict["shared_risk_params"]
    )
end

function run_swarm(config::SwarmConfig)
    println("\nInitializing swarm: $(config.name)")
    
    # Create swarms based on agent types
    arbitrage_agents = filter(a -> a.type == "arbitrage", config.agents)
    lp_agents = filter(a -> a.type == "liquidity", config.agents)
    
    # Initialize chain info
    chain_info = Dict(
        chain => CrossChainArbitrage.ChainInfo(
            chain,
            get_user_input("Enter RPC URL for $chain: "),
            parse(Float64, get_user_input("Enter current gas price for $chain: ")),
            get_user_input("Enter bridge contract address for $chain: "),
            ["ETH", "USDC", "WBTC", "DAI"]  # Default supported tokens
        ) for chain in unique(vcat(a.chains for a in config.agents))
    )
    
    # Initialize pool info if there are LP agents
    pool_info = Dict()
    if !isempty(lp_agents)
        println("\nConfiguring pools for liquidity provision:")
        while true
            pool_id = get_user_input("Enter pool ID (or 'done' to finish): ")
            if pool_id == "done"
                break
            end
            
            pool_info[pool_id] = LiquidityProvider.PoolInfo(
                get_user_input("Enter chain: "),
                get_user_input("Enter protocol (e.g., uniswap-v3): "),
                get_user_input("Enter trading pair: "),
                parse(Float64, get_user_input("Enter fee tier: ")),
                parse(Float64, get_user_input("Enter TVL: ")),
                parse(Float64, get_user_input("Enter 24h volume: ")),
                parse(Float64, get_user_input("Enter APY: ")),
                (
                    parse(Float64, get_user_input("Enter lower price bound: ")),
                    parse(Float64, get_user_input("Enter upper price bound: "))
                )
            )
        end
    end
    
    # Create and run swarms
    if !isempty(arbitrage_agents)
        arbitrage_swarm = create_arbitrage_swarm(
            length(arbitrage_agents),
            chain_info,
            arbitrage_agents[1].risk_params
        )
        println("\nStarting arbitrage swarm...")
        # Start arbitrage operations in background
        @async begin
            while true
                try
                    # Get market data for all chains
                    market_data = Dict(
                        chain => CrossChainArbitrage.get_market_data(chain_info[chain])
                        for chain in keys(chain_info)
                    )
                    
                    # Find arbitrage opportunities
                    opportunities = CrossChainArbitrage.find_opportunities(
                        market_data,
                        arbitrage_agents[1].risk_params
                    )
                    
                    # Execute trades for profitable opportunities
                    for opp in opportunities
                        if opp.expected_profit > arbitrage_agents[1].risk_params["min_profit_threshold"]
                            println("Executing arbitrage trade: $(opp.description)")
                            CrossChainArbitrage.execute_trade(
                                arbitrage_swarm,
                                opp,
                                chain_info
                            )
                        end
                    end
                    
                    # Update performance metrics
                    CrossChainArbitrage.update_metrics(arbitrage_swarm)
                    
                    # Sleep for a short period before next iteration
                    sleep(1)
                catch e
                    println("Error in arbitrage operations: $e")
                    sleep(5)  # Wait longer on error
                end
            end
        end
    end
    
    if !isempty(lp_agents)
        lp_swarm = create_lp_swarm(
            length(lp_agents),
            pool_info,
            lp_agents[1].risk_params,
            lp_agents[1].strategy_params
        )
        println("\nStarting LP swarm...")
        # Start LP operations in background
        @async begin
            while true
                try
                    # Update pool data
                    for (pool_id, pool) in pool_info
                        LiquidityProvider.update_pool_data(pool)
                    end
                    
                    # Check for rebalancing needs
                    for (pool_id, pool) in pool_info
                        if LiquidityProvider.needs_rebalancing(pool, lp_agents[1].risk_params)
                            println("Rebalancing pool: $pool_id")
                            LiquidityProvider.rebalance_position(
                                lp_swarm,
                                pool,
                                lp_agents[1].strategy_params
                            )
                        end
                    end
                    
                    # Monitor impermanent loss
                    for (pool_id, pool) in pool_info
                        il = LiquidityProvider.calculate_impermanent_loss(pool)
                        if il > lp_agents[1].risk_params["max_il_threshold"]
                            println("High impermanent loss detected in pool: $pool_id")
                            LiquidityProvider.adjust_position(
                                lp_swarm,
                                pool,
                                lp_agents[1].risk_params
                            )
                        end
                    end
                    
                    # Update performance metrics
                    LiquidityProvider.update_metrics(lp_swarm)
                    
                    # Sleep for a short period before next iteration
                    sleep(1)
                catch e
                    println("Error in LP operations: $e")
                    sleep(5)  # Wait longer on error
                end
            end
        end
    end
    
    println("\nSwarm is running. Press Ctrl+C to stop.")
    try
        while true
            sleep(1)
        end
    catch e
        if isa(e, InterruptException)
            println("\nStopping swarm...")
            # Implement cleanup logic here
        else
            rethrow(e)
        end
    end
end

# Main CLI function
function main()
    println("Welcome to JuliaOS DeFi CLI")
    println("==========================")
    
    while true
        println("\nOptions:")
        println("1. Create new swarm configuration")
        println("2. Load existing configuration")
        println("3. Exit")
        
        choice = get_user_input("\nEnter your choice (1-3): ")
        
        if choice == "1"
            config = create_swarm_config()
            filename = get_user_input("Enter filename to save configuration: ")
            save_config(config, filename)
            
            if get_user_input("Run swarm now? (y/n): ") == "y"
                run_swarm(config)
            end
            
        elseif choice == "2"
            filename = get_user_input("Enter configuration filename: ")
            config = load_config(filename)
            
            if get_user_input("Run swarm now? (y/n): ") == "y"
                run_swarm(config)
            end
            
        elseif choice == "3"
            println("Goodbye!")
            break
            
        else
            println("Invalid choice. Please try again.")
        end
    end
end

export main

end # module 