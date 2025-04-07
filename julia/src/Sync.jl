module Sync

using Dates
using Logging
using JSON

# Import our storage modules
include("Storage.jl")
include("Web3Storage.jl")

# =====================
# Configuration
# =====================

# Global configuration
sync_enabled = false
auto_sync_interval = 60 * 60  # 1 hour by default
last_sync_time = nothing
sync_preferences = Dict{String, Bool}(
    "agents" => true,
    "swarms" => true,
    "transactions" => false,  # Default to not sync sensitive transaction data
    "settings" => true
)

# Initialize sync configuration
function init_sync(db=Storage.DB)
    global sync_enabled, auto_sync_interval, sync_preferences
    
    # Load sync preferences from database
    prefs = Storage.get_setting(db, "sync_preferences", nothing)
    if prefs !== nothing
        sync_preferences = prefs
    end
    
    auto_sync = Storage.get_setting(db, "auto_sync_interval", nothing)
    if auto_sync !== nothing
        auto_sync_interval = auto_sync
    end
    
    sync_status = Storage.get_setting(db, "sync_enabled", nothing)
    if sync_status !== nothing
        sync_enabled = sync_status
    end
    
    if sync_enabled
        @info "Sync initialized. Auto-sync interval: $(auto_sync_interval / 60) minutes"
    else
        @info "Sync initialized but disabled. Use enable_sync() to enable."
    end
    
    return Dict(
        "sync_enabled" => sync_enabled,
        "auto_sync_interval" => auto_sync_interval,
        "sync_preferences" => sync_preferences
    )
end

# Enable/disable sync
function enable_sync(enabled=true, db=Storage.DB)
    global sync_enabled
    sync_enabled = enabled
    Storage.save_setting(db, "sync_enabled", enabled)
    
    status = enabled ? "enabled" : "disabled"
    @info "Sync $status"
    
    return Dict("success" => true, "sync_enabled" => enabled)
end

# Set sync preferences
function set_sync_preferences(prefs, db=Storage.DB)
    global sync_preferences
    
    for (key, value) in pairs(prefs)
        if haskey(sync_preferences, key)
            sync_preferences[key] = value
        end
    end
    
    Storage.save_setting(db, "sync_preferences", sync_preferences)
    
    @info "Sync preferences updated: $sync_preferences"
    
    return Dict("success" => true, "sync_preferences" => sync_preferences)
end

# Set auto-sync interval (in seconds)
function set_auto_sync_interval(interval, db=Storage.DB)
    global auto_sync_interval
    auto_sync_interval = interval
    Storage.save_setting(db, "auto_sync_interval", interval)
    
    @info "Auto-sync interval set to $(interval / 60) minutes"
    
    return Dict("success" => true, "auto_sync_interval" => interval)
end

# =====================
# Agent Synchronization
# =====================

