"""
TradingVisualizer.jl - Visualization tools for trading data and strategies

This module provides visualization tools for trading data and strategy results.
"""
module TradingVisualizer

export plot_price_data, plot_moving_averages, plot_mean_reversion
export plot_backtest_results, plot_equity_curve, plot_drawdown_curve
export plot_trade_distribution, plot_returns_distribution

using Plots
using Statistics
using Dates
using StatsBase

"""
    plot_price_data(timestamps::Vector{DateTime}, prices::Vector{Float64};
                  title::String="Price Chart", ylabel::String="Price")

Plot price data over time.

# Arguments
- `timestamps::Vector{DateTime}`: The timestamps
- `prices::Vector{Float64}`: The prices
- `title::String`: The chart title
- `ylabel::String`: The y-axis label

# Returns
- `Plots.Plot`: The plot
"""
function plot_price_data(timestamps::Vector{DateTime}, prices::Vector{Float64};
                       title::String="Price Chart", ylabel::String="Price")
    p = plot(timestamps, prices,
        title = title,
        xlabel = "Time",
        ylabel = ylabel,
        legend = false,
        linewidth = 2,
        grid = true,
        color = :blue
    )
    
    return p
end

"""
    plot_moving_averages(timestamps::Vector{DateTime}, prices::Vector{Float64},
                       short_ma::Vector{Float64}, long_ma::Vector{Float64};
                       title::String="Moving Average Crossover")

Plot price data with moving averages.

# Arguments
- `timestamps::Vector{DateTime}`: The timestamps
- `prices::Vector{Float64}`: The prices
- `short_ma::Vector{Float64}`: The short-term moving average
- `long_ma::Vector{Float64}`: The long-term moving average
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_moving_averages(timestamps::Vector{DateTime}, prices::Vector{Float64},
                            short_ma::Vector{Float64}, long_ma::Vector{Float64};
                            title::String="Moving Average Crossover")
    p = plot(timestamps, prices,
        title = title,
        xlabel = "Time",
        ylabel = "Price",
        label = "Price",
        linewidth = 1,
        grid = true,
        color = :black,
        alpha = 0.5
    )
    
    plot!(p, timestamps, short_ma,
        label = "Short MA",
        linewidth = 2,
        color = :blue
    )
    
    plot!(p, timestamps, long_ma,
        label = "Long MA",
        linewidth = 2,
        color = :red
    )
    
    # Find crossover points
    buy_signals = []
    sell_signals = []
    
    for i in 2:length(short_ma)
        if short_ma[i-1] < long_ma[i-1] && short_ma[i] >= long_ma[i]
            push!(buy_signals, (timestamps[i], prices[i]))
        elseif short_ma[i-1] > long_ma[i-1] && short_ma[i] <= long_ma[i]
            push!(sell_signals, (timestamps[i], prices[i]))
        end
    end
    
    # Plot buy signals
    if !isempty(buy_signals)
        scatter!(p, [x[1] for x in buy_signals], [x[2] for x in buy_signals],
            label = "Buy Signal",
            marker = :circle,
            markersize = 6,
            color = :green
        )
    end
    
    # Plot sell signals
    if !isempty(sell_signals)
        scatter!(p, [x[1] for x in sell_signals], [x[2] for x in sell_signals],
            label = "Sell Signal",
            marker = :circle,
            markersize = 6,
            color = :red
        )
    end
    
    return p
end

"""
    plot_mean_reversion(timestamps::Vector{DateTime}, prices::Vector{Float64},
                      mean::Vector{Float64}, upper_band::Vector{Float64}, lower_band::Vector{Float64};
                      title::String="Mean Reversion")

Plot price data with mean and bands for mean reversion strategy.

