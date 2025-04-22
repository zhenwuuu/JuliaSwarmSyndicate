"""
Fault tolerance module for JuliaOS swarm algorithms.

This module provides fault tolerance mechanisms for swarm algorithms.
"""
module SwarmFaultTolerance

export FaultTolerantSwarm, monitor_swarm, recover_swarm, checkpoint_swarm, restore_swarm

using Dates
using Random
using UUIDs
using Logging
using ..Swarms

"""
    FaultTolerantSwarm

Structure for managing fault-tolerant swarm operations.

# Fields
- `swarm_id::String`: ID of the managed swarm
- `checkpoint_interval::Int`: How often to checkpoint (in seconds)
- `max_failures::Int`: Maximum number of failures before giving up
- `failure_count::Dict{String, Int}`: Count of failures per agent
- `last_checkpoint::DateTime`: When the last checkpoint was taken
- `checkpoint_path::String`: Where to store checkpoints
"""
struct FaultTolerantSwarm
    swarm_id::String
    checkpoint_interval::Int
    max_failures::Int
    failure_count::Dict{String, Int}
    last_checkpoint::DateTime
    checkpoint_path::String
    
    function FaultTolerantSwarm(
        swarm_id::String;
        checkpoint_interval::Int = 60,
        max_failures::Int = 3,
        checkpoint_path::String = joinpath(tempdir(), "juliaos_swarm_checkpoints")
    )
        # Ensure checkpoint directory exists
        mkpath(checkpoint_path)
        
        new(
            swarm_id,
            checkpoint_interval,
            max_failures,
            Dict{String, Int}(),
            now(),
            checkpoint_path
        )
    end
end

"""
    monitor_swarm(ft_swarm::FaultTolerantSwarm; interval=5, callback=nothing)

Start monitoring a swarm for failures.

# Arguments
- `ft_swarm::FaultTolerantSwarm`: The fault-tolerant swarm to monitor
- `interval::Int`: Monitoring interval in seconds
- `callback::Function`: Optional callback for monitoring events

# Returns
- `Task`: The monitoring task
"""
function monitor_swarm(ft_swarm::FaultTolerantSwarm; interval=5, callback=nothing)
    swarm_id = ft_swarm.swarm_id
    
    # Create monitoring task
    task = @async begin
        @info "Starting fault tolerance monitoring for swarm $(swarm_id)"
        
        try
            while true
                # Get swarm status
                status_result = Swarms.getSwarmStatus(swarm_id)
                
                if !status_result["success"]
                    @warn "Failed to get status for swarm $(swarm_id): $(status_result["error"])"
                    sleep(interval)
                    continue
                end
                
                swarm_status = status_result["data"]
                
                # Check if swarm is running
                if swarm_status["status"] != "RUNNING"
                    @debug "Swarm $(swarm_id) is not running, status: $(swarm_status["status"])"
                    sleep(interval)
                    continue
                end
                
                # Check for agent failures
                swarm = Swarms.getSwarm(swarm_id)
                if swarm === nothing
                    @warn "Swarm $(swarm_id) not found"
                    sleep(interval)
                    continue
                end
                
                # Check each agent
                for agent_id in swarm.agent_ids
                    agent = nothing
                    try
                        agent = Agents.getAgent(agent_id)
                    catch e
                        @warn "Error getting agent $(agent_id)" exception=(e, catch_backtrace())
                    end
                    
                    if agent === nothing || get(agent, :status, "") != "active"
                        # Agent failure detected
                        @warn "Agent $(agent_id) failure detected"
                        
                        # Increment failure count
                        ft_swarm.failure_count[agent_id] = get(ft_swarm.failure_count, agent_id, 0) + 1
                        
                        # Check if max failures exceeded
                        if ft_swarm.failure_count[agent_id] > ft_swarm.max_failures
                            @error "Agent $(agent_id) exceeded maximum failures, removing from swarm"
                            
                            # Remove agent from swarm
                            remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
                            if !remove_result["success"]
                                @error "Failed to remove agent $(agent_id) from swarm: $(remove_result["error"])"
                            end
                            
                            # Notify callback
                            if callback !== nothing
                                callback(:agent_removed, agent_id, swarm_id)
                            end
                        else
                            # Try to recover agent
                            @info "Attempting to recover agent $(agent_id), failure $(ft_swarm.failure_count[agent_id])/$(ft_swarm.max_failures)"
                            
                            # Notify callback
                            if callback !== nothing
                                callback(:agent_recovery, agent_id, swarm_id)
                            end
                        end
                    else
                        # Agent is healthy, reset failure count
                        ft_swarm.failure_count[agent_id] = 0
                    end
                end
                
                # Check if checkpoint is needed
                if (now() - ft_swarm.last_checkpoint).value / 1000 >= ft_swarm.checkpoint_interval
                    @info "Creating checkpoint for swarm $(swarm_id)"
                    checkpoint_swarm(ft_swarm)
                    
                    # Notify callback
                    if callback !== nothing
                        callback(:checkpoint_created, nothing, swarm_id)
                    end
                end
                
                sleep(interval)
            end
        catch e
            @error "Fault tolerance monitoring failed" exception=(e, catch_backtrace())
        end
    end
    
    return task
