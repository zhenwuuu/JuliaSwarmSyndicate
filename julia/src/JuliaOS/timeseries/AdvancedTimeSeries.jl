module AdvancedTimeSeries

using Statistics
using Dates
using LinearAlgebra
using Random
using Distributions
using FFTW
using StatsBase
using JSON

# Export main functions
export decompose_time_series, detect_anomalies, forecast_arima
export forecast_prophet, forecast_lstm, estimate_var, detect_changepoints
export calculate_features, seasonal_decompose, cross_correlation
export granger_causality, impulse_response, volatility_forecast
export rolling_stats, ewma, fractional_difference, cointegration_test

# Include components
include("decomposition.jl")
include("anomaly_detection.jl")
include("forecasting.jl")
include("statistics.jl")
include("deep_models.jl")
include("volatility.jl")
include("features.jl")
include("causality.jl")

"""
    decompose_time_series(ts::Vector{Float64}; method::String="stl", period::Int=12)

Decompose a time series into trend, seasonal, and residual components.

# Arguments
- `ts`: The time series data as a vector of Float64
- `method`: Decomposition method ("stl", "x11", or "seasonal")
- `period`: The period of the seasonal component

# Returns
- A dictionary with keys "trend", "seasonal", and "residual"
"""
function decompose_time_series(ts::Vector{Float64}; method::String="stl", period::Int=12)
    if method == "stl"
        return stl_decomposition(ts, period=period)
    elseif method == "x11"
        return x11_decomposition(ts, period=period)
    elseif method == "seasonal"
        return seasonal_decomposition(ts, period=period)
    else
        error("Unsupported decomposition method: $method")
    end
end

"""
    detect_anomalies(ts::Vector{Float64}; method::String="zscore", threshold::Float64=3.0)

Detect anomalies in a time series.

# Arguments
- `ts`: The time series data as a vector of Float64
- `method`: Detection method ("zscore", "iqr", "isolation_forest", or "lstm")
- `threshold`: Threshold for anomaly detection

# Returns
- A vector of indices corresponding to detected anomalies
"""
function detect_anomalies(ts::Vector{Float64}; method::String="zscore", threshold::Float64=3.0)
    if method == "zscore"
        return zscore_anomalies(ts, threshold=threshold)
    elseif method == "iqr"
        return iqr_anomalies(ts, threshold=threshold)
    elseif method == "isolation_forest"
        return isolation_forest_anomalies(ts, threshold=threshold)
    elseif method == "lstm"
        return lstm_anomalies(ts, threshold=threshold)
    else
        error("Unsupported anomaly detection method: $method")
    end
end

"""
    forecast_arima(ts::Vector{Float64}, horizon::Int; order::Tuple{Int,Int,Int}=(1,1,1))

Forecast a time series using an ARIMA model.

# Arguments
- `ts`: The time series data as a vector of Float64
- `horizon`: Number of steps to forecast
- `order`: Order of the ARIMA model as (p,d,q)

# Returns
- A dictionary with keys "forecast", "lower_bound", and "upper_bound"
"""
function forecast_arima(ts::Vector{Float64}, horizon::Int; order::Tuple{Int,Int,Int}=(1,1,1))
    return arima_forecast(ts, horizon, order=order)
end

"""
    forecast_prophet(ts::Vector{Float64}, dates::Vector{Date}, horizon::Int)

Forecast a time series using the Prophet algorithm.

# Arguments
- `ts`: The time series data as a vector of Float64
- `dates`: The dates corresponding to the time series
- `horizon`: Number of steps to forecast

# Returns
- A dictionary with keys "forecast", "lower_bound", and "upper_bound"
"""
function forecast_prophet(ts::Vector{Float64}, dates::Vector{Date}, horizon::Int)
    return prophet_forecast(ts, dates, horizon)
end

"""
    forecast_lstm(ts::Vector{Float64}, horizon::Int; lookback::Int=10)

Forecast a time series using an LSTM model.

# Arguments
- `ts`: The time series data as a vector of Float64
- `horizon`: Number of steps to forecast
- `lookback`: Number of lookback steps

# Returns
- A dictionary with keys "forecast", "lower_bound", and "upper_bound"
"""
function forecast_lstm(ts::Vector{Float64}, horizon::Int; lookback::Int=10)
    return lstm_forecast(ts, horizon, lookback=lookback)
end

"""
    estimate_var(ts_matrix::Matrix{Float64}, lags::Int=1)

Estimate a Vector Autoregression (VAR) model.

# Arguments
- `ts_matrix`: Matrix where each column is a different time series
- `lags`: Number of lags to include

# Returns
- A dictionary with VAR model parameters
"""
function estimate_var(ts_matrix::Matrix{Float64}, lags::Int=1)
    return var_estimation(ts_matrix, lags)
end

"""
    detect_changepoints(ts::Vector{Float64}; method::String="pelt", penalty::Float64=0.1)

Detect change points in a time series.

# Arguments
- `ts`: The time series data as a vector of Float64
- `method`: Change point detection method
- `penalty`: Penalty for the change point detection algorithm

# Returns
- A vector of change point indices
"""
function detect_changepoints(ts::Vector{Float64}; method::String="pelt", penalty::Float64=0.1)
    if method == "pelt"
        return pelt_changepoints(ts, penalty=penalty)
    elseif method == "binary_segmentation"
        return binary_segmentation_changepoints(ts, penalty=penalty)
    elseif method == "window_based"
        return window_based_changepoints(ts, penalty=penalty)
    else
        error("Unsupported change point detection method: $method")
    end
