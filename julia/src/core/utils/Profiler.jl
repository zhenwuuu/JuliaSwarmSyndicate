module Profiler

export initialize, start_profiling, stop_profiling, get_profile_data, analyze_profile
export ProfileData, ProfilerConfig, ProfilePoint, ResourceMetrics, OperationProfile
export memory_and_cpu_overhead, gc_overhead

using ..EnhancedErrors
using ..StructuredLogging
using ..EnhancedConfig
using ..Metrics

using Dates
using Statistics
using JSON
using Serialization
using FileWatching
using Profile

# Types of profiling
@enum ProfilerType begin
    CPU_TIME    # CPU time profiling
    MEMORY      # Memory allocation profiling
    GARBAGE_COLLECTION # GC overhead profiling
    IO_OPERATIONS # I/O operations profiling
    API_LATENCY # API latency profiling
    DATABASE    # Database operations profiling
    BLOCKCHAIN  # Blockchain operations profiling
end

"""
    ResourceMetrics

Structure representing resource usage at a point in time.
"""
struct ResourceMetrics
    timestamp::DateTime
    cpu_usage_percent::Float64
    memory_usage_bytes::Int64
    gc_pause_ms::Union{Float64, Nothing}
    thread_count::Int

    ResourceMetrics(;
        cpu_usage_percent::Float64=0.0,
        memory_usage_bytes::Int64=0,
        gc_pause_ms::Union{Float64, Nothing}=nothing,
        thread_count::Int=Threads.nthreads()
    ) = new(now(), cpu_usage_percent, memory_usage_bytes, gc_pause_ms, thread_count)
end

"""
    ProfilePoint

Structure representing a single profiling data point.
"""
struct ProfilePoint
    timestamp::DateTime
    operation::String
    phase::String
    metrics::ResourceMetrics
    duration_ms::Union{Float64, Nothing}
    metadata::Dict{String, Any}

    ProfilePoint(
        operation::String,
        phase::String,
        metrics::ResourceMetrics;
        duration_ms::Union{Float64, Nothing}=nothing,
        metadata::Dict{String, Any}=Dict{String, Any}()
    ) = new(now(), operation, phase, metrics, duration_ms, metadata)
end

"""
    OperationProfile

Structure representing profile data for a specific operation.
"""
struct OperationProfile
    operation::String
    start_time::DateTime
    end_time::Union{DateTime, Nothing}
    phases::Vector{String}
    data_points::Vector{ProfilePoint}
    summary::Dict{String, Any}

    OperationProfile(operation::String) = new(
        operation,
        now(),
        nothing,
        String[],
        ProfilePoint[],
        Dict{String, Any}()
    )
end

"""
    ProfilerConfig

Configuration for the profiler.
"""
mutable struct ProfilerConfig
    enabled::Bool
    sampling_interval_ms::Int
    max_profile_size::Int
    auto_save_profiles::Bool
    profile_save_path::String
    active_profiler_types::Set{ProfilerType}
    detailed_gc_stats::Bool
    memory_threshold_mb::Int
    cpu_threshold_percent::Int

    ProfilerConfig() = new(
        false,           # enabled
        1000,            # sampling_interval_ms
        10000,           # max_profile_size
        true,            # auto_save_profiles
        "profiles",      # profile_save_path
        Set([CPU_TIME, MEMORY, GARBAGE_COLLECTION]), # active_profiler_types
        false,           # detailed_gc_stats
        1024,            # memory_threshold_mb
        80               # cpu_threshold_percent
    )
end

"""
    ProfileData

Structure representing profile data for a run.
"""
mutable struct ProfileData
    id::String
    name::String
    start_time::DateTime
    end_time::Union{DateTime, Nothing}
    operation_profiles::Dict{String, OperationProfile}
    config::ProfilerConfig
    system_info::Dict{String, Any}
    julia_version::VersionNumber
    
    ProfileData(id::String, name::String, config::ProfilerConfig) = new(
        id,
        name,
        now(),
        nothing,
        Dict{String, OperationProfile}(),
        config,
        collect_system_info(),
        VERSION
    )
end

# Global state for profiler
mutable struct ProfilerState
    initialized::Bool
    config::ProfilerConfig
    active_profiles::Dict{String, ProfileData}
    background_tasks::Dict{String, Task}
    
    ProfilerState() = new(
        false,
        ProfilerConfig(),
        Dict{String, ProfileData}(),
        Dict{String, Task}()
    )
