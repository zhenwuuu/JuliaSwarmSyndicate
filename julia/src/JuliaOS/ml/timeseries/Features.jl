module Features

using Statistics
using StatsBase
using LinearAlgebra
using FFTW
using Distributions
using Distances

export extract, detect_anomalies
export simple_moving_average, exponential_moving_average
export macd, relative_strength_index, bollinger_bands
export average_true_range, detect_changepoints
export spectral_analysis, detect_turning_points
export rolling_std, rolling_mean, rolling_entropy, rolling_quantile
export autocorrelation_features, rolling_acf_lag

"""
    extract(data::Vector{<:Real}; window_size=10)

Extract statistical and technical features from a time series.
Returns a DataFrame with features as columns.
"""
function extract(data::Vector{<:Real}; window_size=10)
    n = length(data)
    result = Dict{String, Vector{Float64}}()
    
    # Ensure window size is valid
    window_size = min(window_size, n ÷ 2)
    
    # Basic statistical features
    result["mean"] = rolling_mean(data, window_size)
    result["std"] = rolling_std(data, window_size)
    result["min"] = rolling_min(data, window_size)
    result["max"] = rolling_max(data, window_size)
    result["median"] = rolling_median(data, window_size)
    result["skewness"] = rolling_skewness(data, window_size)
    result["kurtosis"] = rolling_kurtosis(data, window_size)
    
    # Trend features
    result["trend"] = calculate_trend_strength(data, window_size)
    result["momentum"] = calculate_momentum(data, window_size)
    
    # Autocorrelation features
    result["acf_lag1"] = rolling_acf_lag(data, window_size, 1)
    result["acf_lag5"] = rolling_acf_lag(data, window_size, 5)
    
    # Technical indicators
    result["sma_ratio"] = data ./ simple_moving_average(data, window_size)
    result["ema_ratio"] = data ./ exponential_moving_average(data, window_size)
    
    # Non-linear features
    result["entropy"] = rolling_entropy(data, window_size)
    result["sample_entropy"] = rolling_sample_entropy(data, window_size)
    
    # Convert to DataFrame
    return result
end

"""
    detect_anomalies(data::Vector{<:Real}; method="zscore", threshold=3.0)

Detect anomalies in time series using various methods.
Returns a boolean vector indicating anomalous points.
"""
function detect_anomalies(data::Vector{<:Real}; method="zscore", threshold=3.0)
    n = length(data)
    is_anomaly = falses(n)
    
    if method == "zscore"
        # Z-score method
        μ = mean(data)
        σ = std(data)
        
        for i in 1:n
            is_anomaly[i] = abs(data[i] - μ) > threshold * σ
        end
    elseif method == "iqr"
        # Interquartile range method
        q1 = quantile(data, 0.25)
        q3 = quantile(data, 0.75)
        iqr = q3 - q1
        lower_bound = q1 - threshold * iqr
        upper_bound = q3 + threshold * iqr
        
        for i in 1:n
            is_anomaly[i] = data[i] < lower_bound || data[i] > upper_bound
        end
    elseif method == "robust"
        # Robust method using median absolute deviation
        med = median(data)
        mad = median(abs.(data .- med))
        
        for i in 1:n
            is_anomaly[i] = abs(data[i] - med) > threshold * mad
        end
    elseif method == "local"
        # Local outlier detection
        window_size = 20
        for i in 1:n
            window_start = max(1, i - window_size)
            window_end = min(n, i + window_size)
            window = data[window_start:window_end]
            window_mean = mean(window)
            window_std = std(window)
            
            if abs(data[i] - window_mean) > threshold * window_std
                is_anomaly[i] = true
            end
        end
    else
        error("Unknown anomaly detection method: $method")
    end
    
    return is_anomaly
end