end

"""
    recover_swarm(ft_swarm::FaultTolerantSwarm)

Attempt to recover a swarm from failures.

# Arguments
- `ft_swarm::FaultTolerantSwarm`: The fault-tolerant swarm to recover

# Returns
- `Dict`: Result of recovery operation
"""
function recover_swarm(ft_swarm::FaultTolerantSwarm)
    swarm_id = ft_swarm.swarm_id
    
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        # Swarm not found, try to restore from checkpoint
        @info "Swarm $(swarm_id) not found, attempting to restore from checkpoint"
        return restore_swarm(ft_swarm)
    end
    
    # Check swarm status
    if swarm.status == Swarms.ERROR
        @info "Swarm $(swarm_id) is in ERROR state, attempting to restart"
        
        # Try to stop swarm first
        stop_result = Swarms.stopSwarm(swarm_id)
        if !stop_result["success"]
            @warn "Failed to stop swarm $(swarm_id): $(stop_result["error"])"
        end
        
        # Wait a moment
        sleep(1)
        
        # Start swarm
        start_result = Swarms.startSwarm(swarm_id)
        if !start_result["success"]
            @error "Failed to restart swarm $(swarm_id): $(start_result["error"])"
            return Dict("success" => false, "error" => "Failed to restart swarm: $(start_result["error"])")
        end
        
        @info "Successfully restarted swarm $(swarm_id)"
        return Dict("success" => true, "message" => "Swarm restarted successfully")
    end
    
    # If swarm is already running, nothing to do
    if swarm.status == Swarms.RUNNING
        return Dict("success" => true, "message" => "Swarm is already running")
    end
    
    # Otherwise, try to start the swarm
    start_result = Swarms.startSwarm(swarm_id)
    if !start_result["success"]
        @error "Failed to start swarm $(swarm_id): $(start_result["error"])"
        return Dict("success" => false, "error" => "Failed to start swarm: $(start_result["error"])")
    end
    
    @info "Successfully started swarm $(swarm_id)"
    return Dict("success" => true, "message" => "Swarm started successfully")
end

