"""
Security module for JuliaOS swarm algorithms.

This module provides security features for swarm algorithms.
"""
module SwarmSecurity

export SwarmSecurityPolicy, SecureSwarm, authenticate_agent, authorize_action, encrypt_message, decrypt_message

using Random
using SHA
using Base64
using Dates
using UUIDs
using ..Swarms

"""
    SwarmSecurityPolicy

Structure defining security policies for a swarm.

# Fields
- `authentication_required::Bool`: Whether authentication is required
- `encryption_required::Bool`: Whether message encryption is required
- `rate_limits::Dict{String, Int}`: Rate limits for different actions (actions/minute)
- `allowed_roles::Dict{String, Vector{String}}`: Mapping of actions to allowed roles
- `token_expiry::Int`: Token expiry time in seconds
"""
struct SwarmSecurityPolicy
    authentication_required::Bool
    encryption_required::Bool
    rate_limits::Dict{String, Int}
    allowed_roles::Dict{String, Vector{String}}
    token_expiry::Int
    
    function SwarmSecurityPolicy(;
        authentication_required::Bool = true,
        encryption_required::Bool = false,
        rate_limits::Dict{String, Int} = Dict{String, Int}(),
        allowed_roles::Dict{String, Vector{String}} = Dict{String, Vector{String}}(),
        token_expiry::Int = 3600
    )
        # Set default rate limits if not provided
        if isempty(rate_limits)
            rate_limits = Dict(
                "message" => 60,  # 60 messages per minute
                "task" => 10,     # 10 task operations per minute
                "state" => 30     # 30 state operations per minute
            )
        end
        
        # Set default allowed roles if not provided
        if isempty(allowed_roles)
            allowed_roles = Dict(
                "read_state" => ["member", "admin"],
                "write_state" => ["admin"],
                "create_task" => ["member", "admin"],
                "claim_task" => ["member", "admin"],
                "complete_task" => ["member", "admin"],
                "add_agent" => ["admin"],
                "remove_agent" => ["admin"],
                "start_swarm" => ["admin"],
                "stop_swarm" => ["admin"]
            )
        end
        
        new(authentication_required, encryption_required, rate_limits, allowed_roles, token_expiry)
    end
end

"""
    SecureSwarm

Structure for managing swarm security.

# Fields
- `swarm_id::String`: ID of the swarm
- `policy::SwarmSecurityPolicy`: Security policy
- `agent_roles::Dict{String, String}`: Mapping of agent IDs to roles
- `auth_tokens::Dict{String, Dict{String, Any}}`: Authentication tokens
- `rate_counters::Dict{String, Dict{String, Vector{DateTime}}}`: Rate limiting counters
"""
mutable struct SecureSwarm
    swarm_id::String
    policy::SwarmSecurityPolicy
    agent_roles::Dict{String, String}
    auth_tokens::Dict{String, Dict{String, Any}}
    rate_counters::Dict{String, Dict{String, Vector{DateTime}}}
    
    function SecureSwarm(
        swarm_id::String,
        policy::SwarmSecurityPolicy = SwarmSecurityPolicy()
    )
        new(
            swarm_id,
            policy,
            Dict{String, String}(),
            Dict{String, Dict{String, Any}}(),
            Dict{String, Dict{String, Vector{DateTime}}}()
        )
    end
end

"""
    initialize_security(secure_swarm::SecureSwarm)

Initialize security for a swarm.

# Arguments
- `secure_swarm::SecureSwarm`: The secure swarm

# Returns
- `Dict`: Result of the operation
"""
function initialize_security(secure_swarm::SecureSwarm)
    swarm_id = secure_swarm.swarm_id
    
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end
    
    # Store security policy in swarm shared state
    policy_data = Dict(
        "authentication_required" => secure_swarm.policy.authentication_required,
        "encryption_required" => secure_swarm.policy.encryption_required,
        "rate_limits" => secure_swarm.policy.rate_limits,
        "allowed_roles" => secure_swarm.policy.allowed_roles,
        "token_expiry" => secure_swarm.policy.token_expiry
    )
    
    result = Swarms.updateSharedState!(swarm_id, "security_policy", policy_data)
    if !result["success"]
        return Dict("success" => false, "error" => "Failed to update swarm shared state")
    end
    
    # Initialize first agent as admin
    if !isempty(swarm.agent_ids)
        secure_swarm.agent_roles[swarm.agent_ids[1]] = "admin"
        
        # Store agent roles
        Swarms.updateSharedState!(swarm_id, "agent_roles", secure_swarm.agent_roles)
    end
    
    return Dict("success" => true, "message" => "Security initialized successfully")
