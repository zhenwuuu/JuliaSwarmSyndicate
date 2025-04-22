"""
MovingAverageStrategy.jl - Moving average crossover trading strategy

This module provides a moving average crossover trading strategy for DeFi trading.
"""
module MovingAverageStrategy

export MovingAverageCrossoverStrategy, execute_strategy, backtest_strategy

using ..TradingStrategy
using ..DEXBase
using ..PriceFeeds
using Statistics
using Dates

"""
    MovingAverageCrossoverStrategy <: AbstractStrategy

Strategy for trading based on moving average crossovers.

# Fields
- `base_asset::String`: The base asset (e.g., "ETH")
- `quote_asset::String`: The quote asset (e.g., "USD")
- `short_window::Int`: The window size for the short-term moving average
- `long_window::Int`: The window size for the long-term moving average
- `price_feed::AbstractPriceFeed`: The price feed to use
- `dex::AbstractDEX`: The DEX to use for trading
- `trade_amount::Float64`: The amount to trade
- `stop_loss_pct::Float64`: The stop loss percentage
- `take_profit_pct::Float64`: The take profit percentage
"""
struct MovingAverageCrossoverStrategy <: AbstractStrategy
    base_asset::String
    quote_asset::String
    short_window::Int
    long_window::Int
    price_feed::AbstractPriceFeed
    dex::AbstractDEX
    trade_amount::Float64
    stop_loss_pct::Float64
    take_profit_pct::Float64

    function MovingAverageCrossoverStrategy(
        base_asset::String,
        quote_asset::String,
        price_feed::AbstractPriceFeed,
        dex::AbstractDEX;
        short_window::Int = 10,
        long_window::Int = 30,
        trade_amount::Float64 = 1.0,
        stop_loss_pct::Float64 = 5.0,
        take_profit_pct::Float64 = 10.0
    )
        # Validate inputs
        if short_window >= long_window
            error("Short window must be smaller than long window")
        end

        if short_window < 2
            error("Short window must be at least 2")
        end

        if trade_amount <= 0.0
            error("Trade amount must be positive")
        end

        if stop_loss_pct <= 0.0
            error("Stop loss percentage must be positive")
        end

        if take_profit_pct <= 0.0
            error("Take profit percentage must be positive")
        end

        new(
            uppercase(base_asset),
            uppercase(quote_asset),
            short_window,
            long_window,
            price_feed,
            dex,
            trade_amount,
            stop_loss_pct,
            take_profit_pct
        )
    end
end

# ===== Helper Functions =====

"""
    calculate_moving_average(prices::Vector{Float64}, window::Int)

Calculate the moving average of a price series.

# Arguments
- `prices::Vector{Float64}`: The price series
- `window::Int`: The window size

# Returns
- `Vector{Float64}`: The moving average series
"""
function calculate_moving_average(prices::Vector{Float64}, window::Int)
    n = length(prices)
    ma = zeros(n)

    for i in 1:n
        if i < window
            # Not enough data for a full window, use available data
            ma[i] = mean(prices[1:i])
        else
            # Full window available
            ma[i] = mean(prices[i-window+1:i])
        end
    end

    return ma
end

"""
    detect_crossover(short_ma::Vector{Float64}, long_ma::Vector{Float64})

Detect crossovers between short and long moving averages.

# Arguments
- `short_ma::Vector{Float64}`: The short-term moving average series
- `long_ma::Vector{Float64}`: The long-term moving average series

# Returns
- `Tuple{Bool, Bool}`: (golden_cross, death_cross)
"""
function detect_crossover(short_ma::Vector{Float64}, long_ma::Vector{Float64})
    n = length(short_ma)

    if n < 2 || n != length(long_ma)
        return (false, false)
    end

    # Check for golden cross (short MA crosses above long MA)
    golden_cross = short_ma[n-1] <= long_ma[n-1] && short_ma[n] > long_ma[n]

    # Check for death cross (short MA crosses below long MA)
    death_cross = short_ma[n-1] >= long_ma[n-1] && short_ma[n] < long_ma[n]

    return (golden_cross, death_cross)
end

