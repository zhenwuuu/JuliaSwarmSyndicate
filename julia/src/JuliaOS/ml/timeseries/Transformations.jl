module Transformations

using Statistics
using Dates
using DataFrames
using Impute
using StatsBase

export preprocess, normalize_data, standardize_data, log_transform
export difference, inverse_difference, smooth_series
export fill_missing_values, detect_outliers, replace_outliers
export moving_average_filter, binning, truncate_outliers
export box_cox_transform, inverse_box_cox_transform
export power_transform, inverse_power_transform
export fourier_features, lag_features, window_features

"""
    preprocess(data::Union{DataFrame,Vector{<:Real}}; fill_missing=true, normalization=true)

Preprocess time series data with common operations like filling missing values and normalization.
"""
function preprocess(data::Union{DataFrame,Vector{<:Real}}; 
                   fill_missing=true, 
                   normalization=true,
                   standardization=false,
                   log_transform=false,
                   difference_order=0,
                   outlier_removal=false,
                   outlier_threshold=3.0,
                   smooth=false,
                   smooth_window=3)
    
    # Create a copy to avoid modifying original data
    if isa(data, DataFrame)
        result = copy(data)
        
        # Process each numerical column
        for col in names(result)
            if eltype(result[!, col]) <: Real
                # Fill missing values
                if fill_missing
                    result[!, col] = fill_missing_values(result[!, col])
                end
                
                # Remove outliers
                if outlier_removal
                    result[!, col] = replace_outliers(result[!, col], threshold=outlier_threshold)
                end
                
                # Smooth series
                if smooth
                    result[!, col] = smooth_series(result[!, col], window=smooth_window)
                end
                
                # Apply differencing
                if difference_order > 0
                    result[!, Symbol("$(col)_diff")] = difference(result[!, col], order=difference_order)
                end
                
                # Apply transformations
                if log_transform
                    result[!, col] = log_transform(result[!, col])
                end
                
                # Apply normalization
                if normalization
                    result[!, col] = normalize_data(result[!, col])
                elseif standardization
                    result[!, col] = standardize_data(result[!, col])
                end
            end
        end
    else
        # Process vector data
        result = copy(data)
        
        # Fill missing values
        if fill_missing
            result = fill_missing_values(result)
        end
        
        # Remove outliers
        if outlier_removal
            result = replace_outliers(result, threshold=outlier_threshold)
        end
        
        # Smooth series
        if smooth
            result = smooth_series(result, window=smooth_window)
        end
        
        # Apply differencing
        if difference_order > 0
            result = difference(result, order=difference_order)
        end
        
        # Apply transformations
        if log_transform
            result = log_transform(result)
        end
        
        # Apply normalization
        if normalization
            result = normalize_data(result)
        elseif standardization
            result = standardize_data(result)
        end
    end
    
    return result
end

"""
    normalize_data(data::Vector{<:Real})

Normalize data to [0, 1] range.
"""
function normalize_data(data::Vector{<:Real})
    min_val = minimum(data)
    max_val = maximum(data)
    
    if max_val == min_val
        return zeros(length(data))
    end
    
    return (data .- min_val) ./ (max_val - min_val)
end

"""
    standardize_data(data::Vector{<:Real})

Standardize data to have zero mean and unit variance.
"""
function standardize_data(data::Vector{<:Real})
    μ = mean(data)
    σ = std(data)
    
    if σ == 0
        return zeros(length(data))
    end
    
    return (data .- μ) ./ σ
end

"""
    log_transform(data::Vector{<:Real})

Apply logarithmic transformation to data.
"""
function log_transform(data::Vector{<:Real})
    # Ensure data is positive
    min_val = minimum(data)
    
    if min_val <= 0
        offset = abs(min_val) + 1.0
        return log.(data .+ offset)
    else
        return log.(data)
    end
end