# Arguments
- `timestamps::Vector{DateTime}`: The timestamps
- `prices::Vector{Float64}`: The prices
- `mean::Vector{Float64}`: The mean prices
- `upper_band::Vector{Float64}`: The upper band (mean + threshold * std)
- `lower_band::Vector{Float64}`: The lower band (mean - threshold * std)
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_mean_reversion(timestamps::Vector{DateTime}, prices::Vector{Float64},
                           mean::Vector{Float64}, upper_band::Vector{Float64}, lower_band::Vector{Float64};
                           title::String="Mean Reversion")
    p = plot(timestamps, prices,
        title = title,
        xlabel = "Time",
        ylabel = "Price",
        label = "Price",
        linewidth = 1,
        grid = true,
        color = :black,
        alpha = 0.7
    )
    
    plot!(p, timestamps, mean,
        label = "Mean",
        linewidth = 2,
        color = :blue
    )
    
    plot!(p, timestamps, upper_band,
        label = "Upper Band",
        linewidth = 1,
        color = :red,
        linestyle = :dash
    )
    
    plot!(p, timestamps, lower_band,
        label = "Lower Band",
        linewidth = 1,
        color = :green,
        linestyle = :dash
    )
    
    # Find signal points
    buy_signals = []
    sell_signals = []
    exit_signals = []
    
    for i in 1:length(prices)
        if prices[i] <= lower_band[i]
            push!(buy_signals, (timestamps[i], prices[i]))
        elseif prices[i] >= upper_band[i]
            push!(sell_signals, (timestamps[i], prices[i]))
        elseif abs(prices[i] - mean[i]) < 0.5 * (upper_band[i] - mean[i])
            push!(exit_signals, (timestamps[i], prices[i]))
        end
    end
    
    # Plot buy signals
    if !isempty(buy_signals)
        scatter!(p, [x[1] for x in buy_signals], [x[2] for x in buy_signals],
            label = "Buy Signal",
            marker = :circle,
            markersize = 6,
            color = :green
        )
    end
    
    # Plot sell signals
    if !isempty(sell_signals)
        scatter!(p, [x[1] for x in sell_signals], [x[2] for x in sell_signals],
            label = "Sell Signal",
            marker = :circle,
            markersize = 6,
            color = :red
        )
    end
    
    # Plot exit signals
    if !isempty(exit_signals)
        scatter!(p, [x[1] for x in exit_signals], [x[2] for x in exit_signals],
            label = "Exit Signal",
            marker = :circle,
            markersize = 6,
            color = :orange
        )
    end
    
    return p
end

"""
    plot_backtest_results(backtest_result::Dict{String, Any};
                        title::String="Backtest Results")

Plot backtest results.

# Arguments
- `backtest_result::Dict{String, Any}`: The backtest results
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_backtest_results(backtest_result::Dict{String, Any};
                             title::String="Backtest Results")
    # Extract data from backtest results
    trades = backtest_result["trades"]
    
    if isempty(trades)
        error("No trades in backtest results")
    end
    
    # Extract timestamps and equity values
    timestamps = []
    equity_values = []
    
    # Start with initial equity
    initial_equity = backtest_result["initial_equity"]
    push!(timestamps, trades[1]["timestamp"] - Day(1))
    push!(equity_values, initial_equity)
    
    # Add equity after each trade
    current_equity = initial_equity
    for trade in trades
        if haskey(trade, "profit")
            current_equity += trade["profit"]
            push!(timestamps, trade["timestamp"])
            push!(equity_values, current_equity)
        end
    end
    
    # Create the plot
    p = plot(timestamps, equity_values,
        title = title,
        xlabel = "Time",
        ylabel = "Equity",
        label = "Equity Curve",
        linewidth = 2,
        grid = true,
        color = :blue
    )
    
    # Add a horizontal line for initial equity
    hline!(p, [initial_equity],
        label = "Initial Equity",
        linewidth = 1,
        color = :black,
        linestyle = :dash
    )
    
    # Add annotations for key metrics
    total_return = backtest_result["total_return"]
    max_drawdown = backtest_result["max_drawdown"]
    win_rate = backtest_result["win_rate"]
    
    annotations = [
        (timestamps[end], equity_values[end], "Total Return: $(round(total_return, digits=2))%"),
        (timestamps[end], equity_values[end] * 0.95, "Max Drawdown: $(round(max_drawdown, digits=2))%"),
        (timestamps[end], equity_values[end] * 0.9, "Win Rate: $(round(win_rate, digits=2))%")
    ]
    
    for (x, y, text) in annotations
        annotate!(p, x, y, text, :right, :top, 8)
    end
    
    return p
end

"""
    plot_equity_curve(timestamps::Vector{DateTime}, equity_values::Vector{Float64};
                    title::String="Equity Curve")

Plot an equity curve.

# Arguments
- `timestamps::Vector{DateTime}`: The timestamps
- `equity_values::Vector{Float64}`: The equity values
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_equity_curve(timestamps::Vector{DateTime}, equity_values::Vector{Float64};
                         title::String="Equity Curve")
    p = plot(timestamps, equity_values,
        title = title,
        xlabel = "Time",
        ylabel = "Equity",
        label = "Equity Curve",
        linewidth = 2,
        grid = true,
        color = :blue
    )
    
    # Add a horizontal line for initial equity
    hline!(p, [equity_values[1]],
        label = "Initial Equity",
        linewidth = 1,
        color = :black,
        linestyle = :dash
    )
    
    # Calculate and display total return
    total_return = (equity_values[end] - equity_values[1]) / equity_values[1] * 100
    
    annotate!(p, timestamps[end], equity_values[end], "Total Return: $(round(total_return, digits=2))%", :right, :top, 8)
    
    return p
end