# Sync a single agent between local and web3 storage
function sync_agent(agent_id, direction=:both, db=Storage.DB)
    if !sync_enabled || !sync_preferences["agents"]
        return Dict("success" => false, "error" => "Agent sync disabled")
    end
    
    # Get agent from local storage
    local_agent = Storage.get_agent(db, agent_id)
    if local_agent === nothing
        return Dict("success" => false, "error" => "Agent not found: $agent_id")
    end
    
    # Check if agent has web3 storage info
    web3_storage_info = nothing
    if haskey(local_agent, :storage) || haskey(local_agent, "storage")
        storage_info = haskey(local_agent, :storage) ? local_agent[:storage] : local_agent["storage"]
        if typeof(storage_info) == String
            try
                storage_info = JSON.parse(storage_info)
            catch
                @warn "Failed to parse storage info as JSON"
            end
        end
        
        if typeof(storage_info) <: Dict && haskey(storage_info, "type") && storage_info["type"] == "web3"
            web3_storage_info = storage_info
        end
    end
    
    # Local to Web3 sync
    if direction == :local_to_web3 || direction == :both
        # If no web3 storage yet, create new
        if web3_storage_info === nothing
            @info "Creating new web3 storage for agent $agent_id"
            web3_result = Web3Storage.store_agent(convert_to_dict(local_agent))
            
            if web3_result["success"]
                # Update local agent with web3 storage info
                storage_info = Dict(
                    "type" => "web3",
                    "ceramic_doc_id" => web3_result["ceramic_doc_id"],
                    "large_data" => web3_result["large_data"],
                    "last_synced" => string(now())
                )
                
                Storage.update_agent(db, agent_id, Dict("storage" => JSON.json(storage_info)))
                
                @info "Agent $agent_id synced to web3 storage"
                return Dict("success" => true, "action" => "created_in_web3", "storage_info" => storage_info)
            else
                @error "Failed to create web3 storage for agent $agent_id: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        else
            # Update existing web3 storage
            @info "Updating web3 storage for agent $agent_id"
            web3_result = Web3Storage.update_agent(
                web3_storage_info["ceramic_doc_id"],
                convert_to_dict(local_agent)
            )
            
            if web3_result["success"]
                # Update sync timestamp
                web3_storage_info["last_synced"] = string(now())
                
                Storage.update_agent(db, agent_id, Dict("storage" => JSON.json(web3_storage_info)))
                
                @info "Agent $agent_id updated in web3 storage"
                return Dict("success" => true, "action" => "updated_in_web3")
            else
                @error "Failed to update agent $agent_id in web3 storage: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        end
    end
    
    # Web3 to Local sync
    if (direction == :web3_to_local || direction == :both) && web3_storage_info !== nothing
        @info "Retrieving agent $agent_id from web3 storage"
        web3_result = Web3Storage.retrieve_agent(web3_storage_info["ceramic_doc_id"])
        
        if web3_result["success"]
            web3_agent = web3_result["agent"]
            
            # Preserve local ID
            web3_agent["id"] = agent_id
            
            # Update local agent with web3 data
            updates = Dict()
            for (key, value) in pairs(web3_agent)
                if key != "id" && key != "storage"
                    updates[key] = value
                end
            end
            
            # Update sync timestamp in storage info
            web3_storage_info["last_synced"] = string(now())
            updates["storage"] = JSON.json(web3_storage_info)
            
            Storage.update_agent(db, agent_id, updates)
            
            @info "Agent $agent_id updated from web3 storage"
            return Dict("success" => true, "action" => "updated_from_web3")
        else
            @error "Failed to retrieve agent $agent_id from web3 storage: $(web3_result["error"])"
            return Dict("success" => false, "error" => web3_result["error"])
        end
    end
    
    return Dict("success" => true, "action" => "no_action_needed")
end

# Sync all agents
function sync_all_agents(direction=:both, db=Storage.DB)
    if !sync_enabled || !sync_preferences["agents"]
        return Dict("success" => false, "error" => "Agent sync disabled")
    end
    
    @info "Starting sync for all agents"
    
    # Get all agents from local storage
    local_agents = Storage.list_agents(db)
    
    results = Dict()
    for agent in local_agents
        agent_id = haskey(agent, :id) ? agent[:id] : agent["id"]
        results[agent_id] = sync_agent(agent_id, direction, db)
    end
    
    @info "Completed sync for $(length(local_agents)) agents"
    
    return Dict("success" => true, "results" => results)
end

# =====================
# Swarm Synchronization
# =====================