"""
    inverse_log_transform(data::Vector{<:Real}, original_min)

Inverse the logarithmic transformation.
"""
function inverse_log_transform(data::Vector{<:Real}, original_min)
    if original_min <= 0
        offset = abs(original_min) + 1.0
        return exp.(data) .- offset
    else
        return exp.(data)
    end
end

"""
    difference(data::Vector{<:Real}; order=1)

Apply differencing to time series data.
"""
function difference(data::Vector{<:Real}; order=1)
    if order <= 0
        return copy(data)
    end
    
    result = copy(data)
    
    for _ in 1:order
        result = diff(result)
    end
    
    return result
end

"""
    inverse_difference(diff_data::Vector{<:Real}, original_data::Vector{<:Real}; order=1)

Invert differencing operation using the original data.
"""
function inverse_difference(diff_data::Vector{<:Real}, original_data::Vector{<:Real}; order=1)
    if order <= 0
        return copy(diff_data)
    end
    
    n_diff = length(diff_data)
    n_orig = length(original_data)
    
    # We need at least 'order' values from original data
    if n_orig < order
        error("Original data must have at least 'order' values for inverse differencing")
    end
    
    result = zeros(n_diff + order)
    
    # Copy first 'order' values from original data
    result[1:order] = original_data[1:order]
    
    # Reconstruct the series
    for i in 1:n_diff
        result[i+order] = result[i+order-1] + diff_data[i]
    end
    
    return result[order+1:end]
end

"""
    smooth_series(data::Vector{<:Real}; window=3, method="mean")

Apply smoothing to time series data.
"""
function smooth_series(data::Vector{<:Real}; window=3, method="mean")
    n = length(data)
    result = copy(data)
    
    if window <= 1 || n <= 1
        return result
    end
    
    half_window = window ÷ 2
    
    for i in 1:n
        start_idx = max(1, i - half_window)
        end_idx = min(n, i + half_window)
        window_data = data[start_idx:end_idx]
        
        if method == "mean"
            result[i] = mean(window_data)
        elseif method == "median"
            result[i] = median(window_data)
        elseif method == "gaussian"
            # Gaussian weighted average
            weights = exp.(-((collect(start_idx:end_idx) .- i) ./ (window / 3)).^2 / 2)
            result[i] = sum(window_data .* weights) / sum(weights)
        else
            error("Unknown smoothing method: $method")
        end
    end
    
    return result
end

"""
    fill_missing_values(data::Vector; method="linear")

Fill missing values in time series data.
"""
function fill_missing_values(data::Vector; method="linear")
    if !any(ismissing.(data))
        return data
    end
    
    if method == "linear"
        return Impute.fill(data, Impute.Linear())
    elseif method == "mean"
        return Impute.fill(data, Impute.Mean())
    elseif method == "median"
        return Impute.fill(data, Impute.Median())
    elseif method == "knn"
        return Impute.fill(data, Impute.KNN(k=3))
    elseif method == "locf"
        return Impute.fill(data, Impute.LOCF()) # Last observation carried forward
    else
        error("Unknown imputation method: $method")
    end
end

"""
    detect_outliers(data::Vector{<:Real}; method="zscore", threshold=3.0)

Detect outliers in time series data.
"""
function detect_outliers(data::Vector{<:Real}; method="zscore", threshold=3.0)
    n = length(data)
    is_outlier = falses(n)
    
    if method == "zscore"
        # Z-score method
        μ = mean(data)
        σ = std(data)
        
        if σ > 0
            for i in 1:n
                z_score = abs(data[i] - μ) / σ
                is_outlier[i] = z_score > threshold
            end
        end
    elseif method == "iqr"
        # Interquartile range method
        q1 = quantile(data, 0.25)
        q3 = quantile(data, 0.75)
        iqr = q3 - q1
        lower_bound = q1 - threshold * iqr
        upper_bound = q3 + threshold * iqr
        
        for i in 1:n
            is_outlier[i] = data[i] < lower_bound || data[i] > upper_bound
        end
    else
        error("Unknown outlier detection method: $method")
    end
    
    return is_outlier
