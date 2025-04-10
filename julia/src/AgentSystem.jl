module AgentSystem

using JSON
using Dates
using Logging
using Random
using Statistics
using UUIDs
using ..SwarmManager # Import SwarmManager

# Include the SkillRegistry module
include("AgentSystem/SkillRegistry.jl")
using .SkillRegistry

export AgentConfig, AgentState, AgentSkill, AgentMessage
export create_agent, update_agent_status, handle_message, execute_skill
export register_skill, unregister_skill, get_agent_state, delete_agent
export start_agent!, stop_agent!, recover_agent!, cleanup_agent_resources!
export SwarmConfig, SwarmState, create_swarm, update_swarm_status
export broadcast_message, handle_swarm_message, get_swarm_state, delete_swarm
export add_agent_to_swarm, remove_agent_from_swarm, initialize

"""
    AgentConfig

Configuration for an agent instance.
"""
struct AgentConfig
    id::String
    name::String
    version::String
    agent_type::String
    capabilities::Vector{String}
    max_memory::Int
    max_skills::Int
    update_interval::Int
    network_configs::Dict{String, Dict{String, Any}}
    parameters::Dict{String, Any} # Additional configuration parameters
    llm_config::Dict{String, Any} # Configuration for LLM integration

    # Constructor with default values
    function AgentConfig(
        id::String,
        name::String,
        agent_type::String,
        capabilities::Vector{String} = String[],
        network_configs::Dict{String, Dict{String, Any}} = Dict{String, Dict{String, Any}}()
    )
        new(
            id,
            name,
            "1.0.0", # Default version
            agent_type,
            capabilities,
            1000, # Default max memory
            10,   # Default max skills
            60,   # Default update interval (seconds)
            network_configs,
            Dict{String, Any}(), # Default empty parameters
            Dict{String, Any}("model" => "gpt-3.5-turbo") # Default LLM config
        )
    end

    # Extended constructor to match what the server is trying to use
    function AgentConfig(
        id::String,
        name::String,
        version::String,
        agent_type::String,
        capabilities::Vector{String},
        max_memory::Int,
        max_skills::Int,
        update_interval::Int,
        network_configs::Dict{String, Dict{String, Any}}
    )
        new(
            id,
            name,
            version,
            agent_type,
            capabilities,
            max_memory,
            max_skills,
            update_interval,
            network_configs,
            Dict{String, Any}(), # Default empty parameters
            Dict{String, Any}("model" => "gpt-3.5-turbo") # Default LLM config
        )
    end

    # Keyword constructor for use with database loading
    function AgentConfig(;
        id::String,
        name::String,
        agent_type::String,
        version::String = "1.0.0",
        capabilities::Vector{String} = String[],
        networks::Vector{String} = String[],
        max_memory::Int = 1024,
        max_skills::Int = 10,
        update_interval::Int = 60,
        parameters::Dict{String, Any} = Dict{String, Any}(),
        network_configs::Dict{String, Dict{String, Any}} = Dict{String, Dict{String, Any}}(),
        llm_config::Dict{String, Any} = Dict{String, Any}("model" => "gpt-3.5-turbo")
    )
        # Convert networks to network_configs if provided
        if isempty(network_configs) && !isempty(networks)
            network_configs = Dict{String, Dict{String, Any}}(
                network => Dict{String, Any}("enabled" => true) for network in networks
            )
        end

        new(
            id,
            name,
            version,
            agent_type,
            capabilities,
            max_memory,
            max_skills,
            update_interval,
            network_configs,
            parameters,
            llm_config
        )
    end
end

"""
    AgentSkill

Represents a skill that an agent can execute.
"""
struct AgentSkill
    name::String
    description::String
    required_capabilities::Vector{String}
    execute_function_name::String # Name of the function to execute (will be looked up at runtime)
    validate_function_name::String # Name of the function to validate input (will be looked up at runtime)
    error_handler_name::String    # Name of the function to handle errors (will be looked up at runtime)
    parameters::Dict{String, Any} # Define skill parameters
    is_scheduled::Bool           # Whether this skill should be executed on a schedule
    is_message_handler::Bool     # Whether this skill can handle messages

    # Constructor with default values
    function AgentSkill(
        name::String,
        description::String,
        required_capabilities::Vector{String} = String[],
        execute_function_name::String = "default_execute",
        validate_function_name::String = "default_validate",
        error_handler_name::String = "default_error_handler",
        parameters::Dict{String, Any} = Dict{String, Any}(),
        is_scheduled::Bool = false,
        is_message_handler::Bool = false
    )
        new(
            name,
            description,
            required_capabilities,
            execute_function_name,
            validate_function_name,
            error_handler_name,
            parameters,
            is_scheduled,
            is_message_handler
        )
    end
end

