module Decomposition

using Statistics
using LinearAlgebra
using StatsBase
using Loess
using Wavelets
using FFTW

export decompose, decompose_stl, decompose_wavelet, decompose_fourier
export extract_trend, extract_seasonality, extract_cycles

"""
    decompose(data::Vector{<:Real}; method="stl", period=nothing)

Decompose time series into trend, seasonality, and residual components.

# Arguments
- `data`: The time series vector to decompose
- `method`: Decomposition method. Options: "stl", "wavelet", "fourier"
- `period`: Seasonality period. If nothing, it will be automatically detected

# Returns
- A Dict with "trend", "seasonal", and "residual" components
"""
function decompose(data::Vector{<:Real}; method="stl", period=nothing)
    if method == "stl"
        return decompose_stl(data, period)
    elseif method == "wavelet"
        return decompose_wavelet(data)
    elseif method == "fourier"
        return decompose_fourier(data, period)
    else
        error("Unknown decomposition method: $method")
    end
end

"""
    decompose_stl(data::Vector{<:Real}, period=nothing)

Decompose time series using Seasonal-Trend decomposition using Loess (STL).
"""
function decompose_stl(data::Vector{<:Real}, period=nothing)
    # Auto-detect period if not provided
    if period === nothing
        period = detect_period(data)
    end
    
    n = length(data)
    
    # Ensure period is valid
    if period < 2
        # Default to no seasonality
        period = n
    end
    
    # Apply loess smoothing for trend
    trend = estimate_trend(data, Int(ceil(1.5 * period)))
    
    # Calculate seasonal component by removing trend
    detrended = data .- trend
    
    # Extract seasonality
    seasonal = zeros(n)
    if period < n ÷ 2
        # Create seasonal subseries
        for i in 1:period
            indices = i:period:n
            subseries = detrended[indices]
            # Smooth the subseries
            smoothed = loess_smooth(subseries, 0.2)
            seasonal[indices] = smoothed
        end
    end
    
    # Calculate residual
    residual = data .- trend .- seasonal
    
    return Dict(
        "trend" => trend,
        "seasonal" => seasonal,
        "residual" => residual
    )
end

"""
    decompose_wavelet(data::Vector{<:Real})

Decompose time series using wavelet transform.
"""
function decompose_wavelet(data::Vector{<:Real})
    # Pad data to power of 2 length for efficient wavelet transform
    n = length(data)
    n_power2 = 2^ceil(Int, log2(n))
    padded_data = vcat(data, zeros(n_power2 - n))
    
    # Apply wavelet transform
    wt = wavelet(padded_data, WT.db4)
    
    # Extract approximation coefficients (trend)
    level = 4
    trend_coeffs = wt.coefs[level]
    
    # Reconstruct trend
    trend_padded = iwt(trend_coeffs, WT.db4)
    trend = trend_padded[1:n]
    
    # Extract high-frequency noise from the first level
    noise_coeffs = wt.coefs[1]
    noise_padded = iwt(noise_coeffs, WT.db4)
    noise = noise_padded[1:n]
    
    # The rest is considered seasonality/cycles
    seasonal = data .- trend .- noise
    
    return Dict(
        "trend" => trend,
        "seasonal" => seasonal,
        "residual" => noise
    )
end

"""
    decompose_fourier(data::Vector{<:Real}, period=nothing)

Decompose time series using Fourier transform.
"""
function decompose_fourier(data::Vector{<:Real}, period=nothing)
    n = length(data)
    
    # Auto-detect period if not provided
    if period === nothing
        period = detect_period(data)
    end
    
    # Apply FFT
    fft_result = fft(data)
    freq = fftfreq(n)
    amplitude = abs.(fft_result)
    
    # Create trend by keeping only low-frequency components
    trend_threshold = 0.05  # Keep only 5% lowest frequencies for trend
    trend_mask = abs.(freq) .< trend_threshold
    trend_fft = copy(fft_result)
    trend_fft[.!trend_mask] .= 0
    trend = real(ifft(trend_fft))
    
    # Create seasonal by keeping frequencies around detected period
    seasonal_fft = copy(fft_result)
    
    if 2 <= period < n ÷ 2
        seasonal_freq = 1.0 / period
        seasonal_band = 0.02  # Width of frequency band to keep
        seasonal_mask = (abs.(abs.(freq) .- seasonal_freq) .< seasonal_band) .| 
                        (abs.(abs.(freq) .- (1.0 - seasonal_freq)) .< seasonal_band)
        
        seasonal_fft[.!seasonal_mask] .= 0
        # Also remove trend frequencies from seasonal
        seasonal_fft[trend_mask] .= 0
        seasonal = real(ifft(seasonal_fft))
    else
        seasonal = zeros(n)
    end
    
    # Residual is what remains
    residual = data .- trend .- seasonal
    
    return Dict(
        "trend" => trend,
        "seasonal" => seasonal,
        "residual" => residual
    )