end

# Singleton instance of profiler state
const PROFILER_STATE = ProfilerState()

"""
    initialize(config=nothing)

Initialize the profiler with the given configuration.
"""
function initialize(config=nothing)
    if PROFILER_STATE.initialized
        return true
    end
    
    error_context = EnhancedErrors.with_error_context("Profiler", "initialize")
    
    log_context = StructuredLogging.LogContext(
        component="Profiler",
        operation="initialize"
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Configure the profiler
            profiler_config = PROFILER_STATE.config
            
            # Use configuration if provided
            if config !== nothing
                if haskey(config, "enabled")
                    profiler_config.enabled = config["enabled"]
                end
                
                if haskey(config, "sampling_interval_ms")
                    profiler_config.sampling_interval_ms = config["sampling_interval_ms"]
                end
                
                if haskey(config, "max_profile_size")
                    profiler_config.max_profile_size = config["max_profile_size"]
                end
                
                if haskey(config, "auto_save_profiles")
                    profiler_config.auto_save_profiles = config["auto_save_profiles"]
                end
                
                if haskey(config, "profile_save_path")
                    profiler_config.profile_save_path = config["profile_save_path"]
                end
                
                if haskey(config, "active_profiler_types")
                    profiler_config.active_profiler_types = parse_profiler_types(config["active_profiler_types"])
                end
                
                if haskey(config, "detailed_gc_stats")
                    profiler_config.detailed_gc_stats = config["detailed_gc_stats"]
                end
                
                if haskey(config, "memory_threshold_mb")
                    profiler_config.memory_threshold_mb = config["memory_threshold_mb"]
                end
                
                if haskey(config, "cpu_threshold_percent")
                    profiler_config.cpu_threshold_percent = config["cpu_threshold_percent"]
                end
            else
                # Try to load from EnhancedConfig
                try
                    if EnhancedConfig.has_key("profiler.enabled")
                        profiler_config.enabled = EnhancedConfig.get_value("profiler.enabled", false)
                    end
                    
                    if EnhancedConfig.has_key("profiler.sampling_interval_ms")
                        profiler_config.sampling_interval_ms = EnhancedConfig.get_value("profiler.sampling_interval_ms", 1000)
                    end
                    
                    if EnhancedConfig.has_key("profiler.max_profile_size")
                        profiler_config.max_profile_size = EnhancedConfig.get_value("profiler.max_profile_size", 10000)
                    end
                    
                    if EnhancedConfig.has_key("profiler.auto_save_profiles")
                        profiler_config.auto_save_profiles = EnhancedConfig.get_value("profiler.auto_save_profiles", true)
                    end
                    
                    if EnhancedConfig.has_key("profiler.profile_save_path")
                        profiler_config.profile_save_path = EnhancedConfig.get_value("profiler.profile_save_path", "profiles")
                    end
                    
                    if EnhancedConfig.has_key("profiler.active_profiler_types")
                        profiler_config.active_profiler_types = parse_profiler_types(
                            EnhancedConfig.get_value("profiler.active_profiler_types", 
                                                    ["CPU_TIME", "MEMORY", "GARBAGE_COLLECTION"])
                        )
                    end
                    
                    if EnhancedConfig.has_key("profiler.detailed_gc_stats")
                        profiler_config.detailed_gc_stats = EnhancedConfig.get_value("profiler.detailed_gc_stats", false)
                    end
                    
                    if EnhancedConfig.has_key("profiler.memory_threshold_mb")
                        profiler_config.memory_threshold_mb = EnhancedConfig.get_value("profiler.memory_threshold_mb", 1024)
                    end
                    
                    if EnhancedConfig.has_key("profiler.cpu_threshold_percent")
                        profiler_config.cpu_threshold_percent = EnhancedConfig.get_value("profiler.cpu_threshold_percent", 80)
                    end
                catch e
                    StructuredLogging.warn("Failed to load profiler configuration from EnhancedConfig",
                                          exception=e)
                end
            end
            
            # Create profile save directory if needed and if auto-save is enabled
            if profiler_config.auto_save_profiles && !isdir(profiler_config.profile_save_path)
                mkpath(profiler_config.profile_save_path)
            end
            
            # Initialize Julia's built-in profiler if CPU profiling is enabled
            if CPU_TIME in profiler_config.active_profiler_types
                Profile.init(n=10^6, delay=0.001)
            end
            
            # Set initialized flag
            PROFILER_STATE.initialized = true
            
            StructuredLogging.info("Profiler initialized",
                                  data=Dict(
                                      "enabled" => profiler_config.enabled,
                                      "sampling_interval_ms" => profiler_config.sampling_interval_ms,
                                      "active_profiler_types" => [string(t) for t in profiler_config.active_profiler_types]
                                  ))
            
            return true
        catch e
            StructuredLogging.error("Failed to initialize profiler",
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to initialize profiler",
                                                  e, context=error_context))
            end
            
            return false
        end
    end