# Sync a single swarm between local and web3 storage
function sync_swarm(swarm_id, direction=:both, db=Storage.DB)
    if !sync_enabled || !sync_preferences["swarms"]
        return Dict("success" => false, "error" => "Swarm sync disabled")
    end
    
    # Get swarm from local storage
    local_swarm = Storage.get_swarm(db, swarm_id)
    if local_swarm === nothing
        return Dict("success" => false, "error" => "Swarm not found: $swarm_id")
    end
    
    # Check if swarm has web3 storage info
    web3_storage_info = nothing
    if haskey(local_swarm, :storage) || haskey(local_swarm, "storage")
        storage_info = haskey(local_swarm, :storage) ? local_swarm[:storage] : local_swarm["storage"]
        if typeof(storage_info) == String
            try
                storage_info = JSON.parse(storage_info)
            catch
                @warn "Failed to parse storage info as JSON"
            end
        end
        
        if typeof(storage_info) <: Dict && haskey(storage_info, "type") && storage_info["type"] == "web3"
            web3_storage_info = storage_info
        end
    end
    
    # Local to Web3 sync
    if direction == :local_to_web3 || direction == :both
        # If no web3 storage yet, create new
        if web3_storage_info === nothing
            @info "Creating new web3 storage for swarm $swarm_id"
            
            # Get agents in this swarm
            swarm_agents = Storage.get_swarm_agents(db, swarm_id)
            agent_ids = [haskey(a, :id) ? a[:id] : a["id"] for a in swarm_agents]
            
            # Add agent IDs to swarm data
            swarm_data = convert_to_dict(local_swarm)
            swarm_data["agent_ids"] = agent_ids
            
            web3_result = Web3Storage.store_swarm(swarm_data)
            
            if web3_result["success"]
                # Update local swarm with web3 storage info
                storage_info = Dict(
                    "type" => "web3",
                    "ceramic_doc_id" => web3_result["ceramic_doc_id"],
                    "large_data" => web3_result["large_data"],
                    "last_synced" => string(now())
                )
                
                Storage.update_swarm(db, swarm_id, Dict("storage" => JSON.json(storage_info)))
                
                @info "Swarm $swarm_id synced to web3 storage"
                return Dict("success" => true, "action" => "created_in_web3", "storage_info" => storage_info)
            else
                @error "Failed to create web3 storage for swarm $swarm_id: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        else
            # Update existing web3 storage
            @info "Updating web3 storage for swarm $swarm_id"
            
            # Get agents in this swarm
            swarm_agents = Storage.get_swarm_agents(db, swarm_id)
            agent_ids = [haskey(a, :id) ? a[:id] : a["id"] for a in swarm_agents]
            
            # Add agent IDs to swarm data
            swarm_data = convert_to_dict(local_swarm)
            swarm_data["agent_ids"] = agent_ids
            
            web3_result = Web3Storage.update_swarm(
                web3_storage_info["ceramic_doc_id"],
                swarm_data
            )
            
            if web3_result["success"]
                # Update sync timestamp
                web3_storage_info["last_synced"] = string(now())
                
                Storage.update_swarm(db, swarm_id, Dict("storage" => JSON.json(web3_storage_info)))
                
                @info "Swarm $swarm_id updated in web3 storage"
                return Dict("success" => true, "action" => "updated_in_web3")
            else
                @error "Failed to update swarm $swarm_id in web3 storage: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        end
    end
    
    # Web3 to Local sync
    if (direction == :web3_to_local || direction == :both) && web3_storage_info !== nothing
        @info "Retrieving swarm $swarm_id from web3 storage"
        web3_result = Web3Storage.retrieve_swarm(web3_storage_info["ceramic_doc_id"])
        
        if web3_result["success"]
            web3_swarm = web3_result["swarm"]
            
            # Preserve local ID
            web3_swarm["id"] = swarm_id
            
            # Extract agent IDs if present
            agent_ids = nothing
            if haskey(web3_swarm, "agent_ids")
                agent_ids = web3_swarm["agent_ids"]
                delete!(web3_swarm, "agent_ids")
            end
            
            # Update local swarm with web3 data
            updates = Dict()
            for (key, value) in pairs(web3_swarm)
                if key != "id" && key != "storage"
                    updates[key] = value
                end
            end
            
            # Update sync timestamp in storage info
            web3_storage_info["last_synced"] = string(now())
            updates["storage"] = JSON.json(web3_storage_info)
            
            Storage.update_swarm(db, swarm_id, updates)
            
            # If agent_ids was present, sync the agents in the swarm
            if agent_ids !== nothing
                # First get current agents in swarm
                current_agents = Storage.get_swarm_agents(db, swarm_id)
                current_agent_ids = [haskey(a, :id) ? a[:id] : a["id"] for a in current_agents]
                
                # Add new agents
                for agent_id in agent_ids
                    if !(agent_id in current_agent_ids)
                        if Storage.get_agent(db, agent_id) !== nothing
                            Storage.add_agent_to_swarm(db, swarm_id, agent_id)
                            @info "Added agent $agent_id to swarm $swarm_id during sync"
                        else
                            @warn "Agent $agent_id not found locally during swarm sync"
                        end
                    end
                end
                
                # Remove agents not in the web3 version
                for agent_id in current_agent_ids
                    if !(agent_id in agent_ids)
                        Storage.remove_agent_from_swarm(db, swarm_id, agent_id)
                        @info "Removed agent $agent_id from swarm $swarm_id during sync"
                    end
                end
            end
            
            @info "Swarm $swarm_id updated from web3 storage"
            return Dict("success" => true, "action" => "updated_from_web3")
        else
            @error "Failed to retrieve swarm $swarm_id from web3 storage: $(web3_result["error"])"
            return Dict("success" => false, "error" => web3_result["error"])
        end
    end
    
    return Dict("success" => true, "action" => "no_action_needed")