"""
    get_trading_pair(strategy::MovingAverageCrossoverStrategy)

Get the trading pair for the strategy.

# Arguments
- `strategy::MovingAverageCrossoverStrategy`: The strategy

# Returns
- `DEXPair`: The trading pair
"""
function get_trading_pair(strategy::MovingAverageCrossoverStrategy)
    # Get all pairs from the DEX
    pairs = DEXBase.get_pairs(strategy.dex)

    # Find the pair that matches the strategy's assets
    for pair in pairs
        if (pair.token0.symbol == strategy.base_asset && pair.token1.symbol == strategy.quote_asset) ||
           (pair.token0.symbol == strategy.quote_asset && pair.token1.symbol == strategy.base_asset)
            return pair
        end
    end

    error("No trading pair found for $(strategy.base_asset)/$(strategy.quote_asset)")
end

# ===== Strategy Implementation =====

"""
    execute_strategy(strategy::MovingAverageCrossoverStrategy)

Execute the moving average crossover strategy.

# Arguments
- `strategy::MovingAverageCrossoverStrategy`: The strategy

# Returns
- `Dict{String, Any}`: The result of the strategy execution
"""
function TradingStrategy.execute_strategy(strategy::MovingAverageCrossoverStrategy)
    # Get historical prices
    price_data = PriceFeeds.get_historical_prices(
        strategy.price_feed,
        strategy.base_asset,
        strategy.quote_asset;
        interval = "1d",
        limit = max(strategy.long_window * 2, 100)  # Get enough data for the moving averages
    )

    # Extract prices
    prices = [point.price for point in price_data.points]

    # Calculate moving averages
    short_ma = calculate_moving_average(prices, strategy.short_window)
    long_ma = calculate_moving_average(prices, strategy.long_window)

    # Detect crossovers
    golden_cross, death_cross = detect_crossover(short_ma, long_ma)

    # Get the current price
    current_price = PriceFeeds.get_latest_price(
        strategy.price_feed,
        strategy.base_asset,
        strategy.quote_asset
    ).price

    # Get the trading pair
    pair = get_trading_pair(strategy)

    # Determine the action to take
    action = "HOLD"
    order = nothing

    if golden_cross
        # Buy signal
        action = "BUY"

        # Create a buy order
        order = DEXBase.create_order(
            strategy.dex,
            pair,
            DEXBase.MARKET,
            DEXBase.BUY,
            strategy.trade_amount
        )

        # Set stop loss and take profit levels
        stop_loss = current_price * (1.0 - strategy.stop_loss_pct / 100.0)
        take_profit = current_price * (1.0 + strategy.take_profit_pct / 100.0)
    elseif death_cross
        # Sell signal
        action = "SELL"

        # Create a sell order
        order = DEXBase.create_order(
            strategy.dex,
            pair,
            DEXBase.MARKET,
            DEXBase.SELL,
            strategy.trade_amount
        )

        # Set stop loss and take profit levels
        stop_loss = current_price * (1.0 + strategy.stop_loss_pct / 100.0)
        take_profit = current_price * (1.0 - strategy.take_profit_pct / 100.0)
    else
        # No signal, hold
        stop_loss = 0.0
        take_profit = 0.0
    end

    # Return the result
    return Dict(
        "strategy_type" => "MovingAverageCrossoverStrategy",
        "base_asset" => strategy.base_asset,
        "quote_asset" => strategy.quote_asset,
        "current_price" => current_price,
        "short_ma" => short_ma[end],
        "long_ma" => long_ma[end],
        "action" => action,
        "order" => order,
        "stop_loss" => stop_loss,
        "take_profit" => take_profit
    )
end