"""
    simple_moving_average(data::Vector{<:Real}, window::Int)

Calculate simple moving average with specified window size.
"""
function simple_moving_average(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 0
        return copy(data)
    end
    
    # Calculate first window manually
    first_sum = sum(data[1:min(window, n)])
    result[1] = first_sum / min(window, n)
    
    # Use rolling window for the rest
    for i in 2:n
        if i <= window
            # Still in initial window
            result[i] = result[i-1]
        else
            # Update rolling average
            result[i] = result[i-1] + (data[i] - data[i-window]) / window
        end
    end
    
    return result
end

"""
    exponential_moving_average(data::Vector{<:Real}, window::Int; alpha=nothing)

Calculate exponential moving average with specified window size.
"""
function exponential_moving_average(data::Vector{<:Real}, window::Int; alpha=nothing)
    n = length(data)
    result = zeros(n)
    
    # Default alpha based on window size
    if alpha === nothing
        alpha = 2.0 / (window + 1)
    end
    
    # Initialize with first value
    result[1] = data[1]
    
    # Calculate EMA for the rest
    for i in 2:n
        result[i] = alpha * data[i] + (1 - alpha) * result[i-1]
    end
    
    return result
end

"""
    macd(data::Vector{<:Real}; fast_period=12, slow_period=26, signal_period=9)

Calculate MACD (Moving Average Convergence Divergence).
Returns MACD line, signal line, and histogram.
"""
function macd(data::Vector{<:Real}; fast_period=12, slow_period=26, signal_period=9)
    n = length(data)
    
    # Calculate fast and slow EMAs
    fast_ema = exponential_moving_average(data, fast_period)
    slow_ema = exponential_moving_average(data, slow_period)
    
    # Calculate MACD line
    macd_line = fast_ema .- slow_ema
    
    # Calculate signal line
    signal_line = exponential_moving_average(macd_line, signal_period)
    
    # Calculate histogram
    histogram = macd_line .- signal_line
    
    return macd_line, signal_line, histogram
end

"""
    relative_strength_index(data::Vector{<:Real}, period::Int=14)

Calculate Relative Strength Index (RSI).
"""
function relative_strength_index(data::Vector{<:Real}, period::Int=14)
    n = length(data)
    result = zeros(n)
    
    if n <= period + 1
        return result
    end
    
    # Calculate price changes
    changes = diff(data)
    
    # Separate gains and losses
    gains = max.(changes, 0)
    losses = abs.(min.(changes, 0))
    
    # Calculate initial averages
    avg_gain = sum(gains[1:period]) / period
    avg_loss = sum(losses[1:period]) / period
    
    # Calculate first RSI
    if avg_loss ≈ 0.0
        result[period+1] = 100.0
    else
        rs = avg_gain / avg_loss
        result[period+1] = 100.0 - (100.0 / (1.0 + rs))
    end
    
    # Calculate remaining RSIs
    for i in (period+2):n
        # Update averages
        avg_gain = (avg_gain * (period - 1) + gains[i-1]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i-1]) / period
        
        # Calculate RSI
        if avg_loss ≈ 0.0
            result[i] = 100.0
        else
            rs = avg_gain / avg_loss
            result[i] = 100.0 - (100.0 / (1.0 + rs))
        end
    end
    
    return result
end

"""
    bollinger_bands(data::Vector{<:Real}, period::Int=20, num_std::Float64=2.0)

Calculate Bollinger Bands.
Returns upper and lower bands.
"""
function bollinger_bands(data::Vector{<:Real}, period::Int=20, num_std::Float64=2.0)
    n = length(data)
    
    # Calculate SMA
    sma = simple_moving_average(data, period)
    
    # Calculate standard deviation
    std_dev = rolling_std(data, period)
    
    # Calculate bands
    upper_band = sma .+ (num_std .* std_dev)
    lower_band = sma .- (num_std .* std_dev)
    
    return upper_band, lower_band
end

"""
    average_true_range(high::Vector{<:Real}, low::Vector{<:Real}, close::Vector{<:Real}, period::Int=14)

Calculate Average True Range (ATR).
"""
function average_true_range(high::Vector{<:Real}, low::Vector{<:Real}, close::Vector{<:Real}, period::Int=14)
    n = length(high)
    atr = zeros(n)
    
    if n <= 1
        return atr
    end
    
    # Calculate true range
    tr = zeros(n)
    tr[1] = high[1] - low[1]  # First day TR is simply high - low
    
    for i in 2:n
        # True range is the greatest of:
        # 1. Current high - current low
        # 2. Abs(current high - previous close)
        # 3. Abs(current low - previous close)
        tr[i] = max(
            high[i] - low[i],
            abs(high[i] - close[i-1]),
            abs(low[i] - close[i-1])
        )
    end
    
    # First ATR is average of first n TRs
    if n >= period
        atr[period] = sum(tr[1:period]) / period
        
        # Calculate remaining ATRs
        for i in (period+1):n
            atr[i] = (atr[i-1] * (period - 1) + tr[i]) / period
        end
    end
    
    return atr