end

"""
    parse_profiler_types(type_strings)

Parse profiler type strings into profiler type enum values.
"""
function parse_profiler_types(type_strings)
    result = Set{ProfilerType}()
    
    for type_str in type_strings
        upper_type = uppercase(string(type_str))
        
        if upper_type == "CPU_TIME"
            push!(result, CPU_TIME)
        elseif upper_type == "MEMORY"
            push!(result, MEMORY)
        elseif upper_type == "GARBAGE_COLLECTION"
            push!(result, GARBAGE_COLLECTION)
        elseif upper_type == "IO_OPERATIONS"
            push!(result, IO_OPERATIONS)
        elseif upper_type == "API_LATENCY"
            push!(result, API_LATENCY)
        elseif upper_type == "DATABASE"
            push!(result, DATABASE)
        elseif upper_type == "BLOCKCHAIN"
            push!(result, BLOCKCHAIN)
        elseif upper_type == "ALL"
            push!(result, CPU_TIME)
            push!(result, MEMORY)
            push!(result, GARBAGE_COLLECTION)
            push!(result, IO_OPERATIONS)
            push!(result, API_LATENCY)
            push!(result, DATABASE)
            push!(result, BLOCKCHAIN)
        else
            StructuredLogging.warn("Unknown profiler type: $type_str")
        end
    end
    
    return result
end

"""
    start_profiling(name::String; operations::Vector{String}=String[])

Start profiling with the given name and optional operations.
Returns a profile ID.
"""
function start_profiling(name::String; operations::Vector{String}=String[])
    if !PROFILER_STATE.initialized
        initialize()
    end
    
    if !PROFILER_STATE.config.enabled
        return nothing
    end
    
    error_context = EnhancedErrors.with_error_context("Profiler", "start_profiling",
                                                     metadata=Dict("name" => name))
    
    log_context = StructuredLogging.LogContext(
        component="Profiler",
        operation="start_profiling",
        metadata=Dict("name" => name)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Generate a unique ID for the profile
            profile_id = string(uuid4())
            
            # Create profile data
            profile_data = ProfileData(profile_id, name, PROFILER_STATE.config)
            
            # Initialize operations
            for operation in operations
                profile_data.operation_profiles[operation] = OperationProfile(operation)
            end
            
            # Store profile data
            PROFILER_STATE.active_profiles[profile_id] = profile_data
            
            # Start background profiling task
            task = @async background_profiling(profile_id)
            PROFILER_STATE.background_tasks[profile_id] = task
            
            # Start CPU profiling if enabled
            if CPU_TIME in PROFILER_STATE.config.active_profiler_types
                Profile.start()
            end
            
            StructuredLogging.info("Started profiling",
                                  data=Dict(
                                      "profile_id" => profile_id,
                                      "name" => name,
                                      "operations" => operations
                                  ))
            
            return profile_id
        catch e
            StructuredLogging.error("Failed to start profiling",
                                   data=Dict("name" => name),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to start profiling",
                                                  e, context=error_context))
            end
            
            return nothing
        end
    end
end

