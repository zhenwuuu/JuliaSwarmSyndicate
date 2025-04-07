using Test
using JuliaOS.RiskManagement

@testset "Risk Management Tests" begin
    @testset "Risk Parameters" begin
        # Test risk parameter creation
        risk_params = RiskParameters(
            Dict(
                "max_position_size" => 0.1,  # 10% of portfolio
                "max_drawdown" => 0.15,      # 15% max drawdown
                "min_capital_ratio" => 0.5,  # 50% minimum capital ratio
                "max_leverage" => 2.0,       # 2x max leverage
                "stop_loss" => 0.1,          # 10% stop loss
                "take_profit" => 0.2         # 20% take profit
            )
        )
        
        @test risk_params.max_position_size == 0.1
        @test risk_params.max_drawdown == 0.15
        @test risk_params.min_capital_ratio == 0.5
        @test risk_params.max_leverage == 2.0
        @test risk_params.stop_loss == 0.1
        @test risk_params.take_profit == 0.2
    end
    
    @testset "Portfolio Risk Analysis" begin
        # Test portfolio risk analysis
        portfolio = Portfolio(
            Dict(
                "ETH" => Position(
                    "eth_position",
                    "ETH/USDC",
                    1.0,  # ETH amount
                    2000.0,  # USDC amount
                    1900.0,  # Lower price
                    2100.0,  # Upper price
                    0.003,  # Fee tier
                    now()  # Creation time
                )
            ),
            10000.0  # Total value
        )
        
        risk_analysis = analyze_portfolio_risk(portfolio, risk_params)
        
        @test haskey(risk_analysis, "total_exposure")
        @test haskey(risk_analysis, "leverage_ratio")
        @test haskey(risk_analysis, "capital_ratio")
        @test haskey(risk_analysis, "risk_score")
    end
    
    @testset "Position Risk Management" begin
        # Test position risk management
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        # Test position risk analysis
        position_risk = analyze_position_risk(position, risk_params)
        
        @test haskey(position_risk, "exposure")
        @test haskey(position_risk, "leverage")
        @test haskey(position_risk, "risk_score")
        
        # Test position adjustment
        adjusted_position = adjust_position_risk(position, position_risk, risk_params)
        @test adjusted_position.id == position.id
        @test adjusted_position.pair == position.pair
    end
    
    @testset "Stop Loss Management" begin
        # Test stop loss monitoring
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        # Test stop loss check
        should_stop = check_stop_loss(
            position,
            Dict(
                "current_price" => 1800.0,
                "entry_price" => 2000.0,
                "stop_loss" => 0.1
            )
        )
        @test should_stop isa Bool
        
        # Test stop loss execution
        if should_stop
            result = execute_stop_loss(position)
            @test result.status == "success"
            @test haskey(result, "exit_price")
            @test haskey(result, "loss_amount")
        end
    end
    
    @testset "Take Profit Management" begin
        # Test take profit monitoring
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        # Test take profit check
        should_take_profit = check_take_profit(
            position,
            Dict(
                "current_price" => 2400.0,
                "entry_price" => 2000.0,
                "take_profit" => 0.2
            )
        )
        @test should_take_profit isa Bool
        
        # Test take profit execution
        if should_take_profit
            result = execute_take_profit(position)
            @test result.status == "success"
            @test haskey(result, "exit_price")
            @test haskey(result, "profit_amount")
        end
    end
    
    @testset "Drawdown Monitoring" begin
        # Test drawdown monitoring
        portfolio = Portfolio(
            Dict(
                "ETH" => Position(
                    "eth_position",
                    "ETH/USDC",
                    1.0,
                    2000.0,
                    1900.0,
                    2100.0,
                    0.003,
                    now()
                )
            ),
            10000.0
        )
        
        # Test drawdown calculation
        drawdown = calculate_drawdown(
            portfolio,
            Dict(
                "peak_value" => 12000.0,
                "current_value" => 9000.0
            )
        )
        @test drawdown isa Float64
        @test drawdown >= 0.0
        @test drawdown <= 1.0
        
        # Test drawdown monitoring
        should_mitigate = check_drawdown(
            portfolio,
            Dict(
                "max_drawdown" => 0.15,
                "current_drawdown" => drawdown
            )
        )
        @test should_mitigate isa Bool
    end
    
    @testset "Risk Mitigation" begin
        # Test risk mitigation strategies
        portfolio = Portfolio(
            Dict(
                "ETH" => Position(
                    "eth_position",
                    "ETH/USDC",
                    1.0,
                    2000.0,
                    1900.0,
                    2100.0,
                    0.003,
                    now()
                )
            ),
            10000.0
        )
        
        # Test position reduction
        reduced_portfolio = reduce_position_risk(
            portfolio,
            Dict(
                "ETH" => 0.5  # Reduce by 50%
            )
        )
        @test reduced_portfolio.positions["ETH"].token0_amount < portfolio.positions["ETH"].token0_amount
        
        # Test portfolio rebalancing
        rebalanced_portfolio = rebalance_portfolio(
            portfolio,
            Dict(
                "max_position_size" => 0.1,
                "min_capital_ratio" => 0.5
            )
        )
        @test length(rebalanced_portfolio.positions) > 0
    end
    
    @testset "Error Handling" begin
        # Test invalid risk parameters
        @test_throws ArgumentError RiskParameters(
            Dict(
                "max_position_size" => -0.1,
                "max_drawdown" => 0.15,
                "min_capital_ratio" => 0.5
            )
        )
        
        # Test invalid portfolio
        @test_throws ArgumentError Portfolio(
            Dict(),
            -10000.0
        )
        
        # Test invalid position
        @test_throws ArgumentError Position(
            "",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        # Test invalid risk analysis
        @test_throws ArgumentError analyze_portfolio_risk(
            Portfolio(Dict(), 0.0),
            RiskParameters(Dict())
        )
    end
end 