"""
    backtest_strategy(strategy::MovingAverageCrossoverStrategy, start_date::DateTime, end_date::DateTime)

Backtest the moving average crossover strategy.

# Arguments
- `strategy::MovingAverageCrossoverStrategy`: The strategy
- `start_date::DateTime`: The start date for the backtest
- `end_date::DateTime`: The end date for the backtest

# Returns
- `Dict{String, Any}`: The backtest results
"""
function backtest_strategy(strategy::MovingAverageCrossoverStrategy, start_date::DateTime, end_date::DateTime)
    # Get historical prices
    price_data = PriceFeeds.get_historical_prices(
        strategy.price_feed,
        strategy.base_asset,
        strategy.quote_asset;
        interval = "1d",
        start_time = start_date,
        end_time = end_date
    )

    # Extract prices and timestamps
    prices = [point.price for point in price_data.points]
    timestamps = [point.timestamp for point in price_data.points]

    # Initialize backtest variables
    position = 0.0  # 0 = no position, positive = long, negative = short
    entry_price = 0.0
    trades = []
    equity_curve = zeros(length(prices))
    equity = 1000.0  # Start with $1000

    # Calculate moving averages
    short_ma = calculate_moving_average(prices, strategy.short_window)
    long_ma = calculate_moving_average(prices, strategy.long_window)

    # Run the backtest
    for i in strategy.long_window+1:length(prices)
        # Check for crossovers
        golden_cross = short_ma[i-1] <= long_ma[i-1] && short_ma[i] > long_ma[i]
        death_cross = short_ma[i-1] >= long_ma[i-1] && short_ma[i] < long_ma[i]

        # Update equity curve
        equity_curve[i] = equity

        # Check for signals
        if golden_cross && position <= 0
            # Buy signal
            if position < 0
                # Close short position
                profit = entry_price - prices[i]
                equity += profit * abs(position)
                push!(trades, Dict(
                    "type" => "CLOSE_SHORT",
                    "timestamp" => timestamps[i],
                    "price" => prices[i],
                    "profit" => profit * abs(position),
                    "equity" => equity
                ))
            end

            # Open long position
            position = strategy.trade_amount / prices[i]
            entry_price = prices[i]
            push!(trades, Dict(
                "type" => "OPEN_LONG",
                "timestamp" => timestamps[i],
                "price" => prices[i],
                "position" => position,
                "equity" => equity
            ))
        elseif death_cross && position >= 0
            # Sell signal
            if position > 0
                # Close long position
                profit = prices[i] - entry_price
                equity += profit * position
                push!(trades, Dict(
                    "type" => "CLOSE_LONG",
                    "timestamp" => timestamps[i],
                    "price" => prices[i],
                    "profit" => profit * position,
                    "equity" => equity
                ))
            end

            # Open short position
            position = -strategy.trade_amount / prices[i]
            entry_price = prices[i]
            push!(trades, Dict(
                "type" => "OPEN_SHORT",
                "timestamp" => timestamps[i],
                "price" => prices[i],
                "position" => position,
                "equity" => equity
            ))
        end
    end

    # Close any open position at the end
    if position > 0
        # Close long position
        profit = prices[end] - entry_price
        equity += profit * position
        push!(trades, Dict(
            "type" => "CLOSE_LONG",
            "timestamp" => timestamps[end],
            "price" => prices[end],
            "profit" => profit * position,
            "equity" => equity
        ))
    elseif position < 0
        # Close short position
        profit = entry_price - prices[end]
        equity += profit * abs(position)
        push!(trades, Dict(
            "type" => "CLOSE_SHORT",
            "timestamp" => timestamps[end],
            "price" => prices[end],
            "profit" => profit * abs(position),
            "equity" => equity
        ))
    end

    # Calculate performance metrics
    initial_equity = 1000.0
    final_equity = equity
    total_return = (final_equity - initial_equity) / initial_equity * 100.0

    # Calculate drawdown
    peak = initial_equity
    drawdown = 0.0
    max_drawdown = 0.0

    for eq in equity_curve
        if eq > peak
            peak = eq
        end

        drawdown = (peak - eq) / peak * 100.0
        max_drawdown = max(max_drawdown, drawdown)
    end

    # Calculate win rate
    wins = 0
    losses = 0

    for trade in trades
        if haskey(trade, "profit")
            if trade["profit"] > 0
                wins += 1
            elseif trade["profit"] < 0
                losses += 1
            end
        end
    end

    total_trades = wins + losses
    win_rate = total_trades > 0 ? wins / total_trades * 100.0 : 0.0

    # Return the backtest results
    return Dict(
        "strategy_type" => "MovingAverageCrossoverStrategy",
        "base_asset" => strategy.base_asset,
        "quote_asset" => strategy.quote_asset,
        "short_window" => strategy.short_window,
        "long_window" => strategy.long_window,
        "start_date" => start_date,
        "end_date" => end_date,
        "initial_equity" => initial_equity,
        "final_equity" => final_equity,
        "total_return" => total_return,
        "max_drawdown" => max_drawdown,
        "total_trades" => total_trades,
        "wins" => wins,
        "losses" => losses,
        "win_rate" => win_rate,
        "trades" => trades,
        "equity_curve" => equity_curve,
        "prices" => prices,
        "timestamps" => timestamps,
        "short_ma" => short_ma,
        "long_ma" => long_ma
    )
end

end # module