end

"""
    authenticate_agent(secure_swarm::SecureSwarm, agent_id::String, credentials::Dict)

Authenticate an agent and issue a token.

# Arguments
- `secure_swarm::SecureSwarm`: The secure swarm
- `agent_id::String`: ID of the agent
- `credentials::Dict`: Authentication credentials

# Returns
- `Dict`: Result with token if successful
"""
function authenticate_agent(secure_swarm::SecureSwarm, agent_id::String, credentials::Dict)
    swarm_id = secure_swarm.swarm_id
    
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end
    
    # Check if agent is in swarm
    if !(agent_id in swarm.agent_ids)
        return Dict("success" => false, "error" => "Agent $agent_id not in swarm")
    end
    
    # In a real implementation, we would validate credentials
    # For this example, we'll just check if a key exists
    if !haskey(credentials, "key")
        return Dict("success" => false, "error" => "Invalid credentials")
    end
    
    # Generate token
    token = string(uuid4())
    expiry = now() + Dates.Second(secure_swarm.policy.token_expiry)
    
    # Store token
    secure_swarm.auth_tokens[agent_id] = Dict(
        "token" => token,
        "expiry" => expiry,
        "issued_at" => now()
    )
    
    # Get agent role
    role = get(secure_swarm.agent_roles, agent_id, "member")
    
    return Dict(
        "success" => true,
        "token" => token,
        "expiry" => string(expiry),
        "role" => role
    )
end

"""
    verify_token(secure_swarm::SecureSwarm, agent_id::String, token::String)

Verify an authentication token.

# Arguments
- `secure_swarm::SecureSwarm`: The secure swarm
- `agent_id::String`: ID of the agent
- `token::String`: Authentication token

# Returns
- `Bool`: Whether the token is valid
"""
function verify_token(secure_swarm::SecureSwarm, agent_id::String, token::String)
    # Check if agent has a token
    if !haskey(secure_swarm.auth_tokens, agent_id)
        return false
    end
    
    # Get token data
    token_data = secure_swarm.auth_tokens[agent_id]
    
    # Check if token matches
    if token_data["token"] != token
        return false
    end
    
    # Check if token has expired
    if token_data["expiry"] < now()
        # Remove expired token
        delete!(secure_swarm.auth_tokens, agent_id)
        return false
    end
    
    return true
end

"""
    authorize_action(secure_swarm::SecureSwarm, agent_id::String, action::String, token::String)

Authorize an agent to perform an action.

# Arguments
- `secure_swarm::SecureSwarm`: The secure swarm
- `agent_id::String`: ID of the agent
- `action::String`: Action to authorize
- `token::String`: Authentication token

# Returns
- `Dict`: Result of the authorization
"""
function authorize_action(secure_swarm::SecureSwarm, agent_id::String, action::String, token::String)
    # Skip authentication if not required
    if !secure_swarm.policy.authentication_required
        return Dict("success" => true, "authorized" => true)
    end
    
    # Verify token
    if !verify_token(secure_swarm, agent_id, token)
        return Dict("success" => false, "error" => "Invalid or expired token")
    end
    
    # Get agent role
    role = get(secure_swarm.agent_roles, agent_id, "member")
    
    # Check if action is allowed for role
    allowed_roles = get(secure_swarm.policy.allowed_roles, action, String[])
    if !(role in allowed_roles)
        return Dict(
            "success" => true,
            "authorized" => false,
            "reason" => "Action $action not allowed for role $role"
        )
    end
    
    # Check rate limits
    rate_limit = get(secure_swarm.policy.rate_limits, action, 0)
    if rate_limit > 0
        # Initialize rate counter if needed
        if !haskey(secure_swarm.rate_counters, agent_id)
            secure_swarm.rate_counters[agent_id] = Dict{String, Vector{DateTime}}()
        end
        
        if !haskey(secure_swarm.rate_counters[agent_id], action)
            secure_swarm.rate_counters[agent_id][action] = DateTime[]
        end
        
        # Get timestamps for this action
        timestamps = secure_swarm.rate_counters[agent_id][action]
        
        # Remove timestamps older than 1 minute
        filter!(t -> (now() - t).value / 1000 <= 60, timestamps)
        
        # Check if rate limit exceeded
        if length(timestamps) >= rate_limit
            return Dict(
                "success" => true,
                "authorized" => false,
                "reason" => "Rate limit exceeded for action $action"
            )
        end
        
        # Add current timestamp
        push!(timestamps, now())
    end
    
    return Dict("success" => true, "authorized" => true)