end

"""
    replace_outliers(data::Vector{<:Real}; method="median", threshold=3.0)

Replace outliers in time series data.
"""
function replace_outliers(data::Vector{<:Real}; method="median", threshold=3.0)
    result = copy(data)
    outliers = detect_outliers(data, method="zscore", threshold=threshold)
    
    if !any(outliers)
        return result
    end
    
    replacement_value = method == "median" ? median(data) : mean(data)
    
    result[outliers] .= replacement_value
    
    return result
end

"""
    moving_average_filter(data::Vector{<:Real}, window::Int)

Apply moving average filter to time series data.
"""
function moving_average_filter(data::Vector{<:Real}, window::Int)
    n = length(data)
    result = zeros(n)
    
    if window <= 1
        return copy(data)
    end
    
    for i in 1:n
        start_idx = max(1, i - window ÷ 2)
        end_idx = min(n, i + window ÷ 2)
        result[i] = mean(data[start_idx:end_idx])
    end
    
    return result
end

"""
    binning(data::Vector{<:Real}, num_bins::Int; method="equal_width")

Bin time series data into discrete values.
"""
function binning(data::Vector{<:Real}, num_bins::Int; method="equal_width")
    n = length(data)
    result = zeros(Int, n)
    
    if num_bins <= 1
        return ones(Int, n)
    end
    
    if method == "equal_width"
        min_val = minimum(data)
        max_val = maximum(data)
        bin_width = (max_val - min_val) / num_bins
        
        for i in 1:n
            bin = ceil(Int, (data[i] - min_val) / bin_width)
            result[i] = max(1, min(num_bins, bin))
        end
    elseif method == "equal_frequency"
        # Calculate quantiles for equal frequency binning
        quantiles = range(0, 1, length=num_bins+1)
        bin_edges = quantile(data, quantiles)
        
        for i in 1:n
            bin = findfirst(x -> data[i] <= x, bin_edges[2:end])
            if bin === nothing
                result[i] = num_bins
            else
                result[i] = bin
            end
        end
    else
        error("Unknown binning method: $method")
    end
    
    return result
end

"""
    truncate_outliers(data::Vector{<:Real}, lower_percentile::Float64, upper_percentile::Float64)

Truncate values outside the specified percentile range.
"""
function truncate_outliers(data::Vector{<:Real}, lower_percentile::Float64, upper_percentile::Float64)
    result = copy(data)
    
    # Calculate percentile thresholds
    lower_threshold = quantile(data, lower_percentile)
    upper_threshold = quantile(data, upper_percentile)
    
    # Truncate values
    for i in 1:length(result)
        if result[i] < lower_threshold
            result[i] = lower_threshold
        elseif result[i] > upper_threshold
            result[i] = upper_threshold
        end
    end
    
    return result
end

"""
    box_cox_transform(data::Vector{<:Real}, lambda::Union{Float64,Nothing}=nothing)

Apply Box-Cox transformation to make data more Gaussian.
"""
function box_cox_transform(data::Vector{<:Real}, lambda::Union{Float64,Nothing}=nothing)
    # Ensure data is positive
    min_val = minimum(data)
    
    if min_val <= 0
        offset = abs(min_val) + 1.0
        adjusted_data = data .+ offset
    else
        adjusted_data = copy(data)
        offset = 0.0
    end
    
    # Find optimal lambda if not provided
    if lambda === nothing
        # Simple grid search for lambda
        lambdas = range(-2, 2, length=100)
        best_lambda = 1.0
        best_normality = Inf
        
        for l in lambdas
            transformed = box_cox_transform(adjusted_data, l)
            # Measure deviation from normality using skewness
            skew = sum((transformed .- mean(transformed)).^3) / (length(transformed) * std(transformed)^3)
            if abs(skew) < best_normality
                best_normality = abs(skew)
                best_lambda = l
            end
        end
        
        lambda = best_lambda
    end
    
    # Apply transformation
    if abs(lambda) < 1e-10
        # Log transform when lambda is close to zero
        return log.(adjusted_data)
    else
        return (adjusted_data.^lambda .- 1) ./ lambda
    end