"""
    add_profile_point(profile_id::String, operation::String, phase::String;
                     duration_ms::Union{Float64, Nothing}=nothing,
                     metadata::Dict{String, Any}=Dict{String, Any}())

Add a profile point to the specified profile and operation.
"""
function add_profile_point(profile_id::String, operation::String, phase::String;
                          duration_ms::Union{Float64, Nothing}=nothing,
                          metadata::Dict{String, Any}=Dict{String, Any}())
    if !PROFILER_STATE.initialized || !PROFILER_STATE.config.enabled
        return nothing
    end
    
    # Check if profile exists
    if !haskey(PROFILER_STATE.active_profiles, profile_id)
        return nothing
    end
    
    profile = PROFILER_STATE.active_profiles[profile_id]
    
    # Create operation profile if it doesn't exist
    if !haskey(profile.operation_profiles, operation)
        profile.operation_profiles[operation] = OperationProfile(operation)
    end
    
    operation_profile = profile.operation_profiles[operation]
    
    # Add phase if not already in list
    if !(phase in operation_profile.phases)
        push!(operation_profile.phases, phase)
    end
    
    # Collect resource metrics
    metrics = collect_resource_metrics()
    
    # Create profile point
    point = ProfilePoint(operation, phase, metrics; 
                       duration_ms=duration_ms, 
                       metadata=metadata)
    
    # Add to operation profile
    push!(operation_profile.data_points, point)
    
    # Check if we need to trim the profile to stay within max size
    if length(operation_profile.data_points) > PROFILER_STATE.config.max_profile_size
        # Remove oldest points
        operation_profile.data_points = operation_profile.data_points[end-PROFILER_STATE.config.max_profile_size+1:end]
    end
    
    return point
end

"""
    background_profiling(profile_id::String)

Background task for continuous profiling.
"""
function background_profiling(profile_id::String)
    if !haskey(PROFILER_STATE.active_profiles, profile_id)
        return
    end
    
    profile = PROFILER_STATE.active_profiles[profile_id]
    
    log_context = StructuredLogging.LogContext(
        component="Profiler",
        operation="background_profiling",
        metadata=Dict("profile_id" => profile_id)
    )
    
    StructuredLogging.with_context(log_context) do
        try
            # Only profile CPU time in debug builds
            profile_cpu = CPU_TIME in PROFILER_STATE.config.active_profiler_types
            profile_memory = MEMORY in PROFILER_STATE.config.active_profiler_types
            profile_gc = GARBAGE_COLLECTION in PROFILER_STATE.config.active_profiler_types
            
            # Continuously collect profile data
            while haskey(PROFILER_STATE.active_profiles, profile_id)
                try
                    # Collect system metrics
                    metrics = collect_resource_metrics()
                    
                    # Add profile point for system metrics
                    point = ProfilePoint("system", "background", metrics)
                    
                    # Check for any operations that are active
                    for (op_name, op_profile) in profile.operation_profiles
                        if op_profile.end_time === nothing
                            # Add profile point for active operation
                            add_profile_point(profile_id, op_name, "active")
                        end
                    end
                    
                    # Record metrics for thresholds
                    if metrics.memory_usage_bytes > profile.config.memory_threshold_mb * 1024 * 1024
                        StructuredLogging.warn("Memory usage exceeded threshold",
                                              data=Dict(
                                                  "profile_id" => profile_id,
                                                  "memory_usage_mb" => metrics.memory_usage_bytes / (1024 * 1024),
                                                  "threshold_mb" => profile.config.memory_threshold_mb
                                              ))
                        
                        # Record metrics
                        Metrics.record_metric("profiler_memory_threshold_exceeded", 1, 
                                            labels=Dict(
                                                "profile_id" => profile_id,
                                                "profile_name" => profile.name
                                            ))
                    end
                    
                    if metrics.cpu_usage_percent > profile.config.cpu_threshold_percent
                        StructuredLogging.warn("CPU usage exceeded threshold",
                                              data=Dict(
                                                  "profile_id" => profile_id,
                                                  "cpu_usage_percent" => metrics.cpu_usage_percent,
                                                  "threshold_percent" => profile.config.cpu_threshold_percent
                                              ))
                        
                        # Record metrics
                        Metrics.record_metric("profiler_cpu_threshold_exceeded", 1, 
                                            labels=Dict(
                                                "profile_id" => profile_id,
                                                "profile_name" => profile.name
                                            ))
                    end
                catch e
                    StructuredLogging.error("Error during background profiling",
                                          data=Dict("profile_id" => profile_id),
                                          exception=e)
                end
                
                # Sleep for the configured interval
                sleep(profile.config.sampling_interval_ms / 1000)
            end
        catch e
            StructuredLogging.error("Background profiling task failed",
                                   data=Dict("profile_id" => profile_id),
                                   exception=e)
        end
    end
end

