"""
Communication module for JuliaOS swarm algorithms.

This module provides advanced communication patterns for swarm algorithms.
"""
module SwarmCommunication

export MessageSchema, CommunicationPattern, HierarchicalPattern, MeshPattern, 
       RingPattern, BroadcastPattern, send_message, register_handler

using UUIDs
using Dates
using JSON3
using ..Swarms

"""
    MessageSchema

Structure defining a schema for messages.

# Fields
- `type::String`: Message type identifier
- `required_fields::Vector{String}`: Required fields in the message
- `optional_fields::Vector{String}`: Optional fields in the message
- `validator::Function`: Optional function to validate message content
"""
struct MessageSchema
    type::String
    required_fields::Vector{String}
    optional_fields::Vector{String}
    validator::Union{Function, Nothing}
    
    function MessageSchema(
        type::String,
        required_fields::Vector{String} = String[];
        optional_fields::Vector{String} = String[],
        validator::Union{Function, Nothing} = nothing
    )
        new(type, required_fields, optional_fields, validator)
    end
end

"""
    validate_message(schema::MessageSchema, message::Dict)

Validate a message against a schema.

# Arguments
- `schema::MessageSchema`: The schema to validate against
- `message::Dict`: The message to validate

# Returns
- `Tuple{Bool, String}`: (is_valid, error_message)
"""
function validate_message(schema::MessageSchema, message::Dict)
    # Check message type
    if get(message, "type", "") != schema.type
        return (false, "Message type mismatch: expected $(schema.type), got $(get(message, "type", "none"))")
    end
    
    # Check required fields
    for field in schema.required_fields
        if !haskey(message, field)
            return (false, "Missing required field: $field")
        end
    end
    
    # Apply custom validator if provided
    if schema.validator !== nothing
        try
            result, error_msg = schema.validator(message)
            if !result
                return (false, error_msg)
            end
        catch e
            return (false, "Validator error: $(string(e))")
        end
    end
    
    return (true, "")
end

"""
    AbstractCommunicationPattern

Abstract type for communication patterns.
"""
abstract type CommunicationPattern end

"""
    HierarchicalPattern <: CommunicationPattern

Hierarchical communication pattern with leaders and followers.

# Fields
- `swarm_id::String`: ID of the swarm
- `levels::Int`: Number of hierarchy levels
- `branching_factor::Int`: Number of children per node
- `hierarchy::Dict{String, Int}`: Map of agent IDs to hierarchy levels
- `parent_map::Dict{String, String}`: Map of agent IDs to parent IDs
- `children_map::Dict{String, Vector{String}}`: Map of agent IDs to children IDs
"""
mutable struct HierarchicalPattern <: CommunicationPattern
    swarm_id::String
    levels::Int
    branching_factor::Int
    hierarchy::Dict{String, Int}
    parent_map::Dict{String, String}
    children_map::Dict{String, Vector{String}}
    
    function HierarchicalPattern(
        swarm_id::String;
        levels::Int = 2,
        branching_factor::Int = 3
    )
        levels >= 1 || throw(ArgumentError("Levels must be at least 1"))
        branching_factor >= 1 || throw(ArgumentError("Branching factor must be at least 1"))
        
        new(
            swarm_id,
            levels,
            branching_factor,
            Dict{String, Int}(),
            Dict{String, String}(),
            Dict{String, Vector{String}}()
        )
    end
end

"""
    MeshPattern <: CommunicationPattern

Mesh communication pattern where all agents can communicate with each other.

# Fields
- `swarm_id::String`: ID of the swarm
- `connections::Dict{String, Vector{String}}`: Map of agent IDs to connected agent IDs
"""
mutable struct MeshPattern <: CommunicationPattern
    swarm_id::String
    connections::Dict{String, Vector{String}}
    
    function MeshPattern(swarm_id::String)
        new(swarm_id, Dict{String, Vector{String}}())
    end
end

"""
    RingPattern <: CommunicationPattern

Ring communication pattern where agents form a ring.

# Fields
- `swarm_id::String`: ID of the swarm
- `ring::Vector{String}`: Ordered list of agent IDs forming the ring
- `bidirectional::Bool`: Whether communication is bidirectional
"""
mutable struct RingPattern <: CommunicationPattern
    swarm_id::String
    ring::Vector{String}
    bidirectional::Bool
    
    function RingPattern(swarm_id::String; bidirectional::Bool = true)
        new(swarm_id, String[], bidirectional)
    end
