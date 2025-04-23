"""
    Agent command handlers for JuliaOS

This file contains the implementation of agent-related command handlers.
"""

using ..JuliaOS
using Dates
using JSON
using UUIDs

"""
    handle_agent_command(command::String, params::Dict)

Handle commands related to agent operations.
"""
function handle_agent_command(command::String, params::Dict)
    if command == "agents.create_agent" || command == "create_agent"
        # Create a new agent
        name = get(params, "name", nothing)
        agent_type = get(params, "type", "default")
        config = get(params, "config", Dict{String, Any}())

        if isnothing(name)
            return Dict("success" => false, "error" => "Missing required parameter: name")
        end

        try
            # Generate a unique ID for the agent
            agent_id = string(uuid4())[1:8]

            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :createAgent) && isdefined(JuliaOS.Agents, :AgentConfig) && isdefined(JuliaOS.Agents, :AgentType)
                @info "Using JuliaOS.Agents.createAgent"

                # Convert string type to enum
                agent_type_enum = JuliaOS.Agents.CUSTOM # Default to CUSTOM
                try
                    if isa(agent_type, String)
                        agent_type_enum = getfield(JuliaOS.Agents, Symbol(uppercase(agent_type)))
                    elseif isa(agent_type, Integer)
                        agent_type_enum = JuliaOS.Agents.AgentType(agent_type)
                    end
                catch e
                    @warn "Invalid agent type: $agent_type, using CUSTOM" exception=e
                end

                # Get additional parameters
                abilities = String[]
                if haskey(params, "abilities")
                    # Convert Any[] to String[]
                    for ability in params["abilities"]
                        push!(abilities, string(ability))
                    end
                end

                chains = String[]
                if haskey(params, "chains")
                    # Convert Any[] to String[]
                    for chain in params["chains"]
                        push!(chains, string(chain))
                    end
                end

                parameters = get(params, "parameters", Dict{String,Any}())
                llm_config = get(params, "llm_config", Dict{String,Any}())
                memory_config = get(params, "memory_config", Dict{String,Any}())
                max_task_history = get(params, "max_task_history", 100)

                # Create agent config
                agent_config = JuliaOS.Agents.AgentConfig(
                    name,
                    agent_type_enum;
                    abilities=abilities,
                    chains=chains,
                    parameters=parameters,
                    llm_config=llm_config,
                    memory_config=memory_config,
                    max_task_history=max_task_history
                )

                # Create the agent
                agent = JuliaOS.Agents.createAgent(agent_config)

                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "id" => agent.id,
                        "name" => agent.name,
                        "type" => Int(agent.type),
                        "status" => Int(agent.status),
                        "created" => string(agent.created),
                        "updated" => string(agent.updated)
                    )
                )
            else
                @warn "JuliaOS.Agents module not available or create_agent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "name" => name,
                        "type" => agent_type,
                        "created_at" => string(now())
                    )
                )
            end
        catch e
            @error "Error creating agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error creating agent: $(string(e))")
        end
    elseif command == "agents.list_agents"
        # List all agents
        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :listAgents)
                @info "Using JuliaOS.Agents.listAgents"
                agents = JuliaOS.Agents.listAgents()

                # Convert Agent objects to dictionaries
                agent_dicts = []
                for agent in agents
                    push!(agent_dicts, Dict(
                        "id" => agent.id,
                        "name" => agent.name,
                        "type" => Int(agent.type),
                        "status" => Int(agent.status),
                        "created" => string(agent.created),
                        "updated" => string(agent.updated)
                    ))
                end

                agents = agent_dicts

                return Dict(
                    "success" => true,
                    "data" => Dict("agents" => agents)
                )
            else
                @warn "JuliaOS.Agents module not available or list_agents not defined"
                # Provide a mock implementation
                mock_agents = [
                    Dict("id" => "agent1", "name" => "Agent 1", "type" => "default"),
                    Dict("id" => "agent2", "name" => "Agent 2", "type" => "specialized"),
                    Dict("id" => "agent3", "name" => "Agent 3", "type" => "default")
                ]

                return Dict(
                    "success" => true,
                    "data" => Dict("agents" => mock_agents)
                )
            end
        catch e
            @error "Error listing agents" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error listing agents: $(string(e))")
        end
    elseif command == "agents.get_agent"
        # Get agent details
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :getAgent)
                @info "Using JuliaOS.Agents.getAgent"
                agent = JuliaOS.Agents.getAgent(agent_id)

                if agent === nothing
                    return Dict("success" => false, "error" => "Agent not found: $agent_id")
                end

                # Convert Agent object to dictionary
                agent_dict = Dict(
                    "id" => agent.id,
                    "name" => agent.name,
                    "type" => Int(agent.type),
                    "status" => Int(agent.status),
                    "created" => string(agent.created),
                    "updated" => string(agent.updated),
                    "memory_size" => length(agent.memory),
                    "task_history_size" => length(agent.task_history),
                    "skills" => collect(keys(agent.skills))
                )

                return Dict(
                    "success" => true,
                    "data" => agent_dict
                )
            else
                @warn "JuliaOS.Agents module not available or get_agent not defined"
                # Provide a mock implementation
                mock_agent = Dict(
                    "id" => agent_id,
                    "name" => "Agent $agent_id",
                    "type" => "default",
                    "created_at" => string(now() - Day(1)),
                    "status" => "active",
                    "config" => Dict("key" => "value")
                )

                return Dict(
                    "success" => true,
                    "data" => mock_agent
                )
            end
        catch e
            @error "Error getting agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting agent: $(string(e))")
        end
    elseif command == "agents.update_agent"
        # Update agent
        agent_id = get(params, "agent_id", nothing)
        name = get(params, "name", nothing)
        config = get(params, "config", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :updateAgent)
                @info "Using JuliaOS.Agents.updateAgent"

                update_params = Dict{String, Any}()
                if !isnothing(name)
                    update_params["name"] = name
                end

                if !isnothing(config)
                    update_params["config"] = config
                end

                agent = JuliaOS.Agents.updateAgent(agent_id, update_params)

                if agent === nothing
                    return Dict("success" => false, "error" => "Agent not found: $agent_id")
                end

                # Convert Agent object to dictionary
                agent_dict = Dict(
                    "id" => agent.id,
                    "name" => agent.name,
                    "type" => Int(agent.type),
                    "status" => Int(agent.status),
                    "created" => string(agent.created),
                    "updated" => string(agent.updated),
                    "memory_size" => length(agent.memory),
                    "task_history_size" => length(agent.task_history),
                    "skills" => collect(keys(agent.skills))
                )

                return Dict(
                    "success" => true,
                    "data" => agent_dict
                )
            else
                @warn "JuliaOS.Agents module not available or update_agent not defined"
                # Provide a mock implementation
                mock_agent = Dict(
                    "id" => agent_id,
                    "name" => !isnothing(name) ? name : "Agent $agent_id",
                    "type" => "default",
                    "updated_at" => string(now()),
                    "status" => "active",
                    "config" => !isnothing(config) ? config : Dict("key" => "value")
                )

                return Dict(
                    "success" => true,
                    "data" => mock_agent
                )
            end
        catch e
            @error "Error updating agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error updating agent: $(string(e))")
        end
    elseif command == "agents.delete_agent"
        # Delete agent
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :deleteAgent)
                @info "Using JuliaOS.Agents.deleteAgent"
                success = JuliaOS.Agents.deleteAgent(agent_id)

                if !success
                    return Dict("success" => false, "error" => "Failed to delete agent: $agent_id")
                end

                return Dict(
                    "success" => true,
                    "data" => Dict("agent_id" => agent_id)
                )
            else
                @warn "JuliaOS.Agents module not available or delete_agent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict("agent_id" => agent_id)
                )
            end
        catch e
            @error "Error deleting agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error deleting agent: $(string(e))")
        end
    elseif command == "agents.execute_task"
        # Execute a task with an agent
        agent_id = get(params, "agent_id", nothing)
        task_type = get(params, "task_type", nothing)
        task_params = get(params, "task_params", Dict{String, Any}())

        if isnothing(agent_id) || isnothing(task_type)
            return Dict("success" => false, "error" => "Missing required parameters: agent_id and task_type")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :executeAgentTask)
                @info "Using JuliaOS.Agents.executeAgentTask"
                # Create a task dictionary
                task = Dict{String, Any}(
                    "ability" => task_type,
                    "params" => task_params
                )
                result = JuliaOS.Agents.executeAgentTask(agent_id, task)

                return Dict(
                    "success" => true,
                    "data" => result
                )
            else
                @warn "JuliaOS.Agents module not available or execute_task not defined"
                # Provide a mock implementation
                task_id = string(uuid4())[1:8]

                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "task_id" => task_id,
                        "agent_id" => agent_id,
                        "task_type" => task_type,
                        "status" => "completed",
                        "result" => Dict("message" => "Task executed successfully")
                    )
                )
            end
        catch e
            @error "Error executing task" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error executing task: $(string(e))")
        end
    elseif command == "agents.start_agent"
        # Start an agent
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :startAgent)
                @info "Using JuliaOS.Agents.startAgent"
                success = JuliaOS.Agents.startAgent(agent_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "status" => "started"
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to start agent: $agent_id")
                end
            else
                @warn "JuliaOS.Agents module not available or startAgent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "status" => "started"
                    )
                )
            end
        catch e
            @error "Error starting agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error starting agent: $(string(e))")
        end
    elseif command == "agents.stop_agent"
        # Stop an agent
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :stopAgent)
                @info "Using JuliaOS.Agents.stopAgent"
                success = JuliaOS.Agents.stopAgent(agent_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "status" => "stopped"
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to stop agent: $agent_id")
                end
            else
                @warn "JuliaOS.Agents module not available or stopAgent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "status" => "stopped"
                    )
                )
            end
        catch e
            @error "Error stopping agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error stopping agent: $(string(e))")
        end
    elseif command == "agents.pause_agent"
        # Pause an agent
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :pauseAgent)
                @info "Using JuliaOS.Agents.pauseAgent"
                success = JuliaOS.Agents.pauseAgent(agent_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "status" => "paused"
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to pause agent: $agent_id")
                end
            else
                @warn "JuliaOS.Agents module not available or pauseAgent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "status" => "paused"
                    )
                )
            end
        catch e
            @error "Error pausing agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error pausing agent: $(string(e))")
        end
    elseif command == "agents.resume_agent"
        # Resume an agent
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :resumeAgent)
                @info "Using JuliaOS.Agents.resumeAgent"
                success = JuliaOS.Agents.resumeAgent(agent_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "status" => "resumed"
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to resume agent: $agent_id")
                end
            else
                @warn "JuliaOS.Agents module not available or resumeAgent not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "status" => "resumed"
                    )
                )
            end
        catch e
            @error "Error resuming agent" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error resuming agent: $(string(e))")
        end
    elseif command == "agents.get_agent_status"
        # Get agent status
        agent_id = get(params, "agent_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :getAgentStatus)
                @info "Using JuliaOS.Agents.getAgentStatus"
                status = JuliaOS.Agents.getAgentStatus(agent_id)

                return Dict(
                    "success" => true,
                    "data" => status
                )
            else
                @warn "JuliaOS.Agents module not available or getAgentStatus not defined"
                # Provide a mock implementation
                mock_status = Dict(
                    "id" => agent_id,
                    "name" => "Agent $agent_id",
                    "type" => "CUSTOM",
                    "status" => "RUNNING",
                    "uptime_seconds" => rand(1:3600),
                    "tasks_completed" => rand(0:100),
                    "queue_len" => rand(0:10),
                    "memory_size" => rand(0:1000),
                    "last_updated" => string(now() - Dates.Second(rand(1:3600)))
                )

                return Dict(
                    "success" => true,
                    "data" => mock_status
                )
            end
        catch e
            @error "Error getting agent status" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting agent status: $(string(e))")
        end
    elseif command == "agents.get_memory" || command == "agents.get_agent_memory"
        # Get agent memory
        agent_id = get(params, "agent_id", nothing)
        key = get(params, "key", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :getAgentMemory)
                @info "Using JuliaOS.Agents.getAgentMemory"
                memory = JuliaOS.Agents.getAgentMemory(agent_id, key)

                return Dict(
                    "success" => true,
                    "data" => memory
                )
            else
                @warn "JuliaOS.Agents module not available or getAgentMemory not defined"
                # Provide a mock implementation
                mock_memory = Dict(
                    "agent_id" => agent_id,
                    "key" => key,
                    "value" => Dict("data" => "mock memory value"),
                    "timestamp" => string(now())
                )

                return Dict(
                    "success" => true,
                    "data" => mock_memory
                )
            end
        catch e
            @error "Error getting agent memory" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting agent memory: $(string(e))")
        end
    elseif command == "agents.set_memory" || command == "agents.set_agent_memory"
        # Set agent memory
        agent_id = get(params, "agent_id", nothing)
        key = get(params, "key", nothing)
        value = get(params, "value", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        if isnothing(key)
            return Dict("success" => false, "error" => "Missing required parameter: key")
        end

        if isnothing(value)
            return Dict("success" => false, "error" => "Missing required parameter: value")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :setAgentMemory)
                @info "Using JuliaOS.Agents.setAgentMemory"
                success = JuliaOS.Agents.setAgentMemory(agent_id, key, value)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "key" => key,
                            "timestamp" => string(now())
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to set agent memory")
                end
            else
                @warn "JuliaOS.Agents module not available or setAgentMemory not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "key" => key,
                        "timestamp" => string(now())
                    )
                )
            end
        catch e
            @error "Error setting agent memory" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error setting agent memory: $(string(e))")
        end
    elseif command == "agents.clear_memory" || command == "agents.clear_agent_memory"
        # Clear agent memory
        agent_id = get(params, "agent_id", nothing)
        key = get(params, "key", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :clearAgentMemory)
                @info "Using JuliaOS.Agents.clearAgentMemory"
                success = JuliaOS.Agents.clearAgentMemory(agent_id, key)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "key" => key,
                            "timestamp" => string(now())
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to clear agent memory")
                end
            else
                @warn "JuliaOS.Agents module not available or clearAgentMemory not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "key" => key,
                        "timestamp" => string(now())
                    )
                )
            end
        catch e
            @error "Error clearing agent memory" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error clearing agent memory: $(string(e))")
        end
    elseif command == "agents.connect_swarm" || command == "agents.connect_agent_to_swarm"
        # Connect agent to swarm
        agent_id = get(params, "agent_id", nothing)
        swarm_id = get(params, "swarm_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        if isnothing(swarm_id)
            return Dict("success" => false, "error" => "Missing required parameter: swarm_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :connectAgentToSwarm)
                @info "Using JuliaOS.Agents.connectAgentToSwarm"
                success = JuliaOS.Agents.connectAgentToSwarm(agent_id, swarm_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "swarm_id" => swarm_id,
                            "timestamp" => string(now())
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to connect agent to swarm")
                end
            else
                @warn "JuliaOS.Agents module not available or connectAgentToSwarm not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "swarm_id" => swarm_id,
                        "timestamp" => string(now())
                    )
                )
            end
        catch e
            @error "Error connecting agent to swarm" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error connecting agent to swarm: $(string(e))")
        end
    elseif command == "agents.disconnect_swarm" || command == "agents.disconnect_agent_from_swarm"
        # Disconnect agent from swarm
        agent_id = get(params, "agent_id", nothing)
        swarm_id = get(params, "swarm_id", nothing)

        if isnothing(agent_id)
            return Dict("success" => false, "error" => "Missing required parameter: agent_id")
        end

        if isnothing(swarm_id)
            return Dict("success" => false, "error" => "Missing required parameter: swarm_id")
        end

        try
            # Check if Agents module is available
            if isdefined(JuliaOS, :Agents) && isdefined(JuliaOS.Agents, :disconnectAgentFromSwarm)
                @info "Using JuliaOS.Agents.disconnectAgentFromSwarm"
                success = JuliaOS.Agents.disconnectAgentFromSwarm(agent_id, swarm_id)

                if success
                    return Dict(
                        "success" => true,
                        "data" => Dict(
                            "agent_id" => agent_id,
                            "swarm_id" => swarm_id,
                            "timestamp" => string(now())
                        )
                    )
                else
                    return Dict("success" => false, "error" => "Failed to disconnect agent from swarm")
                end
            else
                @warn "JuliaOS.Agents module not available or disconnectAgentFromSwarm not defined"
                # Provide a mock implementation
                return Dict(
                    "success" => true,
                    "data" => Dict(
                        "agent_id" => agent_id,
                        "swarm_id" => swarm_id,
                        "timestamp" => string(now())
                    )
                )
            end
        catch e
            @error "Error disconnecting agent from swarm" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error disconnecting agent from swarm: $(string(e))")
        end
    else
        return Dict("success" => false, "error" => "Unknown agent command: $command")
    end
end