"""
    stop_profiling(profile_id::String)

Stop profiling for the given profile ID.
Returns the profile data.
"""
function stop_profiling(profile_id::String)
    if !PROFILER_STATE.initialized || !PROFILER_STATE.config.enabled
        return nothing
    end
    
    if !haskey(PROFILER_STATE.active_profiles, profile_id)
        return nothing
    end
    
    error_context = EnhancedErrors.with_error_context("Profiler", "stop_profiling",
                                                     metadata=Dict("profile_id" => profile_id))
    
    log_context = StructuredLogging.LogContext(
        component="Profiler",
        operation="stop_profiling",
        metadata=Dict("profile_id" => profile_id)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Get profile data
            profile = PROFILER_STATE.active_profiles[profile_id]
            
            # Stop CPU profiling if enabled
            if CPU_TIME in PROFILER_STATE.config.active_profiler_types
                Profile.stop()
            end
            
            # Mark profile as ended
            profile.end_time = now()
            
            # Mark all operations as ended
            for (_, op_profile) in profile.operation_profiles
                if op_profile.end_time === nothing
                    op_profile.end_time = now()
                end
            end
            
            # Remove from active profiles but keep the data
            delete!(PROFILER_STATE.active_profiles, profile_id)
            
            # Stop background task
            if haskey(PROFILER_STATE.background_tasks, profile_id)
                task = PROFILER_STATE.background_tasks[profile_id]
                if !istaskdone(task)
                    try
                        schedule(task, InterruptException(); error=true)
                    catch
                        # Ignore errors when interrupting the task
                    end
                end
                delete!(PROFILER_STATE.background_tasks, profile_id)
            end
            
            # Calculate summary statistics
            analyze_profile(profile)
            
            # Auto-save profile if enabled
            if PROFILER_STATE.config.auto_save_profiles
                save_profile(profile)
            end
            
            StructuredLogging.info("Stopped profiling",
                                  data=Dict(
                                      "profile_id" => profile_id,
                                      "duration_ms" => (profile.end_time - profile.start_time).value
                                  ))
            
            return profile
        catch e
            StructuredLogging.error("Failed to stop profiling",
                                   data=Dict("profile_id" => profile_id),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to stop profiling",
                                                  e, context=error_context))
            end
            
            return nothing
        end
    end
end

"""
    get_profile_data(profile_id::String)

Get the profile data for the given profile ID.
"""
function get_profile_data(profile_id::String)
    if !PROFILER_STATE.initialized
        return nothing
    end
    
    # Check active profiles first
    if haskey(PROFILER_STATE.active_profiles, profile_id)
        return PROFILER_STATE.active_profiles[profile_id]
    end
    
    # Try to load from file
    if PROFILER_STATE.config.auto_save_profiles
        try
            file_path = joinpath(PROFILER_STATE.config.profile_save_path, profile_id * ".profile")
            if isfile(file_path)
                return load_profile(file_path)
            end
        catch e
            StructuredLogging.error("Failed to load profile from file",
                                   data=Dict("profile_id" => profile_id),
                                   exception=e)
        end
    end
    
    return nothing
end