end

"""
    detect_period(data::Vector{<:Real})

Detect main seasonality period in a time series using autocorrelation and FFT.
"""
function detect_period(data::Vector{<:Real})
    n = length(data)
    max_lag = min(n ÷ 2, 365)  # Cap at half the length or a year
    
    # Method 1: Autocorrelation
    acf = autocor(data, 1:max_lag)
    
    # Find peaks in ACF (ignoring lag 1)
    peaks = findlocalmaxima(acf[2:end])
    peaks = peaks .+ 1  # Adjust for 0-based indexing
    
    # Method 2: Fourier transform
    fft_result = abs.(fft(data .- mean(data)))
    freq = fftfreq(n)[2:n÷2]  # Ignore DC and mirror frequencies
    amp = fft_result[2:n÷2]
    
    # Find peaks in frequency domain
    peak_indices = findlocalmaxima(amp)
    peak_freqs = freq[peak_indices]
    periods_fft = round.(Int, 1 ./ peak_freqs)
    
    # Combine both methods
    if !isempty(peaks) && !isempty(periods_fft)
        # Find common periods between both methods
        common_periods = filter(p -> p in periods_fft, peaks)
        
        if !isempty(common_periods)
            return common_periods[1]
        else
            # If no common period, take strongest peak from ACF
            return peaks[1]
        end
    elseif !isempty(peaks)
        return peaks[1]
    elseif !isempty(periods_fft)
        # Get the period with highest amplitude
        max_amp_idx = argmax(amp[peak_indices])
        return periods_fft[max_amp_idx]
    else
        # Default: no clear seasonality
        return n
    end
end

"""
    estimate_trend(data::Vector{<:Real}, window_size::Int)

Estimate trend component using Loess smoothing.
"""
function estimate_trend(data::Vector{<:Real}, window_size::Int)
    n = length(data)
    
    # Ensure window size is valid
    window_size = max(3, min(window_size, n))
    
    return loess_smooth(data, window_size / n)
end

"""
    loess_smooth(data::Vector{<:Real}, span::Float64)

Apply Loess smoothing to a time series.
"""
function loess_smooth(data::Vector{<:Real}, span::Float64)
    n = length(data)
    x = collect(1:n)
    
    # Apply loess smoothing
    model = Loess.loess(x, data; span=span)
    smoothed = Loess.predict(model, x)
    
    return smoothed
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

"""
    extract_trend(data::Vector{<:Real}; window_size=nothing)

Extract trend component from time series using smoothing.
"""
function extract_trend(data::Vector{<:Real}; window_size=nothing)
    n = length(data)
    
    # Default window size based on data length
    if window_size === nothing
        window_size = max(5, n ÷ 10)
    end
    
    return estimate_trend(data, window_size)
end

"""
    extract_seasonality(data::Vector{<:Real}, period::Int)

Extract seasonality component with a known period.
"""
function extract_seasonality(data::Vector{<:Real}, period::Int)
    n = length(data)
    result = zeros(n)
    
    if period < 2 || period > n ÷ 2
        return result
    end
    
    # Remove trend first
    trend = extract_trend(data)
    detrended = data .- trend
    
    # Calculate average seasonal pattern
    season_pattern = zeros(period)
    counts = zeros(Int, period)
    
    for i in 1:n
        idx = mod1(i, period)
        season_pattern[idx] += detrended[i]
        counts[idx] += 1
    end
    
    # Average the pattern
    for i in 1:period
        if counts[i] > 0
            season_pattern[i] /= counts[i]
        end
    end
    
    # Apply pattern to result
    for i in 1:n
        idx = mod1(i, period)
        result[i] = season_pattern[idx]
    end
    
    return result
end

"""
    extract_cycles(data::Vector{<:Real}; min_period=2, max_period=nothing)

Extract cyclical components from time series using spectral analysis.
"""
function extract_cycles(data::Vector{<:Real}; min_period=2, max_period=nothing)
    n = length(data)
    
    if max_period === nothing
        max_period = n ÷ 2
    end
    
    # Compute FFT
    fft_result = fft(data .- mean(data))
    freq = fftfreq(n)
    
    # Create mask for cycle frequencies
    min_freq = 1.0 / max_period
    max_freq = 1.0 / min_period
    cycle_mask = (min_freq .<= abs.(freq) .<= max_freq)
    
    # Keep only cycle frequencies
    cycle_fft = copy(fft_result)
    cycle_fft[.!cycle_mask] .= 0
    
    # Inverse FFT to get cycles
    cycles = real(ifft(cycle_fft))
    
    return cycles
end

end # module 