end

"""
    BroadcastPattern <: CommunicationPattern

Broadcast communication pattern where messages are sent to all agents.

# Fields
- `swarm_id::String`: ID of the swarm
- `senders::Vector{String}`: Agent IDs allowed to broadcast
"""
mutable struct BroadcastPattern <: CommunicationPattern
    swarm_id::String
    senders::Vector{String}
    
    function BroadcastPattern(swarm_id::String; senders::Vector{String} = String[])
        new(swarm_id, senders)
    end
end

"""
    initialize_pattern!(pattern::HierarchicalPattern, agent_ids::Vector{String})

Initialize a hierarchical communication pattern.

# Arguments
- `pattern::HierarchicalPattern`: The pattern to initialize
- `agent_ids::Vector{String}`: List of agent IDs to organize

# Returns
- `Bool`: Whether initialization was successful
"""
function initialize_pattern!(pattern::HierarchicalPattern, agent_ids::Vector{String})
    # Clear existing data
    empty!(pattern.hierarchy)
    empty!(pattern.parent_map)
    empty!(pattern.children_map)
    
    # Check if we have enough agents
    if length(agent_ids) < 2
        @warn "Not enough agents for hierarchical pattern"
        return false
    end
    
    # Assign root (level 0)
    root_id = agent_ids[1]
    pattern.hierarchy[root_id] = 0
    pattern.children_map[root_id] = String[]
    
    # Assign remaining agents to levels
    remaining_agents = agent_ids[2:end]
    current_level = 1
    current_parent_idx = 1
    parent_id = root_id
    
    for agent_id in remaining_agents
        # Assign to current level
        pattern.hierarchy[agent_id] = current_level
        pattern.parent_map[agent_id] = parent_id
        push!(pattern.children_map[parent_id], agent_id)
        
        # Initialize children list
        pattern.children_map[agent_id] = String[]
        
        # Move to next parent if needed
        if length(pattern.children_map[parent_id]) >= pattern.branching_factor
            current_parent_idx += 1
            
            # If we've gone through all parents at this level, move to next level
            if current_parent_idx > length(filter(id -> pattern.hierarchy[id] == current_level - 1, collect(keys(pattern.hierarchy))))
                current_level += 1
                current_parent_idx = 1
            end
            
            # Find next parent
            parents_at_prev_level = filter(id -> pattern.hierarchy[id] == current_level - 1, collect(keys(pattern.hierarchy)))
            if isempty(parents_at_prev_level)
                # No more parents available, use root
                parent_id = root_id
            else
                parent_id = parents_at_prev_level[current_parent_idx]
            end
        end
    end
    
    return true
end

"""
    initialize_pattern!(pattern::MeshPattern, agent_ids::Vector{String})

Initialize a mesh communication pattern.

# Arguments
- `pattern::MeshPattern`: The pattern to initialize
- `agent_ids::Vector{String}`: List of agent IDs to organize

# Returns
- `Bool`: Whether initialization was successful
"""
function initialize_pattern!(pattern::MeshPattern, agent_ids::Vector{String})
    # Clear existing data
    empty!(pattern.connections)
    
    # Create full mesh
    for agent_id in agent_ids
        # Connect to all other agents
        pattern.connections[agent_id] = filter(id -> id != agent_id, agent_ids)
    end
    
    return true
end

"""
    initialize_pattern!(pattern::RingPattern, agent_ids::Vector{String})

Initialize a ring communication pattern.

# Arguments
- `pattern::RingPattern`: The pattern to initialize
- `agent_ids::Vector{String}`: List of agent IDs to organize

# Returns
- `Bool`: Whether initialization was successful
"""
function initialize_pattern!(pattern::RingPattern, agent_ids::Vector{String})
    # Clear existing data
    empty!(pattern.ring)
    
    # Check if we have enough agents
    if length(agent_ids) < 2
        @warn "Not enough agents for ring pattern"
        return false
    end
    
    # Create ring (just store the order)
    pattern.ring = copy(agent_ids)
    
    return true
end

