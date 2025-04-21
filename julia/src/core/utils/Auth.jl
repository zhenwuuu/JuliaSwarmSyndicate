module Auth

export initialize, authenticate, authorize, create_user, verify_token
export generate_token, invalidate_token, hash_password, verify_password
export Permission, Role, User, Session, AuthenticationError, AuthorizationError
export is_authorized, has_permission, require_permission

using ..EnhancedErrors
using ..StructuredLogging
using ..EnhancedConfig
using ..Utils
using ..Validation

using Dates
using UUIDs
using Random
using SHA
using Base64

using MbedTLS: digest, MD

"""
    Permission

Represents a specific action that can be performed on a resource.
"""
struct Permission
    name::String
    resource::String
    action::String
    description::String
    
    function Permission(name::String, resource::String, action::String; description::String="")
        return new(name, resource, action, description)
    end
end

"""
    Role

Represents a set of permissions that can be assigned to users.
"""
struct Role
    id::String
    name::String
    description::String
    permissions::Vector{String}  # Permission names
    
    function Role(name::String, permissions::Vector{String}; 
                 id::String=string(uuid4()), description::String="")
        return new(id, name, description, permissions)
    end
end

"""
    User

Represents an authenticated user of the system.
"""
struct User
    id::String
    username::String
    password_hash::String
    salt::String
    roles::Vector{String}  # Role IDs
    email::String
    created_at::DateTime
    last_login::Union{DateTime, Nothing}
    is_active::Bool
    metadata::Dict{String, Any}
    
    function User(username::String, password_hash::String, salt::String, roles::Vector{String};
                 id::String=string(uuid4()), email::String="", 
                 metadata::Dict{String, Any}=Dict{String, Any}(),
                 is_active::Bool=true)
        return new(
            id, 
            username, 
            password_hash, 
            salt, 
            roles, 
            email, 
            now(), 
            nothing, 
            is_active, 
            metadata
        )
    end
end

"""
    Session

Represents an active user session.
"""
struct Session
    token::String
    user_id::String
    created_at::DateTime
    expires_at::DateTime
    ip_address::String
    user_agent::String
    is_valid::Bool
    
    function Session(user_id::String, token::String, expires_at::DateTime;
                    ip_address::String="", user_agent::String="")
        return new(token, user_id, now(), expires_at, ip_address, user_agent, true)
    end
end

"""
    AuthenticationError

Thrown when authentication fails.
"""
struct AuthenticationError <: Exception
    message::String
    reason::String
    
    AuthenticationError(message::String; reason::String="Invalid credentials") = new(message, reason)
end

"""
    AuthorizationError

Thrown when authorization fails.
"""
struct AuthorizationError <: Exception
    message::String
    permission::String
    user_id::String
    
    AuthorizationError(message::String; 
                      permission::String="unknown", 
                      user_id::String="unknown") = new(message, permission, user_id)
end

# Global state for auth system
mutable struct AuthState
    initialized::Bool
    secret_key::String
    token_expiration_seconds::Int
    permissions::Dict{String, Permission}
    roles::Dict{String, Role}
    users::Dict{String, User}
    sessions::Dict{String, Session}
    default_admin_created::Bool
    
    AuthState() = new(
        false,
        "",
        86400,  # 24 hours
        Dict{String, Permission}(),
        Dict{String, Role}(),
        Dict{String, User}(),
        Dict{String, Session}(),
        false
    )
end

# Singleton instance of auth state
const AUTH_STATE = AuthState()