"""
    AgentMessage

Represents a message that can be sent between agents.
"""
struct AgentMessage
    id::String
    sender_id::String
    receiver_id::String
    message_type::String
    content::Dict{String, Any}
    timestamp::DateTime
    priority::Int
    requires_response::Bool
    response_to::Union{String, Nothing}
    ttl::Int
    metadata::Dict{String, Any}

    # Constructor with default values
    function AgentMessage(
        sender_id::String,
        receiver_id::String,
        message_type::String,
        content::Dict{String, Any};
        priority::Int = 3,
        requires_response::Bool = false,
        response_to::Union{String, Nothing} = nothing,
        ttl::Int = 3600,
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
        # Generate a unique ID for the message
        id = string(UUIDs.uuid4())

        new(
            id,
            sender_id,
            receiver_id,
            message_type,
            content,
            now(),
            priority,
            requires_response,
            response_to,
            ttl,
            metadata
        )
    end
end

"""
    AgentState

Represents the current state of an agent.
"""
mutable struct AgentState
    config::AgentConfig
    memory::Dict{String, Any}
    skills::Dict{String, AgentSkill}
    connections::Dict{String, Any} # Network connections and integrations
    messages::Vector{AgentMessage} # Message queue
    created_at::DateTime
    last_update::DateTime
    last_execution::DateTime # Last time the agent executed a task
    status::String # e.g., "initializing", "active", "inactive", "error"
    error_count::Int
    recovery_attempts::Int
    is_running::Bool # Whether the agent is currently running
    metrics::Dict{String, Any} # Performance metrics
    swarm_id::Union{String, Nothing} # ID of the swarm this agent belongs to, if any

    function AgentState(config::AgentConfig)
        new(
            config,
            Dict{String, Any}(), # Initialize memory
            Dict{String, AgentSkill}(), # Initialize skills
            Dict{String, Any}(), # Initialize connections
            AgentMessage[], # Initialize message queue
            now(), # created_at
            now(), # last_update
            now(), # last_execution
            "initialized", # Initial status
            0, # error_count
            0, # recovery_attempts
            false, # is_running
            Dict{String, Any}("tasks_completed" => 0, "tasks_failed" => 0), # metrics
            nothing # swarm_id
        )
    end
end

"""
    AgentMessage

Represents a message between agents.
"""
struct AgentMessage
    id::String # Unique message ID
    sender_id::String
    receiver_id::String
    message_type::String
    content::Dict{String, Any}
    timestamp::DateTime
    priority::Int # 1 (highest) to 5 (lowest)
    requires_response::Bool
    response_to::Union{String, Nothing} # ID of the message this is a response to, if any
    ttl::Int # Time to live in seconds
    metadata::Dict{String, Any} # Additional metadata

    # Constructor is already defined above
end

"""
    SwarmState (AgentSystem)

Represents the current runtime state of a swarm managed by AgentSystem.
Holds the core Swarm object from SwarmManager.
"""
mutable struct SwarmState
    # config::SwarmConfig # Config is now inside SwarmObject
    swarm_object::SwarmManager.Swarm # Holds the object with config, algorithm, metrics etc.
    agent_ids::Vector{String} # Store IDs of agents belonging to the swarm
    messages::Vector{AgentMessage} # Shared message queue for the swarm
    decisions::Dict{String, Any} # Collective decisions made by the swarm
    last_update::DateTime
    last_execution::DateTime # Last time the swarm executed a task
    status::String # initialized, active, inactive, error
    is_running::Bool # Whether the swarm is currently running
    metrics::Dict{String, Any} # Performance metrics
    task_handle::Union{Task, Nothing} # Handle to the async task if running

    # Constructor now takes the Swarm object from SwarmManager
    function SwarmState(swarm_obj::SwarmManager.Swarm)
        new(
            swarm_obj,
            String[], # Initialize agent IDs
            AgentMessage[], # Initialize message queue
            Dict{String, Any}(), # Initialize decisions
            now(), # last_update
            now(), # last_execution
            "initialized", # status
            false, # is_running
            Dict{String, Any}("tasks_completed" => 0, "tasks_failed" => 0), # metrics
            nothing # task_handle
        )
    end
end

# Global registries for active runtime state (in-memory)
const ACTIVE_AGENTS = Dict{String, AgentState}()
const ACTIVE_SWARMS = Dict{String, SwarmState}()

"""
    initialize()

Initialize the AgentSystem runtime state.
Clears active agents and swarms.
"""
function initialize()
    empty!(ACTIVE_AGENTS)
    empty!(ACTIVE_SWARMS)
    @info "AgentSystem initialized. Cleared active agents and swarms."
end

"""
    create_agent(config::AgentConfig)

Create a new agent instance and store its state in memory.
Assumes the agent config/details are already saved in persistent storage (e.g., Storage.jl).
"""
function create_agent(config::AgentConfig)
    if haskey(ACTIVE_AGENTS, config.id)
        @warn "Agent $(config.id) already exists in active agents."
        return ACTIVE_AGENTS[config.id]
    end

    @info "Creating and activating agent: $(config.id) ($(config.name))"

    try
        # Create the agent state
        state = AgentState(config)
        state.status = "initialized" # Set initial status

        # Initialize memory with basic information
        state.memory["agent_info"] = Dict(
            "id" => config.id,
            "name" => config.name,
            "type" => config.agent_type,
            "version" => config.version,
            "capabilities" => config.capabilities,
            "created_at" => now()
        )

        # Initialize empty collections
        state.memory["messages"] = AgentMessage[]
        state.memory["observations"] = Dict{String, Any}[]
        state.memory["decisions"] = Dict{String, Any}[]
        state.memory["task_history"] = Dict{String, Any}[]
        state.memory["knowledge_base"] = Dict{String, Any}()

        # Initialize performance metrics
        state.metrics = Dict(
            "tasks_completed" => 0,
            "tasks_failed" => 0,
            "messages_processed" => 0,
            "errors" => 0,
            "average_response_time" => 0.0,
            "uptime" => 0.0,
            "memory_usage" => 0
        )

        # Register default skills based on agent type
        register_default_skills!(state)

        # Initialize connections based on network configs
        for (network, config) in state.config.network_configs
            initialize_network_connection!(state, network, config)
        end

        # Register agent in active memory
        ACTIVE_AGENTS[config.id] = state

        # Log creation event
        log_agent_event!(state, "created", "Agent created and initialized")

        return state # Return the runtime state
    catch e
        @error "Failed to create agent $(config.id): $e" exception=(e, catch_backtrace())
        return nothing
    end
end

# Helper function to initialize network connections
function initialize_network_connection!(state::AgentState, network::String, config::Dict{String, Any})
    @info "Initializing network connection for agent $(state.config.id): $network"

    try
        # Store connection configuration in the connections dictionary
        state.connections[network] = Dict(
            "config" => config,
            "status" => "initialized",
            "last_connected" => nothing,
            "error" => nothing
        )

        # Different initialization logic based on network type
        if network == "blockchain"
            # Initialize blockchain connection
            chain = get(config, "chain", "ethereum")
            state.connections[network]["chain"] = chain
            state.connections[network]["status"] = "connected"
            @info "Initialized blockchain connection for agent $(state.config.id): $chain"
        elseif network == "api"
            # Initialize API connection
            api_type = get(config, "type", "rest")
            state.connections[network]["api_type"] = api_type
            state.connections[network]["status"] = "connected"
            @info "Initialized API connection for agent $(state.config.id): $api_type"
        elseif network == "database"
            # Initialize database connection
            db_type = get(config, "type", "in_memory")
            state.connections[network]["db_type"] = db_type
            state.connections[network]["status"] = "connected"
            @info "Initialized database connection for agent $(state.config.id): $db_type"
        else
            # Generic connection initialization
            state.connections[network]["status"] = "connected"
            @info "Initialized generic connection for agent $(state.config.id): $network"
        end

        return true
    catch e
        @error "Failed to initialize network connection for agent $(state.config.id): $network" exception=(e, catch_backtrace())
        state.connections[network] = Dict(
            "config" => config,
            "status" => "error",
            "error" => string(e)
        )
        return false
    end
end

# Helper function to register default skills based on agent type
function register_default_skills!(state::AgentState)
    agent_type = lowercase(state.config.agent_type)

    # Register common skills for all agent types
    register_skill(state.config.id, AgentSkill(
        "status_report",
        "Generate a status report for the agent",
        ["basic"]
    ))

    # Register type-specific skills
    try
        if agent_type == "trading"
            register_skill(state.config.id, AgentSkill(
                "market_analysis",
                "Analyze market conditions and trends",
                ["trading", "analysis"],
                "execute_market_analysis",
                "validate_market_analysis",
                "handle_market_analysis_error",
                Dict("timeframe" => "1h", "indicators" => ["ma", "rsi"]),
                true, # scheduled
                false # not a message handler
            ))

            register_skill(state.config.id, AgentSkill(
                "execute_trade",
                "Execute a trade based on analysis",
                ["trading", "execution"],
                "execute_trade_function",
                "validate_trade_parameters",
                "handle_trade_error",
                Dict("max_slippage" => 0.01),
                false, # not scheduled
                false # not a message handler
            ))
        elseif agent_type == "arbitrage"
            register_skill(state.config.id, AgentSkill(
                "find_arbitrage",
                "Find arbitrage opportunities across exchanges or chains",
                ["arbitrage", "analysis"],
                "execute_arbitrage_finder",
                "validate_arbitrage_parameters",
                "handle_arbitrage_error",
                Dict("min_profit" => 0.005, "max_gas" => 100),
                true, # scheduled
                false # not a message handler
            ))
        elseif agent_type == "monitoring"
            register_skill(state.config.id, AgentSkill(
                "monitor_metrics",
                "Monitor system or market metrics",
                ["monitoring", "analysis"],
                "execute_monitoring",
                "validate_monitoring_parameters",
                "handle_monitoring_error",
                Dict("alert_threshold" => 0.1),
                true, # scheduled
                false # not a message handler
            ))
        elseif agent_type == "cross_chain_optimizer"
            # Register cross-chain optimization skills
            register_skill(state.config.id, AgentSkill(
                "optimize_cross_chain_routing",
                "Optimize routing of transactions across different blockchain networks",
                ["cross_chain", "optimization"],
                "execute_cross_chain_routing",
                "validate_cross_chain_parameters",
                "handle_cross_chain_error",
                Dict("min_savings" => 0.01, "max_time" => 60),
                true, # scheduled
                false # not a message handler
            ))

            register_skill(state.config.id, AgentSkill(
                "optimize_gas_fees",
                "Optimize gas fees across different blockchain networks",
                ["cross_chain", "gas_optimization"],
                "execute_gas_optimization",
                "validate_gas_parameters",
                "handle_gas_optimization_error",
                Dict("max_wait_time" => 300),
                true, # scheduled
                false # not a message handler
            ))

            register_skill(state.config.id, AgentSkill(
                "analyze_bridge_opportunities",
                "Analyze and identify optimal bridge opportunities across blockchain networks",
                ["cross_chain", "bridge_analysis"],
                "execute_bridge_analysis",
                "validate_bridge_parameters",
                "handle_bridge_analysis_error",
                Dict("min_liquidity" => 10000),
                true, # scheduled
                false # not a message handler
            ))
        elseif agent_type == "communication"
            register_skill(state.config.id, AgentSkill(
                "message_handler",
                "Handle incoming messages from other agents",
                ["communication"],
                "handle_incoming_message",
                "validate_message",
                "handle_message_error",
                Dict(),
                false, # not scheduled
                true   # is a message handler
            ))
        end
    catch e
        @warn "Failed to register default skills for agent $(state.config.id): $e"
    end
end

# Helper function to log agent events
function log_agent_event!(state::AgentState, event_type::String, description::String)
    timestamp = now()

    # Create event record
    event = Dict(
        "agent_id" => state.config.id,
        "event_type" => event_type,
        "description" => description,
        "timestamp" => timestamp
    )

    # Store in memory if we have an events array
    if !haskey(state.memory, "events")
        state.memory["events"] = Dict{String, Any}[]
    end
    push!(state.memory["events"], event)

    # Log to system log
    @info "Agent $(state.config.id) event: $event_type - $description"

    return event
end

"""
    update_agent_status(agent_id::String, new_status::String)

Update an agent's runtime status (e.g., "active", "inactive").
"""
function update_agent_status(agent_id::String, new_status::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @error "Agent $agent_id not found in active agents."
        return false
    end

    try
        agent_state = ACTIVE_AGENTS[agent_id]
        old_status = agent_state.status

        # Don't update if status is the same
        if old_status == new_status
            return true
        end

        # Update status and timestamps
        agent_state.status = new_status
        agent_state.last_update = now()

        # Log the status change
        log_agent_event!(agent_state, "status_change", "Status changed from '$old_status' to '$new_status'")

        # Perform actions based on the new status
        if new_status == "active" && !agent_state.is_running
            # Start the agent if it's not already running
            return start_agent!(agent_state)
        elseif new_status == "inactive" && agent_state.is_running
            # Stop the agent if it's running
            return stop_agent!(agent_state)
        elseif new_status == "error"
            # Increment error count
            agent_state.error_count += 1

            # Attempt recovery if error count is not too high
            if agent_state.error_count <= 3
                agent_state.recovery_attempts += 1
                @info "Attempting recovery for agent $agent_id (attempt $(agent_state.recovery_attempts))"
                return recover_agent!(agent_state)
            else
                @warn "Agent $agent_id has too many errors ($(agent_state.error_count)). Manual intervention required."
            end
        end

        return true
    catch e
        @error "Error updating agent $agent_id status: $e" exception=(e, catch_backtrace())
        return false
    end
end

"""
    delete_agent(agent_id::String)

Remove an agent from the active runtime registry.
Assumes the agent is already deleted from persistent storage.
"""
function delete_agent(agent_id::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @warn "Agent $agent_id not found in active agents registry for deletion."
        return false # Or indicate already deleted
    end

    try
        # Get the agent state
        agent_state = ACTIVE_AGENTS[agent_id]

        # Stop the agent if it's running
        if agent_state.is_running
            stop_agent!(agent_state)
        end

        # Clean up resources
        cleanup_agent_resources!(agent_state)

        # Remove from registry
        delete!(ACTIVE_AGENTS, agent_id)
        @info "Agent $agent_id removed from active registry."

        return true
    catch e
        @error "Error deleting agent $agent_id: $e" exception=(e, catch_backtrace())
        return false
    end
end

# Helper function to start an agent
function start_agent!(agent_state::AgentState)
    @info "Starting agent $(agent_state.config.id)"

    try
        # Don't start if already running
        if agent_state.is_running
            @info "Agent $(agent_state.config.id) is already running"
            return true
        end

        # Mark as running
        agent_state.is_running = true
        agent_state.status = "active"
        agent_state.last_update = now()

        # Log the event
        log_agent_event!(agent_state, "started", "Agent started")

        # Start a background task for the agent
        agent_state.task_handle = @async begin
            try
                run_agent_loop!(agent_state)
            catch e
                @error "Agent $(agent_state.config.id) task failed: $e" exception=(e, catch_backtrace())
                agent_state.is_running = false
                agent_state.status = "error"
                agent_state.error_count += 1
                log_agent_event!(agent_state, "error", "Agent task failed: $e")
            end
        end

        return true
    catch e
        @error "Failed to start agent $(agent_state.config.id): $e" exception=(e, catch_backtrace())
        agent_state.is_running = false
        agent_state.status = "error"
        agent_state.error_count += 1
        log_agent_event!(agent_state, "error", "Failed to start agent: $e")
        return false
    end
end

# Helper function to stop an agent
function stop_agent!(agent_state::AgentState)
    @info "Stopping agent $(agent_state.config.id)"

    try
        # Don't stop if not running
        if !agent_state.is_running
            @info "Agent $(agent_state.config.id) is not running"
            return true
        end

        # Mark as not running
        agent_state.is_running = false
        agent_state.status = "inactive"
        agent_state.last_update = now()

        # Log the event
        log_agent_event!(agent_state, "stopped", "Agent stopped")

        # The task will exit on its own when it checks is_running

        return true
    catch e
        @error "Failed to stop agent $(agent_state.config.id): $e" exception=(e, catch_backtrace())
        log_agent_event!(agent_state, "error", "Failed to stop agent: $e")
        return false
    end
end

# Helper function to recover an agent
function recover_agent!(agent_state::AgentState)
    @info "Recovering agent $(agent_state.config.id)"

    try
        # Stop the agent if it's running
        if agent_state.is_running
            stop_agent!(agent_state)
        end

        # Clean up resources
        cleanup_agent_resources!(agent_state)

        # Reset error count
        agent_state.error_count = 0

        # Start the agent again
        return start_agent!(agent_state)
    catch e
        @error "Failed to recover agent $(agent_state.config.id): $e" exception=(e, catch_backtrace())
        log_agent_event!(agent_state, "error", "Failed to recover agent: $e")
        return false
    end
end

# Helper function to clean up agent resources
function cleanup_agent_resources!(agent_state::AgentState)
    @info "Cleaning up resources for agent $(agent_state.config.id)"

    try
        # Close any open connections
        for (network, connection) in agent_state.connections
            if get(connection, "status", "") == "connected"
                @info "Closing connection to $network for agent $(agent_state.config.id)"
                connection["status"] = "disconnected"
            end
        end

        # Clear message queue
        empty!(agent_state.messages)

        # Log the event
        log_agent_event!(agent_state, "cleanup", "Agent resources cleaned up")

        return true
    catch e
        @error "Failed to clean up resources for agent $(agent_state.config.id): $e" exception=(e, catch_backtrace())
        return false
    end
end

# Helper function to run the agent's main loop
function run_agent_loop!(agent_state::AgentState)
    @info "Agent $(agent_state.config.id) main loop started"

    # Initialize agent metrics if not already present
    if !haskey(agent_state.memory, "metrics")
        agent_state.memory["metrics"] = Dict(
            "messages_processed" => 0,
            "tasks_completed" => 0,
            "tasks_failed" => 0,
            "uptime" => 0.0
        )
    end

    # Log agent startup
    log_agent_event!(agent_state, "running", "Agent main loop is running")

    # Run until stopped
    start_time = now()
    while agent_state.is_running
        try
            # Update last execution time
            agent_state.last_execution = now()

            # Update uptime metric
            if haskey(agent_state.memory, "metrics")
                agent_state.memory["metrics"]["uptime"] = (now() - start_time).value / 1000.0  # in seconds
            end

            # Process messages (if the function exists)
            if @isdefined process_agent_messages!
                process_agent_messages!(agent_state)
            end

            # Execute scheduled skills (if the function exists)
            if @isdefined execute_scheduled_skills!
                execute_scheduled_skills!(agent_state)
            else
                # Fallback: Execute a simple status update
                agent_state.status = "active"
                agent_state.last_update = now()
            end

            # Sleep for a bit to avoid consuming too much CPU
            sleep(agent_state.config.update_interval)
        catch e
            @error "Error in agent $(agent_state.config.id) main loop: $e" exception=(e, catch_backtrace())
            agent_state.error_count += 1
            log_agent_event!(agent_state, "error", "Error in main loop: $e")

            # If too many errors, stop the agent
            if agent_state.error_count > 10
                @warn "Too many errors in agent $(agent_state.config.id) main loop. Stopping agent."
                agent_state.is_running = false
                agent_state.status = "error"
                log_agent_event!(agent_state, "stopped", "Agent stopped due to too many errors")
                break
            end

            # Sleep for a bit before retrying
            sleep(5)
        end
    end

    @info "Agent $(agent_state.config.id) main loop ended"
end

# Helper functions for processing messages and executing skills
function process_agent_messages!(agent_state::AgentState)
    # Process messages in the agent's message queue
    if !isempty(agent_state.messages)
        @info "Processing $(length(agent_state.messages)) messages for agent $(agent_state.config.id)"

        # Process messages in order of priority
        sort!(agent_state.messages, by = m -> m.priority)

        # Process up to 10 messages at a time to avoid blocking too long
        message_count = min(10, length(agent_state.messages))

        for i in 1:message_count
            message = popfirst!(agent_state.messages)

            # Skip expired messages
            if (now() - message.timestamp).value > message.ttl
                @info "Skipping expired message $(message.id) for agent $(agent_state.config.id)"
                continue
            end

            # Find a skill that can handle this message type
            handled = false
            for (skill_name, skill) in agent_state.skills
                if skill.is_message_handler
                    try
                        # Execute the skill with the message
                        result = execute_skill(agent_state.config.id, skill_name, message)
                        if result !== nothing
                            handled = true
                            agent_state.metrics["messages_processed"] += 1
                            break
                        end
                    catch e
                        @error "Error handling message with skill $skill_name: $e" exception=(e, catch_backtrace())
                    end
                end
            end

            if !handled
                @warn "No skill could handle message $(message.id) of type $(message.message_type) for agent $(agent_state.config.id)"
            end
        end
    end
end

function execute_scheduled_skills!(agent_state::AgentState)
    # Execute scheduled skills
    for (skill_name, skill) in agent_state.skills
        if skill.is_scheduled
            try
                # Check if it's time to execute
                last_execution_key = "last_$(skill_name)_execution"
                if !haskey(agent_state.memory, last_execution_key) ||
                   (now() - agent_state.memory[last_execution_key]).value >= agent_state.config.update_interval

                    @info "Executing scheduled skill $skill_name for agent $(agent_state.config.id)"

                    # Execute the skill
                    result = execute_skill(agent_state.config.id, skill_name)

                    # Update last execution time
                    agent_state.memory[last_execution_key] = now()

                    # Update metrics
                    if result !== nothing
                        agent_state.metrics["tasks_completed"] += 1
                    end
                end
            catch e
                @error "Error executing scheduled skill $skill_name: $e" exception=(e, catch_backtrace())
                agent_state.metrics["tasks_failed"] += 1
            end
        end
    end
end

"""
    handle_message(agent_id::String, message::AgentMessage)

Handle an incoming message for an agent (basic implementation).
"""
function handle_message(agent_id::String, message::AgentMessage)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @error "Agent $agent_id not found for message handling."
        return Dict("status" => "error", "error" => "Agent not found")
    end

    try
        agent_state = ACTIVE_AGENTS[agent_id]
        @info "Agent $agent_id received message type '$(message.message_type)' from $(message.sender_id)."

        # Record start time for performance tracking
        start_time = now()

        # Add message to the agent's message queue
        push!(agent_state.messages, message)

        # If the agent is not running, start processing immediately
        # Otherwise, the message will be processed in the agent's main loop
        if !agent_state.is_running
            @info "Agent $agent_id is not running. Processing message immediately."
            result = process_single_message!(agent_state, message)
            return result
        else
            # If the message requires immediate response, process it now
            if message.priority == 1 || message.requires_response
                @info "Processing high-priority message immediately for agent $agent_id."
                result = process_single_message!(agent_state, message)
                return result
            else
                # Otherwise, let the agent's main loop handle it
                @info "Message queued for agent $agent_id. Will be processed in main loop."
                return Dict(
                    "status" => "queued",
                    "agent_id" => agent_id,
                    "message_id" => message.id,
                    "timestamp" => now(),
                    "queue_position" => length(agent_state.messages)
                )
            end
        end
    catch e
        @error "Error handling message for agent $agent_id: $e" exception=(e, catch_backtrace())
        return Dict(
            "status" => "error",
            "error" => string(e),
            "agent_id" => agent_id,
            "message_id" => message.id,
            "timestamp" => now()
        )
    end
end

# Helper function to process a single message
function process_single_message!(agent_state::AgentState, message::AgentMessage)
    # Record start time for performance tracking
    start_time = now()

    # Find a skill that can handle this message type
    handled = false
    result = Dict(
        "status" => "error",
        "error" => "No handler found",
        "agent_id" => agent_state.config.id,
        "message_id" => message.id,
        "timestamp" => now()
    )

    for (skill_name, skill) in agent_state.skills
        if skill.is_message_handler
            try
                # Execute the skill with the message
                skill_result = execute_skill(agent_state.config.id, skill_name, message)
                if skill_result !== nothing
                    handled = true
                    result = skill_result
                    agent_state.metrics["messages_processed"] += 1
                    break
                end
            catch e
                @error "Error handling message with skill $skill_name: $e" exception=(e, catch_backtrace())
            end
        end
    end

    if !handled
        @warn "No skill could handle message $(message.id) of type $(message.message_type) for agent $(agent_state.config.id)"
    end

    # Log the message handling event
    log_agent_event!(agent_state, "message_processed", "Processed message of type '$(message.message_type)' from $(message.sender_id)")

    # Update agent's last update timestamp
    agent_state.last_update = now()

    # Calculate and update response time metrics
    response_time = (now() - start_time).value / 1000.0  # in seconds
    current_avg = agent_state.metrics["average_response_time"]
    msg_count = agent_state.metrics["messages_processed"]

    # Update running average
    if msg_count > 1
        new_avg = ((current_avg * (msg_count - 1)) + response_time) / msg_count
        agent_state.metrics["average_response_time"] = new_avg
    else
        agent_state.metrics["average_response_time"] = response_time
    end

    return result
end

# Helper function to process messages based on their type
function process_message_by_type(agent::AgentState, message::AgentMessage)
    message_type = lowercase(message.message_type)

    # Basic response structure
    response = Dict(
        "status" => "processed",
        "agent_id" => agent.config.id,
        "message_id" => message.id,
        "timestamp" => now(),
        "message_type" => message.message_type
    )

    try
        if message_type == "command"
            # Process command messages
            if isa(message.content, Dict) && haskey(message.content, "command")
                command = message.content["command"]
                params = get(message.content, "params", Dict())

                # Execute the command
                command_result = execute_command(agent, command, params)
                response["result"] = command_result
                response["command"] = command
            else
                response["status"] = "error"
                response["error"] = "Invalid command format"
            end

        elseif message_type == "query"
            # Process query messages
            if isa(message.content, Dict) && haskey(message.content, "query")
                query = message.content["query"]
                params = get(message.content, "params", Dict())

                # Execute the query
                query_result = execute_query(agent, query, params)
                response["result"] = query_result
                response["query"] = query
            else
                response["status"] = "error"
                response["error"] = "Invalid query format"
            end

        elseif message_type == "notification"
            # Process notification messages
            response["status"] = "acknowledged"

            # Store notification in a dedicated section
            if !haskey(agent.memory, "notifications")
                agent.memory["notifications"] = []
            end
            push!(agent.memory["notifications"], Dict(
                "timestamp" => now(),
                "content" => message.content,
                "sender" => message.sender_id
            ))

        elseif message_type == "data"
            # Process data messages
            if isa(message.content, Dict) && haskey(message.content, "data_type")
                data_type = message.content["data_type"]
                data = get(message.content, "data", nothing)

                # Process the data
                process_result = process_data(agent, data_type, data)
                response["result"] = process_result
                response["data_type"] = data_type
            else
                response["status"] = "error"
                response["error"] = "Invalid data format"
            end

        else
            # Default handling for unknown message types
            response["status"] = "received"
            response["message_content_preview"] = first(string(message.content), 50)
        end
    catch e
        # Handle any errors during message processing
        @error "Error processing message: $e" exception=(e, catch_backtrace())
        response["status"] = "error"
        response["error"] = "Internal error: $(typeof(e))"

        # Update error metrics
        if haskey(agent.memory, "metrics")
            agent.memory["metrics"]["errors"] += 1
        end
    end

    return response
end

# Helper function to execute agent commands
function execute_command(agent::AgentState, command::String, params::Dict)
    command = lowercase(command)

    if command == "status"
        # Return agent status information
        return Dict(
            "status" => agent.status,
            "uptime" => (now() - agent.created_at).value / 1000.0,  # in seconds
            "last_update" => agent.last_update,
            "metrics" => get(agent.memory, "metrics", Dict())
        )

    elseif command == "execute_skill"
        # Execute a specific skill
        if haskey(params, "skill_name")
            skill_name = params["skill_name"]
            skill_params = get(params, "params", Dict())
            return execute_skill(agent.config.id, skill_name, skill_params)
        else
            return Dict("error" => "Missing skill_name parameter")
        end

    elseif command == "update_config"
        # Update agent configuration
        # This would typically involve more validation and persistence
        for (key, value) in params
            # Update only allowed configuration parameters
            if key in ["update_interval", "max_memory", "max_skills"]
                # This is a simplified example - real implementation would be more robust
                # agent.config[key] = value  # Would need proper setters for immutable struct
            end
        end
        return Dict("result" => "Configuration updated")

    else
        return Dict("error" => "Unknown command: $command")
    end
end

# Helper function to execute agent queries
function execute_query(agent::AgentState, query::String, params::Dict)
    query = lowercase(query)

    if query == "skills"
        # Return list of agent skills
        return Dict("skills" => collect(keys(agent.skills)))

    elseif query == "memory"
        # Return specific memory section if specified
        if haskey(params, "section")
            section = params["section"]
            if haskey(agent.memory, section)
                return Dict(section => agent.memory[section])
            else
                return Dict("error" => "Memory section not found: $section")
            end
        else
            # Return summary of memory sections
            return Dict("memory_sections" => collect(keys(agent.memory)))
        end

    elseif query == "messages"
        # Return recent messages, optionally filtered
        messages = get(agent.memory, "messages", AgentMessage[])
        limit = get(params, "limit", 10)

        # Apply filters if specified
        if haskey(params, "sender")
            messages = filter(m -> m.sender_id == params["sender"], messages)
        end
        if haskey(params, "type")
            messages = filter(m -> m.message_type == params["type"], messages)
        end

        # Return limited number of messages
        return Dict("messages" => messages[max(1, end-limit+1):end])

    else
        return Dict("error" => "Unknown query: $query")
    end
end

# Helper function to process data messages
function process_data(agent::AgentState, data_type::String, data)
    data_type = lowercase(data_type)

    # Store the data in agent memory
    if !haskey(agent.memory, "data")
        agent.memory["data"] = Dict()
    end

    if !haskey(agent.memory["data"], data_type)
        agent.memory["data"][data_type] = []
    end

    # Add timestamp to the data
    data_entry = Dict(
        "timestamp" => now(),
        "data" => data
    )

    push!(agent.memory["data"][data_type], data_entry)

    # Limit the size of stored data
    max_entries = 100
    if length(agent.memory["data"][data_type]) > max_entries
        agent.memory["data"][data_type] = agent.memory["data"][data_type][end-max_entries+1:end]
    end

    return Dict("status" => "data_stored", "data_type" => data_type)
end

"""
    execute_skill(agent_id::String, skill_name::String, params::Dict{String, Any})

Execute a specific skill for an agent (placeholder).
"""
function execute_skill(agent_id::String, skill_name::String, message::Union{AgentMessage, Nothing}=nothing)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @error "Agent $agent_id not found for skill execution."
        return Dict("status" => "error", "error" => "Agent not found")
    end

    try
        agent_state = ACTIVE_AGENTS[agent_id]

        if !haskey(agent_state.skills, skill_name)
            @error "Skill '$skill_name' not registered for agent $agent_id."
            return Dict("status" => "error", "error" => "Skill not found")
        end

        skill = agent_state.skills[skill_name]

        # Extract parameters from message if provided
        params = Dict{String, Any}()
        if message !== nothing
            params = message.content
            params["message_id"] = message.id
            params["sender_id"] = message.sender_id
            params["message_type"] = message.message_type
        end

        @info "Executing skill '$(skill.name)' for agent $agent_id"

        # Record start time for performance tracking
        start_time = now()

        # Check if agent has the required capabilities for this skill
        agent_capabilities = agent_state.config.capabilities
        required_capabilities = skill.required_capabilities

        missing_capabilities = setdiff(required_capabilities, agent_capabilities)
        if !isempty(missing_capabilities)
            @warn "Agent $agent_id missing capabilities for skill '$skill_name': $missing_capabilities"
            return Dict(
                "status" => "error",
                "error" => "Missing capabilities",
                "missing_capabilities" => missing_capabilities
            )
        end

        # Validate input parameters if this is a message handler
        if message !== nothing && skill.is_message_handler
            # Look up the validation function by name
            validate_func_name = skill.validate_function_name

            # First try to find the function in the SkillRegistry
            if isdefined(SkillRegistry, Symbol(validate_func_name))
                validate_func = getfield(SkillRegistry, Symbol(validate_func_name))
                valid, error_msg = validate_func(agent_state, params, message)
                if !valid
                    @warn "Message validation failed for skill '$skill_name': $error_msg"
                    return Dict(
                        "status" => "error",
                        "error" => "Message validation failed: $error_msg",
                        "skill" => skill_name
                    )
                end
            elseif isdefined(Main, Symbol(validate_func_name))
                validate_func = getfield(Main, Symbol(validate_func_name))
                if !validate_func(message, skill.parameters)
                    @warn "Message validation failed for skill '$skill_name'"
                    return Dict(
                        "status" => "error",
                        "error" => "Message validation failed",
                        "skill" => skill_name
                    )
                end
            end
        end

        # Execute the skill based on its type
        result = Dict{String, Any}()

        try
            # Look up the execution function by name
            execute_func_name = skill.execute_function_name

            # First try to find the function in the SkillRegistry
            if isdefined(SkillRegistry, Symbol(execute_func_name))
                # Call the function from SkillRegistry
                execute_func = getfield(SkillRegistry, Symbol(execute_func_name))
                result = execute_func(agent_state, params)
            elseif isdefined(Main, Symbol(execute_func_name))
                # Call the registered function from Main
                execute_func = getfield(Main, Symbol(execute_func_name))
                result = execute_func(agent_state, params)
            else
                # Fallback to built-in implementations
                if skill_name == "status_report"
                    result = execute_status_report_skill(agent_state, params)
                elseif skill_name == "market_analysis"
                    result = execute_market_analysis_skill(agent_state, params)
                elseif skill_name == "execute_trade"
                    result = execute_trade_skill(agent_state, params)
                elseif skill_name == "message_handler"
                    result = execute_message_handler_skill(agent_state, params, message)
                else
                    # Generic skill execution for custom skills
                    result = Dict(
                        "status" => "executed",
                        "skill" => skill_name,
                        "message" => "Executed generic implementation for skill: $(skill_name)",
                        "params_received" => params
                    )
                end
            end

            # Update metrics
            agent_state.metrics["tasks_completed"] += 1

        catch e
            # Handle errors during skill execution
            @error "Error executing skill '$skill_name': $e" exception=(e, catch_backtrace())

            # Try to call the error handler
            error_handler_name = skill.error_handler_name
            error_handled = false

            # First try to find the error handler in the SkillRegistry
            if isdefined(SkillRegistry, Symbol(error_handler_name))
                try
                    error_handler = getfield(SkillRegistry, Symbol(error_handler_name))
                    result = error_handler(agent_state, params, e)
                    error_handled = true
                catch handler_error
                    @error "Error in SkillRegistry error handler for skill '$skill_name': $handler_error" exception=(handler_error, catch_backtrace())
                end
            elseif isdefined(Main, Symbol(error_handler_name))
                try
                    error_handler = getfield(Main, Symbol(error_handler_name))
                    error_handler(agent_state, message, e)
                    error_handled = true
                catch handler_error
                    @error "Error in error handler for skill '$skill_name': $handler_error" exception=(handler_error, catch_backtrace())
                end
            end

            # Default error handling if not handled by custom handler
            if !error_handled
                result = Dict(
                    "status" => "error",
                    "error" => "Execution error: $(typeof(e))",
                    "message" => string(e)
                )
            end

            # Update error metrics
            agent_state.metrics["tasks_failed"] += 1
            agent_state.error_count += 1
        end

        # Calculate execution time
        execution_time = (now() - start_time).value / 1000.0  # in seconds
        result["execution_time"] = execution_time

        # Log the skill execution
        log_agent_event!(agent_state, "skill_executed",
            "Executed skill '$skill_name' with result status: $(get(result, "status", "unknown"))")

        # Update agent's last update timestamp
        agent_state.last_update = now()
        agent_state.last_execution = now()

        return Dict(
            "status" => get(result, "status", "completed"),
            "skill" => skill_name,
            "result" => result,
            "execution_time" => execution_time
        )
    catch e
        @error "Error in execute_skill for agent $agent_id, skill $skill_name: $e" exception=(e, catch_backtrace())
        return Dict(
            "status" => "error",
            "error" => string(e),
            "skill" => skill_name
        )
    end
end

# Skill implementation functions

function execute_status_report_skill(agent::AgentState, params::Dict)
    # Generate a status report for the agent
    uptime = (now() - agent.created_at).value / 1000.0  # in seconds

    # Format uptime in a human-readable format
    uptime_str = if uptime < 60
        "$(round(uptime, digits=1)) seconds"
    elseif uptime < 3600
        "$(round(uptime / 60, digits=1)) minutes"
    else
        "$(round(uptime / 3600, digits=1)) hours"
    end

    # Get message count
    message_count = 0
    if haskey(agent.memory, "messages")
        message_count = length(agent.memory["messages"])
    end

    # Get skill count
    skill_count = length(agent.skills)

    # Get metrics
    metrics = get(agent.memory, "metrics", Dict())

    return Dict(
        "status" => "success",
        "agent_id" => agent.config.id,
        "agent_name" => agent.config.name,
        "agent_type" => agent.config.agent_type,
        "agent_status" => agent.status,
        "uptime" => uptime,
        "uptime_formatted" => uptime_str,
        "created_at" => agent.created_at,
        "last_update" => agent.last_update,
        "message_count" => message_count,
        "skill_count" => skill_count,
        "metrics" => metrics,
        "capabilities" => agent.config.capabilities
    )
end

function execute_market_analysis_skill(agent::AgentState, params::Dict)
    # Perform market analysis
    # In a real implementation, this would connect to market data sources
    # and perform actual analysis

    # Get market symbol from parameters
    symbol = get(params, "symbol", "BTC-USD")
    timeframe = get(params, "timeframe", "1h")
    indicators = get(params, "indicators", ["sma", "rsi"])

    # Mock market data and analysis
    mock_price = rand(5000:100:50000)
    mock_change = rand(-500:10:500) / 100.0
    mock_volume = rand(100:1000) * 1000

    # Mock indicator values
    mock_indicators = Dict()
    if "sma" in indicators
        mock_indicators["sma"] = Dict(
            "sma20" => mock_price * (1 + rand(-0.05:0.001:0.05)),
            "sma50" => mock_price * (1 + rand(-0.1:0.001:0.1)),
            "sma200" => mock_price * (1 + rand(-0.2:0.001:0.2))
        )
    end
    if "rsi" in indicators
        mock_indicators["rsi"] = rand(20:80)
    end
    if "macd" in indicators
        mock_indicators["macd"] = Dict(
            "macd" => rand(-20:0.1:20),
            "signal" => rand(-20:0.1:20),
            "histogram" => rand(-10:0.1:10)
        )
    end

    # Generate mock analysis result
    trend = if mock_change > 0
        "bullish"
    elseif mock_change < 0
        "bearish"
    else
        "neutral"
    end

    # Store analysis in agent memory
    if !haskey(agent.memory, "market_analysis")
        agent.memory["market_analysis"] = Dict()
    end

    analysis_result = Dict(
        "symbol" => symbol,
        "timeframe" => timeframe,
        "price" => mock_price,
        "change" => mock_change,
        "change_percent" => (mock_change / mock_price) * 100,
        "volume" => mock_volume,
        "indicators" => mock_indicators,
        "trend" => trend,
        "timestamp" => now()
    )

    agent.memory["market_analysis"][symbol] = analysis_result

    return Dict(
        "status" => "success",
        "analysis" => analysis_result
    )
end

function execute_trade_skill(agent::AgentState, params::Dict)
    # Execute a trade based on parameters
    # In a real implementation, this would connect to exchange APIs
    # and execute actual trades

    # Get trade parameters
    symbol = get(params, "symbol", "BTC-USD")
    side = get(params, "side", "buy")
    amount = get(params, "amount", 0.1)
    price = get(params, "price", nothing)  # nil for market orders
    order_type = get(params, "type", "market")

    # Validate parameters
    if !(side in ["buy", "sell"])
        return Dict("status" => "error", "error" => "Invalid side: $side. Must be 'buy' or 'sell'.")
    end

    if !(order_type in ["market", "limit"])
        return Dict("status" => "error", "error" => "Invalid order type: $order_type. Must be 'market' or 'limit'.")
    end

    if order_type == "limit" && price === nothing
        return Dict("status" => "error", "error" => "Price must be specified for limit orders.")
    end

    # Generate mock trade execution result
    mock_execution_price = if price !== nothing
        price
    else
        # For market orders, generate a price with some slippage
        base_price = rand(5000:100:50000)
        slippage = base_price * (rand(-0.01:0.001:0.01))
        base_price + slippage
    end

    mock_order_id = "ord_" * join(rand('a':'z', 10))
    mock_trade_id = "trade_" * join(rand('0':'9', 8))

    # Calculate trade value
    trade_value = amount * mock_execution_price

    # Store trade in agent memory
    if !haskey(agent.memory, "trades")
        agent.memory["trades"] = []
    end

    trade_record = Dict(
        "order_id" => mock_order_id,
        "trade_id" => mock_trade_id,
        "symbol" => symbol,
        "side" => side,
        "amount" => amount,
        "price" => mock_execution_price,
        "value" => trade_value,
        "type" => order_type,
        "status" => "executed",
        "timestamp" => now()
    )

    push!(agent.memory["trades"], trade_record)

    return Dict(
        "status" => "success",
        "trade" => trade_record
    )
end

function execute_system_health_check_skill(agent::AgentState, params::Dict)
    # Perform system health check
    # In a real implementation, this would check actual system metrics

    # Mock system health data
    mock_cpu_usage = rand(10:90)
    mock_memory_usage = rand(20:80)
    mock_disk_usage = rand(30:70)
    mock_network_latency = rand(5:100)

    # Determine health status based on thresholds
    cpu_status = if mock_cpu_usage > 80
        "critical"
    elseif mock_cpu_usage > 60
        "warning"
    else
        "normal"
    end

    memory_status = if mock_memory_usage > 80
        "critical"
    elseif mock_memory_usage > 60
        "warning"
    else
        "normal"
    end

    disk_status = if mock_disk_usage > 80
        "critical"
    elseif mock_disk_usage > 60
        "warning"
    else
        "normal"
    end

    network_status = if mock_network_latency > 80
        "critical"
    elseif mock_network_latency > 40
        "warning"
    else
        "normal"
    end

    # Overall system status is the worst of all components
    overall_status = if "critical" in [cpu_status, memory_status, disk_status, network_status]
        "critical"
    elseif "warning" in [cpu_status, memory_status, disk_status, network_status]
        "warning"
    else
        "normal"
    end

    # Store health check in agent memory
    if !haskey(agent.memory, "health_checks")
        agent.memory["health_checks"] = []
    end

    health_check = Dict(
        "timestamp" => now(),
        "cpu" => Dict("usage" => mock_cpu_usage, "status" => cpu_status),
        "memory" => Dict("usage" => mock_memory_usage, "status" => memory_status),
        "disk" => Dict("usage" => mock_disk_usage, "status" => disk_status),
        "network" => Dict("latency" => mock_network_latency, "status" => network_status),
        "overall_status" => overall_status
    )

    # Keep only the last 100 health checks
    push!(agent.memory["health_checks"], health_check)
    if length(agent.memory["health_checks"]) > 100
        agent.memory["health_checks"] = agent.memory["health_checks"][end-99:end]
    end

    return Dict(
        "status" => "success",
        "health_check" => health_check
    )
end

function execute_alert_generation_skill(agent::AgentState, params::Dict)
    # Generate alerts based on conditions
    # In a real implementation, this would check actual metrics and generate real alerts

    # Get alert parameters
    alert_type = get(params, "type", "system")
    severity = get(params, "severity", "info")
    message = get(params, "message", "")

    # If no message provided, generate one based on type and severity
    if isempty(message)
        if alert_type == "system"
            if severity == "critical"
                message = "Critical system issue detected: High resource usage"
            elseif severity == "warning"
                message = "Warning: System resources approaching thresholds"
            else
                message = "System operating normally"
            end
        elseif alert_type == "security"
            if severity == "critical"
                message = "Critical security alert: Potential breach detected"
            elseif severity == "warning"
                message = "Security warning: Unusual access patterns detected"
            else
                message = "Security scan completed: No issues found"
            end
        elseif alert_type == "performance"
            if severity == "critical"
                message = "Critical performance issue: System response time exceeds thresholds"
            elseif severity == "warning"
                message = "Performance warning: Degraded response times detected"
            else
                message = "Performance metrics within normal ranges"
            end
        end
    end

    # Generate a unique alert ID
    alert_id = "alert_" * join(rand('0':'9', 8))

    # Store alert in agent memory
    if !haskey(agent.memory, "alerts")
        agent.memory["alerts"] = []
    end

    alert = Dict(
        "id" => alert_id,
        "type" => alert_type,
        "severity" => severity,
        "message" => message,
        "timestamp" => now(),
        "status" => "active"
    )

    push!(agent.memory["alerts"], alert)

    # In a real implementation, this would also send the alert to notification systems

    return Dict(
        "status" => "success",
        "alert" => alert
    )
end

function execute_data_processing_skill(agent::AgentState, params::Dict)
    # Process and analyze data
    # In a real implementation, this would perform actual data processing

    # Get data processing parameters
    data_source = get(params, "source", "internal")
    data_type = get(params, "data_type", "time_series")
    operation = get(params, "operation", "analyze")
    data = get(params, "data", nothing)

    # If no data provided, use mock data
    if data === nothing
        if data_type == "time_series"
            # Generate mock time series data
            data = [
                Dict("timestamp" => now() - Dates.Second(i * 60), "value" => rand(100:1000))
                for i in 1:20
            ]
        elseif data_type == "categorical"
            # Generate mock categorical data
            categories = ["A", "B", "C", "D"]
            data = [
                Dict("category" => rand(categories), "count" => rand(10:100))
                for i in 1:10
            ]
        elseif data_type == "text"
            # Generate mock text data
            data = "This is a sample text for analysis. It contains multiple sentences and some keywords like data, analysis, and processing."
        end
    end

    # Process the data based on operation
    result = Dict()

    if operation == "analyze"
        if data_type == "time_series"
            # Perform time series analysis
            values = [d["value"] for d in data]
            result = Dict(
                "min" => minimum(values),
                "max" => maximum(values),
                "mean" => mean(values),
                "median" => median(values),
                "std_dev" => std(values),
                "trend" => rand(["increasing", "decreasing", "stable"])
            )
        elseif data_type == "categorical"
            # Perform categorical analysis
            total = sum([d["count"] for d in data])
            result = Dict(
                "total" => total,
                "distribution" => [Dict("category" => d["category"], "percentage" => (d["count"] / total) * 100) for d in data],
                "most_common" => data[argmax([d["count"] for d in data])]["category"]
            )
        elseif data_type == "text"
            # Perform text analysis
            word_count = length(split(data))
            sentence_count = length(split(data, "."))
            result = Dict(
                "word_count" => word_count,
                "sentence_count" => sentence_count,
                "average_words_per_sentence" => word_count / max(1, sentence_count),
                "keywords" => ["data", "analysis", "processing"]
            )
        end
    elseif operation == "transform"
        if data_type == "time_series"
            # Transform time series data
            result = Dict(
                "transformed" => [Dict("timestamp" => d["timestamp"], "value" => d["value"] * 2) for d in data],
                "transformation" => "doubled"
            )
        elseif data_type == "categorical"
            # Transform categorical data
            result = Dict(
                "transformed" => [Dict("category" => d["category"], "normalized" => d["count"] / 100) for d in data],
                "transformation" => "normalized"
            )
        elseif data_type == "text"
            # Transform text data
            result = Dict(
                "transformed" => uppercase(data),
                "transformation" => "uppercase"
            )
        end
    end

    # Store processing result in agent memory
    if !haskey(agent.memory, "data_processing")
        agent.memory["data_processing"] = []
    end

    processing_record = Dict(
        "timestamp" => now(),
        "source" => data_source,
        "data_type" => data_type,
        "operation" => operation,
        "result" => result
    )

    push!(agent.memory["data_processing"], processing_record)

    return Dict(
        "status" => "success",
        "processing" => processing_record
    )
end

function execute_report_generation_skill(agent::AgentState, params::Dict)
    # Generate analysis reports
    # In a real implementation, this would generate actual reports

    # Get report parameters
    report_type = get(params, "type", "summary")
    time_period = get(params, "period", "daily")
    subject = get(params, "subject", "performance")

    # Generate report content based on parameters
    title = "$(titlecase(time_period)) $(titlecase(subject)) $(titlecase(report_type))"
    timestamp = now()

    # Format timestamp based on time period
    formatted_date = if time_period == "daily"
        Dates.format(timestamp, "yyyy-mm-dd")
    elseif time_period == "weekly"
        "Week of " * Dates.format(timestamp - Dates.Day(Dates.dayofweek(timestamp) - 1), "yyyy-mm-dd")
    elseif time_period == "monthly"
        Dates.format(timestamp, "yyyy-mm")
    else
        Dates.format(timestamp, "yyyy-mm-dd")
    end

    # Generate mock report sections
    sections = []

    if subject == "performance"
        push!(sections, Dict(
            "title" => "System Performance",
            "content" => "System performance has been $(rand(["excellent", "good", "average", "below average"])) during this period. CPU usage averaged $(rand(10:90))% with peak usage of $(rand(50:100))%."
        ))
        push!(sections, Dict(
            "title" => "Response Times",
            "content" => "Average response time was $(rand(10:500))ms, which is $(rand(["better than", "worse than", "comparable to"])) the previous period."
        ))
    elseif subject == "security"
        push!(sections, Dict(
            "title" => "Security Incidents",
            "content" => "There were $(rand(0:10)) security incidents during this period, of which $(rand(0:5)) were critical."
        ))
        push!(sections, Dict(
            "title" => "Vulnerability Assessment",
            "content" => "$(rand(0:20)) new vulnerabilities were identified, with $(rand(0:10)) already patched."
        ))
    elseif subject == "market"
        push!(sections, Dict(
            "title" => "Market Overview",
            "content" => "The market has been $(rand(["bullish", "bearish", "volatile", "stable"])) during this period. Major indices $(rand(["gained", "lost"])) $(rand(1:10))% on average."
        ))
        push!(sections, Dict(
            "title" => "Trading Activity",
            "content" => "There were $(rand(10:1000)) trades executed with a total volume of $(rand(10000:1000000)) units."
        ))
    end

    # Add recommendations section
    push!(sections, Dict(
        "title" => "Recommendations",
        "content" => "Based on the analysis, it is recommended to $(rand(["increase monitoring", "optimize resource allocation", "review security policies", "adjust trading strategies", "continue current operations"]))."
    ))

    # Generate a unique report ID
    report_id = "report_" * join(rand('0':'9', 8))

    # Create the report
    report = Dict(
        "id" => report_id,
        "title" => title,
        "type" => report_type,
        "period" => time_period,
        "subject" => subject,
        "date" => formatted_date,
        "timestamp" => timestamp,
        "sections" => sections
    )

    # Store report in agent memory
    if !haskey(agent.memory, "reports")
        agent.memory["reports"] = []
    end

    push!(agent.memory["reports"], report)

    return Dict(
        "status" => "success",
        "report" => report
    )
end

"""
    register_skill(agent_id::String, skill::AgentSkill)

Register a new skill for an agent.
"""
function register_skill(agent_id::String, skill::AgentSkill)
    if !haskey(ACTIVE_AGENTS, agent_id)
         @error "Agent $agent_id not found for skill registration."
        return false
    end

    agent = ACTIVE_AGENTS[agent_id]
    if haskey(agent.skills, skill.name)
        @warn "Skill '$(skill.name)' already registered for agent $agent_id. Overwriting."
    end

    agent.skills[skill.name] = skill
    @info "Registered skill '$(skill.name)' for agent $agent_id."
    return true
end

"""
    unregister_skill(agent_id::String, skill_name::String)

Unregister a skill from an agent.
"""
function unregister_skill(agent_id::String, skill_name::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
         @error "Agent $agent_id not found for skill unregistration."
        return false
    end

    agent = ACTIVE_AGENTS[agent_id]

    if !haskey(agent.skills, skill_name)
        @warn "Skill '$skill_name' not found for agent $agent_id."
        return false
    end

    delete!(agent.skills, skill_name)
    @info "Unregistered skill '$skill_name' from agent $agent_id."
    return true
end

"""
    get_agent_state(agent_id::String)

Get the current runtime state of an agent.
"""
function get_agent_state(agent_id::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @info "Agent $agent_id not found in active agents registry."
        return nothing
    end
    return ACTIVE_AGENTS[agent_id]
end


# --- Swarm Functions --- #

"""
    create_swarm(swarm_manager_config::SwarmManager.SwarmManagerConfig, chain::String, dex::String)

Create a new swarm instance using SwarmManager, store its runtime state in memory.
Assumes the swarm config/details are also saved in persistent storage.
"""
function create_swarm(swarm_manager_config::SwarmManager.SwarmManagerConfig, chain::String="ethereum", dex::String="uniswap-v3")
    swarm_id = swarm_manager_config.name # Use name as ID for consistency
    runtime_id = swarm_manager_config.name

    if haskey(ACTIVE_SWARMS, runtime_id)
        @warn "Swarm $runtime_id already exists in active swarms."
        return ACTIVE_SWARMS[runtime_id]
    end

    try
        @info "Creating swarm object via SwarmManager for: $runtime_id"
        # 1. Create the core Swarm object using SwarmManager
        swarm_obj = SwarmManager.create_swarm(swarm_manager_config, chain, dex)

        @info "Creating and activating runtime state for swarm: $runtime_id"
        # 2. Create the AgentSystem SwarmState holding the Swarm object
        state = SwarmState(swarm_obj)
        state.status = "initialized"

        # Register swarm runtime state in active memory
        ACTIVE_SWARMS[runtime_id] = state

        return state # Return the runtime state
    catch e
        @error "Failed to create swarm $runtime_id: $e" exception=(e, catch_backtrace())
        return nothing
    end
end

"""
    update_swarm_status(swarm_id::String, new_status::String)

Update a swarm's runtime status (e.g., "active", "inactive").
"""
function update_swarm_status(swarm_id::String, new_status::String)
    if !haskey(ACTIVE_SWARMS, swarm_id)
        @error "Swarm $swarm_id not found in active swarms."
        return false
    end

    try
        swarm_state = ACTIVE_SWARMS[swarm_id]
        old_status = swarm_state.status

        # Prevent starting/stopping if already in that state or not initialized
        if old_status == new_status
            @warn "Swarm $swarm_id is already in status '$new_status'."
            return false
        end

        if old_status == "initialized" && new_status == "inactive"
            @warn "Cannot stop an initialized swarm, only active ones."
            return false
        end

        # Update the status in the SwarmManager object
        swarm_state.swarm_object.status = new_status
        swarm_state.swarm_object.last_update = now()

        # Update the status in the AgentSystem state
        swarm_state.status = new_status
        swarm_state.last_update = now()

        @info "Updated swarm $swarm_id status from '$old_status' to '$new_status'."

        # Start or stop the swarm based on the new status
        if new_status == "active" && !swarm_state.swarm_object.is_running
            # Start the swarm
            success = SwarmManager.start_swarm!(swarm_state.swarm_object)
            if !success
                @error "Failed to start swarm $swarm_id."
                swarm_state.status = old_status
                return false
            end
        elseif new_status == "inactive" && swarm_state.swarm_object.is_running
            # Stop the swarm
            success = SwarmManager.stop_swarm!(swarm_state.swarm_object)
            if !success
                @error "Failed to stop swarm $swarm_id."
                swarm_state.status = old_status
                return false
            end
        end

        return true
    catch e
        @error "Error updating swarm $swarm_id status: $e" exception=(e, catch_backtrace())
        return false
    end
end

"""
    add_agent_to_swarm(agent_id::String, swarm_id::String)

Add an agent to a swarm.
"""
function add_agent_to_swarm(agent_id::String, swarm_id::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @error "Agent $agent_id not found in active agents."
        return false
    end

    if !haskey(ACTIVE_SWARMS, swarm_id)
        @error "Swarm $swarm_id not found in active swarms."
        return false
    end

    try
        agent_state = ACTIVE_AGENTS[agent_id]
        swarm_state = ACTIVE_SWARMS[swarm_id]

        # Check if agent is already in a swarm
        if agent_state.swarm_id !== nothing
            if agent_state.swarm_id == swarm_id
                @warn "Agent $agent_id is already in swarm $swarm_id."
                return false
            else
                @warn "Agent $agent_id is already in swarm $(agent_state.swarm_id). Removing from that swarm first."
                remove_agent_from_swarm(agent_id, agent_state.swarm_id)
            end
        end

        # Add agent to swarm in SwarmManager
        success = SwarmManager.add_agent_to_swarm!(swarm_state.swarm_object, agent_id, agent_state.config.agent_type, agent_state.config.capabilities)
        if !success
            @error "Failed to add agent $agent_id to swarm $swarm_id in SwarmManager."
            return false
        end

        # Update agent state
        agent_state.swarm_id = swarm_id
        agent_state.last_update = now()

        # Update swarm state
        push!(swarm_state.agent_ids, agent_id)
        swarm_state.last_update = now()

        # Log the event
        log_agent_event!(agent_state, "joined_swarm", "Joined swarm $swarm_id")

        @info "Added agent $agent_id to swarm $swarm_id."
        return true
    catch e
        @error "Error adding agent $agent_id to swarm $swarm_id: $e" exception=(e, catch_backtrace())
        return false
    end
end

"""
    remove_agent_from_swarm(agent_id::String, swarm_id::String)

Remove an agent from a swarm.
"""
function remove_agent_from_swarm(agent_id::String, swarm_id::String)
    if !haskey(ACTIVE_AGENTS, agent_id)
        @error "Agent $agent_id not found in active agents."
        return false
    end

    if !haskey(ACTIVE_SWARMS, swarm_id)
        @error "Swarm $swarm_id not found in active swarms."
        return false
    end

    try
        agent_state = ACTIVE_AGENTS[agent_id]
        swarm_state = ACTIVE_SWARMS[swarm_id]

        # Check if agent is in the swarm
        if agent_state.swarm_id !== swarm_id
            @warn "Agent $agent_id is not in swarm $swarm_id."
            return false
        end

        # Remove agent from swarm in SwarmManager
        success = SwarmManager.remove_agent_from_swarm!(swarm_state.swarm_object, agent_id)
        if !success
            @error "Failed to remove agent $agent_id from swarm $swarm_id in SwarmManager."
            return false
        end

        # Update agent state
        agent_state.swarm_id = nothing
        agent_state.last_update = now()

        # Update swarm state
        filter!(id -> id != agent_id, swarm_state.agent_ids)
        swarm_state.last_update = now()

        # Log the event
        log_agent_event!(agent_state, "left_swarm", "Left swarm $swarm_id")

        @info "Removed agent $agent_id from swarm $swarm_id."
        return true
    catch e
        @error "Error removing agent $agent_id from swarm $swarm_id: $e" exception=(e, catch_backtrace())
        return false
    end
end

"""
    delete_swarm(swarm_id::String)

Remove a swarm from the active runtime registry.
Assumes the swarm is already deleted from persistent storage.
"""
function delete_swarm(swarm_id::String)
     if !haskey(ACTIVE_SWARMS, swarm_id)
         @warn "Swarm $swarm_id not found in active swarms registry for deletion."
         return false # Or indicate already deleted
     end

     # TODO: Optionally deactivate/remove associated agents?

     delete!(ACTIVE_SWARMS, swarm_id)
     @info "Removed swarm $swarm_id from active registry."
     return true
end

"""
    broadcast_message(swarm_id::String, message::AgentMessage)

Broadcast a message to all agents associated with a swarm (placeholder).
"""
function broadcast_message(swarm_id::String, message::AgentMessage)
    if !haskey(ACTIVE_SWARMS, swarm_id)
         @error "Swarm $swarm_id not found for broadcasting."
        return false
    end

    swarm = ACTIVE_SWARMS[swarm_id]
    @info "Broadcasting message type '$(message.message_type)' to swarm $swarm_id (agent count: $(length(swarm.agent_ids)))."
    push!(swarm.messages, message) # Store broadcasted message

    # TODO: Implement actual message delivery to each agent in swarm.agent_ids
    # for agent_id in swarm.agent_ids
    #     handle_message(agent_id, message)
    # end

    return true
end

"""
    handle_swarm_message(swarm_id::String, message::AgentMessage)

Handle a message intended for the entire swarm (basic implementation).
"""
function handle_swarm_message(swarm_id::String, message::AgentMessage)
    if !haskey(ACTIVE_SWARMS, swarm_id)
        @error "Swarm $swarm_id not found for message handling."
        return nothing
    end

    swarm = ACTIVE_SWARMS[swarm_id]
    @info "Swarm $swarm_id received swarm message type '$(message.message_type)' from $(message.sender_id)."

    push!(swarm.messages, message)

    # TODO: Implement swarm-level message processing/coordination logic

    return Dict("status" => "received_by_swarm", "message_content_preview" => first(string(message.content), 50))
end

"""
    get_swarm_state(swarm_id::String)

Get the current runtime state of a swarm.
"""
function get_swarm_state(swarm_id::String)
    if !haskey(ACTIVE_SWARMS, swarm_id)
        @info "Swarm $swarm_id not found in active swarms registry."
        return nothing
    end
    return ACTIVE_SWARMS[swarm_id] # Return the AgentSystem.SwarmState
end

# --- Helper Functions --- #

"""
    execute_status_report_skill(agent_state::AgentState, params::Dict{String, Any})

Execute the status report skill for an agent.
"""
function execute_status_report_skill(agent_state::AgentState, params::Dict{String, Any})
    @info "Executing status report skill for agent $(agent_state.config.id)"

    # Generate a status report
    report = Dict{
        String, Any
    }(
        "agent_id" => agent_state.config.id,
        "agent_name" => agent_state.config.name,
        "agent_type" => agent_state.config.agent_type,
        "status" => agent_state.status,
        "uptime" => (now() - agent_state.created_at).value / 1000.0, # in seconds
        "last_update" => agent_state.last_update,
        "error_count" => agent_state.error_count,
        "recovery_attempts" => agent_state.recovery_attempts,
        "metrics" => agent_state.metrics,
        "skills" => [skill_name for (skill_name, _) in agent_state.skills],
        "memory_usage" => length(agent_state.memory),
        "is_running" => agent_state.is_running,
        "swarm_id" => agent_state.swarm_id
    )

    return Dict(
        "status" => "success",
        "report" => report
    )
end

"""
    execute_market_analysis_skill(agent_state::AgentState, params::Dict{String, Any})

Execute the market analysis skill for an agent.
"""
function execute_market_analysis_skill(agent_state::AgentState, params::Dict{String, Any})
    @info "Executing market analysis skill for agent $(agent_state.config.id)"

    # Get parameters
    timeframe = get(params, "timeframe", "1h")
    indicators = get(params, "indicators", ["ma", "rsi"])

    # Mock market analysis
    analysis = Dict{
        String, Any
    }(
        "timestamp" => now(),
        "timeframe" => timeframe,
        "indicators" => Dict{
            String, Any
        }(),
        "sentiment" => rand(["bullish", "bearish", "neutral"]),
        "confidence" => rand(0.1:0.1:1.0)
    )

    # Generate mock indicator values
    for indicator in indicators
        if indicator == "ma"
            analysis["indicators"]["ma"] = Dict{
                String, Any
            }(
                "ma20" => 100.0 + rand(-5.0:0.1:5.0),
                "ma50" => 98.0 + rand(-3.0:0.1:3.0),
                "ma200" => 95.0 + rand(-2.0:0.1:2.0),
                "trend" => rand(["up", "down", "sideways"])
            )
        elseif indicator == "rsi"
            analysis["indicators"]["rsi"] = Dict{
                String, Any
            }(
                "value" => rand(0:100),
                "overbought" => rand(70:80),
                "oversold" => rand(20:30)
            )
        end
    end

    return Dict(
        "status" => "success",
        "analysis" => analysis
    )
end

"""
    execute_trade_skill(agent_state::AgentState, params::Dict{String, Any})

Execute the trade skill for an agent.
"""
function execute_trade_skill(agent_state::AgentState, params::Dict{String, Any})
    @info "Executing trade skill for agent $(agent_state.config.id)"

    # Get parameters
    action = get(params, "action", "buy")
    symbol = get(params, "symbol", "BTC/USDT")
    amount = get(params, "amount", 0.01)
    price = get(params, "price", nothing)

    # Mock trade execution
    trade = Dict{
        String, Any
    }(
        "timestamp" => now(),
        "action" => action,
        "symbol" => symbol,
        "amount" => amount,
        "price" => price === nothing ? 50000.0 + rand(-1000.0:0.1:1000.0) : price,
        "status" => "executed",
        "transaction_id" => string(UUIDs.uuid4())
    )

    return Dict(
        "status" => "success",
        "trade" => trade
    )
end

"""
    execute_message_handler_skill(agent_state::AgentState, params::Dict{String, Any}, message::Union{AgentMessage, Nothing})

Execute the message handler skill for an agent.
"""
function execute_message_handler_skill(agent_state::AgentState, params::Dict{String, Any}, message::Union{AgentMessage, Nothing})
    @info "Executing message handler skill for agent $(agent_state.config.id)"

    if message === nothing
        return Dict(
            "status" => "error",
            "error" => "No message provided"
        )
    end

    # Process the message based on its type
    if message.message_type == "command"
        # Handle command messages
        command = get(message.content, "command", "")

        if command == "status"
            # Return agent status
            return execute_status_report_skill(agent_state, Dict{String, Any}())
        elseif command == "execute_skill"
            # Execute a skill
            skill_name = get(message.content, "skill_name", "")
            skill_params = get(message.content, "params", Dict{String, Any}())

            if skill_name == ""
                return Dict(
                    "status" => "error",
                    "error" => "No skill name provided"
                )
            end

            return execute_skill(agent_state.config.id, skill_name, skill_params)
        else
            return Dict(
                "status" => "error",
                "error" => "Unknown command: $command"
            )
        end
    elseif message.message_type == "data"
        # Handle data messages
        data_type = get(message.content, "data_type", "")

        if data_type == "market_data"
            # Store market data in memory
            if !haskey(agent_state.memory, "market_data")
                agent_state.memory["market_data"] = Dict{String, Any}[]
            end

            push!(agent_state.memory["market_data"], message.content["data"])

            return Dict(
                "status" => "success",
                "message" => "Market data stored"
            )
        else
            return Dict(
                "status" => "error",
                "error" => "Unknown data type: $data_type"
            )
        end
    else
        # Handle other message types
        return Dict(
            "status" => "success",
            "message" => "Message received",
            "message_type" => message.message_type
        )
    end
end

# The initialize function is already defined above

# Cross-Chain Optimizer Agent Skills

"""
    execute_cross_chain_routing(agent::AgentState, params::Dict)

Execute the cross-chain routing optimization skill.
This skill analyzes different routes across blockchains and finds the optimal path.
"""
function execute_cross_chain_routing(agent::AgentState, params::Dict)
    @info "Executing cross-chain routing optimization for agent $(agent.config.id)"

    # Get parameters
    source_chain = get(params, "source_chain", "ethereum")
    target_chain = get(params, "target_chain", "polygon")
    token = get(params, "token", "USDC")
    amount = get(params, "amount", 1000.0)
    max_time = get(params, "max_time", 60)  # Maximum time in seconds
    min_savings = get(params, "min_savings", 0.01)  # Minimum savings threshold (1%)

    # In a real implementation, this would use the CrossChainOptimizer module
    # to find the optimal routing path

    # Mock transaction data and chain metrics
    transaction_data = Dict(
        "source_chain" => source_chain,
        "target_chain" => target_chain,
        "token" => token,
        "amount" => amount
    )

    chain_metrics = Dict(
        source_chain => Dict(
            "gas_price" => rand(10:100),
            "congestion" => rand(0.1:0.1:1.0),
            "block_time" => rand(1:15)
        ),
        target_chain => Dict(
            "gas_price" => rand(5:50),
            "congestion" => rand(0.1:0.1:1.0),
            "block_time" => rand(1:15)
        )
    )

    # Create a mock CrossChainConfig
    config = Dict(
        "algorithm" => "pso",
        "parameters" => Dict(
            "particles" => 20,
            "iterations" => 50
        ),
        "swarm_size" => 20,
        "dimension" => 5,
        "supported_chains" => [source_chain, target_chain],
        "bridge_protocols" => ["wormhole", "layerzero", "stargate"]
    )

    # Generate mock optimization results
    optimal_paths = [
        Dict(
            "source_chain" => source_chain,
            "target_chain" => target_chain,
            "bridge_protocol" => rand(["wormhole", "layerzero", "stargate"]),
            "estimated_fee" => rand(5:100)
        )
    ]

    routing_metrics = Dict(
        "total_fees" => sum(p["estimated_fee"] for p in optimal_paths),
        "route_efficiency" => rand(0.7:0.1:0.95),
        "time_estimate" => rand(1:10)
    )

    estimated_savings = Dict(
        "fee_savings" => rand(0.05:0.01:0.3),
        "time_savings" => rand(1:5)
    )

    # Store results in agent memory
    if !haskey(agent.memory, "cross_chain_routing")
        agent.memory["cross_chain_routing"] = Dict()
    end

    routing_result = Dict(
        "source_chain" => source_chain,
        "target_chain" => target_chain,
        "token" => token,
        "amount" => amount,
        "optimal_paths" => optimal_paths,
        "routing_metrics" => routing_metrics,
        "estimated_savings" => estimated_savings,
        "timestamp" => now()
    )

    agent.memory["cross_chain_routing"]["$(source_chain)_$(target_chain)_$(token)"] = routing_result

    return Dict(
        "status" => "success",
        "routing" => routing_result
    )
end

"""
    execute_gas_optimization(agent::AgentState, params::Dict)

Execute the gas fee optimization skill.
This skill analyzes gas fees across different blockchains and finds optimal timing and strategies.
"""
function execute_gas_optimization(agent::AgentState, params::Dict)
    @info "Executing gas fee optimization for agent $(agent.config.id)"

    # Get parameters
    chain = get(params, "chain", "ethereum")
    max_wait_time = get(params, "max_wait_time", 300)  # Maximum wait time in seconds
    transaction_type = get(params, "transaction_type", "transfer")
    priority = get(params, "priority", "medium")  # low, medium, high

    # In a real implementation, this would use the CrossChainOptimizer module
    # to optimize gas fees

    # Mock transaction data and chain metrics
    transaction_data = Dict(
        "chain" => chain,
        "transaction_type" => transaction_type,
        "priority" => priority
    )

    chain_metrics = Dict(
        chain => Dict(
            "current_gas_price" => rand(10:100),
            "historical_gas_prices" => rand(5:100, 24),
            "congestion" => rand(0.1:0.1:1.0),
            "block_time" => rand(1:15)
        )
    )

    # Generate mock gas strategies
    gas_strategies = Dict(
        "optimal_gas_price" => rand(10:100),
        "batch_size" => rand(1:10),
        "timing_recommendation" => rand(["now", "wait_1h", "wait_4h", "wait_24h"])
    )

    savings_metrics = Dict(
        "estimated_savings" => rand(0.05:0.01:0.3),
        "optimization_efficiency" => rand(0.7:0.1:0.95)
    )

    recommended_timing = Dict(
        "best_hours" => rand(0:23, 3),
        "avoid_hours" => rand(0:23, 3),
        "confidence_score" => rand(0.7:0.1:0.95)
    )

    # Store results in agent memory
    if !haskey(agent.memory, "gas_optimization")
        agent.memory["gas_optimization"] = Dict()
    end

    gas_result = Dict(
        "chain" => chain,
        "transaction_type" => transaction_type,
        "priority" => priority,
        "gas_strategies" => gas_strategies,
        "savings_metrics" => savings_metrics,
        "recommended_timing" => recommended_timing,
        "timestamp" => now()
    )

    agent.memory["gas_optimization"][chain] = gas_result

    return Dict(
        "status" => "success",
        "gas_optimization" => gas_result
    )
end

"""
    execute_bridge_analysis(agent::AgentState, params::Dict)

Execute the bridge analysis skill.
This skill analyzes different bridge protocols and identifies optimal opportunities.
"""
function execute_bridge_analysis(agent::AgentState, params::Dict)
    @info "Executing bridge analysis for agent $(agent.config.id)"

    # Get parameters
    source_chain = get(params, "source_chain", "ethereum")
    target_chain = get(params, "target_chain", "polygon")
    token = get(params, "token", "USDC")
    amount = get(params, "amount", 1000.0)
    min_liquidity = get(params, "min_liquidity", 10000)  # Minimum liquidity threshold

    # In a real implementation, this would use the CrossChainOptimizer module
    # to analyze bridge opportunities

    # Mock bridge data and chain metrics
    bridge_data = Dict(
        "wormhole" => Dict(
            "fee" => rand(0.001:0.001:0.01),
            "speed" => rand(1:30),
            "liquidity" => rand(10000:100000),
            "reliability" => rand(0.9:0.01:0.99)
        ),
        "layerzero" => Dict(
            "fee" => rand(0.001:0.001:0.01),
            "speed" => rand(1:30),
            "liquidity" => rand(10000:100000),
            "reliability" => rand(0.9:0.01:0.99)
        ),
        "stargate" => Dict(
            "fee" => rand(0.001:0.001:0.01),
            "speed" => rand(1:30),
            "liquidity" => rand(10000:100000),
            "reliability" => rand(0.9:0.01:0.99)
        )
    )

    chain_metrics = Dict(
        source_chain => Dict(
            "gas_price" => rand(10:100),
            "congestion" => rand(0.1:0.1:1.0)
        ),
        target_chain => Dict(
            "gas_price" => rand(5:50),
            "congestion" => rand(0.1:0.1:1.0)
        )
    )

    # Generate mock bridge opportunities
    bridge_opportunities = Dict()
    for bridge_name in keys(bridge_data)
        bridge_opportunities[bridge_name] = Dict(
            "fee" => bridge_data[bridge_name]["fee"],
            "speed" => bridge_data[bridge_name]["speed"],
            "reliability" => bridge_data[bridge_name]["reliability"],
            "estimated_cost" => amount * bridge_data[bridge_name]["fee"],
            "estimated_time" => bridge_data[bridge_name]["speed"]
        )
    end

    # Find the best opportunity
    best_bridge = sort(collect(keys(bridge_opportunities)),
                      by = b -> bridge_opportunities[b]["fee"])[1]

    opportunity_metrics = Dict(
        "best_opportunity" => best_bridge,
        "expected_savings" => rand(0.05:0.01:0.3),
        "risk_score" => rand(0.1:0.1:0.5)
    )

    risk_assessment = Dict(
        "overall_risk" => rand(["low", "medium", "high"]),
        "bridge_risks" => Dict(
            bridge => Dict(
                "smart_contract_risk" => rand(["low", "medium", "high"]),
                "liquidity_risk" => rand(["low", "medium", "high"]),
                "centralization_risk" => rand(["low", "medium", "high"])
            ) for bridge in keys(bridge_data)
        )
    )

    # Store results in agent memory
    if !haskey(agent.memory, "bridge_analysis")
        agent.memory["bridge_analysis"] = Dict()
    end

    bridge_result = Dict(
        "source_chain" => source_chain,
        "target_chain" => target_chain,
        "token" => token,
        "amount" => amount,
        "bridge_opportunities" => bridge_opportunities,
        "opportunity_metrics" => opportunity_metrics,
        "risk_assessment" => risk_assessment,
        "timestamp" => now()
    )

    agent.memory["bridge_analysis"]["$(source_chain)_$(target_chain)_$(token)"] = bridge_result

    return Dict(
        "status" => "success",
        "bridge_analysis" => bridge_result
    )
end

end # module