"""
    initialize_pattern!(pattern::BroadcastPattern, agent_ids::Vector{String})

Initialize a broadcast communication pattern.

# Arguments
- `pattern::BroadcastPattern`: The pattern to initialize
- `agent_ids::Vector{String}`: List of agent IDs to organize

# Returns
- `Bool`: Whether initialization was successful
"""
function initialize_pattern!(pattern::BroadcastPattern, agent_ids::Vector{String})
    # If no specific senders, all agents can broadcast
    if isempty(pattern.senders)
        pattern.senders = copy(agent_ids)
    else
        # Filter out any senders that aren't in the agent list
        filter!(id -> id in agent_ids, pattern.senders)
    end
    
    return true
end

"""
    setup_communication_pattern(swarm_id::String, pattern::CommunicationPattern)

Set up a communication pattern for a swarm.

# Arguments
- `swarm_id::String`: ID of the swarm
- `pattern::CommunicationPattern`: The communication pattern to set up

# Returns
- `Dict`: Result of the operation
"""
function setup_communication_pattern(swarm_id::String, pattern::CommunicationPattern)
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end
    
    # Initialize pattern with agent IDs
    success = initialize_pattern!(pattern, swarm.agent_ids)
    if !success
        return Dict("success" => false, "error" => "Failed to initialize communication pattern")
    end
    
    # Store pattern in swarm shared state
    pattern_type = string(typeof(pattern))
    result = Swarms.updateSharedState!(swarm_id, "communication_pattern", pattern_type)
    if !result["success"]
        return Dict("success" => false, "error" => "Failed to update swarm shared state")
    end
    
    # Store pattern-specific data
    if pattern isa HierarchicalPattern
        Swarms.updateSharedState!(swarm_id, "hierarchy_levels", pattern.hierarchy)
        Swarms.updateSharedState!(swarm_id, "hierarchy_parents", pattern.parent_map)
        Swarms.updateSharedState!(swarm_id, "hierarchy_children", pattern.children_map)
    elseif pattern isa MeshPattern
        Swarms.updateSharedState!(swarm_id, "mesh_connections", pattern.connections)
    elseif pattern isa RingPattern
        Swarms.updateSharedState!(swarm_id, "ring_order", pattern.ring)
        Swarms.updateSharedState!(swarm_id, "ring_bidirectional", pattern.bidirectional)
    elseif pattern isa BroadcastPattern
        Swarms.updateSharedState!(swarm_id, "broadcast_senders", pattern.senders)
    end
    
    return Dict("success" => true, "message" => "Communication pattern set up successfully")
end