"""
    initialize(config)

Initialize the authentication system with the given configuration.
"""
function initialize(config=nothing)
    if AUTH_STATE.initialized
        return true
    end
    
    error_context = EnhancedErrors.with_error_context("Auth", "initialize")
    
    log_context = StructuredLogging.LogContext(
        component="Auth",
        operation="initialize"
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Get configuration
            jwt_secret = if config !== nothing && get(config, "jwt_secret", nothing) !== nothing
                config["jwt_secret"]
            elseif EnhancedConfig.get_value("security.jwt_secret", nothing) !== nothing
                EnhancedConfig.get_value("security.jwt_secret")
            else
                # Generate a secure random secret if not provided
                random_bytes = rand(UInt8, 32)
                base64encode(random_bytes)
            end
            
            # Get token expiration
            token_expiration = if config !== nothing && get(config, "token_expiration", nothing) !== nothing
                config["token_expiration"]
            elseif EnhancedConfig.get_value("security.token_expiration", nothing) !== nothing
                EnhancedConfig.get_value("security.token_expiration")
            else
                86400  # 24 hours default
            end
            
            # Set up auth state
            AUTH_STATE.secret_key = jwt_secret
            AUTH_STATE.token_expiration_seconds = token_expiration
            AUTH_STATE.initialized = true
            
            # Register default permissions
            register_default_permissions()
            
            # Register default roles
            register_default_roles()
            
            # Create default admin user if no users exist
            if isempty(AUTH_STATE.users) && !AUTH_STATE.default_admin_created
                create_default_admin()
                AUTH_STATE.default_admin_created = true
            end
            
            StructuredLogging.info("Authentication system initialized")
            
            return true
        catch e
            StructuredLogging.error("Failed to initialize authentication system", 
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to initialize authentication system", 
                                                  e, context=error_context))
            end
            
            return false
        end
    end
end

"""
    register_default_permissions()

Register the default set of permissions for the system.
"""
function register_default_permissions()
    # System permissions
    register_permission(Permission("system.admin", "system", "admin", 
                                  description="Full system administration access"))
    register_permission(Permission("system.view", "system", "view", 
                                  description="View system information"))
    register_permission(Permission("system.configure", "system", "configure", 
                                  description="Configure system settings"))
    
    # User permissions
    register_permission(Permission("user.create", "user", "create", 
                                  description="Create new users"))
    register_permission(Permission("user.read", "user", "read", 
                                  description="Read user information"))
    register_permission(Permission("user.update", "user", "update", 
                                  description="Update user information"))
    register_permission(Permission("user.delete", "user", "delete", 
                                  description="Delete users"))
    
    # Role permissions
    register_permission(Permission("role.create", "role", "create", 
                                  description="Create new roles"))
    register_permission(Permission("role.read", "role", "read", 
                                  description="Read role information"))
    register_permission(Permission("role.update", "role", "update", 
                                  description="Update role information"))
    register_permission(Permission("role.delete", "role", "delete", 
                                  description="Delete roles"))
    
    # Agent permissions
    register_permission(Permission("agent.create", "agent", "create", 
                                  description="Create new agents"))
    register_permission(Permission("agent.read", "agent", "read", 
                                  description="Read agent information"))
    register_permission(Permission("agent.update", "agent", "update", 
                                  description="Update agent configuration"))
    register_permission(Permission("agent.delete", "agent", "delete", 
                                  description="Delete agents"))
    register_permission(Permission("agent.run", "agent", "run", 
                                  description="Run agents"))
    
    # Swarm permissions
    register_permission(Permission("swarm.create", "swarm", "create", 
                                  description="Create new swarms"))
    register_permission(Permission("swarm.read", "swarm", "read", 
                                  description="Read swarm information"))
    register_permission(Permission("swarm.update", "swarm", "update", 
                                  description="Update swarm configuration"))
    register_permission(Permission("swarm.delete", "swarm", "delete", 
                                  description="Delete swarms"))
    register_permission(Permission("swarm.run", "swarm", "run", 
                                  description="Run swarm optimization"))
    
    # Blockchain permissions
    register_permission(Permission("blockchain.read", "blockchain", "read", 
                                  description="Read blockchain data"))
    register_permission(Permission("blockchain.transact", "blockchain", "transact", 
                                  description="Send blockchain transactions"))
    
    # DEX permissions
    register_permission(Permission("dex.read", "dex", "read", 
                                  description="Read DEX data"))
    register_permission(Permission("dex.trade", "dex", "trade", 
                                  description="Execute DEX trades"))
    
    # Bridge permissions
    register_permission(Permission("bridge.read", "bridge", "read", 
                                  description="Read bridge data"))
    register_permission(Permission("bridge.transfer", "bridge", "transfer", 
                                  description="Execute bridge transfers"))
    
    # API permissions
    register_permission(Permission("api.access", "api", "access", 
                                  description="Access the API"))
    register_permission(Permission("api.admin", "api", "admin", 
                                  description="Administer the API"))