end

"""
    inverse_box_cox_transform(data::Vector{<:Real}, lambda::Float64, offset::Float64=0.0)

Invert Box-Cox transformation.
"""
function inverse_box_cox_transform(data::Vector{<:Real}, lambda::Float64, offset::Float64=0.0)
    if abs(lambda) < 1e-10
        # Inverse of log transform
        transformed = exp.(data)
    else
        transformed = (lambda .* data .+ 1).^(1/lambda)
    end
    
    # Apply offset correction if needed
    if offset != 0.0
        transformed = transformed .- offset
    end
    
    return transformed
end

"""
    power_transform(data::Vector{<:Real}, power::Float64)

Apply power transformation to data.
"""
function power_transform(data::Vector{<:Real}, power::Float64)
    # Ensure data is positive for negative powers
    if power < 0
        min_val = minimum(data)
        if min_val <= 0
            offset = abs(min_val) + 1.0
            return ((data .+ offset).^power)
        end
    end
    
    return data.^power
end

"""
    inverse_power_transform(data::Vector{<:Real}, power::Float64)

Invert power transformation.
"""
function inverse_power_transform(data::Vector{<:Real}, power::Float64)
    if abs(power) < 1e-10
        error("Cannot invert power transform with power = 0")
    end
    
    return data.^(1/power)
end

"""
    fourier_features(data::Vector{<:Real}, frequencies::Vector{<:Int})

Extract Fourier features from time series.
"""
function fourier_features(data::Vector{<:Real}, frequencies::Vector{<:Int})
    n = length(data)
    result = Dict{String, Vector{Float64}}()
    
    # Time indices (normalized to [0, 2π])
    t = collect(0:n-1) .* (2π/n)
    
    for freq in frequencies
        # Sine and cosine features
        result["sin_$freq"] = sin.(freq .* t)
        result["cos_$freq"] = cos.(freq .* t)
    end
    
    return result
end

"""
    lag_features(data::Vector{<:Real}, lags::Vector{<:Int})

Create lagged features from time series.
"""
function lag_features(data::Vector{<:Real}, lags::Vector{<:Int})
    n = length(data)
    result = Dict{String, Vector{Float64}}()
    
    for lag in lags
        if lag <= 0
            continue
        end
        
        lagged = Vector{Float64}(undef, n)
        lagged[1:lag] .= NaN  # First 'lag' values have no lag values
        lagged[lag+1:end] = data[1:end-lag]
        
        result["lag_$lag"] = lagged
    end
    
    return result
end

"""
    window_features(data::Vector{<:Real}, window_sizes::Vector{<:Int})

Extract window-based features from time series.
"""
function window_features(data::Vector{<:Real}, window_sizes::Vector{<:Int})
    result = Dict{String, Vector{Float64}}()
    
    for window in window_sizes
        # Mean feature
        result["mean_$window"] = smooth_series(data, window=window, method="mean")
        
        # Standard deviation feature
        stddev = zeros(length(data))
        for i in 1:length(data)
            start_idx = max(1, i - window + 1)
            window_data = data[start_idx:i]
            stddev[i] = std(window_data)
        end
        result["std_$window"] = stddev
        
        # Min and max features
        min_vals = zeros(length(data))
        max_vals = zeros(length(data))
        for i in 1:length(data)
            start_idx = max(1, i - window + 1)
            window_data = data[start_idx:i]
            min_vals[i] = minimum(window_data)
            max_vals[i] = maximum(window_data)
        end
        result["min_$window"] = min_vals
        result["max_$window"] = max_vals
    end
    
    return result
end

end # module 