end

# Sync all swarms
function sync_all_swarms(direction=:both, db=Storage.DB)
    if !sync_enabled || !sync_preferences["swarms"]
        return Dict("success" => false, "error" => "Swarm sync disabled")
    end
    
    @info "Starting sync for all swarms"
    
    # Get all swarms from local storage
    local_swarms = Storage.list_swarms(db)
    
    results = Dict()
    for swarm in local_swarms
        swarm_id = haskey(swarm, :id) ? swarm[:id] : swarm["id"]
        results[swarm_id] = sync_swarm(swarm_id, direction, db)
    end
    
    @info "Completed sync for $(length(local_swarms)) swarms"
    
    return Dict("success" => true, "results" => results)
end

# =====================
# Settings Synchronization
# =====================

# Sync settings between local and web3 storage
function sync_settings(direction=:both, db=Storage.DB)
    if !sync_enabled || !sync_preferences["settings"]
        return Dict("success" => false, "error" => "Settings sync disabled")
    end
    
    @info "Syncing settings"
    
    # Get all settings from local storage (except sensitive ones)
    local_settings = Storage.list_settings(db)
    
    # Filter out sensitive settings
    sensitive_keys = ["api_keys", "private_keys", "wallet_data"]
    filtered_settings = Dict()
    
    for setting in local_settings
        key = haskey(setting, :key) ? setting[:key] : setting["key"]
        if !(key in sensitive_keys) && !startswith(key, "private_") && !endswith(key, "_key")
            value = haskey(setting, :value) ? setting[:value] : setting["value"]
            filtered_settings[key] = value
        end
    end
    
    # Get settings storage info
    settings_storage_info = Storage.get_setting(db, "settings_storage_info", nothing)
    if typeof(settings_storage_info) == String
        try
            settings_storage_info = JSON.parse(settings_storage_info)
        catch
            settings_storage_info = nothing
        end
    end
    
    # Local to Web3 sync
    if direction == :local_to_web3 || direction == :both
        # If no web3 storage yet, create new
        if settings_storage_info === nothing
            @info "Creating new web3 storage for settings"
            web3_result = Web3Storage.create_ceramic_document(filtered_settings, schema="settings")
            
            if web3_result["success"]
                # Store the storage info
                storage_info = Dict(
                    "type" => "web3",
                    "ceramic_doc_id" => web3_result["document_id"],
                    "last_synced" => string(now())
                )
                
                Storage.save_setting(db, "settings_storage_info", storage_info)
                
                @info "Settings synced to web3 storage"
                return Dict("success" => true, "action" => "created_in_web3", "storage_info" => storage_info)
            else
                @error "Failed to create web3 storage for settings: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        else
            # Update existing web3 storage
            @info "Updating settings in web3 storage"
            web3_result = Web3Storage.update_ceramic_document(
                settings_storage_info["ceramic_doc_id"],
                filtered_settings
            )
            
            if web3_result["success"]
                # Update sync timestamp
                settings_storage_info["last_synced"] = string(now())
                Storage.save_setting(db, "settings_storage_info", settings_storage_info)
                
                @info "Settings updated in web3 storage"
                return Dict("success" => true, "action" => "updated_in_web3")
            else
                @error "Failed to update settings in web3 storage: $(web3_result["error"])"
                return Dict("success" => false, "error" => web3_result["error"])
            end
        end
    end
    
    # Web3 to Local sync
    if (direction == :web3_to_local || direction == :both) && settings_storage_info !== nothing
        @info "Retrieving settings from web3 storage"
        web3_result = Web3Storage.get_ceramic_document(settings_storage_info["ceramic_doc_id"])
        
        if web3_result["success"]
            web3_settings = web3_result["content"]
            
            # Update local settings
            for (key, value) in pairs(web3_settings)
                if !(key in sensitive_keys) && !startswith(key, "private_") && !endswith(key, "_key")
                    Storage.save_setting(db, key, value)
                end
            end
            
            # Update sync timestamp
            settings_storage_info["last_synced"] = string(now())
            Storage.save_setting(db, "settings_storage_info", settings_storage_info)
            
            @info "Settings updated from web3 storage"
            return Dict("success" => true, "action" => "updated_from_web3")
        else
            @error "Failed to retrieve settings from web3 storage: $(web3_result["error"])"
            return Dict("success" => false, "error" => web3_result["error"])
        end
    end
    
    return Dict("success" => true, "action" => "no_action_needed")