end

"""
    register_default_roles()

Register the default set of roles for the system.
"""
function register_default_roles()
    # Admin role
    register_role(Role("admin", [
        "system.admin",
        "user.create", "user.read", "user.update", "user.delete",
        "role.create", "role.read", "role.update", "role.delete",
        "agent.create", "agent.read", "agent.update", "agent.delete", "agent.run",
        "swarm.create", "swarm.read", "swarm.update", "swarm.delete", "swarm.run",
        "blockchain.read", "blockchain.transact",
        "dex.read", "dex.trade",
        "bridge.read", "bridge.transfer",
        "api.access", "api.admin"
    ], description="Administrator with full system access"))
    
    # Readonly role
    register_role(Role("readonly", [
        "system.view",
        "user.read",
        "role.read",
        "agent.read",
        "swarm.read",
        "blockchain.read",
        "dex.read",
        "bridge.read",
        "api.access"
    ], description="Read-only access to all resources"))
    
    # Agent manager role
    register_role(Role("agent_manager", [
        "agent.create", "agent.read", "agent.update", "agent.delete", "agent.run",
        "api.access"
    ], description="Manage and run agents"))
    
    # Swarm manager role
    register_role(Role("swarm_manager", [
        "swarm.create", "swarm.read", "swarm.update", "swarm.delete", "swarm.run",
        "api.access"
    ], description="Manage and run swarms"))
    
    # Trader role
    register_role(Role("trader", [
        "blockchain.read", "blockchain.transact",
        "dex.read", "dex.trade",
        "bridge.read", "bridge.transfer",
        "api.access"
    ], description="Execute trades and transfers"))
end

"""
    create_default_admin()

Create a default admin user if no users exist.
"""
function create_default_admin()
    # Generate a strong random password
    password_length = 16
    charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*()-_=+"
    password = join(rand(charset, password_length))
    
    # Create admin user
    admin = create_user("admin", password, ["admin"], email="admin@juliaos.local")
    
    # Log the temporary password (in a real system, we would email this or use another secure channel)
    StructuredLogging.info("Created default admin user", 
                          data=Dict(
                              "username" => "admin",
                              "temporary_password" => password,
                              "note" => "Please change this password immediately!"
                          ))
    
    return admin
end

"""
    register_permission(permission::Permission)

Register a new permission in the system.
"""
function register_permission(permission::Permission)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    AUTH_STATE.permissions[permission.name] = permission
    
    StructuredLogging.debug("Registered permission", 
                           data=Dict("name" => permission.name, 
                                    "resource" => permission.resource,
                                    "action" => permission.action))
    
    return permission
end

"""
    register_role(role::Role)

Register a new role in the system.
"""
function register_role(role::Role)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Validate that all permissions exist
    for permission_name in role.permissions
        if !haskey(AUTH_STATE.permissions, permission_name)
            error_context = EnhancedErrors.with_error_context("Auth", "register_role", 
                                                             metadata=Dict("role" => role.name,
                                                                          "permission" => permission_name))
            
            StructuredLogging.error("Cannot register role with unknown permission", 
                                   data=Dict("role" => role.name, "permission" => permission_name))
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.ValidationError("Unknown permission: $permission_name", 
                                                    context=error_context))
            end
        end
    end
    
    AUTH_STATE.roles[role.id] = role
    
    StructuredLogging.debug("Registered role", 
                           data=Dict("id" => role.id, 
                                    "name" => role.name, 
                                    "permission_count" => length(role.permissions)))
    
    return role
