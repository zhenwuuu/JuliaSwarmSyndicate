using JSON
using Dates
using HTTP
using ..AgentSystem
using ..Bridge

module AgentBridge

using JSON
using Dates
using HTTP
using ..AgentSystem
using ..Bridge

# Agent bridge types
struct AgentBridgeMessage
    id::String
    source::String  # "julia" or "typescript"
    target::String
    message_type::String
    payload::Dict{String, Any}
    timestamp::DateTime
    status::String
end

# Agent bridge state
struct AgentBridgeState
    messages::Dict{String, AgentBridgeMessage}
    pending_messages::Vector{String}
    processed_messages::Set{String}
    connected_agents::Dict{String, Dict{String, Any}}
    bridge_config::Dict{String, Any}
end

# Initialize bridge state
const BRIDGE_STATE = Ref{AgentBridgeState}(AgentBridgeState(
    Dict{String, AgentBridgeMessage}(),
    String[],
    Set{String}(),
    Dict{String, Dict{String, Any}}(),
    Dict{String, Any}()
))

"""
    connect_to_typescript_agent(agent_id::String, config::Dict{String, Any})

Connect a Julia agent to the TypeScript agent system.
"""
function connect_to_typescript_agent(agent_id::String, config::Dict{String, Any})
    try
        # Validate agent exists
        if !AgentSystem.agent_exists(agent_id)
            throw(ErrorException("Agent not found: $agent_id"))
        end

        # Create bridge message
        message = AgentBridgeMessage(
            string(uuid4()),
            "julia",
            "typescript",
            "agent_connect",
            Dict(
                "agent_id" => agent_id,
                "config" => config
            ),
            now(),
            "pending"
        )

        # Store message
        BRIDGE_STATE[].messages[message.id] = message
        push!(BRIDGE_STATE[].pending_messages, message.id)

        # Send message through bridge
        Bridge.send_command("agent_connect", Dict(
            "message_id" => message.id,
            "agent_id" => agent_id,
            "config" => config
        ))

        # Update connected agents
        BRIDGE_STATE[].connected_agents[agent_id] = config

        return true
    catch e
        @error "Failed to connect agent: $e"
        return false
    end
end

"""
    send_agent_message(agent_id::String, target_agent::String, message_type::String, payload::Dict{String, Any})

Send a message between agents across the bridge.
"""
function send_agent_message(
    agent_id::String,
    target_agent::String,
    message_type::String,
    payload::Dict{String, Any}
)
    try
        # Validate agents are connected
        if !haskey(BRIDGE_STATE[].connected_agents, agent_id)
            throw(ErrorException("Source agent not connected: $agent_id"))
        end

        # Create bridge message
        message = AgentBridgeMessage(
            string(uuid4()),
            "julia",
            "typescript",
            message_type,
            Dict(
                "source_agent" => agent_id,
                "target_agent" => target_agent,
                "payload" => payload
            ),
            now(),
            "pending"
        )

        # Store message
        BRIDGE_STATE[].messages[message.id] = message
        push!(BRIDGE_STATE[].pending_messages, message.id)

        # Send message through bridge
        Bridge.send_command("agent_message", Dict(
            "message_id" => message.id,
            "source_agent" => agent_id,
            "target_agent" => target_agent,
            "message_type" => message_type,
            "payload" => payload
        ))

        return message.id
    catch e
        @error "Failed to send agent message: $e"
        return nothing
    end
end

"""
    handle_agent_message(message::Dict{String, Any})

Handle incoming messages from the TypeScript agent system.
"""
function handle_agent_message(message::Dict{String, Any})
    try
        message_type = get(message, "message_type", "")
        payload = get(message, "payload", Dict{String, Any}())

        if message_type == "agent_connect"
            # Handle agent connection
            agent_id = get(payload, "agent_id", "")
            if !isempty(agent_id)
                BRIDGE_STATE[].connected_agents[agent_id] = get(payload, "config", Dict{String, Any}())
                @info "TypeScript agent connected: $agent_id"
            end

        elseif message_type == "agent_message"
            # Handle agent message
            source_agent = get(payload, "source_agent", "")
            target_agent = get(payload, "target_agent", "")
            message_payload = get(payload, "payload", Dict{String, Any}())

            if !isempty(source_agent) && !isempty(target_agent)
                # Forward message to target agent
                AgentSystem.send_message(target_agent, source_agent, message_payload)
            end

        elseif message_type == "agent_disconnect"
            # Handle agent disconnection
            agent_id = get(payload, "agent_id", "")
            if !isempty(agent_id) && haskey(BRIDGE_STATE[].connected_agents, agent_id)
                delete!(BRIDGE_STATE[].connected_agents, agent_id)
                @info "TypeScript agent disconnected: $agent_id"
            end
        end

        return true
    catch e
        @error "Failed to handle agent message: $e"
        return false
    end
end

"""
    get_agent_status(agent_id::String)

Get the connection status of an agent.
"""
function get_agent_status(agent_id::String)::Dict{String, Any}
    if !haskey(BRIDGE_STATE[].connected_agents, agent_id)
        return Dict(
            "connected" => false,
            "error" => "Agent not connected"
        )
    end

    return Dict(
        "connected" => true,
        "config" => BRIDGE_STATE[].connected_agents[agent_id],
        "messages_sent" => count(x -> x.source == "julia" && x.target == "typescript", values(BRIDGE_STATE[].messages)),
        "messages_received" => count(x -> x.source == "typescript" && x.target == "julia", values(BRIDGE_STATE[].messages))
    )
end

"""
    disconnect_agent(agent_id::String)

Disconnect an agent from the TypeScript system.
"""
function disconnect_agent(agent_id::String)::Bool
    try
        if !haskey(BRIDGE_STATE[].connected_agents, agent_id)
            return false
        end

        # Send disconnect message
        message = AgentBridgeMessage(
            string(uuid4()),
            "julia",
            "typescript",
            "agent_disconnect",
            Dict("agent_id" => agent_id),
            now(),
            "pending"
        )

        # Store message
        BRIDGE_STATE[].messages[message.id] = message
        push!(BRIDGE_STATE[].pending_messages, message.id)

        # Send message through bridge
        Bridge.send_command("agent_disconnect", Dict(
            "message_id" => message.id,
            "agent_id" => agent_id
        ))

        # Remove from connected agents
        delete!(BRIDGE_STATE[].connected_agents, agent_id)

        return true
    catch e
        @error "Failed to disconnect agent: $e"
        return false
    end
end

# Module initialization
function __init__()
    # Register message handler with bridge
    Bridge.register_callback("agent_message", handle_agent_message)
    @info "AgentBridge module initialized"
end

end # module 