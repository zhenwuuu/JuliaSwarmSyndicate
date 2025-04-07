using Test
using JuliaOS
using JuliaOS.MarketData
using JuliaOS.Config
using TestUtils
using Dates

@testset "Market Data Tests" begin
    @testset "Market Data Initialization" begin
        TestUtils.with_test_market_data(market_data -> begin
            @test haskey(market_data.prices, "ethereum")
            @test haskey(market_data.prices, "solana")
            @test haskey(market_data.volumes, "ethereum")
            @test haskey(market_data.volumes, "solana")
        end)
    end

    @testset "Price Data" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Test Ethereum price data
            eth_price = MarketData.get_price("ethereum", "ETH/USDC")
            @test eth_price > 0
            @test eth_price == market_data.prices["ethereum"]["ETH/USDC"]

            # Test Solana price data
            sol_price = MarketData.get_price("solana", "SOL/USDC")
            @test sol_price > 0
            @test sol_price == market_data.prices["solana"]["SOL/USDC"]

            # Test invalid pair
            @test_throws ArgumentError MarketData.get_price("ethereum", "INVALID/PAIR")
        end)
    end

    @testset "Volume Data" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Test Ethereum volume data
            eth_volume = MarketData.get_volume("ethereum", "ETH/USDC")
            @test eth_volume >= 0
            @test eth_volume == market_data.volumes["ethereum"]["ETH/USDC"]

            # Test Solana volume data
            sol_volume = MarketData.get_volume("solana", "SOL/USDC")
            @test sol_volume >= 0
            @test sol_volume == market_data.volumes["solana"]["SOL/USDC"]

            # Test invalid pair
            @test_throws ArgumentError MarketData.get_volume("ethereum", "INVALID/PAIR")
        end)
    end

    @testset "Historical Data" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Test historical data fetching
            historical = MarketData.fetch_historical(
                "ethereum",
                "ETH/USDC";
                days=7,
                interval="1h"
            )
            @test historical isa Vector
            @test !isempty(historical)

            # Test historical data structure
            if !isempty(historical)
                data_point = historical[1]
                @test haskey(data_point, "timestamp")
                @test haskey(data_point, "price")
                @test haskey(data_point, "volume")
                @test haskey(data_point, "high")
                @test haskey(data_point, "low")
                @test haskey(data_point, "open")
                @test haskey(data_point, "close")
            end

            # Test invalid parameters
            @test_throws ArgumentError MarketData.fetch_historical(
                "ethereum",
                "ETH/USDC";
                days=-1,
                interval="1h"
            )
            @test_throws ArgumentError MarketData.fetch_historical(
                "ethereum",
                "ETH/USDC";
                days=7,
                interval="invalid"
            )
        end)
    end

    @testset "Technical Indicators" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Generate test price data
            prices = [100.0, 101.0, 99.0, 102.0, 101.0]
            volumes = [1000.0, 1100.0, 900.0, 1200.0, 1100.0]

            # Test RSI calculation
            rsi = MarketData.calculate_rsi(prices)
            @test rsi isa Float64
            @test 0 <= rsi <= 100

            # Test MACD calculation
            macd = MarketData.calculate_macd(prices)
            @test macd isa Dict
            @test haskey(macd, "macd")
            @test haskey(macd, "signal")
            @test haskey(macd, "histogram")

            # Test Bollinger Bands
            bb = MarketData.calculate_bollinger_bands(prices)
            @test bb isa Dict
            @test haskey(bb, "upper")
            @test haskey(bb, "middle")
            @test haskey(bb, "lower")

            # Test Volume indicators
            volume_indicators = MarketData.calculate_volume_indicators(prices, volumes)
            @test volume_indicators isa Dict
            @test haskey(volume_indicators, "obv")
            @test haskey(volume_indicators, "vwap")
        end)
    end

    @testset "Market Analysis" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Test market analysis
            analysis = MarketData.analyze_market(
                "ethereum",
                "ETH/USDC";
                days=7,
                interval="1h"
            )
            @test analysis isa Dict
            @test haskey(analysis, "trend")
            @test haskey(analysis, "volatility")
            @test haskey(analysis, "support_levels")
            @test haskey(analysis, "resistance_levels")
            @test haskey(analysis, "indicators")

            # Test trend analysis
            trend = analysis["trend"]
            @test haskey(trend, "direction")
            @test haskey(trend, "strength")
            @test haskey(trend, "confidence")

            # Test volatility analysis
            volatility = analysis["volatility"]
            @test haskey(volatility, "current")
            @test haskey(volatility, "historical")
            @test haskey(volatility, "trend")
        end)
    end

    @testset "Error Handling" begin
        TestUtils.with_test_market_data(market_data -> begin
            # Test network error handling
            @test_throws HTTP.RequestError MarketData.get_price("ethereum", "ETH/USDC")

            # Test timeout handling
            @test_throws TimeoutError MarketData.fetch_historical(
                "ethereum",
                "ETH/USDC";
                days=7,
                interval="1h"
            )

            # Test invalid data handling
            @test_throws ArgumentError MarketData.calculate_rsi([])
            @test_throws ArgumentError MarketData.calculate_macd([1.0])
            @test_throws ArgumentError MarketData.calculate_bollinger_bands([1.0])
        end)
    end
end 