end

"""
    create_user(username::String, password::String, roles::Vector{String}; email::String="", metadata::Dict{String, Any}=Dict{String, Any}())

Create a new user with the given username, password, and roles.
"""
function create_user(username::String, password::String, roles::Vector{String}; 
                    email::String="", metadata::Dict{String, Any}=Dict{String, Any}())
    if !AUTH_STATE.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("Auth", "create_user", 
                                                     metadata=Dict("username" => username))
    
    log_context = StructuredLogging.LogContext(
        component="Auth",
        operation="create_user",
        metadata=Dict("username" => username)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Validate username (minimum length 3, alphanumeric + underscore)
            if !occursin(r"^[a-zA-Z0-9_]{3,}$", username)
                StructuredLogging.error("Invalid username format", 
                                       data=Dict("username" => username))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.ValidationError("Username must be at least 3 characters and contain only letters, numbers, and underscores", 
                                                        context=error_context))
                end
            end
            
            # Check if username already exists
            for (_, user) in AUTH_STATE.users
                if lowercase(user.username) == lowercase(username)
                    StructuredLogging.error("Username already exists", 
                                           data=Dict("username" => username))
                    
                    EnhancedErrors.try_operation(error_context) do
                        throw(EnhancedErrors.ValidationError("Username already exists", 
                                                            context=error_context))
                    end
                end
            end
            
            # Validate roles exist
            for role_id in roles
                if !haskey(AUTH_STATE.roles, role_id)
                    StructuredLogging.error("Cannot create user with unknown role", 
                                           data=Dict("username" => username, "role" => role_id))
                    
                    EnhancedErrors.try_operation(error_context) do
                        throw(EnhancedErrors.ValidationError("Unknown role: $role_id", 
                                                            context=error_context))
                    end
                end
            end
            
            # Hash password
            salt = generate_salt()
            password_hash = hash_password(password, salt)
            
            # Create user
            user = User(
                username,
                password_hash,
                salt,
                roles,
                id=string(uuid4()),
                email=email,
                metadata=metadata
            )
            
            # Store user
            AUTH_STATE.users[user.id] = user
            
            StructuredLogging.info("Created user", 
                                  data=Dict("id" => user.id, 
                                           "username" => user.username,
                                           "roles" => user.roles))
            
            return user
        catch e
            StructuredLogging.error("Failed to create user", 
                                   data=Dict("username" => username),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to create user", e, 
                                                      context=error_context))
                end
            end
        end
    end
end