"""
    checkpoint_swarm(ft_swarm::FaultTolerantSwarm)

Create a checkpoint of the swarm state.

# Arguments
- `ft_swarm::FaultTolerantSwarm`: The fault-tolerant swarm to checkpoint

# Returns
- `Dict`: Result of checkpoint operation
"""
function checkpoint_swarm(ft_swarm::FaultTolerantSwarm)
    swarm_id = ft_swarm.swarm_id
    
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $(swarm_id) not found")
    end
    
    # Create checkpoint filename
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    checkpoint_file = joinpath(ft_swarm.checkpoint_path, "$(swarm_id)_$(timestamp).checkpoint")
    
    # Serialize swarm state
    try
        # Get shared state and tasks
        shared_state = swarm.shared_state
        pending_tasks = swarm.pending_tasks
        assigned_tasks = swarm.assigned_tasks
        completed_tasks = swarm.completed_tasks
        
        # Create checkpoint data
        checkpoint_data = Dict(
            "swarm_id" => swarm_id,
            "timestamp" => string(now()),
            "status" => Int(swarm.status),
            "agent_ids" => swarm.agent_ids,
            "shared_state" => shared_state,
            "pending_tasks" => pending_tasks,
            "assigned_tasks" => assigned_tasks,
            "completed_tasks" => completed_tasks,
            "current_iteration" => swarm.current_iteration,
            "best_known_solution" => swarm.best_known_solution
        )
        
        # Write to file
        open(checkpoint_file, "w") do io
            JSON3.write(io, checkpoint_data)
        end
        
        # Update last checkpoint time
        ft_swarm.last_checkpoint = now()
        
        @info "Created checkpoint for swarm $(swarm_id) at $(checkpoint_file)"
        return Dict("success" => true, "checkpoint_file" => checkpoint_file)
    catch e
        @error "Failed to create checkpoint" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Failed to create checkpoint: $(string(e))")
    end
end

"""
    restore_swarm(ft_swarm::FaultTolerantSwarm; checkpoint_file=nothing)

Restore a swarm from a checkpoint.

# Arguments
- `ft_swarm::FaultTolerantSwarm`: The fault-tolerant swarm to restore
- `checkpoint_file::String`: Optional specific checkpoint file to restore from

# Returns
- `Dict`: Result of restore operation
"""
function restore_swarm(ft_swarm::FaultTolerantSwarm; checkpoint_file=nothing)
    swarm_id = ft_swarm.swarm_id
    
    # Find latest checkpoint if not specified
    if checkpoint_file === nothing
        checkpoints = filter(
            f -> startswith(basename(f), "$(swarm_id)_") && endswith(f, ".checkpoint"),
            readdir(ft_swarm.checkpoint_path, join=true)
        )
        
        if isempty(checkpoints)
            return Dict("success" => false, "error" => "No checkpoints found for swarm $(swarm_id)")
        end
        
        # Sort by modification time (newest first)
        sort!(checkpoints, by=mtime, rev=true)
        checkpoint_file = checkpoints[1]
    end
    
    # Load checkpoint
    try
        checkpoint_data = JSON3.read(open(checkpoint_file, "r"))
        
        # Check if swarm exists
        swarm = Swarms.getSwarm(swarm_id)
        if swarm === nothing
            @warn "Swarm $(swarm_id) not found, cannot restore from checkpoint"
            return Dict("success" => false, "error" => "Swarm not found")
        end
        
        # Restore shared state
        if haskey(checkpoint_data, "shared_state")
            swarm.shared_state = checkpoint_data["shared_state"]
        end
        
        # Restore tasks
        if haskey(checkpoint_data, "pending_tasks")
            swarm.pending_tasks = checkpoint_data["pending_tasks"]
        end
        
        if haskey(checkpoint_data, "assigned_tasks")
            swarm.assigned_tasks = checkpoint_data["assigned_tasks"]
        end
        
        if haskey(checkpoint_data, "completed_tasks")
            swarm.completed_tasks = checkpoint_data["completed_tasks"]
        end
        
        # Restore iteration and best solution
        if haskey(checkpoint_data, "current_iteration")
            swarm.current_iteration = checkpoint_data["current_iteration"]
        end
        
        if haskey(checkpoint_data, "best_known_solution")
            swarm.best_known_solution = checkpoint_data["best_known_solution"]
        end
        
        @info "Restored swarm $(swarm_id) from checkpoint $(checkpoint_file)"
        return Dict("success" => true, "message" => "Swarm restored successfully")
    catch e
        @error "Failed to restore from checkpoint" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Failed to restore from checkpoint: $(string(e))")
    end
end

end # module