"""
    plot_drawdown_curve(timestamps::Vector{DateTime}, equity_values::Vector{Float64};
                      title::String="Drawdown Curve")

Plot a drawdown curve.

# Arguments
- `timestamps::Vector{DateTime}`: The timestamps
- `equity_values::Vector{Float64}`: The equity values
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_drawdown_curve(timestamps::Vector{DateTime}, equity_values::Vector{Float64};
                           title::String="Drawdown Curve")
    # Calculate drawdown
    max_equity = equity_values[1]
    drawdowns = zeros(length(equity_values))
    
    for i in 1:length(equity_values)
        max_equity = max(max_equity, equity_values[i])
        drawdowns[i] = (max_equity - equity_values[i]) / max_equity * 100
    end
    
    p = plot(timestamps, drawdowns,
        title = title,
        xlabel = "Time",
        ylabel = "Drawdown (%)",
        label = "Drawdown",
        linewidth = 2,
        grid = true,
        color = :red,
        fill = (0, 0.3, :red)
    )
    
    # Add a horizontal line for zero drawdown
    hline!(p, [0],
        label = nothing,
        linewidth = 1,
        color = :black,
        linestyle = :dash
    )
    
    # Calculate and display max drawdown
    max_drawdown = maximum(drawdowns)
    
    annotate!(p, timestamps[end], max_drawdown, "Max Drawdown: $(round(max_drawdown, digits=2))%", :right, :top, 8)
    
    return p
end

"""
    plot_trade_distribution(trades::Vector{Dict{String, Any}};
                          title::String="Trade Distribution")

Plot a distribution of trade profits.

# Arguments
- `trades::Vector{Dict{String, Any}}`: The trades
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_trade_distribution(trades::Vector{Dict{String, Any}};
                               title::String="Trade Distribution")
    # Extract profits from trades
    profits = []
    
    for trade in trades
        if haskey(trade, "profit")
            push!(profits, trade["profit"])
        end
    end
    
    if isempty(profits)
        error("No profits in trades")
    end
    
    # Create a histogram
    p = histogram(profits,
        title = title,
        xlabel = "Profit",
        ylabel = "Frequency",
        label = "Trade Profits",
        bins = min(20, length(profits)),
        grid = true,
        color = :blue,
        alpha = 0.7
    )
    
    # Add a vertical line for zero profit
    vline!(p, [0],
        label = "Break Even",
        linewidth = 2,
        color = :black,
        linestyle = :dash
    )
    
    # Calculate and display statistics
    avg_profit = mean(profits)
    win_rate = count(x -> x > 0, profits) / length(profits) * 100
    
    annotations = [
        (maximum(profits) * 0.8, maximum(StatsBase.fit(Histogram, profits).weights) * 0.9, "Avg Profit: \$$(round(avg_profit, digits=2))"),
        (maximum(profits) * 0.8, maximum(StatsBase.fit(Histogram, profits).weights) * 0.8, "Win Rate: $(round(win_rate, digits=2))%")
    ]
    
    for (x, y, text) in annotations
        annotate!(p, x, y, text, :right, :top, 8)
    end
    
    return p
end

"""
    plot_returns_distribution(returns::Vector{Float64};
                            title::String="Returns Distribution")

Plot a distribution of returns.

# Arguments
- `returns::Vector{Float64}`: The returns
- `title::String`: The chart title

# Returns
- `Plots.Plot`: The plot
"""
function plot_returns_distribution(returns::Vector{Float64};
                                 title::String="Returns Distribution")
    # Create a histogram
    p = histogram(returns,
        title = title,
        xlabel = "Return (%)",
        ylabel = "Frequency",
        label = "Returns",
        bins = min(20, length(returns)),
        grid = true,
        color = :blue,
        alpha = 0.7
    )
    
    # Add a vertical line for zero return
    vline!(p, [0],
        label = "Zero Return",
        linewidth = 2,
        color = :black,
        linestyle = :dash
    )
    
    # Calculate and display statistics
    avg_return = mean(returns)
    std_return = std(returns)
    sharpe_ratio = avg_return / std_return
    
    annotations = [
        (maximum(returns) * 0.8, maximum(StatsBase.fit(Histogram, returns).weights) * 0.9, "Avg Return: $(round(avg_return * 100, digits=2))%"),
        (maximum(returns) * 0.8, maximum(StatsBase.fit(Histogram, returns).weights) * 0.8, "Std Dev: $(round(std_return * 100, digits=2))%"),
        (maximum(returns) * 0.8, maximum(StatsBase.fit(Histogram, returns).weights) * 0.7, "Sharpe Ratio: $(round(sharpe_ratio, digits=2))")
    ]
    
    for (x, y, text) in annotations
        annotate!(p, x, y, text, :right, :top, 8)
    end
    
    return p
end

end # module