"""
    authenticate(username::String, password::String; ip_address::String="", user_agent::String="")

Authenticate a user with the given username and password.
Returns a session token if successful, throws an AuthenticationError otherwise.
"""
function authenticate(username::String, password::String; 
                     ip_address::String="", user_agent::String="")
    if !AUTH_STATE.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("Auth", "authenticate", 
                                                     metadata=Dict("username" => username,
                                                                  "ip_address" => ip_address))
    
    log_context = StructuredLogging.LogContext(
        component="Auth",
        operation="authenticate",
        metadata=Dict("username" => username, "ip_address" => ip_address)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Find user by username
            user = nothing
            for (_, u) in AUTH_STATE.users
                if lowercase(u.username) == lowercase(username)
                    user = u
                    break
                end
            end
            
            # Check if user exists
            if user === nothing
                StructuredLogging.warn("Authentication failed: user not found", 
                                      data=Dict("username" => username))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(AuthenticationError("Authentication failed", 
                                             reason="User not found"))
                end
            end
            
            # Check if user is active
            if !user.is_active
                StructuredLogging.warn("Authentication failed: user is inactive", 
                                      data=Dict("username" => username))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(AuthenticationError("Authentication failed", 
                                             reason="User is inactive"))
                end
            end
            
            # Verify password
            if !verify_password(password, user.password_hash, user.salt)
                StructuredLogging.warn("Authentication failed: invalid password", 
                                      data=Dict("username" => username))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(AuthenticationError("Authentication failed", 
                                             reason="Invalid password"))
                end
            end
            
            # Generate session token
            token = generate_token(user.id)
            
            # Calculate expiration time
            expires_at = now() + Dates.Second(AUTH_STATE.token_expiration_seconds)
            
            # Create session
            session = Session(user.id, token, expires_at, 
                             ip_address=ip_address, user_agent=user_agent)
            
            # Store session
            AUTH_STATE.sessions[token] = session
            
            # Update last login time
            user_copy = User(
                user.username,
                user.password_hash,
                user.salt,
                user.roles,
                id=user.id,
                email=user.email,
                metadata=user.metadata,
                is_active=user.is_active
            )
            AUTH_STATE.users[user.id] = user_copy
            
            StructuredLogging.info("User authenticated successfully", 
                                  data=Dict("user_id" => user.id, 
                                           "username" => user.username,
                                           "expires_at" => string(expires_at)))
            
            return token
        catch e
            if e isa AuthenticationError
                # This is an expected error, already logged with a warning
                EnhancedErrors.try_operation(error_context) do
                    rethrow(e)
                end
            else
                StructuredLogging.error("Unexpected error during authentication", 
                                       exception=e)
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.InternalError("Authentication failed due to internal error", 
                                                      e, context=error_context))
                end
            end
        end
    end
end