end

"""
    encrypt_message(message::Dict, key::String)

Encrypt a message using a shared key.

# Arguments
- `message::Dict`: Message to encrypt
- `key::String`: Encryption key

# Returns
- `Dict`: Encrypted message
"""
function encrypt_message(message::Dict, key::String)
    # In a real implementation, we would use proper encryption
    # For this example, we'll just use a simple XOR with the key hash
    
    # Convert message to JSON string
    message_str = JSON3.write(message)
    
    # Get key hash
    key_hash = bytes2hex(sha256(key))
    
    # XOR encrypt
    encrypted = Vector{UInt8}(undef, length(message_str))
    for i in 1:length(message_str)
        key_char = key_hash[mod1(i, length(key_hash))]
        encrypted[i] = xor(UInt8(message_str[i]), UInt8(key_char))
    end
    
    # Base64 encode
    encoded = base64encode(encrypted)
    
    return Dict(
        "encrypted" => true,
        "data" => encoded,
        "algorithm" => "xor-sha256"
    )
end

"""
    decrypt_message(encrypted::Dict, key::String)

Decrypt a message using a shared key.

# Arguments
- `encrypted::Dict`: Encrypted message
- `key::String`: Encryption key

# Returns
- `Dict`: Decrypted message
"""
function decrypt_message(encrypted::Dict, key::String)
    # Check if message is encrypted
    if !get(encrypted, "encrypted", false)
        return encrypted
    end
    
    # Check algorithm
    if get(encrypted, "algorithm", "") != "xor-sha256"
        return Dict("success" => false, "error" => "Unsupported encryption algorithm")
    end
    
    # Get encrypted data
    encoded = get(encrypted, "data", "")
    if encoded == ""
        return Dict("success" => false, "error" => "No encrypted data")
    end
    
    # Base64 decode
    encrypted_data = base64decode(encoded)
    
    # Get key hash
    key_hash = bytes2hex(sha256(key))
    
    # XOR decrypt
    decrypted = Vector{UInt8}(undef, length(encrypted_data))
    for i in 1:length(encrypted_data)
        key_char = key_hash[mod1(i, length(key_hash))]
        decrypted[i] = xor(encrypted_data[i], UInt8(key_char))
    end
    
    # Parse JSON
    try
        return JSON3.read(String(decrypted), Dict)
    catch e
        return Dict("success" => false, "error" => "Failed to decrypt message: $(string(e))")
    end
end

"""
    set_agent_role(secure_swarm::SecureSwarm, agent_id::String, role::String, admin_token::String)

Set the role for an agent.

# Arguments
- `secure_swarm::SecureSwarm`: The secure swarm
- `agent_id::String`: ID of the agent
- `role::String`: Role to set
- `admin_token::String`: Admin authentication token

# Returns
- `Dict`: Result of the operation
"""
function set_agent_role(secure_swarm::SecureSwarm, agent_id::String, role::String, admin_token::String)
    swarm_id = secure_swarm.swarm_id
    
    # Get swarm
    swarm = Swarms.getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end
    
    # Check if agent is in swarm
    if !(agent_id in swarm.agent_ids)
        return Dict("success" => false, "error" => "Agent $agent_id not in swarm")
    end
    
    # Find admin agent
    admin_id = nothing
    for (id, token_data) in secure_swarm.auth_tokens
        if token_data["token"] == admin_token && get(secure_swarm.agent_roles, id, "") == "admin"
            admin_id = id
            break
        end
    end
    
    if admin_id === nothing
        return Dict("success" => false, "error" => "Invalid admin token")
    end
    
    # Set role
    secure_swarm.agent_roles[agent_id] = role
    
    # Update shared state
    Swarms.updateSharedState!(swarm_id, "agent_roles", secure_swarm.agent_roles)
    
    return Dict("success" => true, "message" => "Agent role set successfully")
end

end # module
