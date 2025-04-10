"""
    coordinate_agents!(swarm::Swarm)

Coordinate the agents in a swarm using the SwarmCoordination module.
"""
function coordinate_agents!(swarm::Swarm)
    @info "Coordinating agents in swarm '$(swarm.config.name)'..."
    
    # Use the SwarmCoordination module to coordinate the agents
    result = coordinate_swarm!(swarm, swarm.agents)
    
    # Update swarm status
    swarm.last_update = now()
    
    return result
end

"""
    broadcast_message_to_agents!(swarm::Swarm, message::Dict{String, Any})

Broadcast a message to all agents in the swarm.
"""
function broadcast_message_to_agents!(swarm::Swarm, message::Dict{String, Any})
    # Use the SwarmCoordination module to broadcast the message
    return broadcast_to_swarm(swarm, swarm.agents, message)
end