"""
    analyze_profile(profile::ProfileData)

Analyze profile data and generate summary statistics.
"""
function analyze_profile(profile::ProfileData)
    if isnothing(profile.end_time)
        profile.end_time = now()
    end
    
    total_duration_ms = (profile.end_time - profile.start_time).value
    
    # Calculate summary statistics
    for (op_name, op_profile) in profile.operation_profiles
        # Skip if no data points
        if isempty(op_profile.data_points)
            continue
        end
        
        # Set end time if not set
        if op_profile.end_time === nothing
            op_profile.end_time = profile.end_time
        end
        
        op_duration_ms = (op_profile.end_time - op_profile.start_time).value
        
        # Calculate per-phase statistics
        phase_stats = Dict{String, Dict{String, Any}}()
        
        for phase in op_profile.phases
            # Filter data points for this phase
            phase_points = filter(p -> p.phase == phase, op_profile.data_points)
            
            if isempty(phase_points)
                continue
            end
            
            # Calculate memory and CPU usage statistics
            memory_values = [p.metrics.memory_usage_bytes for p in phase_points]
            cpu_values = [p.metrics.cpu_usage_percent for p in phase_points]
            
            # Calculate duration statistics if available
            duration_values = filter(x -> x !== nothing, [p.duration_ms for p in phase_points])
            
            phase_stats[phase] = Dict{String, Any}(
                "count" => length(phase_points),
                "memory" => Dict{String, Any}(
                    "min" => minimum(memory_values),
                    "max" => maximum(memory_values),
                    "mean" => mean(memory_values),
                    "median" => median(memory_values),
                    "std" => std(memory_values, corrected=false)
                ),
                "cpu" => Dict{String, Any}(
                    "min" => minimum(cpu_values),
                    "max" => maximum(cpu_values),
                    "mean" => mean(cpu_values),
                    "median" => median(cpu_values),
                    "std" => std(cpu_values, corrected=false)
                )
            )
            
            if !isempty(duration_values)
                phase_stats[phase]["duration"] = Dict{String, Any}(
                    "min" => minimum(duration_values),
                    "max" => maximum(duration_values),
                    "mean" => mean(duration_values),
                    "median" => median(duration_values),
                    "std" => std(duration_values, corrected=false),
                    "total" => sum(duration_values)
                )
            end
            
            # Calculate GC statistics if available
            gc_values = filter(x -> x !== nothing, [p.metrics.gc_pause_ms for p in phase_points])
            if !isempty(gc_values)
                phase_stats[phase]["gc"] = Dict{String, Any}(
                    "min" => minimum(gc_values),
                    "max" => maximum(gc_values),
                    "mean" => mean(gc_values),
                    "median" => median(gc_values),
                    "std" => std(gc_values, corrected=false),
                    "total" => sum(gc_values)
                )
            end
        end
        
        # Calculate overall statistics
        all_memory_values = [p.metrics.memory_usage_bytes for p in op_profile.data_points]
        all_cpu_values = [p.metrics.cpu_usage_percent for p in op_profile.data_points]
        all_duration_values = filter(x -> x !== nothing, [p.duration_ms for p in op_profile.data_points])
        all_gc_values = filter(x -> x !== nothing, [p.metrics.gc_pause_ms for p in op_profile.data_points])
        
        # Set summary
        op_profile.summary = Dict{String, Any}(
            "operation" => op_name,
            "duration_ms" => op_duration_ms,
            "data_points" => length(op_profile.data_points),
            "phases" => phase_stats,
            "memory" => Dict{String, Any}(
                "min" => minimum(all_memory_values),
                "max" => maximum(all_memory_values),
                "mean" => mean(all_memory_values),
                "median" => median(all_memory_values),
                "std" => std(all_memory_values, corrected=false)
            ),
            "cpu" => Dict{String, Any}(
                "min" => minimum(all_cpu_values),
                "max" => maximum(all_cpu_values),
                "mean" => mean(all_cpu_values),
                "median" => median(all_cpu_values),
                "std" => std(all_cpu_values, corrected=false)
            )
        )
        
        if !isempty(all_duration_values)
            op_profile.summary["duration"] = Dict{String, Any}(
                "min" => minimum(all_duration_values),
                "max" => maximum(all_duration_values),
                "mean" => mean(all_duration_values),
                "median" => median(all_duration_values),
                "std" => std(all_duration_values, corrected=false),
                "total" => sum(all_duration_values)
            )
        end
        
        if !isempty(all_gc_values)
            op_profile.summary["gc"] = Dict{String, Any}(
                "min" => minimum(all_gc_values),
                "max" => maximum(all_gc_values),
                "mean" => mean(all_gc_values),
                "median" => median(all_gc_values),
                "std" => std(all_gc_values, corrected=false),
                "total" => sum(all_gc_values)
            )
        end
    end
    
    return profile
end