end

"""
    calculate_features(ts::Vector{Float64})

Calculate a comprehensive set of time series features.

# Arguments
- `ts`: The time series data as a vector of Float64

# Returns
- A dictionary of calculated features
"""
function calculate_features(ts::Vector{Float64})
    return extract_features(ts)
end

"""
    seasonal_decompose(ts::Vector{Float64}, period::Int=12)

Decompose a time series into seasonal, trend, and residual components.

# Arguments
- `ts`: The time series data as a vector of Float64
- `period`: The period of the seasonal component

# Returns
- A dictionary with keys "trend", "seasonal", and "residual"
"""
function seasonal_decompose(ts::Vector{Float64}, period::Int=12)
    return seasonal_decomposition(ts, period=period)
end

"""
    cross_correlation(ts1::Vector{Float64}, ts2::Vector{Float64}; max_lag::Int=10)

Calculate cross-correlation between two time series.

# Arguments
- `ts1`: First time series as a vector of Float64
- `ts2`: Second time series as a vector of Float64
- `max_lag`: Maximum lag to consider

# Returns
- A vector of cross-correlation values for different lags
"""
function cross_correlation(ts1::Vector{Float64}, ts2::Vector{Float64}; max_lag::Int=10)
    return compute_cross_correlation(ts1, ts2, max_lag=max_lag)
end

"""
    granger_causality(ts1::Vector{Float64}, ts2::Vector{Float64}; max_lag::Int=5)

Test for Granger causality between two time series.

# Arguments
- `ts1`: First time series as a vector of Float64
- `ts2`: Second time series as a vector of Float64
- `max_lag`: Maximum lag to consider

# Returns
- A dictionary with test statistics and p-values
"""
function granger_causality(ts1::Vector{Float64}, ts2::Vector{Float64}; max_lag::Int=5)
    return compute_granger_causality(ts1, ts2, max_lag=max_lag)
end

"""
    impulse_response(var_model::Dict, shock_variable::Int, horizon::Int=10)

Calculate impulse response functions for a VAR model.

# Arguments
- `var_model`: VAR model as returned by estimate_var
- `shock_variable`: Index of the variable to shock
- `horizon`: Number of periods for the response

# Returns
- A matrix of impulse responses
"""
function impulse_response(var_model::Dict, shock_variable::Int, horizon::Int=10)
    return compute_impulse_response(var_model, shock_variable, horizon)
end

"""
    volatility_forecast(ts::Vector{Float64}, horizon::Int; model::String="garch")

Forecast volatility using GARCH family models.

# Arguments
- `ts`: The time series data as a vector of Float64
- `horizon`: Number of steps to forecast
- `model`: Volatility model to use ("garch", "egarch", "gjr_garch")

# Returns
- A vector of volatility forecasts
"""
function volatility_forecast(ts::Vector{Float64}, horizon::Int; model::String="garch")
    if model == "garch"
        return garch_volatility(ts, horizon)
    elseif model == "egarch"
        return egarch_volatility(ts, horizon)
    elseif model == "gjr_garch"
        return gjr_garch_volatility(ts, horizon)
    else
        error("Unsupported volatility model: $model")
    end
end

"""
    rolling_stats(ts::Vector{Float64}, window::Int; stats::Vector{String}=["mean", "std"])

Calculate rolling statistics for a time series.

# Arguments
- `ts`: The time series data as a vector of Float64
- `window`: Window size
- `stats`: Statistics to calculate

# Returns
- A dictionary of rolling statistics
"""
function rolling_stats(ts::Vector{Float64}, window::Int; stats::Vector{String}=["mean", "std"])
    return compute_rolling_stats(ts, window, stats=stats)
end

"""
    ewma(ts::Vector{Float64}, alpha::Float64=0.05)

Calculate Exponentially Weighted Moving Average.

# Arguments
- `ts`: The time series data as a vector of Float64
- `alpha`: Smoothing factor

# Returns
- A vector of EWMA values
"""
function ewma(ts::Vector{Float64}, alpha::Float64=0.05)
    return compute_ewma(ts, alpha)
end

"""
    fractional_difference(ts::Vector{Float64}, d::Float64=0.5; window::Int=10)

Apply fractional differencing to a time series.

# Arguments
- `ts`: The time series data as a vector of Float64
- `d`: Fractional difference parameter
- `window`: Window size for the calculation

# Returns
- A vector of fractionally differenced values
"""
function fractional_difference(ts::Vector{Float64}, d::Float64=0.5; window::Int=10)
    return compute_fractional_difference(ts, d, window=window)
end

"""
    cointegration_test(ts_matrix::Matrix{Float64})

Test for cointegration between multiple time series.

# Arguments
- `ts_matrix`: Matrix where each column is a different time series

# Returns
- A dictionary with test statistics and p-values
"""
function cointegration_test(ts_matrix::Matrix{Float64})
    return compute_cointegration_test(ts_matrix)
end

# Initialize module
function __init__()
    @info "Initializing AdvancedTimeSeries module"
end

end # module 