"""
    send_message(swarm_id::String, sender_id::String, message::Dict, pattern::CommunicationPattern)

Send a message using a specific communication pattern.

# Arguments
- `swarm_id::String`: ID of the swarm
- `sender_id::String`: ID of the sending agent
- `message::Dict`: The message to send
- `pattern::CommunicationPattern`: The communication pattern to use

# Returns
- `Dict`: Result of the operation
"""
function send_message(swarm_id::String, sender_id::String, message::Dict, pattern::CommunicationPattern)
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end
    
    # Check if sender is in swarm
    if !(sender_id in swarm.agent_ids)
        return Dict("success" => false, "error" => "Sender $sender_id not in swarm")
    end
    
    # Add message metadata
    message_with_meta = merge(message, Dict(
        "sender_id" => sender_id,
        "timestamp" => string(now()),
        "message_id" => string(uuid4())
    ))
    
    # Send message according to pattern
    if pattern isa HierarchicalPattern
        # Get sender's level
        sender_level = get(pattern.hierarchy, sender_id, -1)
        if sender_level == -1
            return Dict("success" => false, "error" => "Sender not in hierarchy")
        end
        
        # Determine recipients based on direction
        recipients = String[]
        
        if get(message, "direction", "down") == "up"
            # Send to parent
            if haskey(pattern.parent_map, sender_id)
                push!(recipients, pattern.parent_map[sender_id])
            end
        elseif get(message, "direction", "down") == "down"
            # Send to children
            if haskey(pattern.children_map, sender_id)
                append!(recipients, pattern.children_map[sender_id])
            end
        else
            # Invalid direction
            return Dict("success" => false, "error" => "Invalid message direction")
        end
        
        # Send to all recipients
        for recipient_id in recipients
            try
                Agents.Swarm.publish_to_swarm(sender_id, "agent.$recipient_id.message", message_with_meta)
            catch e
                @warn "Failed to send message to $recipient_id" exception=(e, catch_backtrace())
            end
        end
    elseif pattern isa MeshPattern
        # Get connections
        connections = get(pattern.connections, sender_id, String[])
        
        # Send to all connections
        for recipient_id in connections
            try
                Agents.Swarm.publish_to_swarm(sender_id, "agent.$recipient_id.message", message_with_meta)
            catch e
                @warn "Failed to send message to $recipient_id" exception=(e, catch_backtrace())
            end
        end
    elseif pattern isa RingPattern
        # Find sender in ring
        sender_idx = findfirst(id -> id == sender_id, pattern.ring)
        if sender_idx === nothing
            return Dict("success" => false, "error" => "Sender not in ring")
        end
        
        # Determine next agent in ring
        next_idx = sender_idx % length(pattern.ring) + 1
        next_id = pattern.ring[next_idx]
        
        # Send to next agent
        try
            Agents.Swarm.publish_to_swarm(sender_id, "agent.$next_id.message", message_with_meta)
        catch e
            @warn "Failed to send message to $next_id" exception=(e, catch_backtrace())
        end
        
        # If bidirectional, also send to previous agent
        if pattern.bidirectional
            prev_idx = sender_idx == 1 ? length(pattern.ring) : sender_idx - 1
            prev_id = pattern.ring[prev_idx]
            
            try
                Agents.Swarm.publish_to_swarm(sender_id, "agent.$prev_id.message", message_with_meta)
            catch e
                @warn "Failed to send message to $prev_id" exception=(e, catch_backtrace())
            end
        end
    elseif pattern isa BroadcastPattern
        # Check if sender is allowed to broadcast
        if !(sender_id in pattern.senders)
            return Dict("success" => false, "error" => "Sender not authorized to broadcast")
        end
        
        # Broadcast to all agents in swarm
        try
            Agents.Swarm.publish_to_swarm(sender_id, "swarm.$swarm_id.broadcast", message_with_meta)
        catch e
            @warn "Failed to broadcast message" exception=(e, catch_backtrace())
        end
    end
    
    return Dict(
        "success" => true,
        "message_id" => message_with_meta["message_id"],
        "timestamp" => message_with_meta["timestamp"]
    )
end

"""
    register_handler(agent_id::String, pattern::CommunicationPattern, handler::Function)

Register a message handler for an agent.

# Arguments
- `agent_id::String`: ID of the agent
- `pattern::CommunicationPattern`: The communication pattern
- `handler::Function`: Function to handle messages

# Returns
- `Dict`: Result of the operation
"""
function register_handler(agent_id::String, pattern::CommunicationPattern, handler::Function)
    # Get agent
    agent = nothing
    try
        agent = Agents.getAgent(agent_id)
    catch e
        @warn "Error getting agent $agent_id" exception=(e, catch_backtrace())
    end
    
    if agent === nothing
        return Dict("success" => false, "error" => "Agent $agent_id not found")
    end
    
    # Subscribe to appropriate topics based on pattern
    if pattern isa HierarchicalPattern
        # Subscribe to direct messages
        try
            Agents.Swarm.subscribe_swarm!(agent_id, "agent.$agent_id.message", handler)
        catch e
            @warn "Failed to subscribe to direct messages" exception=(e, catch_backtrace())
        end
    elseif pattern isa MeshPattern
        # Subscribe to direct messages
        try
            Agents.Swarm.subscribe_swarm!(agent_id, "agent.$agent_id.message", handler)
        catch e
            @warn "Failed to subscribe to direct messages" exception=(e, catch_backtrace())
        end
    elseif pattern isa RingPattern
        # Subscribe to direct messages
        try
            Agents.Swarm.subscribe_swarm!(agent_id, "agent.$agent_id.message", handler)
        catch e
            @warn "Failed to subscribe to direct messages" exception=(e, catch_backtrace())
        end
    elseif pattern isa BroadcastPattern
        # Subscribe to broadcast messages
        try
            Agents.Swarm.subscribe_swarm!(agent_id, "swarm.$(pattern.swarm_id).broadcast", handler)
        catch e
            @warn "Failed to subscribe to broadcast messages" exception=(e, catch_backtrace())
        end
    end
    
    return Dict("success" => true, "message" => "Handler registered successfully")
end

end # module