"""
    collect_resource_metrics()

Collect resource metrics for the current process.
"""
function collect_resource_metrics()
    # Collect CPU usage
    cpu_usage = 0.0
    try
        # This is platform-dependent and simplistic
        # In a real implementation, we would use a more robust method
        if Sys.islinux()
            # Linux: read /proc/stat
            stat1 = read("/proc/self/stat", String)
            parts1 = split(stat1)
            user_time1 = parse(Float64, parts1[14])
            system_time1 = parse(Float64, parts1[15])
            total_time1 = user_time1 + system_time1
            
            sleep(0.1)
            
            stat2 = read("/proc/self/stat", String)
            parts2 = split(stat2)
            user_time2 = parse(Float64, parts2[14])
            system_time2 = parse(Float64, parts2[15])
            total_time2 = user_time2 + system_time2
            
            cpu_usage = (total_time2 - total_time1) / 0.1 * 100
        else
            # For other platforms, use a simple approximation
            # This is not accurate but gives some indication
            gc_bytes = Sys.total_memory() - Sys.free_memory()
            cpu_usage = gc_bytes / Sys.total_memory() * 100
        end
    catch
        # Ignore errors and use default value
        cpu_usage = 0.0
    end
    
    # Collect memory usage
    memory_usage = 0
    try
        # Get memory usage from GC
        gc_stats = Base.gc_num()
        memory_usage = gc_stats.total_bytes
    catch
        # Ignore errors and use default value
        memory_usage = 0
    end
    
    # Collect GC pause time
    gc_pause = nothing
    try
        if PROFILER_STATE.config.detailed_gc_stats
            gc_stats = Base.gc_num()
            gc_pause = gc_stats.pause_time
        end
    catch
        # Ignore errors and use default value
        gc_pause = nothing
    end
    
    return ResourceMetrics(
        cpu_usage_percent=cpu_usage,
        memory_usage_bytes=memory_usage,
        gc_pause_ms=gc_pause
    )
end

"""
    collect_system_info()

Collect system information.
"""
function collect_system_info()
    info = Dict{String, Any}(
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "cpu_cores" => Sys.CPU_THREADS,
        "word_size" => Sys.WORD_SIZE,
        "gc_total_mem" => Sys.total_memory(),
        "gc_free_mem" => Sys.free_memory()
    )
    
    # Add git commit hash if available
    try
        git_commit = read(`git rev-parse HEAD`, String)
        info["git_commit"] = strip(git_commit)
    catch
        # Ignore if git is not available
    end
    
    return info
end

"""
    save_profile(profile::ProfileData)

Save profile data to a file.
"""
function save_profile(profile::ProfileData)
    if !PROFILER_STATE.config.auto_save_profiles
        return false
    end
    
    # Ensure the directory exists
    if !isdir(PROFILER_STATE.config.profile_save_path)
        mkpath(PROFILER_STATE.config.profile_save_path)
    end
    
    # Serialize to binary file
    file_path = joinpath(PROFILER_STATE.config.profile_save_path, profile.id * ".profile")
    try
        open(file_path, "w") do io
            serialize(io, profile)
        end
        
        # Also save a JSON summary
        json_path = joinpath(PROFILER_STATE.config.profile_save_path, profile.id * "_summary.json")
        open(json_path, "w") do io
            # Create a summary dictionary
            summary = Dict{String, Any}(
                "id" => profile.id,
                "name" => profile.name,
                "start_time" => string(profile.start_time),
                "end_time" => isnothing(profile.end_time) ? nothing : string(profile.end_time),
                "duration_ms" => isnothing(profile.end_time) ? nothing : (profile.end_time - profile.start_time).value,
                "operations" => Dict{String, Any}()
            )
            
            # Add operation summaries
            for (op_name, op_profile) in profile.operation_profiles
                summary["operations"][op_name] = op_profile.summary
            end
            
            # Add system info
            summary["system_info"] = profile.system_info
            
            # Write summary as JSON
            JSON.print(io, summary, 4)
        end
        
        StructuredLogging.debug("Profile saved",
                               data=Dict(
                                   "profile_id" => profile.id,
                                   "path" => file_path
                               ))
        
        return true
    catch e
        StructuredLogging.error("Failed to save profile",
                               data=Dict(
                                   "profile_id" => profile.id,
                                   "path" => file_path
                               ),
                               exception=e)
        return false
    end
end

"""
    load_profile(file_path::String)

Load profile data from a file.
"""
function load_profile(file_path::String)
    try
        open(file_path, "r") do io
            return deserialize(io)
        end
    catch e
        StructuredLogging.error("Failed to load profile",
                               data=Dict("path" => file_path),
                               exception=e)
        return nothing
    end
end

