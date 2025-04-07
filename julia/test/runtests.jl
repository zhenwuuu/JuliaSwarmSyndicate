using Test
using JuliaOS
using JuliaOS.Config
using JuliaOS.SwarmManager
using JuliaOS.MarketData
using JuliaOS.Bridge
using JuliaOS.CLI.Interactive
using Dates
using JSON

# Test configuration
const TEST_CONFIG = Config.JuliaOSConfig(
    "test",
    Dict{String, String}(),
    Config.BridgeConfig(
        Dict(
            "ethereum" => Config.ChainConfig(
                "http://localhost:8545",
                1,
                21000,
                50.0,
                1,
                30
            ),
            "solana" => Config.ChainConfig(
                "http://localhost:8899",
                1,
                100000,
                0.00001,
                1,
                30
            )
        ),
        100,
        3,
        30,
        12
    ),
    Dict{String, Config.AgentConfig}(),
    Dict{String, Config.SwarmConfig}(),
    Config.DashboardConfig(
        "127.0.0.1",
        8000,
        5,
        1000,
        Dict(
            "max_drawdown" => 0.1,
            "min_win_rate" => 0.5,
            "min_sharpe" => 1.0
        )
    ),
    Dict(
        "level" => "DEBUG",
        "file" => "test.log",
        "max_size" => 1_000_000,
        "backup_count" => 2
    ),
    Dict(
        "enabled" => true,
        "interval" => 60,
        "max_backups" => 5,
        "path" => "test_backups"
    )
)

# Test helper functions
function setup_test_environment()
    # Create test directories
    mkpath("test_data")
    mkpath("test_backups")
    
    # Save test configuration
    Config.save_config(TEST_CONFIG, "test_data/config.json")
end

function cleanup_test_environment()
    # Remove test directories
    rm("test_data", recursive=true, force=true)
    rm("test_backups", recursive=true, force=true)
end

# Configuration tests
@testset "Configuration Tests" begin
    @test begin
        # Test configuration validation
        Config.validate_config(TEST_CONFIG)
        true
    end
    
    @test begin
        # Test configuration loading
        loaded_config = Config.load_config("test_data/config.json")
        loaded_config.environment == TEST_CONFIG.environment
    end
    
    @test begin
        # Test configuration saving
        Config.save_config(TEST_CONFIG, "test_data/config_save.json")
        isfile("test_data/config_save.json")
    end
    
    @test begin
        # Test configuration backup
        Config.backup_config(TEST_CONFIG)
        length(readdir("test_backups")) > 0
    end
    
    @test begin
        # Test configuration restoration
        backup_files = filter(f -> startswith(f, "config_"), readdir("test_backups"))
        if !isempty(backup_files)
            restored_config = Config.restore_config(joinpath("test_backups", backup_files[1]))
            restored_config !== nothing
        else
            true
        end
    end
end

# Bridge tests
@testset "Bridge Tests" begin
    @test begin
        # Test bridge initialization
        Bridge.start_bridge()
        Bridge.CONNECTION.is_connected
    end
    
    @test begin
        # Test chain status
        status = Bridge.get_chain_status("ethereum")
        haskey(status, "connected") && haskey(status, "block_height")
    end
    
    @test begin
        # Test token balance
        if Bridge.CONNECTION.is_connected
            balance = Bridge.get_token_balance("ethereum", "ETH")
            balance !== nothing
        else
            true
        end
    end
end

# Market data tests
@testset "Market Data Tests" begin
    @test begin
        # Test market data fetching
        data = MarketData.fetch_market_data("ethereum", "uniswap-v3", "ETH/USDC")
        data !== nothing && haskey(data, "price")
    end
    
    @test begin
        # Test historical data
        historical = MarketData.fetch_historical(
            "ethereum", "uniswap-v3", "ETH/USDC";
            days=1, interval="1h"
        )
        !isempty(historical)
    end
    
    @test begin
        # Test indicator calculation
        prices = [100.0, 101.0, 99.0, 102.0, 101.0]
        volumes = [1000.0, 1100.0, 900.0, 1200.0, 1100.0]
        indicators = MarketData.calculate_indicators(prices, volumes)
        haskey(indicators, "rsi") && haskey(indicators, "macd")
    end
end

# Swarm manager tests
@testset "Swarm Manager Tests" begin
    @test begin
        # Test swarm creation
        swarm_config = SwarmConfig(
            "test_swarm",
            10,
            "pso",
            ["ETH/USDC"],
            Dict(
                "inertia_weight" => 0.7,
                "cognitive_coef" => 1.5,
                "social_coef" => 1.5
            )
        )
        swarm = SwarmManager.create_swarm(swarm_config, "ethereum")
        swarm !== nothing
    end
    
    @test begin
        # Test agent creation
        agent = SwarmManager.create_agent(
            "test_agent",
            "Arbitrage Agent",
            "Mean Reversion",
            ["ethereum"],
            Dict(
                "max_position_size" => 0.1,
                "min_profit_threshold" => 0.01
            )
        )
        agent !== nothing
    end
    
    @test begin
        # Test performance calculation
        returns = [0.01, -0.005, 0.02, -0.01, 0.015]
        metrics = SwarmManager.calculate_performance_metrics(returns)
        haskey(metrics, "sharpe_ratio") && haskey(metrics, "max_drawdown")
    end
end

# CLI tests
@testset "CLI Tests" begin
    @test begin
        # Test command completion
        completions = Interactive.get_command_completions("br")
        "bridge" in completions
    end
    
    @test begin
        # Test input validation
        valid, _ = Interactive.validate_input("0.5", :float, min=0.0, max=1.0)
        valid
    end
    
    @test begin
        # Test invalid input validation
        valid, _ = Interactive.validate_input("1.5", :float, min=0.0, max=1.0)
        !valid
    end
end

# Run all tests
function run_tests()
    setup_test_environment()
    
    @testset "JuliaOS Framework Tests" begin
        include("runtests.jl")
    end
    
    cleanup_test_environment()
end

# Run tests if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_tests()
end 