module Utils

export formatCurrency, formatDateTime, validateJSON, retryWithBackoff,
       encodeHex, decodeHex, logMessage, LogLevel, printProgress

using Dates
using JSON3

"""
    LogLevel

Enumeration for log levels.
"""
@enum LogLevel begin
    DEBUG
    INFO
    WARNING
    ERROR
    CRITICAL
end

"""
    formatCurrency(amount::Number, currency::String="", decimals::Int=2)

Format a currency amount with proper decimals and symbol.

# Arguments
- `amount::Number`: The amount to format
- `currency::String=""`: Currency symbol
- `decimals::Int=2`: Number of decimal places

# Returns
- `String`: Formatted currency string
"""
function formatCurrency(amount::Number, currency::String="", decimals::Int=2)
    formatted = string(round(amount, digits=decimals))
    
    # Add thousand separators
    integer_part, decimal_part = split(formatted, '.')
    integer_part = reverse(join(["$(i > 1 && i % 3 == 1 ? "," : "")$(c)" for (i, c) in enumerate(reverse(integer_part))]))
    
    if length(decimal_part) < decimals
        decimal_part = decimal_part * "0"^(decimals - length(decimal_part))
    end
    
    result = "$integer_part.$decimal_part"
    
    if !isempty(currency)
        # Put currency symbol at appropriate position
        if currency in ["$", "£", "€", "¥"]
            result = "$currency$result"
        else
            result = "$result $currency"
        end
    end
    
    return result
end

"""
    formatDateTime(dt::DateTime, format::String="yyyy-mm-dd HH:MM:SS")

Format a DateTime object with specified format.

# Arguments
- `dt::DateTime`: The DateTime to format
- `format::String="yyyy-mm-dd HH:MM:SS"`: Output format

# Returns
- `String`: Formatted date/time string
"""
function formatDateTime(dt::DateTime, format::String="yyyy-mm-dd HH:MM:SS")
    return Dates.format(dt, format)
end

"""
    validateJSON(json_string::String)

Validate if a string is valid JSON.

# Arguments
- `json_string::String`: JSON string to validate

# Returns
- `Tuple{Bool, Union{Exception, Nothing}}`: (is_valid, error)
"""
function validateJSON(json_string::String)
    try
        JSON3.read(json_string)
        return (true, nothing)
    catch e
        return (false, e)
    end
end

"""
    retryWithBackoff(f::Function, max_retries::Int=3, initial_delay::Float64=1.0, backoff_factor::Float64=2.0)

Retry a function with exponential backoff.

# Arguments
- `f::Function`: Function to retry
- `max_retries::Int=3`: Maximum number of retries
- `initial_delay::Float64=1.0`: Initial delay in seconds
- `backoff_factor::Float64=2.0`: Factor by which to increase delay on each retry

# Returns
- Result of the function if successful, otherwise throws the last exception
"""
function retryWithBackoff(f::Function, max_retries::Int=3, initial_delay::Float64=1.0, backoff_factor::Float64=2.0)
    delay = initial_delay
    last_error = nothing
    
    for i in 0:max_retries
        try
            return f()
        catch e
            last_error = e
            if i == max_retries
                break
            end
            
            # Log the error and retry
            @info "Retry $(i+1)/$max_retries after error: $e"
            sleep(delay)
            delay *= backoff_factor
        end
    end
    
    throw(last_error)
end

"""
    encodeHex(data::Union{String, Vector{UInt8}})

Encode data as a hexadecimal string.

# Arguments
- `data::Union{String, Vector{UInt8}}`: Data to encode

# Returns
- `String`: Hexadecimal string prefixed with "0x"
"""
function encodeHex(data::Union{String, Vector{UInt8}})
    bytes = data isa String ? Vector{UInt8}(data) : data
    return "0x" * join(string(b, base=16, pad=2) for b in bytes)
end

"""
    decodeHex(hex_string::String)

Decode a hexadecimal string into bytes.

# Arguments
- `hex_string::String`: Hexadecimal string (with or without 0x prefix)

# Returns
- `Vector{UInt8}`: Decoded bytes
"""
function decodeHex(hex_string::String)
    # Remove 0x prefix if present
    if startswith(hex_string, "0x")
        hex_string = hex_string[3:end]
    end
    
    # Ensure even length
    if length(hex_string) % 2 != 0
        hex_string = "0" * hex_string
    end
    
    # Convert to bytes
    return map(i -> parse(UInt8, hex_string[i:i+1], base=16), 1:2:length(hex_string))
end

"""
    logMessage(level::LogLevel, message::String, context::Dict{String, Any}=Dict{String, Any}())

Log a message with specified level and context.

# Arguments
- `level::LogLevel`: Log level
- `message::String`: Log message
- `context::Dict{String, Any}=Dict{String, Any}()`: Additional context

# Returns
- `Nothing`
"""
function logMessage(level::LogLevel, message::String, context::Dict{String, Any}=Dict{String, Any}())
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    
    # Color-coded level
    level_str = if level == DEBUG
        "\e[90mDEBUG\e[0m"    # Gray
    elseif level == INFO
        "\e[32mINFO\e[0m"     # Green
    elseif level == WARNING
        "\e[33mWARNING\e[0m"  # Yellow
    elseif level == ERROR
        "\e[31mERROR\e[0m"    # Red
    elseif level == CRITICAL
        "\e[41;97mCRITICAL\e[0m" # White on red background
    end
    
    # Format the log entry
    log_entry = "[$timestamp] $level_str: $message"
    
    # Add context if provided
    if !isempty(context)
        context_str = join(["$key=$value" for (key, value) in context], ", ")
        log_entry *= " {$context_str}"
    end
    
    # Print to appropriate stream
    if level == DEBUG
        @debug log_entry
    elseif level == INFO
        @info log_entry
    elseif level == WARNING
        @warn log_entry
    elseif level == ERROR || level == CRITICAL
        @error log_entry
    end
    
    return nothing
end

"""
    printProgress(current::Int, total::Int, label::String="Progress", width::Int=50)

Print a progress bar to the console.

# Arguments
- `current::Int`: Current progress value
- `total::Int`: Total value
- `label::String="Progress"`: Label for the progress bar
- `width::Int=50`: Width of the progress bar

# Returns
- `Nothing`
"""
function printProgress(current::Int, total::Int, label::String="Progress", width::Int=50)
    percentage = round(current / total * 100, digits=1)
    filled_width = round(Int, width * current / total)
    bar = "["
    bar *= repeat("█", filled_width)
    bar *= repeat("░", width - filled_width)
    bar *= "]"
    
    # Use carriage return to overwrite previous line
    print("\r$label: $bar $current/$total ($percentage%)")
    if current == total
        println()  # New line when complete
    end
    
    return nothing
end

end # module 