"""
    memory_and_cpu_overhead(operations::Vector{String}, iterations::Int=1000)

Measures the memory and CPU overhead of operations.
"""
function memory_and_cpu_overhead(operations::Vector{String}, iterations::Int=1000)
    if !PROFILER_STATE.initialized
        initialize()
    end
    
    # Start profiling
    profile_id = start_profiling("overhead_benchmark",
                                operations=operations)
    
    if profile_id === nothing
        return Dict{String, Any}(
            "success" => false,
            "error" => "Failed to start profiling"
        )
    end
    
    # Run operations
    results = Dict{String, Any}()
    
    for operation in operations
        # Run operation for warmup
        add_profile_point(profile_id, operation, "warmup")
        
        # Run operation for benchmark
        start_time = time()
        peak_memory = 0
        
        for i in 1:iterations
            # Add profile point for operation
            add_profile_point(profile_id, operation, "benchmark",
                            duration_ms=0.0,
                            metadata=Dict("iteration" => i))
            
            # Check memory usage
            gc_stats = Base.gc_num()
            peak_memory = max(peak_memory, gc_stats.total_bytes)
            
            # Small sleep to avoid overwhelming the system
            if i % 100 == 0
                sleep(0.001)
            end
        end
        
        end_time = time()
        elapsed_time = end_time - start_time
        
        # Add results
        results[operation] = Dict{String, Any}(
            "iterations" => iterations,
            "total_time_s" => elapsed_time,
            "time_per_iteration_ms" => (elapsed_time / iterations) * 1000,
            "peak_memory_mb" => peak_memory / (1024 * 1024)
        )
    end
    
    # Stop profiling
    profile = stop_profiling(profile_id)
    
    # Add profile summary
    if profile !== nothing
        for (op_name, op_profile) in profile.operation_profiles
            if haskey(results, op_name) && haskey(op_profile.summary, "memory") && haskey(op_profile.summary, "cpu")
                results[op_name]["avg_memory_mb"] = op_profile.summary["memory"]["mean"] / (1024 * 1024)
                results[op_name]["avg_cpu_percent"] = op_profile.summary["cpu"]["mean"]
            end
        end
        
        return Dict{String, Any}(
            "success" => true,
            "profile_id" => profile_id,
            "operations" => results
        )
    else
        return Dict{String, Any}(
            "success" => false,
            "error" => "Failed to complete profiling",
            "partial_results" => results
        )
    end
end

"""
    gc_overhead(operation::String, iterations::Int=100)

Measures the garbage collection overhead of an operation.
"""
function gc_overhead(operation::String, iterations::Int=100)
    if !PROFILER_STATE.initialized
        initialize()
    end
    
    # Start profiling
    profile_id = start_profiling("gc_overhead_benchmark",
                                operations=[operation])
    
    if profile_id === nothing
        return Dict{String, Any}(
            "success" => false,
            "error" => "Failed to start profiling"
        )
    end
    
    # Run operation for warmup
    add_profile_point(profile_id, operation, "warmup")
    
    # Get initial GC stats
    gc_stats_before = Base.gc_num()
    
    # Run operation for benchmark
    start_time = time()
    
    for i in 1:iterations
        # Add profile point for operation
        add_profile_point(profile_id, operation, "benchmark",
                         duration_ms=0.0,
                         metadata=Dict("iteration" => i))
        
        # Force GC every 10 iterations
        if i % 10 == 0
            GC.gc()
        end
    end
    
    end_time = time()
    elapsed_time = end_time - start_time
    
    # Get final GC stats
    gc_stats_after = Base.gc_num()
    
    # Calculate GC overhead
    gc_time = gc_stats_after.pause_time - gc_stats_before.pause_time
    gc_percentage = (gc_time / (elapsed_time * 1e9)) * 100  # Convert ns to s
    
    # Stop profiling
    profile = stop_profiling(profile_id)
    
    if profile !== nothing
        return Dict{String, Any}(
            "success" => true,
            "profile_id" => profile_id,
            "operation" => operation,
            "iterations" => iterations,
            "total_time_s" => elapsed_time,
            "gc_time_ms" => gc_time / 1e6,  # Convert ns to ms
            "gc_percentage" => gc_percentage,
            "gc_collections" => gc_stats_after.total_collections - gc_stats_before.total_collections
        )
    else
        return Dict{String, Any}(
            "success" => false,
            "error" => "Failed to complete profiling",
            "partial_results" => Dict{String, Any}(
                "operation" => operation,
                "iterations" => iterations,
                "total_time_s" => elapsed_time,
                "gc_time_ms" => gc_time / 1e6,
                "gc_percentage" => gc_percentage
            )
        )
    end
end

end # module