"""
    verify_token(token::String)

Verify a session token and return the associated user ID if valid.
Returns nothing if the token is invalid or expired.
"""
function verify_token(token::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Check if token exists
    if !haskey(AUTH_STATE.sessions, token)
        return nothing
    end
    
    session = AUTH_STATE.sessions[token]
    
    # Check if session is valid
    if !session.is_valid
        return nothing
    end
    
    # Check if session has expired
    if now() > session.expires_at
        # Invalidate session
        invalidate_token(token)
        return nothing
    end
    
    return session.user_id
end

"""
    authorize(token::String, permission::String)

Check if a user has the specified permission.
Returns true if authorized, false otherwise.
"""
function authorize(token::String, permission::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Verify token and get user ID
    user_id = verify_token(token)
    if user_id === nothing
        return false
    end
    
    # Get user
    if !haskey(AUTH_STATE.users, user_id)
        return false
    end
    
    user = AUTH_STATE.users[user_id]
    
    # Check if user is active
    if !user.is_active
        return false
    end
    
    # Check if permission exists
    if !haskey(AUTH_STATE.permissions, permission)
        return false
    end
    
    # Check user roles for permission
    for role_id in user.roles
        if !haskey(AUTH_STATE.roles, role_id)
            continue
        end
        
        role = AUTH_STATE.roles[role_id]
        
        if permission in role.permissions
            return true
        end
    end
    
    return false
end

"""
    is_authorized(token::String, permission::String)

Check if a user has the specified permission.
This is an alias for authorize() for more readable code.
"""
function is_authorized(token::String, permission::String)
    return authorize(token, permission)
end

"""
    has_permission(user_id::String, permission::String)

Check if a user has the specified permission.
"""
function has_permission(user_id::String, permission::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Get user
    if !haskey(AUTH_STATE.users, user_id)
        return false
    end
    
    user = AUTH_STATE.users[user_id]
    
    # Check if user is active
    if !user.is_active
        return false
    end
    
    # Check if permission exists
    if !haskey(AUTH_STATE.permissions, permission)
        return false
    end
    
    # Check user roles for permission
    for role_id in user.roles
        if !haskey(AUTH_STATE.roles, role_id)
            continue
        end
        
        role = AUTH_STATE.roles[role_id]
        
        if permission in role.permissions
            return true
        end
    end
    
    return false
end

"""
    require_permission(token::String, permission::String)

Require that a user has the specified permission.
Throws an AuthorizationError if the user does not have the permission.
"""
function require_permission(token::String, permission::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Verify token and get user ID
    user_id = verify_token(token)
    if user_id === nothing
        throw(AuthenticationError("Authentication required", reason="Invalid or expired token"))
    end
    
    error_context = EnhancedErrors.with_error_context("Auth", "require_permission", 
                                                     metadata=Dict("user_id" => user_id,
                                                                  "permission" => permission))
    
    # Check permission
    if !has_permission(user_id, permission)
        StructuredLogging.warn("Authorization failed: permission denied", 
                              data=Dict("user_id" => user_id, "permission" => permission))
        
        EnhancedErrors.try_operation(error_context) do
            throw(AuthorizationError("Permission denied", 
                                    permission=permission, user_id=user_id))
        end
    end
    
    return true
end

"""
    invalidate_token(token::String)

Invalidate a session token.
"""
function invalidate_token(token::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Check if token exists
    if !haskey(AUTH_STATE.sessions, token)
        return false
    end
    
    # Get session
    session = AUTH_STATE.sessions[token]
    
    # Create a new session with is_valid=false
    new_session = Session(
        session.user_id,
        session.token,
        session.expires_at,
        ip_address=session.ip_address,
        user_agent=session.user_agent
    )
    new_session.is_valid = false
    
    # Update session
    AUTH_STATE.sessions[token] = new_session
    
    StructuredLogging.info("Token invalidated", 
                          data=Dict("user_id" => session.user_id))
    
    return true
end

"""
    generate_token(user_id::String)

Generate a JSON Web Token (JWT) for the specified user ID.
"""
function generate_token(user_id::String)
    if !AUTH_STATE.initialized
        initialize()
    end
    
    # Create JWT header
    header = Dict(
        "alg" => "HS256",
        "typ" => "JWT"
    )
    header_json = JSON.json(header)
    header_base64 = base64encode(header_json)
    
    # Create JWT payload
    payload = Dict(
        "sub" => user_id,
        "iat" => round(Int, datetime2unix(now())),
        "exp" => round(Int, datetime2unix(now() + Dates.Second(AUTH_STATE.token_expiration_seconds))),
        "jti" => string(uuid4())
    )
    payload_json = JSON.json(payload)
    payload_base64 = base64encode(payload_json)
    
    # Combine header and payload
    message = header_base64 * "." * payload_base64
    
    # Create signature
    signature = create_signature(message, AUTH_STATE.secret_key)
    signature_base64 = base64encode(signature)
    
    # Combine all parts to create the JWT
    token = message * "." * signature_base64
    
    return token
end

"""
    create_signature(message::String, secret::String)

Create a HMAC-SHA256 signature for a message.
"""
function create_signature(message::String, secret::String)
    return digest(MD.MD_SHA256, message, secret)
end

"""
    hash_password(password::String, salt::String)

Hash a password with the given salt using HMAC-SHA256.
"""
function hash_password(password::String, salt::String)
    # Convert the password and salt to bytes
    password_bytes = Vector{UInt8}(password)
    salt_bytes = Vector{UInt8}(salt)
    
    # Create a salted password (salt + password)
    salted_password = [salt_bytes; password_bytes]
    
    # Hash the salted password
    hash = digest(MD.MD_SHA256, salted_password, salt_bytes)
    
    # Convert the hash to a Base64 string
    return base64encode(hash)
end

"""
    verify_password(password::String, password_hash::String, salt::String)

Verify a password against a hash and salt.
"""
function verify_password(password::String, password_hash::String, salt::String)
    # Hash the provided password
    computed_hash = hash_password(password, salt)
    
    # Compare the computed hash with the stored hash
    return computed_hash == password_hash
end

"""
    generate_salt()

Generate a random salt for password hashing.
"""
function generate_salt()
    # Generate 16 random bytes for the salt
    random_bytes = rand(UInt8, 16)
    
    # Convert the salt to a Base64 string
    return base64encode(random_bytes)
end

end # module