end

"""
    detect_changepoints(data::Vector{<:Real}, window_size::Int=50; method="cusum")

Detect change points in a time series.
"""
function detect_changepoints(data::Vector{<:Real}, window_size::Int=50; method="cusum")
    n = length(data)
    change_points = Int[]
    
    if method == "cusum"
        # CUSUM (Cumulative Sum) method
        threshold = 5.0 * std(data)  # Sensitivity parameter
        s_pos = zeros(n)
        s_neg = zeros(n)
        
        # Initialize with mean of first window
        μ_0 = mean(data[1:min(window_size, n)])
        
        for i in 2:n
            # Update positive and negative CUSUM
            s_pos[i] = max(0, s_pos[i-1] + (data[i] - μ_0 - 0.5))
            s_neg[i] = max(0, s_neg[i-1] + (μ_0 - data[i] - 0.5))
            
            # Check for change point
            if s_pos[i] > threshold || s_neg[i] > threshold
                push!(change_points, i)
                
                # Reset CUSUM
                s_pos[i] = 0
                s_neg[i] = 0
                
                # Update reference mean
                start_idx = max(1, i - window_size)
                μ_0 = mean(data[start_idx:i])
            end
        end
    elseif method == "pelt"
        # Implementation of PELT algorithm would go here
        # This requires more complex cost functions and is typically
        # provided by specialized packages
        error("PELT method not implemented in this basic version")
    end
    
    return change_points
end

"""
    spectral_analysis(data::Vector{<:Real}; normalize=true)

Perform spectral analysis to identify cycles in the time series.
"""
function spectral_analysis(data::Vector{<:Real}; normalize=true)
    n = length(data)
    
    # Remove mean if normalizing
    ts_data = normalize ? data .- mean(data) : copy(data)
    
    # Apply FFT
    fft_result = fft(ts_data)
    amplitudes = abs.(fft_result[1:div(n, 2) + 1])
    
    # Normalize amplitudes
    if normalize
        amplitudes ./= n
    end
    
    # First element is DC component (zero frequency)
    amplitudes[1] = 0
    
    # Calculate frequencies
    freqs = fftfreq(n)[1:div(n, 2) + 1]
    
    # Convert to periods
    periods = 1.0 ./ freqs[2:end]
    periods_amplitudes = amplitudes[2:end]
    
    # Find dominant cycles (local maxima)
    dominant_indices = findlocalmaxima(periods_amplitudes)
    dominant_periods = periods[dominant_indices]
    dominant_amplitudes = periods_amplitudes[dominant_indices]
    
    # Sort by amplitude (descending)
    sort_idx = sortperm(dominant_amplitudes, rev=true)
    
    return Dict(
        "periods" => dominant_periods[sort_idx],
        "amplitudes" => dominant_amplitudes[sort_idx],
        "raw_periods" => periods,
        "raw_amplitudes" => periods_amplitudes
    )
end

"""
    detect_turning_points(data::Vector{<:Real}; window_size=3)

Detect local maxima and minima (turning points) in a time series.
"""
function detect_turning_points(data::Vector{<:Real}; window_size=3)
    n = length(data)
    peaks = Int[]
    troughs = Int[]
    
    # Function requires at least 2*window_size + 1 points
    if n < 2*window_size + 1
        return Dict("peaks" => peaks, "troughs" => troughs)
    end
    
    # Detect peaks and troughs
    for i in (window_size+1):(n-window_size)
        is_peak = true
        is_trough = true
        
        for j in (i-window_size):(i+window_size)
            if j == i
                continue
            end
            
            if data[j] >= data[i]
                is_peak = false
            end
            
            if data[j] <= data[i]
                is_trough = false
            end
            
            # Early exit if neither peak nor trough
            if !is_peak && !is_trough
                break
            end
        end
        
        if is_peak
            push!(peaks, i)
        elseif is_trough
            push!(troughs, i)
        end
    end
    
    return Dict("peaks" => peaks, "troughs" => troughs)
end

