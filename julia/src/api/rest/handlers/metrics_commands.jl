"""
    Metrics command handlers for JuliaOS

This file contains the implementation of metrics-related command handlers.
"""

"""
    handle_metrics_command(command::String, params::Dict)

Handle commands related to metrics.
"""
function handle_metrics_command(command::String, params::Dict)
    if command == "metrics.get_system_overview"
        # Get system overview metrics
        try
            metrics = Metrics.get_system_overview()
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting system overview metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting system overview metrics: $(string(e))")
        end
    elseif command == "metrics.get_realtime_metrics"
        # Get realtime metrics
        try
            metrics = Metrics.get_realtime_metrics()
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting realtime metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting realtime metrics: $(string(e))")
        end
    elseif command == "metrics.get_resource_usage"
        # Get resource usage metrics
        try
            metrics = Metrics.get_resource_usage()
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting resource usage metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting resource usage metrics: $(string(e))")
        end
    elseif command == "metrics.run_performance_test"
        # Run a performance test
        test_type = get(params, "test_type", "default")
        duration = get(params, "duration", 10)
        
        try
            result = Metrics.run_performance_test(test_type, duration)
            return Dict("success" => true, "data" => result)
        catch e
            @error "Error running performance test" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error running performance test: $(string(e))")
        end
    elseif command == "metrics.get_agent_metrics"
        # Get metrics for a specific agent
        agent_id = get(params, "agent_id", nothing)
        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing agent_id for get_agent_metrics")
        end
        
        try
            metrics = Metrics.get_agent_metrics(agent_id)
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting agent metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting agent metrics: $(string(e))")
        end
    elseif command == "metrics.get_swarm_metrics"
        # Get metrics for a specific swarm
        swarm_id = get(params, "swarm_id", nothing)
        if isnothing(swarm_id)
            return Dict("success" => false, "error" => "Missing swarm_id for get_swarm_metrics")
        end
        
        try
            metrics = Metrics.get_swarm_metrics(swarm_id)
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting swarm metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting swarm metrics: $(string(e))")
        end
    elseif command == "metrics.get_historical_metrics"
        # Get historical metrics
        metric_type = get(params, "metric_type", "system")
        start_time = get(params, "start_time", nothing)
        end_time = get(params, "end_time", nothing)
        
        if isnothing(start_time) || isnothing(end_time)
            return Dict("success" => false, "error" => "Missing start_time or end_time for get_historical_metrics")
        end
        
        try
            metrics = Metrics.get_historical_metrics(metric_type, start_time, end_time)
            return Dict("success" => true, "data" => metrics)
        catch e
            @error "Error getting historical metrics" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting historical metrics: $(string(e))")
        end
    else
        return Dict("success" => false, "error" => "Unknown metrics command: $command")
    end
end