end

# =====================
# Full Synchronization
# =====================

# Sync everything
function sync_all(direction=:both, db=Storage.DB)
    if !sync_enabled
        return Dict("success" => false, "error" => "Sync disabled")
    end
    
    @info "Starting full sync"
    global last_sync_time
    last_sync_time = now()
    
    results = Dict()
    
    if sync_preferences["agents"]
        results["agents"] = sync_all_agents(direction, db)
    end
    
    if sync_preferences["swarms"]
        results["swarms"] = sync_all_swarms(direction, db)
    end
    
    if sync_preferences["settings"]
        results["settings"] = sync_settings(direction, db)
    end
    
    # Store last sync time
    Storage.save_setting(db, "last_sync_time", string(last_sync_time))
    
    @info "Full sync completed"
    
    return Dict("success" => true, "results" => results, "last_sync_time" => last_sync_time)
end

# =====================
# Auto-Sync Scheduler
# =====================

# Check if auto-sync is due
function is_auto_sync_due()
    if !sync_enabled || last_sync_time === nothing
        return false
    end
    
    elapsed = Dates.value(now() - last_sync_time) / 1000  # in seconds
    return elapsed >= auto_sync_interval
end

# Get sync status
function get_sync_status(db=Storage.DB)
    last_time = Storage.get_setting(db, "last_sync_time", nothing)
    
    if last_time !== nothing
        last_time_date = try
            DateTime(last_time)
        catch
            nothing
        end
    else
        last_time_date = nothing
    end
    
    return Dict(
        "sync_enabled" => sync_enabled,
        "auto_sync_interval" => auto_sync_interval,
        "sync_preferences" => sync_preferences,
        "last_sync_time" => last_time_date,
        "auto_sync_due" => is_auto_sync_due()
    )
end

# =====================
# Helper Functions
# =====================

# Convert symbols to strings in dict keys
function convert_to_dict(obj)
    if typeof(obj) <: Dict
        result = Dict{String, Any}()
        for (k, v) in pairs(obj)
            key = typeof(k) == Symbol ? string(k) : k
            if typeof(v) <: Dict
                result[key] = convert_to_dict(v)
            elseif typeof(v) <: Vector
                result[key] = [typeof(x) <: Dict ? convert_to_dict(x) : x for x in v]
            else
                result[key] = v
            end
        end
        return result
    end
    return obj
end

end # module 