"""
    rolling_std(data::Vector{<:Real}, window::Int)

Calculate rolling standard deviation.
"""
function rolling_std(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 1
        return zeros(n)
    end
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = std(window_data)
    end
    
    return result
end

"""
    rolling_mean(data::Vector{<:Real}, window::Int)

Calculate rolling mean.
"""
function rolling_mean(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 0
        return copy(data)
    end
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = mean(window_data)
    end
    
    return result
end

"""
    rolling_min(data::Vector{<:Real}, window::Int)

Calculate rolling minimum.
"""
function rolling_min(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = minimum(window_data)
    end
    
    return result
end

"""
    rolling_max(data::Vector{<:Real}, window::Int)

Calculate rolling maximum.
"""
function rolling_max(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = maximum(window_data)
    end
    
    return result
end

"""
    rolling_median(data::Vector{<:Real}, window::Int)

Calculate rolling median.
"""
function rolling_median(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = median(window_data)
    end
    
    return result
end

"""
    rolling_skewness(data::Vector{<:Real}, window::Int)

Calculate rolling skewness.
"""
function rolling_skewness(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 2
        return zeros(n)
    end
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        
        if length(window_data) >= 3
            # Calculate skewness
            μ = mean(window_data)
            σ = std(window_data)
            
            if σ > 0
                # Fisher's moment coefficient of skewness
                skew = sum((window_data .- μ).^3) / (length(window_data) * σ^3)
                result[i] = skew
            end
        end
    end
    
    return result
end

"""
    rolling_kurtosis(data::Vector{<:Real}, window::Int)

Calculate rolling kurtosis (excess kurtosis).
"""
function rolling_kurtosis(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 3
        return zeros(n)
    end
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        
        if length(window_data) >= 4
            # Calculate excess kurtosis
            μ = mean(window_data)
            σ = std(window_data)
            
            if σ > 0
                # Excess kurtosis (normal distribution has kurtosis of 3, excess of 0)
                kurt = sum((window_data .- μ).^4) / (length(window_data) * σ^4) - 3
                result[i] = kurt
            end
        end
    end
    
    return result
end

"""
    rolling_entropy(data::Vector{<:Real}, window::Int; bins=10)

Calculate rolling Shannon entropy.
"""
function rolling_entropy(data::Vector{<:Real}, window::Int; bins=10)
    n = length(data)
    result = zeros(n)
    
    if window <= 2
        return zeros(n)
    end
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        
        if length(window_data) >= 3
            # Create histogram
            edges = range(minimum(window_data), maximum(window_data), length=bins+1)
            counts = fit(Histogram, window_data, edges).weights
            
            # Calculate probabilities
            probs = counts ./ sum(counts)
            
            # Calculate entropy
            entropy = 0.0
            for p in probs
                if p > 0
                    entropy -= p * log2(p)
                end
            end
            
            result[i] = entropy
        end
    end
    
    return result
end

"""
    rolling_sample_entropy(data::Vector{<:Real}, window::Int; m=2, r=0.2)

Calculate rolling sample entropy.
"""
function rolling_sample_entropy(data::Vector{<:Real}, window::Int; m=2, r=0.2)
    n = length(data)
    result = zeros(n)
    
    if window <= m+1
        return zeros(n)
    end
    
    for i in window:n
        window_data = data[(i-window+1):i]
        
        # Normalize window data
        window_std = std(window_data)
        if window_std > 0
            normalized_data = (window_data .- mean(window_data)) ./ window_std
            result[i] = sample_entropy(normalized_data, m, r)
        end
    end
    
    return result
end

"""
    sample_entropy(data::Vector{<:Real}, m::Int=2, r::Float64=0.2)

Calculate sample entropy for a time series.
"""
function sample_entropy(data::Vector{<:Real}, m::Int=2, r::Float64=0.2)
    n = length(data)
    
    if n <= m+1
        return 0.0
    end
    
    # Count matches for templates of length m and m+1
    count_m = 0
    count_m_plus_1 = 0
    
    # Create templates of length m and m+1
    templates_m = [data[i:(i+m-1)] for i in 1:(n-m)]
    templates_m_plus_1 = [data[i:(i+m)] for i in 1:(n-m-1)]
    
    # Count matches for templates of length m
    for i in 1:(n-m)
        for j in (i+1):(n-m)
            # Check if templates match within tolerance r
            if maximum(abs.(templates_m[i] - templates_m[j])) <= r
                count_m += 1
            end
        end
    end
    
    # Count matches for templates of length m+1
    for i in 1:(n-m-1)
        for j in (i+1):(n-m-1)
            # Check if templates match within tolerance r
            if maximum(abs.(templates_m_plus_1[i] - templates_m_plus_1[j])) <= r
                count_m_plus_1 += 1
            end
        end
    end
    
    # Calculate probability of matches
    # Add tiny value to avoid division by zero
    prob_m = (count_m + 1e-10) / ((n-m) * (n-m-1) / 2)
    prob_m_plus_1 = (count_m_plus_1 + 1e-10) / ((n-m-1) * (n-m-2) / 2)
    
    # Calculate sample entropy
    return -log(prob_m_plus_1 / prob_m)
end

"""
    rolling_acf_lag(data::Vector{<:Real}, window::Int, lag::Int)

Calculate rolling autocorrelation at specified lag.
"""
function rolling_acf_lag(data::Vector{<:Real}, window::Int, lag::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= lag + 1
        return zeros(n)
    end
    
    for i in window:n
        window_data = data[(i-window+1):i]
        
        # Calculate autocorrelation at specified lag
        if length(window_data) > lag
            # Subtract mean
            centered = window_data .- mean(window_data)
            
            # Calculate autocovariance
            autocov = sum(centered[1:(end-lag)] .* centered[(lag+1):end])
            
            # Normalize by variance
            variance = sum(centered.^2)
            
            if variance > 0
                result[i] = autocov / variance
            end
        end
    end
    
    return result
end

"""
    autocorrelation_features(data::Vector{<:Real}; max_lag=10)

Calculate autocorrelation features for various lags.
"""
function autocorrelation_features(data::Vector{<:Real}; max_lag=10)
    # Calculate autocorrelation
    acf = autocor(data, 1:max_lag)
    
    # Find the lag with highest autocorrelation
    max_acf_idx = argmax(abs.(acf))
    max_acf_lag = max_acf_idx
    max_acf_value = acf[max_acf_idx]
    
    # Calculate sum of squared autocorrelations
    acf_sum_sq = sum(acf.^2)
    
    # Calculate the decay of autocorrelation
    acf_decay = abs(acf[1] / (acf[max_lag] + 1e-10))
    
    return Dict(
        "acf" => acf,
        "max_acf_lag" => max_acf_lag,
        "max_acf_value" => max_acf_value,
        "acf_sum_sq" => acf_sum_sq,
        "acf_decay" => acf_decay
    )
end

"""
    calculate_trend_strength(data::Vector{<:Real}, window::Int)

Calculate trend strength using linear regression.
"""
function calculate_trend_strength(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 2
        return zeros(n)
    end
    
    for i in window:n
        window_data = data[(i-window+1):i]
        x = collect(1:length(window_data))
        
        # Calculate linear regression
        x_mean = mean(x)
        y_mean = mean(window_data)
        
        numerator = sum((x .- x_mean) .* (window_data .- y_mean))
        denominator = sum((x .- x_mean).^2)
        
        if denominator > 0
            # Slope of linear regression
            slope = numerator / denominator
            
            # Calculate correlation coefficient for trend strength
            correlation = numerator / sqrt(denominator * sum((window_data .- y_mean).^2))
            
            # Use correlation as trend strength
            result[i] = correlation
        end
    end
    
    return result
end

"""
    calculate_momentum(data::Vector{<:Real}, window::Int)

Calculate momentum as rate of change.
"""
function calculate_momentum(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    for i in (window+1):n
        # Rate of change as percentage
        result[i] = (data[i] - data[i-window]) / data[i-window]
    end
    
    return result
end

"""
    rolling_quantile(data::Vector{<:Real}, window::Int, q::Float64)

Calculate rolling quantile.
"""
function rolling_quantile(data::Vector{<:Real}, window::Int, q::Float64)
    n = length(data)
    result = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        window_data = data[start_idx:i]
        result[i] = quantile(window_data, q)
    end
    
    return result
end

"""
    findlocalmaxima(data::Vector{<:Real})

Find indices of local maxima in a vector.
"""
function findlocalmaxima(data::Vector{<:Real})
    n = length(data)
    result = Int[]
    
    if n < 3
        return result
    end
    
    # Check first point
    if data[1] > data[2]
        push!(result, 1)
    end
    
    # Check interior points
    for i in 2:n-1
        if data[i] > data[i-1] && data[i] > data[i+1]
            push!(result, i)
        end
    end
    
    # Check last point
    if data[n] > data[n-1]
        push!(result, n)
    end
    
    return result
end

end # module 