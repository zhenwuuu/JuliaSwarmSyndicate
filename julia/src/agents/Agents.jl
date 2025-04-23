module Agents

export Agent, AgentConfig, AgentStatus, AgentType,
       createAgent, getAgent, listAgents, updateAgent, deleteAgent,
       startAgent, stopAgent, pauseAgent, resumeAgent, getAgentStatus,
       executeAgentTask, getAgentMemory, setAgentMemory, clearAgentMemory,
       register_ability, register_skill, publish_to_swarm

#=
===========================================================
   JuliaOS – Complete Agent Runtime (all‑in‑one edition)
   Drop‑in replacement for julia/src/agents/Agents.jl
===========================================================
  Features
  --------
  ✔ CRUD & life‑cycle helpers (create/start/pause/stop/etc.)
  ✔ Ability registry (callable functions)
  ✔ Skill engine with XP & scheduling
  ✔ Priority message queue per agent
  ✔ LRU memory w/ OrderedDict
  ✔ Persistent store (JSON on disk) – survives restarts (NOW ATOMIC)
  ✔ Basic Swarm hooks (publish / subscribe)
  ✔ Optional OpenAI chat integration
===========================================================
=#

# ----------------------------------------------------------------------
# DEPENDENCIES
# ----------------------------------------------------------------------
using Dates, Random, UUIDs, Logging, Base.Threads
using DataStructures           # OrderedDict + PriorityQueue
using JSON3                    # light persistence (stdlib in Julia 1.10+)

# ----------------------------------------------------------------------
# CONFIGURATION MANAGEMENT
# ----------------------------------------------------------------------
module Config
    using TOML, Logging
    export load_config, get_config, set_config

    # Default configuration values
    const DEFAULT_CONFIG = Dict(
        "storage" => Dict(
            "path" => joinpath(@__DIR__, "..", "..", "db", "agents_state.json"),
            "backup_enabled" => true,
            "backup_count" => 5,
            "auto_persist" => true
        ),
        "agent" => Dict(
            "max_task_history" => 100,
            "xp_decay_rate" => 0.999,
            "default_sleep_ms" => 1000,
            "paused_sleep_ms" => 500,
            "auto_restart" => false
        ),
        "metrics" => Dict(
            "enabled" => true,
            "collection_interval" => 60, # seconds
            "retention_period" => 86400  # 24 hours in seconds
        ),
        "swarm" => Dict(
            "enabled" => false,
            "backend" => "none", # Options: none, redis, nats, zeromq
            "connection_string" => "",
            "default_topic" => "juliaos.swarm"
        )
    )

    # Current configuration (initialized with defaults)
    const CURRENT_CONFIG = deepcopy(DEFAULT_CONFIG)

    # Load configuration from file
    function load_config(config_path::String="")
        if isempty(config_path)
            # Try default locations
            config_paths = [
                joinpath(@__DIR__, "..", "..", "config", "agents.toml"),
                joinpath(homedir(), ".juliaos", "config", "agents.toml")
            ]

            for path in config_paths
                if isfile(path)
                    config_path = path
                    break
                end
            end
        end

        if !isempty(config_path) && isfile(config_path)
            try
                config_data = TOML.parsefile(config_path)
                # Merge with defaults (keeping defaults for missing values)
                _merge_configs!(CURRENT_CONFIG, config_data)
                @info "Loaded configuration from $config_path"
                return true
            catch e
                @error "Failed to load configuration from $config_path" exception=(e, catch_backtrace())
                return false
            end
        else
            @info "No configuration file found, using defaults"
            return false
        end
    end

    # Helper to recursively merge configs
    function _merge_configs!(target::Dict, source::Dict)
        for (k, v) in source
            if isa(v, Dict) && haskey(target, k) && isa(target[k], Dict)
                _merge_configs!(target[k], v)
            else
                target[k] = v
            end
        end
    end

    # Get configuration value with dot notation
    function get_config(key::String, default=nothing)
        parts = split(key, ".")
        current = CURRENT_CONFIG

        for part in parts[1:end-1]
            if haskey(current, part) && isa(current[part], Dict)
                current = current[part]
            else
                return default
            end
        end

        # Get the value or return the default
        value = get(current, parts[end], default)

        # If the value and default are of different types, try to convert
        if value !== default && default !== nothing && typeof(value) != typeof(default)
            try
                # Convert value to match the type of default
                if isa(default, Number) && (isa(value, AbstractString) || isa(value, Number))
                    if isa(default, Integer)
                        value = isa(value, AbstractString) ? parse(Int, value) : Int(value)
                    elseif isa(default, AbstractFloat)
                        value = isa(value, AbstractString) ? parse(Float64, value) : Float64(value)
                    end
                elseif isa(default, Bool) && isa(value, AbstractString)
                    lowercase_value = lowercase(value)
                    if lowercase_value == "true"
                        value = true
                    elseif lowercase_value == "false"
                        value = false
                    end
                end
            catch
                # If conversion fails, return the default
                return default
            end
        end

        return value
    end

    # Set configuration value with dot notation
    function set_config(key::String, value)
        parts = split(key, ".")
        current = CURRENT_CONFIG

        for part in parts[1:end-1]
            if !haskey(current, part) || !isa(current[part], Dict)
                current[part] = Dict{String, Any}()
            end
            current = current[part]
        end

        # Convert the value to the appropriate type if needed
        if haskey(current, parts[end])
            existing_value = current[parts[end]]
            if isa(existing_value, Number) && isa(value, AbstractString)
                # Try to convert string to number
                try
                    if isa(existing_value, Integer)
                        value = parse(Int, value)
                    elseif isa(existing_value, AbstractFloat)
                        value = parse(Float64, value)
                    end
                catch
                    # If conversion fails, use the original value
                end
            elseif isa(existing_value, Bool) && isa(value, AbstractString)
                # Try to convert string to boolean
                lowercase_value = lowercase(value)
                if lowercase_value == "true"
                    value = true
                elseif lowercase_value == "false"
                    value = false
                end
            end
        end

        current[parts[end]] = value
        return value
    end

    # Load configuration at module initialization
    function __init__()
        load_config()
    end
end

# Import configuration functions
using .Config: get_config, set_config, load_config

# Initialize configuration values from loaded config
const STORE_PATH = get_config("storage.path", joinpath(@__DIR__, "..", "..", "db", "agents_state.json"))
const MAX_TASK_HISTORY = get_config("agent.max_task_history", 100)
const XP_DECAY_RATE = get_config("agent.xp_decay_rate", 0.999)
const DEFAULT_SLEEP_MS = get_config("agent.default_sleep_ms", 1000)
const PAUSED_SLEEP_MS = get_config("agent.paused_sleep_ms", 500)
const AUTO_RESTART = get_config("agent.auto_restart", false)


# ----------------------------------------------------------------------
# ENUMS
# ----------------------------------------------------------------------
@enum AgentType begin
    TRADING = 1; MONITOR = 2; ARBITRAGE = 3; DATA_COLLECTION = 4;
    NOTIFICATION = 5; CUSTOM = 99
end

@enum AgentStatus begin
    CREATED = 1; INITIALIZING = 2; RUNNING = 3;
    PAUSED = 4; STOPPED = 5; ERROR = 6
end

# ----------------------------------------------------------------------
# CONFIG STRUCT
# ----------------------------------------------------------------------
struct AgentConfig
    name::String
    type::AgentType
    abilities::Vector{String}
    chains::Vector{String}
    parameters::Dict{String,Any}
    llm_config::Dict{String,Any}
    memory_config::Dict{String,Any}
    max_task_history::Int # Added config for history limit

    function AgentConfig(name::String, type::AgentType;
                         abilities::Vector{String}=String[], chains::Vector{String}=String[],
                         parameters::Dict{String,Any}=Dict(),
                         llm_config::Dict{String,Any}=Dict(),
                         memory_config::Dict{String,Any}=Dict(),
                         max_task_history::Int=MAX_TASK_HISTORY) # Default history size
        isempty(llm_config) && (llm_config = Dict("provider"=>"openai","model"=>"gpt-4o-mini","temperature"=>0.7,"max_tokens"=>1024))
        isempty(memory_config) && (memory_config = Dict("max_size"=>1000,"retention_policy"=>"lru"))
        new(name, type, abilities, chains, parameters, llm_config, memory_config, max_task_history)
    end
end

# ----------------------------------------------------------------------
# SKILL ENGINE -----------------------------------------------------------
# ----------------------------------------------------------------------
struct Skill
    name::String
    fn::Function
    schedule::Real          # seconds; 0 → on‑demand only
end

mutable struct SkillState
    skill::Skill
    xp::Float64
    last_exec::DateTime
end

const SKILL_REGISTRY = Dict{String,Skill}()

function register_skill(name::String, fn::Function; schedule::Real=0)
    SKILL_REGISTRY[name] = Skill(name, fn, schedule)
    @info "Registered skill $name (schedule = $schedule s)"
end

# ----------------------------------------------------------------------
# MAIN AGENT STRUCTURE
# ----------------------------------------------------------------------
mutable struct Agent
    id::String; name::String; type::AgentType; status::AgentStatus
    created::DateTime; updated::DateTime; config::AgentConfig
    memory::OrderedDict{String,Any}                 # LRU memory
    task_history::Vector{Dict{String,Any}}
    skills::Dict{String,SkillState}
    queue::PriorityQueue{Any,Float64}               # message queue (lower = higher prio)
end

# ----------------------------------------------------------------------
# METRICS COLLECTION
# ----------------------------------------------------------------------
module Metrics
    using Dates, DataStructures, Statistics
    export record_metric, get_metrics, get_agent_metrics, reset_metrics

    # Import the get_config function from parent module
    using ..Config: get_config

    # Metric types
    @enum MetricType begin
        COUNTER = 1    # Monotonically increasing counter (e.g., tasks_executed)
        GAUGE = 2      # Value that can go up and down (e.g., memory_usage)
        HISTOGRAM = 3  # Distribution of values (e.g., execution_time)
        SUMMARY = 4    # Summary statistics (min, max, avg, etc.)
    end

    # Metric data structure
    mutable struct Metric
        name::String
        type::MetricType
        value::Union{Number, Vector{Number}, Dict{String, Any}}
        timestamp::DateTime
        tags::Dict{String, String}
    end

    # Global metrics storage
    # Structure: Dict{agent_id, Dict{metric_name, CircularBuffer{Metric}}}
    const METRICS_STORE = Dict{String, Dict{String, CircularBuffer{Metric}}}()
    const METRICS_LOCK = ReentrantLock()

    # Initialize metrics for an agent
    function init_agent_metrics(agent_id::String)
        lock(METRICS_LOCK) do
            if !haskey(METRICS_STORE, agent_id)
                METRICS_STORE[agent_id] = Dict{String, CircularBuffer{Metric}}()
            end
        end
    end

    # Record a metric for an agent
    function record_metric(agent_id::String, name::String, value::Any;
                          type::MetricType=GAUGE,
                          tags::Dict{String, String}=Dict{String, String}())
        lock(METRICS_LOCK) do
            # Initialize agent metrics if needed
            if !haskey(METRICS_STORE, agent_id)
                init_agent_metrics(agent_id)
            end

            # Initialize metric buffer if needed
            agent_metrics = METRICS_STORE[agent_id]
            if !haskey(agent_metrics, name)
                # Buffer size based on retention period and collection interval
                retention_period = get_config("metrics.retention_period", 86400) # 24 hours
                collection_interval = get_config("metrics.collection_interval", 60) # 60 seconds
                buffer_size = max(100, ceil(Int, retention_period / collection_interval))
                agent_metrics[name] = CircularBuffer{Metric}(buffer_size)
            end

            # Create and store the metric
            metric = Metric(name, type, value, now(), tags)
            push!(agent_metrics[name], metric)

            return metric
        end
    end

    # Get metrics for a specific agent
    function get_agent_metrics(agent_id::String;
                              metric_name::Union{String, Nothing}=nothing,
                              start_time::Union{DateTime, Nothing}=nothing,
                              end_time::Union{DateTime, Nothing}=nothing)
        result = Dict{String, Any}()

        lock(METRICS_LOCK) do
            if !haskey(METRICS_STORE, agent_id)
                return result
            end

            agent_metrics = METRICS_STORE[agent_id]

            # Filter by metric name if specified
            metric_names = isnothing(metric_name) ? keys(agent_metrics) : [metric_name]

            for name in metric_names
                if haskey(agent_metrics, name)
                    # Filter by time range if specified
                    filtered_metrics = collect(agent_metrics[name])
                    if !isnothing(start_time)
                        filter!(m -> m.timestamp >= start_time, filtered_metrics)
                    end
                    if !isnothing(end_time)
                        filter!(m -> m.timestamp <= end_time, filtered_metrics)
                    end

                    # Process metrics based on type
                    if !isempty(filtered_metrics)
                        last_metric = filtered_metrics[end]

                        if last_metric.type == COUNTER || last_metric.type == GAUGE
                            # For counters and gauges, return the latest value and a time series
                            result[name] = Dict(
                                "current" => last_metric.value,
                                "type" => string(last_metric.type),
                                "history" => [(m.timestamp, m.value) for m in filtered_metrics],
                                "last_updated" => last_metric.timestamp
                            )
                        elseif last_metric.type == HISTOGRAM
                            # For histograms, compute statistics
                            all_values = vcat([m.value for m in filtered_metrics]...)
                            if !isempty(all_values)
                                result[name] = Dict(
                                    "type" => "HISTOGRAM",
                                    "count" => length(all_values),
                                    "min" => minimum(all_values),
                                    "max" => maximum(all_values),
                                    "mean" => mean(all_values),
                                    "median" => median(all_values),
                                    "last_updated" => last_metric.timestamp
                                )
                            end
                        elseif last_metric.type == SUMMARY
                            # For summaries, return the latest summary
                            result[name] = Dict(
                                "type" => "SUMMARY",
                                "value" => last_metric.value,
                                "last_updated" => last_metric.timestamp
                            )
                        end
                    end
                end
            end
        end

        return result
    end

    # Get metrics for all agents
    function get_metrics(; metric_name::Union{String, Nothing}=nothing,
                        start_time::Union{DateTime, Nothing}=nothing,
                        end_time::Union{DateTime, Nothing}=nothing)
        result = Dict{String, Dict{String, Any}}()

        lock(METRICS_LOCK) do
            for agent_id in keys(METRICS_STORE)
                agent_metrics = get_agent_metrics(agent_id;
                                                 metric_name=metric_name,
                                                 start_time=start_time,
                                                 end_time=end_time)
                if !isempty(agent_metrics)
                    result[agent_id] = agent_metrics
                end
            end
        end

        return result
    end

    # Reset metrics for an agent or all agents
    function reset_metrics(agent_id::Union{String, Nothing}=nothing)
        lock(METRICS_LOCK) do
            if isnothing(agent_id)
                # Reset all metrics
                empty!(METRICS_STORE)
            elseif haskey(METRICS_STORE, agent_id)
                # Reset metrics for a specific agent
                delete!(METRICS_STORE, agent_id)
            end
        end
    end
end

# Import metrics functions
using .Metrics: record_metric, get_metrics, get_agent_metrics

# ----------------------------------------------------------------------
# GLOBAL REGISTRIES & PERSISTENCE
# ----------------------------------------------------------------------
const AGENTS        = Dict{String,Agent}()
const AGENT_THREADS = Dict{String,Task}()
const ABILITY_REGISTRY = Dict{String,Function}()
const AGENTS_LOCK   = ReentrantLock() # ADDED: Lock for concurrent access to AGENTS dict

# Configuration constants
const DEFAULT_SLEEP_MS = get_config("agent.default_sleep_ms", 1000)
const PAUSED_SLEEP_MS = get_config("agent.paused_sleep_ms", 500)

# Atomic state saving ---------------------------------------------------
function _save_state()
    # !! IMPORTANT: Consider locking AGENTS_LOCK if agents can be modified
    # while saving state from another thread !!
    data = Dict{String, Dict{String, Any}}()
    lock(AGENTS_LOCK) do # Lock during data extraction
        for (id, a) in AGENTS
             data[id] = Dict(
                "id"=>a.id, "name"=>a.name, "type"=>Int(a.type), "status"=>Int(a.status),
                "created"=>string(a.created), "updated"=>string(a.updated),
                "config"=>a.config, # AgentConfig is immutable struct, should serialize ok
                "memory"=>collect(a.memory), # Collect OrderedDict into Vector{Pair}
                # Save skill state (XP and last execution time)
                "skills"=>Dict(k=>Dict("xp"=>s.xp,"last_exec"=>string(s.last_exec)) for (k,s) in a.skills)
            )
        end
    end # Unlock AGENTS_LOCK

    temp_path = STORE_PATH * ".tmp"
    try
        # Ensure directory exists
        store_dir = dirname(STORE_PATH)
        ispath(store_dir) || mkpath(store_dir)

        # Write to temporary file
        open(temp_path, "w") do io
            JSON3.write(io, data)
        end

        # Atomically replace old state file with new one
        mv(temp_path, STORE_PATH; force=true)

    catch e
        @error "Failed to save agent state to $STORE_PATH" exception=(e, catch_backtrace())
        # Clean up temporary file if it exists
        isfile(temp_path) && rm(temp_path; force=true)
    end
end

# Auto-persist setting from configuration
const auto_persist = get_config("storage.auto_persist", true)
# Consider saving more frequently or based on specific events if atexit is not reliable enough
atexit(() -> auto_persist && _save_state())

function _load_state()
    isfile(STORE_PATH) || return
    local raw # Ensure raw is accessible in catch block if needed
    try
        raw = JSON3.read(open(STORE_PATH, "r")) # Open explicitly for reading
        num_loaded = 0
        lock(AGENTS_LOCK) do # Lock AGENTS while loading
            empty!(AGENTS) # Clear existing agents before loading
            for (id, obj) in raw
                try
                    # Reconstruct AgentConfig (handle potential missing fields with get)
                    cfg_data = obj["config"]
                    cfg = AgentConfig(
                        get(cfg_data, "name", "Unnamed Agent"),
                        AgentType(Int(get(cfg_data, "type", Int(CUSTOM)))),
                        abilities = get(cfg_data, "abilities", String[]),
                        chains = get(cfg_data, "chains", String[]),
                        parameters = get(cfg_data, "parameters", Dict{String,Any}()),
                        llm_config = get(cfg_data, "llm_config", Dict{String,Any}()),
                        memory_config = get(cfg_data, "memory_config", Dict{String,Any}()),
                        max_task_history = get(cfg_data, "max_task_history", MAX_TASK_HISTORY) # Load history limit
                    )

                    # Reconstruct Agent
                    ag_status = AgentStatus(Int(get(obj, "status", Int(STOPPED)))) # Default to STOPPED if missing
                    ag = Agent(
                        id,
                        get(obj, "name", cfg.name), # Use config name if obj name missing
                        AgentType(Int(get(obj, "type", Int(cfg.type)))), # Use config type if obj type missing
                        ag_status,
                        DateTime(get(obj, "created", string(now()))),
                        DateTime(get(obj, "updated", string(now()))),
                        cfg,
                        OrderedDict{String,Any}(get(obj, "memory", [])), # Load memory, default empty
                        Dict{String,Any}[], # Task history is transient, start empty
                        Dict{String,SkillState}(), # Initialize skills empty, load below
                        PriorityQueue{Any,Float64}() # Queue is transient, start empty
                    )

                    # *** FIXED: Load skill states ***
                    if haskey(obj, "skills") && obj["skills"] isa Dict && !isempty(obj["skills"])
                        loaded_skills_data = obj["skills"]
                        for (skill_name, skill_data) in loaded_skills_data
                            registered_skill = get(SKILL_REGISTRY, skill_name, nothing)
                            if registered_skill !== nothing && skill_data isa Dict
                                try
                                    loaded_xp = Float64(get(skill_data, "xp", 0.0))
                                    loaded_last_exec = DateTime(get(skill_data, "last_exec", string(epoch))) # Use epoch if missing
                                    ag.skills[skill_name] = SkillState(registered_skill, loaded_xp, loaded_last_exec)
                                catch skill_load_err
                                    @warn "Error parsing state for skill '$skill_name' in agent $id: $skill_load_err"
                                end
                            elseif registered_skill === nothing
                                @warn "Skill '$skill_name' found in saved state for agent $id but not in SKILL_REGISTRY. Ignoring."
                            end
                        end
                    end
                    # *** End Skill Loading Fix ***

                    AGENTS[id] = ag
                    num_loaded += 1

                    # If agent was running/paused, maybe restart it? Or leave stopped?
                    # Current behavior: Loads agent as STOPPED (unless ERROR state saved)
                    # You might want to automatically restart agents that were RUNNING.
                    # if ag.status == RUNNING || ag.status == PAUSED
                    #     @info "Attempting to restart loaded agent $(ag.name) ($id)"
                    #     startAgent(id) # This might need adjustment based on startAgent logic
                    # end

                catch e
                    @error "Error loading agent $id from state file: $e" stacktrace=catch_backtrace()
                end
            end # end for loop iterating through agents in JSON
        end # end lock
        @info "Loaded $num_loaded agents from $STORE_PATH"

    catch e
        @error "Error reading or parsing agent state file $STORE_PATH: $e" stacktrace=catch_backtrace()
        # Consider renaming the corrupt file here to prevent load loops
        # corrupt_path = STORE_PATH * ".corrupt." * string(now())
        # try; mv(STORE_PATH, corrupt_path; force=true); @warn("Moved corrupt state file to $corrupt_path"); catch mv_e; @error("Could not move corrupt state file $STORE_PATH", exception=mv_e); end
    end
end

# ----------------------------------------------------------------------
# AGENT MONITORING SYSTEM
# ----------------------------------------------------------------------
module AgentMonitor
    using Dates, Logging, Base.Threads
    export start_monitor, stop_monitor, get_health_status

    # Import the get_config function from parent module
    using ..Config: get_config
    # Import other needed symbols from parent module
    import .. AGENTS
    import .. AGENT_THREADS
    import .. AGENTS_LOCK
    import .. getAgent
    import .. startAgent

    # Health status enum
    @enum HealthStatus begin
        HEALTHY = 1
        WARNING = 2
        CRITICAL = 3
        UNKNOWN = 4
    end

    # Health check result structure
    struct HealthCheck
        agent_id::String
        status::HealthStatus
        message::String
        timestamp::DateTime
        details::Dict{String, Any}
    end

    # Global monitoring state
    const MONITOR_TASK = Ref{Union{Task, Nothing}}(nothing)
    const MONITOR_RUNNING = Ref{Bool}(false)
    const HEALTH_STATUS = Dict{String, HealthCheck}()
    const MONITOR_LOCK = ReentrantLock()

    # Start the agent monitoring system
    function start_monitor()
        lock(MONITOR_LOCK) do
            if MONITOR_RUNNING[]
                @warn "Agent monitor is already running"
                return false
            end

            MONITOR_RUNNING[] = true
            MONITOR_TASK[] = @task _monitor_loop()
            schedule(MONITOR_TASK[])
            @info "Agent monitoring system started"
            return true
        end
    end

    # Stop the agent monitoring system
    function stop_monitor()
        lock(MONITOR_LOCK) do
            if !MONITOR_RUNNING[]
                @warn "Agent monitor is not running"
                return false
            end

            MONITOR_RUNNING[] = false
            # Wait for the task to finish
            if MONITOR_TASK[] !== nothing && !istaskdone(MONITOR_TASK[])
                try
                    wait(MONITOR_TASK[])
                catch e
                    @error "Error waiting for monitor task to finish" exception=(e, catch_backtrace())
                end
            end

            MONITOR_TASK[] = nothing
            @info "Agent monitoring system stopped"
            return true
        end
    end

    # Get health status for all agents or a specific agent
    function get_health_status(agent_id::Union{String, Nothing}=nothing)
        if isnothing(agent_id)
            # Return all health statuses
            return copy(HEALTH_STATUS)
        else
            # Return health status for a specific agent
            return get(HEALTH_STATUS, agent_id, HealthCheck(
                agent_id, UNKNOWN, "Agent not monitored", now(), Dict{String, Any}()
            ))
        end
    end

    # Internal monitoring loop
    function _monitor_loop()
        @info "Agent monitor loop started"
        check_interval = get_config("agent.monitor_interval", 30) # seconds

        try
            while MONITOR_RUNNING[]
                # Check all agents
                _check_all_agents()

                # Sleep until next check
                for _ in 1:check_interval
                    if !MONITOR_RUNNING[]
                        break
                    end
                    sleep(1)
                end
            end
        catch e
            @error "Agent monitor loop crashed!" exception=(e, catch_backtrace())
            MONITOR_RUNNING[] = false
        finally
            @info "Agent monitor loop stopped"
        end
    end

    # Check health of all agents
    function _check_all_agents()
        # Get a snapshot of all agents
        agents_snapshot = Dict{String, Any}()
        lock(AGENTS_LOCK) do
            for (id, agent) in AGENTS
                agents_snapshot[id] = (
                    id = id,
                    name = agent.name,
                    status = agent.status,
                    thread = get(AGENT_THREADS, id, nothing),
                    updated = agent.updated
                )
            end
        end

        # Check each agent
        for (id, agent_data) in agents_snapshot
            # Skip agents that don't have a thread (not started)
            thread = agent_data.thread
            if thread === nothing
                continue
            end

            status = HEALTHY
            message = "Agent is healthy"
            details = Dict{String, Any}()

            # Check if thread is done but agent status is RUNNING
            if istaskdone(thread) && agent_data.status == RUNNING
                status = CRITICAL
                message = "Agent thread crashed but status is RUNNING"
                details["thread_status"] = "done"
                details["agent_status"] = string(agent_data.status)

                # Auto-restart if configured
                if get_config("agent.auto_restart", false)
                    @warn "Auto-restarting crashed agent $(agent_data.name) ($id)"
                    # Call startAgent outside the monitor lock to avoid deadlocks
                    @async startAgent(id)
                end
            end

            # Check for stalled agents (no updates for a long time)
            time_since_update = now() - agent_data.updated
            max_stall_time = get_config("agent.max_stall_seconds", 300) # 5 minutes
            if agent_data.status == RUNNING && time_since_update > Second(max_stall_time)
                status = WARNING
                message = "Agent may be stalled (no updates for $(time_since_update))"
                details["time_since_update"] = time_since_update
            end

            # Record health check result
            HEALTH_STATUS[id] = HealthCheck(
                id, status, message, now(), details
            )

            # Record metrics
            if get_config("metrics.enabled", true)
                record_metric(id, "health_status", Int(status);
                              type=Metrics.GAUGE,
                              tags=Dict("agent_name" => agent_data.name))
            end
        end
    end
end

# Import monitoring functions
using .AgentMonitor: start_monitor, stop_monitor, get_health_status

# Load state immediately when module is loaded
_load_state()

# Start the agent monitor if enabled
if get_config("agent.monitoring_enabled", true)
    @async start_monitor()
end

# ----------------------------------------------------------------------
# ABILITY REGISTRY -------------------------------------------------------
# ----------------------------------------------------------------------
function register_ability(name::String, fn::Function)
    ABILITY_REGISTRY[name] = fn
    # also expose as skill (on‑demand)
    haskey(SKILL_REGISTRY, name) || register_skill(name, fn; schedule=0)
    @info "Registered ability '$name'" # More specific log
end

# ----------------------------------------------------------------------
# MEMORY HELPERS ---------------------------------------------------------
# ----------------------------------------------------------------------
# Internal function, assumes key exists. Use getAgentMemory for safe access.
function _touch!(mem::OrderedDict, key)
    # No need for haskey check if only called internally after confirming existence
    val = mem[key]; delete!(mem,key); mem[key] = val
end

function _enforce_lru!(agent::Agent)
    max_size = get(agent.config.memory_config, "max_size", 0)::Int # Specify type hint
    if max_size > 0
        while length(agent.memory) > max_size
            # Delete the least recently used item (the first one in OrderedDict)
            popfirst!(agent.memory) # More efficient than getting keys then deleting
        end
    end
end

# ----------------------------------------------------------------------
# CRUD (with locking for AGENTS dict) -----------------------------------
# ----------------------------------------------------------------------
function createAgent(cfg::AgentConfig)
    id = "agent-" * randstring(8)
    skills = Dict{String,SkillState}()
    # Initialize skills based on config
    for ability_name in cfg.abilities # Abilities are used to find corresponding skills
        sk = get(SKILL_REGISTRY, ability_name, nothing)
        # Only add if a skill with the same name as the ability exists
        sk === nothing && continue
        # Initialize with 0 XP and current time as last exec
        skills[ability_name] = SkillState(sk, 0.0, now())
    end

    ag = Agent(id, cfg.name, cfg.type, CREATED, now(), now(), cfg,
               OrderedDict{String,Any}(), # Start with empty memory
               Dict{String,Any}[],        # Start with empty task history
               skills,                    # Initialized skills
               PriorityQueue{Any,Float64}()) # Start with empty queue

    lock(AGENTS_LOCK) do
        AGENTS[id] = ag
    end
    auto_persist && _save_state() # Save state after modification
    @info "Created agent $(cfg.name) ($id)"
    return ag
end

function getAgent(id::String)::Union{Agent, Nothing}
    lock(AGENTS_LOCK) do
        return get(AGENTS, id, nothing)
    end
end

function listAgents(;filter_type=nothing, filter_status=nothing)
    agents_list = Agent[]
    lock(AGENTS_LOCK) do
        # Create a copy to avoid holding lock during filtering if complex
        agents_list = collect(values(AGENTS))
    end

    # Apply filters outside the lock
    if filter_type !== nothing
        filter!(a -> a.type == filter_type, agents_list)
    end
    if filter_status !== nothing
        filter!(a -> a.status == filter_status, agents_list)
    end
    return agents_list
end

function updateAgent(id::String, upd::Dict{String,Any})
    # Retrieve agent first (uses lock internally)
    ag = getAgent(id)
    ag === nothing && return nothing

    # Lock the specific agent if fine-grained locking is needed,
    # or use the global lock if modifying shared structures or status
    # For simplicity here, assume modifications are safe or handled by caller context
    # A lock per agent could be added to the Agent struct if needed: `lock::ReentrantLock`

    updated = false
    if haskey(upd,"name") && ag.name != upd["name"]
        ag.name = upd["name"]; updated = true
    end
     # Be careful allowing direct status updates via API, might conflict with internal state machine
    if haskey(upd,"status")
        new_status_val = upd["status"]
        try
            new_status = isa(new_status_val, AgentStatus) ? new_status_val : AgentStatus(Int(new_status_val))
             if ag.status != new_status
                 # TODO: Add checks here - e.g., prevent setting RUNNING directly?
                 # This should ideally only be set by startAgent/stopAgent internal logic
                 @warn "Agent status for $id externally set to $new_status. Internal state might be inconsistent."
                 ag.status = new_status; updated = true
             end
        catch e
             @warn "Invalid status value provided for agent $id: $new_status_val"
        end
    end
    if haskey(upd,"config") && haskey(upd["config"],"parameters")
        # Only merge parameters for now, config itself is immutable struct
        # If config needs full update, need AgentConfig constructor logic
        params_to_merge = get(upd["config"],"parameters", Dict())
        if !isempty(params_to_merge)
            merge!(ag.config.parameters, params_to_merge); updated = true
             @info "Updated parameters for agent $id"
        end
    end

    if updated
        ag.updated = now()
        auto_persist && _save_state() # Save state if anything changed
        @info "Agent $id updated."
    end
    return ag
end

function deleteAgent(id::String)::Bool
    lock(AGENTS_LOCK) do
        haskey(AGENTS, id) || return false
        # Stop the agent task *before* removing from dict
        # stopAgent needs to handle the case where agent doesn't exist in AGENT_THREADS
        stopAgent(id) # stopAgent handles missing agent/thread gracefully

        delete!(AGENTS, id)
        # Also clean up thread entry if it exists
        haskey(AGENT_THREADS, id) && delete!(AGENT_THREADS, id)

        auto_persist && _save_state() # Save state after deletion
        @info "Deleted agent $id"
        return true
    end
end


# ----------------------------------------------------------------------
# INTERNAL LOOP (Handles PAUSED state) ---------------------------------
# ----------------------------------------------------------------------
function _process_skill!(ag::Agent, sstate::SkillState)
    # XP decay using configurable decay factor
    sstate.xp *= get_config("agent.xp_decay_rate", 0.999)
    sk = sstate.skill # Access skill definition
    if sk.schedule > 0 # Only process scheduled skills
        diff = now() - sstate.last_exec
        if diff >= Millisecond(round(Int, sk.schedule * 1000)) # Use Millisecond for comparison
            try
                @debug "Running scheduled skill '$(sk.name)' for agent $(ag.name)"
                # --- Execute the skill function ---
                sk.fn(ag) # Pass the agent object to the skill function
                # ------------------------------------
                sstate.xp += 1 # Increase XP on success
            catch e
                sstate.xp -= 2 # Decrease XP on error (consider magnitude)
                @error "Skill $(sk.name) error in agent $(ag.name)" exception=(e, catch_backtrace())
                 # Maybe set agent status to ERROR? Depends on severity desired.
                 # ag.status = ERROR
            end
            sstate.last_exec = now() # Update last execution time regardless of success/failure
        end
    end
end

# *** MODIFIED: Agent loop handles PAUSED state ***
function _agent_loop(ag::Agent)
    @info "Agent loop started for $(ag.name) ($ag.id)"
    try
        while ag.status != STOPPED && ag.status != ERROR # Keep running unless stopped or errored
            # --- Check for PAUSED status ---
            if ag.status == PAUSED
                # Agent is paused, wait briefly and check again
                # TODO: Replace sleep with a Condition wait for better efficiency
                sleep(PAUSED_SLEEP_MS / 1000) # Convert ms to seconds
                continue # Skip the rest of the loop iteration
            end
            # -------------------------------

            active = false # Flag to see if any work was done in this iteration

            # 1) Scheduled skills
            # Iterate over a copy of keys in case skills are modified during iteration (less likely here)
            current_skill_keys = collect(keys(ag.skills))
            for skill_name in current_skill_keys
                 sstate = get(ag.skills, skill_name, nothing) # Re-fetch in case deleted
                 sstate === nothing && continue
                 _process_skill!(ag, sstate)
                 # Note: _process_skill! only runs if schedule time has passed
            end

            # 2) Queued messages
            if !isempty(ag.queue)
                active = true # Work done: processed queue item
                msg, _ = peek(ag.queue) # Priority included in peek result
                dequeue!(ag.queue)      # Remove from queue

                ability_name = get(msg, "ability", "") # Assume message is a Dict
                if !isempty(ability_name)
                    f = get(ABILITY_REGISTRY, ability_name, nothing)
                    if f !== nothing
                        try
                            @debug "Executing ability '$ability_name' from queue for agent $(ag.name)"
                            f(ag, msg) # Execute the ability function
                        catch e
                            @error "Error executing ability '$ability_name' from queue for agent $(ag.name)" exception=(e, catch_backtrace())
                            # Decide if this error should stop the agent
                            # ag.status = ERROR
                        end
                    else
                        @warn "Unknown ability '$ability_name' requested in queue for agent $(ag.name)"
                    end
                else
                    @warn "Message dequeued with no 'ability' key for agent $(ag.name): $msg"
                end
            end

            # --- Intelligent Sleep ---
            # TODO: Replace this fixed sleep with dynamic waiting based on:
            # 1. Time until the next scheduled skill needs to run.
            # 2. Waiting on a notification (e.g., Condition) for new queue messages.
            # This avoids busy-waiting and improves responsiveness.
            if !active
                 sleep(DEFAULT_SLEEP_MS / 1000) # Sleep only if no work was done (convert ms to seconds)
            else
                 yield() # Yield to allow other tasks to run if work was done
            end
            # -------------------------

        end # End while loop
    catch e
        ag.status = ERROR
        ag.updated = now()
        @error "Agent $(ag.name) ($ag.id) loop crashed!" exception=(e, catch_backtrace())
        # Rethrow? Or just log and let the status indicate error?
        # rethrow(e)
    finally
         # Ensure status is updated if loop terminates normally
         # If loop exited due to status change (STOPPED/ERROR), keep that status
         if ag.status != STOPPED && ag.status != ERROR
             ag.status = STOPPED
             ag.updated = now()
         end
         @info "Agent loop stopped for $(ag.name) ($ag.id). Final status: $(ag.status)"
         # Clean up thread entry? Should be done by deleteAgent or perhaps a monitor task
         # lock(AGENTS_LOCK) do
         #     haskey(AGENT_THREADS, ag.id) && delete!(AGENT_THREADS, ag.id)
         # end
    end
end


# ----------------------------------------------------------------------
# LIFE‑CYCLE (Pause/Resume now works with modified loop) ---------------
# ----------------------------------------------------------------------
function startAgent(id::String)::Bool
    ag = getAgent(id)
    ag === nothing && (@warn "startAgent: Agent $id not found"; return false)

    # Check current status and task state
    lock(AGENTS_LOCK) do # Lock to safely check/update AGENT_THREADS
        current_task = get(AGENT_THREADS, id, nothing)
        if current_task !== nothing && !istaskdone(current_task)
             # If paused, resumeAgent should be used. If running, do nothing.
             if ag.status == RUNNING
                 @warn "Agent $id ($(ag.name)) is already running."
                 return true # Indicate it's effectively running
             elseif ag.status == PAUSED
                  @warn "Agent $id ($(ag.name)) is paused. Use resumeAgent() to resume."
                  return false # Indicate failure to start because it's paused
             else
                  # Should not happen if status reflects task state, but handle defensively
                  @warn "Agent $id ($(ag.name)) has status $(ag.status) but task exists and is not done. Attempting to stop old task."
                  # Force stop might be needed here if wait hangs
                  ag.status = STOPPED
                  try; wait(current_task); catch e; @error "Error waiting for old task of $id" exception=e; end
             end
        end

        # Okay to start
        ag.status = INITIALIZING
        ag.updated = now()
        @info "Starting agent $(ag.name) ($id)..."

        # Create and schedule the new task
        AGENT_THREADS[id] = @task begin
            try
                # Set status to RUNNING *inside* the task, after initialization phase (if any)
                ag.status = RUNNING
                ag.updated = now()
                _agent_loop(ag) # Run the main loop
            catch task_err
                 # This catch block might be redundant if _agent_loop handles its errors
                 @error "Unhandled error in agent task for $id ($(ag.name))" exception=(task_err, catch_backtrace())
                 ag.status = ERROR # Ensure status reflects error
                 ag.updated = now()
            finally
                 # Final status update is handled inside _agent_loop's finally block now
                 # Ensure state is saved if auto_persist is on and loop finishes
                 # auto_persist && _save_state() # Might save too often, rely on CRUD ops?
            end
        end
        schedule(AGENT_THREADS[id])
        return true
    end # unlock AGENTS_LOCK
end

function stopAgent(id::String)::Bool
    ag = getAgent(id)
    # No agent found, nothing to stop
    ag === nothing && return true # Arguably, goal (agent not running) is achieved

    current_task = lock(AGENTS_LOCK) do
        get(AGENT_THREADS, id, nothing)
    end

    if current_task === nothing || istaskdone(current_task)
        # Task doesn't exist or is already done
        if ag.status == RUNNING || ag.status == PAUSED || ag.status == INITIALIZING
            @warn "Agent $id ($(ag.name)) status is $(ag.status), but no active task found. Setting status to STOPPED."
            ag.status = STOPPED
            ag.updated = now()
            auto_persist && _save_state()
        end
        return true # Agent is effectively stopped
    end

    # Task exists and is not done, signal it to stop
    if ag.status != STOPPED && ag.status != ERROR
        @info "Stopping agent $(ag.name) ($id)..."
        ag.status = STOPPED # Signal the loop to exit
        ag.updated = now()
        # Don't save state here yet, wait for loop to finish maybe?
    end

    # Wait for the task to finish (with a timeout?)
    try
        # TODO: Add a timeout to the wait to prevent hanging indefinitely
        wait(current_task)
        @info "Agent $(ag.name) ($id) task finished."
    catch e
        @error "Error occurred while waiting for agent $id ($(ag.name)) task to stop." exception=(e, catch_backtrace())
        # Force status to error? Or keep as stopped?
        ag.status = ERROR
        ag.updated = now()
    end

    # Final state save after ensuring task is stopped/waited for
    auto_persist && _save_state()
    return true
end

# *** MODIFIED: pauseAgent just sets the flag ***
function pauseAgent(id::String)::Bool
    ag = getAgent(id)
    if ag !== nothing && ag.status == RUNNING
        ag.status = PAUSED
        ag.updated = now()
        @info "Agent $(ag.name) ($id) paused."
        auto_persist && _save_state() # Save status change
        return true
    elseif ag !== nothing && ag.status == PAUSED
         @warn "Agent $(ag.name) ($id) is already paused."
         return true # Already achieved
    else
        state = ag === nothing ? "Not Found" : ag.status
        @warn "Cannot pause agent $(ag.name) ($id). State: $state"
        return false
    end
end

# *** MODIFIED: resumeAgent just sets the flag ***
function resumeAgent(id::String)::Bool
    ag = getAgent(id)
    if ag !== nothing && ag.status == PAUSED
        ag.status = RUNNING
        ag.updated = now()
        @info "Agent $(ag.name) ($id) resumed."
        auto_persist && _save_state() # Save status change
        return true
     elseif ag !== nothing && ag.status == RUNNING
         @warn "Agent $(ag.name) ($id) is already running."
         return true # Already achieved
    else
        state = ag === nothing ? "Not Found" : ag.status
        @warn "Cannot resume agent $(ag.name) ($id). State: $state"
        return false
    end
end

# ----------------------------------------------------------------------
# STATUS ---------------------------------------------------------------
# ----------------------------------------------------------------------
function getAgentStatus(id::String)::Dict{String, Any}
    ag = getAgent(id) # Uses lock internally
    ag === nothing && return Dict("status"=>"not_found", "error"=>"Agent $id not found")

    # Calculate uptime if running/paused
    uptime_sec = 0
    if ag.status == RUNNING || ag.status == PAUSED
        # Uptime based on last status change to RUNNING/PAUSED
        # Need to store 'last_started' or similar timestamp?
        # Using 'updated' provides time since last status change, which is okay for now
        try
            uptime_sec = round(Int, (now() - ag.updated).value / 1000)
        catch e
            @warn "Error calculating uptime for agent $id" exception=e
            uptime_sec = -1 # Indicate error
        end
    end

    return Dict(
        "id" => ag.id,
        "name" => ag.name,
        "type" => string(ag.type),
        "status" => string(ag.status),
        "uptime_seconds" => uptime_sec,
        "tasks_completed" => length(ag.task_history), # Note: History might be capped
        "queue_len" => length(ag.queue),
        "memory_size" => length(ag.memory),
        "last_updated" => string(ag.updated)
    )
end

# ----------------------------------------------------------------------
# TASK EXECUTION (with history capping) ---------------------------------
# ----------------------------------------------------------------------
function executeAgentTask(id::String, task::Dict{String,Any})::Dict{String, Any}
    ag = getAgent(id)
    ag === nothing && return Dict("success"=>false, "error"=>"Agent $id not found")

    # Check if agent is in a state that can execute tasks
    if ag.status != RUNNING
        # Maybe allow tasks if PAUSED? Depends on requirements.
        # If allowed when paused, they would run immediately when resumed.
        # For now, only RUNNING agents execute tasks directly.
        return Dict("success"=>false, "error"=>"Agent $(ag.name) is not RUNNING (status: $(ag.status))")
    end

    # --- QUEUE MODE ---
    if get(task, "mode", "ability") == "queue"
        # Add task to the agent's priority queue
        # Lower number = higher priority
        prio = -float(get(task, "priority", 0.0)) # Negate for Min-Heap behavior
        try
            enqueue!(ag.queue, task, prio)
            @info "Task queued for agent $(ag.name) ($id) with priority $prio"
            return Dict("success"=>true, "queued"=>true, "agent_id"=>id, "queue_length"=>length(ag.queue))
        catch e
             @error "Failed to enqueue task for agent $id" exception=(e, catch_backtrace())
             return Dict("success"=>false, "error"=>"Failed to enqueue task: $(string(e))")
        end
    end

    # --- DIRECT EXECUTION MODE ---
    ability_name = get(task, "ability", "")
    if isempty(ability_name)
        return Dict("success"=>false, "error"=>"Task requires an 'ability' field for direct execution")
    end

    f = get(ABILITY_REGISTRY, ability_name, nothing)
    if f === nothing
        return Dict("success"=>false, "error"=>"Unknown ability: '$ability_name'")
    end

    try
        # --- Execute the ability function ---
        @debug "Executing direct task '$ability_name' for agent $(ag.name)"
        output = f(ag, task) # Pass agent and full task dict
        # ------------------------------------

        # --- Add to Task History (with capping) ---
        max_hist = ag.config.max_task_history
        if max_hist > 0
            history_entry = Dict("timestamp"=>now(), "input"=>task, "output"=>output)
            push!(ag.task_history, history_entry)
            # Enforce history limit
            while length(ag.task_history) > max_hist
                popfirst!(ag.task_history)
            end
        end
        # ------------------------------------------

        # Return success merged with the output from the ability
        # Ensure output is a Dict or handle other types
        result_data = isa(output, Dict) ? output : Dict("result" => output)
        return merge(Dict("success"=>true, "queued"=>false, "agent_id"=>id), result_data)

    catch e
        @error "Error executing task '$ability_name' for agent $id" exception=(e, catch_backtrace())
        # Optionally set agent status to ERROR?
        # ag.status = ERROR
        # ag.updated = now()
        # auto_persist && _save_state()
        return Dict("success"=>false, "error"=>"Execution error: $(string(e))", "queued"=>false, "agent_id"=>id)
    end
end


# ----------------------------------------------------------------------
# MEMORY ACCESS (LRU handled) ------------------------------------------
# ----------------------------------------------------------------------
function getAgentMemory(id::String, key::String)
    ag = getAgent(id)
    ag === nothing && return nothing # Agent not found

    # Get value and update LRU status
    val = get(ag.memory, key, nothing)
    if val !== nothing && haskey(ag.memory, key) # Check haskey again in case of race condition if not locked
        _touch!(ag.memory, key) # Move accessed item to the end (most recently used)
    end
    return val
end

function setAgentMemory(id::String, key::String, val)::Bool
    ag = getAgent(id)
    ag === nothing && return false

    # Set value (adds if new, updates if exists)
    ag.memory[key] = val
    # Update LRU status (move to end) and enforce size limit
    _touch!(ag.memory, key)
    _enforce_lru!(ag)

    # Persist state? Setting memory might happen frequently.
    # Decide if every memory set needs a full state save.
    # auto_persist && _save_state() # This might be too slow if memory is set often

    return true
end

function clearAgentMemory(id::String)::Bool
    ag = getAgent(id)
    if ag !== nothing
        if !isempty(ag.memory)
            empty!(ag.memory)
            @info "Cleared memory for agent $(ag.name) ($id)"
            # auto_persist && _save_state() # Save after significant change
        end
        return true
    end
    return false
end

# ----------------------------------------------------------------------
# DEFAULT ABILITIES -----------------------------------------------------
# ----------------------------------------------------------------------
register_ability("ping", (ag::Agent, task::Dict) -> begin
    @info "'ping' received by agent $(ag.name)"
    return Dict("msg"=>"pong", "agent_id"=>ag.id, "agent_name"=>ag.name)
end)

# --- LLM Integration Submodule ---
module LLMIntegration
    # This structure keeps OpenAI optional
    using Logging, Pkg
    export chat

    # Attempt to load OpenAI, fallback to echo if fails
    const OpenAI_LOADED = Ref(false)
    try
        eval(:(using OpenAI)) # Use eval to load conditionally
        global OpenAI_LOADED[] = true
        @info "OpenAI.jl loaded successfully for LLM integration."
    catch e
        @warn "OpenAI.jl not found or failed to load. LLM chat ability will fallback to echo mode." e
    end

    function chat(prompt::String; cfg::Dict)
        if OpenAI_LOADED[]
            # Extract config with defaults
            api_key = get(ENV, "OPENAI_API_KEY", "") # Prefer environment variable
            if isempty(api_key) && haskey(cfg, "api_key")
                 api_key = cfg["api_key"]
            end
             isempty(api_key) && (@error "OpenAI API key not found in ENV or config."; return "[LLM ERROR: API Key Missing]")

            model = get(cfg, "model", "gpt-4o-mini")
            temp = get(cfg, "temperature", 0.7)
            max_tokens = get(cfg, "max_tokens", 1024)

            try
                 # Use the loaded OpenAI module's function
                 # Assuming chat_completion takes api_key, model, prompt etc.
                 # Adjust call signature based on actual OpenAI.jl version API
                 # Example call structure (verify with OpenAI.jl docs):
                 result = OpenAI.create_chat(
                     api_key,
                     model,
                     [Dict("role" => "user", "content" => prompt)];
                     temperature=temp,
                     max_tokens=max_tokens
                 )
                 # Extract the response content
                 return result.choices[1].message.content
            catch e
                 @error "OpenAI API call failed" model=model exception=(e,catch_backtrace())
                 return "[LLM ERROR: API Call Failed]"
            end
        else
            # Fallback echo mode
            return "[LLM disabled] Echo: " * prompt
        end
    end
end # end LLMIntegration submodule

register_ability("llm_chat", (ag::Agent, task::Dict) -> begin
    prompt = get(task, "prompt", "Hi!")
    @info "Agent $(ag.name) performing LLM chat with prompt: $(first(prompt, 50))..."
    # Call the chat function from the submodule
    answer = LLMIntegration.chat(prompt; cfg=ag.config.llm_config)
    return Dict("answer" => answer)
end)
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# SWARM IMPLEMENTATION ---------------------------------------------------
# ----------------------------------------------------------------------
module Swarm
    using Dates, Logging, JSON3, Base.Threads
    export SwarmBackend, connect_swarm, disconnect_swarm, publish_to_swarm, subscribe_swarm!

    # Import the get_config function from parent module
    using ..Config: get_config
    # Import other needed symbols from parent module
    import .. getAgent
    import .. record_metric
    import .. Metrics
    import DataStructures: enqueue!

    # Swarm backend types
    @enum SwarmBackend begin
        NONE = 0      # No backend, messages are logged but not sent
        MEMORY = 1    # In-memory message bus (for testing/development)
        REDIS = 2     # Redis pub/sub
        NATS = 3      # NATS messaging system
        ZEROMQ = 4    # ZeroMQ messaging
    end

    # Global swarm state
    const SWARM_CONNECTIONS = Dict{String, Any}() # Agent ID -> Connection
    const SWARM_SUBSCRIPTIONS = Dict{String, Dict{String, Any}}() # Agent ID -> Topic -> Subscription
    const SWARM_LOCK = ReentrantLock()

    # In-memory message bus for MEMORY backend
    const MEMORY_BUS = Dict{String, Channel{Any}}() # Topic -> Channel
    const MEMORY_BUS_LOCK = ReentrantLock()

    # Get the swarm backend type from config
    function _get_backend_type()
        backend_str = lowercase(get_config("swarm.backend", "none"))
        if backend_str == "memory"
            return MEMORY
        elseif backend_str == "redis"
            return REDIS
        elseif backend_str == "nats"
            return NATS
        elseif backend_str == "zeromq"
            return ZEROMQ
        else
            return NONE
        end
    end

    # Connect to the swarm backend
    function connect_swarm(agent_id::String)
        lock(SWARM_LOCK) do
            # Check if already connected
            if haskey(SWARM_CONNECTIONS, agent_id)
                @debug "Agent $agent_id already connected to swarm"
                return SWARM_CONNECTIONS[agent_id]
            end

            # Get backend type
            backend = _get_backend_type()

            # Connect based on backend type
            connection = nothing
            if backend == MEMORY
                # For memory backend, just create an empty dict to store subscriptions
                connection = Dict{String, Any}("backend" => MEMORY)
                @info "Agent $agent_id connected to in-memory swarm backend"
            elseif backend == REDIS
                # Redis backend
                if !@isdefined(Redis)
                    @warn "Redis.jl not found. Install with: using Pkg; Pkg.add(\"Redis\")"
                    return nothing
                end

                try
                    conn_string = get_config("swarm.connection_string", "redis://localhost:6379")
                    redis_conn = Redis.RedisConnection(conn_string)
                    connection = Dict{String, Any}("backend" => REDIS, "connection" => redis_conn)
                    @info "Agent $agent_id connected to Redis swarm backend at $conn_string"
                catch e
                    @error "Failed to connect to Redis" exception=(e, catch_backtrace())
                    return nothing
                end
            elseif backend == NATS
                # NATS backend
                if !@isdefined(NATS)
                    @warn "NATS.jl not found. Install with: using Pkg; Pkg.add(\"NATS\")"
                    return nothing
                end

                try
                    conn_string = get_config("swarm.connection_string", "nats://localhost:4222")
                    nats_conn = NATS.connect(conn_string)
                    connection = Dict{String, Any}("backend" => NATS, "connection" => nats_conn)
                    @info "Agent $agent_id connected to NATS swarm backend at $conn_string"
                catch e
                    @error "Failed to connect to NATS" exception=(e, catch_backtrace())
                    return nothing
                end
            elseif backend == ZEROMQ
                # ZeroMQ backend
                if !@isdefined(ZMQ)
                    @warn "ZMQ.jl not found. Install with: using Pkg; Pkg.add(\"ZMQ\")"
                    return nothing
                end

                try
                    conn_string = get_config("swarm.connection_string", "tcp://localhost:5555")
                    context = ZMQ.Context()
                    pub_socket = ZMQ.Socket(context, ZMQ.PUB)
                    sub_socket = ZMQ.Socket(context, ZMQ.SUB)
                    ZMQ.connect(pub_socket, conn_string)
                    ZMQ.connect(sub_socket, conn_string)
                    connection = Dict{String, Any}(
                        "backend" => ZEROMQ,
                        "context" => context,
                        "pub_socket" => pub_socket,
                        "sub_socket" => sub_socket
                    )
                    @info "Agent $agent_id connected to ZeroMQ swarm backend at $conn_string"
                catch e
                    @error "Failed to connect to ZeroMQ" exception=(e, catch_backtrace())
                    return nothing
                end
            else
                # NONE backend - just log messages
                connection = Dict{String, Any}("backend" => NONE)
                @info "Agent $agent_id using null swarm backend (messages will be logged only)"
            end

            # Store the connection
            SWARM_CONNECTIONS[agent_id] = connection
            SWARM_SUBSCRIPTIONS[agent_id] = Dict{String, Any}()

            return connection
        end
    end

    # Disconnect from the swarm backend
    function disconnect_swarm(agent_id::String)
        lock(SWARM_LOCK) do
            if !haskey(SWARM_CONNECTIONS, agent_id)
                @debug "Agent $agent_id not connected to swarm"
                return false
            end

            # Get the connection
            connection = SWARM_CONNECTIONS[agent_id]
            backend = connection["backend"]

            # Unsubscribe from all topics
            if haskey(SWARM_SUBSCRIPTIONS, agent_id)
                for (topic, subscription) in SWARM_SUBSCRIPTIONS[agent_id]
                    _unsubscribe(agent_id, topic, connection, subscription)
                end
                delete!(SWARM_SUBSCRIPTIONS, agent_id)
            end

            # Close connection based on backend type
            if backend == REDIS && haskey(connection, "connection")
                try
                    Redis.disconnect(connection["connection"])
                catch e
                    @warn "Error disconnecting from Redis" exception=e
                end
            elseif backend == NATS && haskey(connection, "connection")
                try
                    NATS.close(connection["connection"])
                catch e
                    @warn "Error disconnecting from NATS" exception=e
                end
            elseif backend == ZEROMQ
                try
                    if haskey(connection, "pub_socket")
                        ZMQ.close(connection["pub_socket"])
                    end
                    if haskey(connection, "sub_socket")
                        ZMQ.close(connection["sub_socket"])
                    end
                    if haskey(connection, "context")
                        ZMQ.close(connection["context"])
                    end
                catch e
                    @warn "Error disconnecting from ZeroMQ" exception=e
                end
            end

            # Remove the connection
            delete!(SWARM_CONNECTIONS, agent_id)
            @info "Agent $agent_id disconnected from swarm"

            return true
        end
    end

    # Helper to format the full topic
    function _format_topic(agent_id::String, topic::String)
        # Get the swarm ID from the agent's config
        swarm_id = "default"
        try
            ag = getAgent(agent_id)
            if ag !== nothing && haskey(ag.config.parameters, "swarm_id")
                swarm_id = ag.config.parameters["swarm_id"]
            end
        catch
            # Ignore errors and use default
        end

        # Format the full topic
        base_topic = get_config("swarm.default_topic", "juliaos.swarm")
        return "$base_topic.$swarm_id.$topic"
    end

    # Helper to unsubscribe from a topic
    function _unsubscribe(agent_id::String, topic::String, connection::Dict{String, Any}, subscription::Any)
        backend = connection["backend"]

        if backend == MEMORY
            # For memory backend, remove the task
            if haskey(subscription, "task") && subscription["task"] !== nothing
                try
                    # Signal the task to stop
                    subscription["running"] = false
                    # Wait for it to finish
                    if !istaskdone(subscription["task"])
                        wait(subscription["task"])
                    end
                catch e
                    @warn "Error stopping memory subscription task" exception=e
                end
            end
        elseif backend == REDIS && haskey(connection, "connection")
            # For Redis, unsubscribe from the channel
            try
                Redis.unsubscribe(connection["connection"], subscription["channel"])
            catch e
                @warn "Error unsubscribing from Redis channel" exception=e
            end
        elseif backend == NATS && haskey(connection, "connection")
            # For NATS, unsubscribe from the subject
            try
                NATS.unsubscribe(connection["connection"], subscription["subscription"])
            catch e
                @warn "Error unsubscribing from NATS subject" exception=e
            end
        elseif backend == ZEROMQ && haskey(connection, "sub_socket")
            # For ZeroMQ, unsubscribe from the topic
            try
                ZMQ.unsubscribe(connection["sub_socket"], subscription["topic"])
            catch e
                @warn "Error unsubscribing from ZeroMQ topic" exception=e
            end
        end

        @debug "Agent $agent_id unsubscribed from topic $topic"
    end

    # Publish a message to a topic
    function publish_to_swarm(agent_id::String, topic::String, msg::Dict)
        # Ensure the agent is connected
        connection = get(SWARM_CONNECTIONS, agent_id, nothing)
        if connection === nothing
            connection = connect_swarm(agent_id)
            if connection === nothing
                @warn "Failed to connect agent $agent_id to swarm"
                return false
            end
        end

        # Format the full topic
        full_topic = _format_topic(agent_id, topic)

        # Add metadata to the message
        msg_with_meta = copy(msg)
        msg_with_meta["_source_agent"] = agent_id
        msg_with_meta["_timestamp"] = string(now())
        msg_with_meta["_topic"] = topic

        # Serialize the message
        serialized_msg = JSON3.write(msg_with_meta)

        # Publish based on backend type
        backend = connection["backend"]
        if backend == MEMORY
            # For memory backend, send to the in-memory channel
            lock(MEMORY_BUS_LOCK) do
                if !haskey(MEMORY_BUS, full_topic)
                    # Create a new channel for this topic
                    MEMORY_BUS[full_topic] = Channel{Any}(100) # Buffer up to 100 messages
                end

                # Try to put the message in the channel
                try
                    put!(MEMORY_BUS[full_topic], msg_with_meta)
                    @debug "Published message to in-memory topic $full_topic"
                    return true
                catch e
                    @error "Failed to publish to in-memory topic $full_topic" exception=e
                    return false
                end
            end
        elseif backend == REDIS && haskey(connection, "connection")
            # For Redis, publish to the channel
            try
                Redis.publish(connection["connection"], full_topic, serialized_msg)
                @debug "Published message to Redis channel $full_topic"
                return true
            catch e
                @error "Failed to publish to Redis channel $full_topic" exception=e
                return false
            end
        elseif backend == NATS && haskey(connection, "connection")
            # For NATS, publish to the subject
            try
                NATS.publish(connection["connection"], full_topic, serialized_msg)
                @debug "Published message to NATS subject $full_topic"
                return true
            catch e
                @error "Failed to publish to NATS subject $full_topic" exception=e
                return false
            end
        elseif backend == ZEROMQ && haskey(connection, "pub_socket")
            # For ZeroMQ, publish to the topic
            try
                ZMQ.send(connection["pub_socket"], full_topic, ZMQ.SNDMORE)
                ZMQ.send(connection["pub_socket"], serialized_msg)
                @debug "Published message to ZeroMQ topic $full_topic"
                return true
            catch e
                @error "Failed to publish to ZeroMQ topic $full_topic" exception=e
                return false
            end
        else
            # NONE backend - just log the message
            @info "SWARM: Agent $agent_id publishing to topic $topic" msg=msg
            return true
        end
    end

    # Subscribe to a topic
    function subscribe_swarm!(agent_id::String, topic::String)
        # Ensure the agent is connected
        connection = get(SWARM_CONNECTIONS, agent_id, nothing)
        if connection === nothing
            connection = connect_swarm(agent_id)
            if connection === nothing
                @warn "Failed to connect agent $agent_id to swarm"
                return false
            end
        end

        # Check if already subscribed
        lock(SWARM_LOCK) do
            if haskey(SWARM_SUBSCRIPTIONS, agent_id) &&
               haskey(SWARM_SUBSCRIPTIONS[agent_id], topic)
                @debug "Agent $agent_id already subscribed to topic $topic"
                return true
            end

            # Format the full topic
            full_topic = _format_topic(agent_id, topic)

            # Subscribe based on backend type
            backend = connection["backend"]
            subscription = Dict{String, Any}()

            if backend == MEMORY
                # For memory backend, create a task that listens on the channel
                lock(MEMORY_BUS_LOCK) do
                    if !haskey(MEMORY_BUS, full_topic)
                        # Create a new channel for this topic
                        MEMORY_BUS[full_topic] = Channel{Any}(100) # Buffer up to 100 messages
                    end
                end

                # Create a flag to signal the task to stop
                subscription["running"] = true

                # Create a task that listens on the channel
                subscription["task"] = @task begin
                    try
                        @debug "Started memory subscription task for agent $agent_id on topic $topic"
                        while subscription["running"]
                            # Try to take a message from the channel
                            try
                                channel = MEMORY_BUS[full_topic]
                                if isready(channel)
                                    msg = take!(channel)
                                    # Process the message
                                    _process_message(agent_id, topic, msg)
                                else
                                    # No message available, sleep briefly
                                    sleep(0.1)
                                end
                            catch e
                                if e isa InvalidStateException && e.state == :closed
                                    # Channel was closed, exit the loop
                                    break
                                else
                                    @warn "Error processing message from memory channel" exception=e
                                    # Sleep briefly to avoid tight loop on error
                                    sleep(1)
                                end
                            end
                        end
                    catch e
                        @error "Memory subscription task crashed" exception=(e, catch_backtrace())
                    finally
                        @debug "Memory subscription task for agent $agent_id on topic $topic stopped"
                    end
                end

                # Start the task
                schedule(subscription["task"])
                @debug "Agent $agent_id subscribed to in-memory topic $full_topic"
            elseif backend == REDIS && haskey(connection, "connection")
                # For Redis, subscribe to the channel
                try
                    # Create a callback function
                    callback = (channel, message) -> _process_message(agent_id, topic, JSON3.read(message))

                    # Subscribe to the channel
                    subscription["channel"] = full_topic
                    Redis.subscribe(connection["connection"], full_topic, callback)
                    @debug "Agent $agent_id subscribed to Redis channel $full_topic"
                catch e
                    @error "Failed to subscribe to Redis channel $full_topic" exception=e
                    return false
                end
            elseif backend == NATS && haskey(connection, "connection")
                # For NATS, subscribe to the subject
                try
                    # Create a callback function
                    callback = (msg) -> _process_message(agent_id, topic, JSON3.read(String(msg.data)))

                    # Subscribe to the subject
                    sub = NATS.subscribe(connection["connection"], full_topic, callback)
                    subscription["subscription"] = sub
                    @debug "Agent $agent_id subscribed to NATS subject $full_topic"
                catch e
                    @error "Failed to subscribe to NATS subject $full_topic" exception=e
                    return false
                end
            elseif backend == ZEROMQ && haskey(connection, "sub_socket")
                # For ZeroMQ, subscribe to the topic
                try
                    # Subscribe to the topic
                    ZMQ.subscribe(connection["sub_socket"], full_topic)
                    subscription["topic"] = full_topic

                    # Create a task that listens for messages
                    subscription["running"] = true
                    subscription["task"] = @task begin
                        try
                            @debug "Started ZeroMQ subscription task for agent $agent_id on topic $topic"
                            while subscription["running"]
                                # Try to receive a message
                                try
                                    # First frame is the topic
                                    topic_frame = ZMQ.recv(connection["sub_socket"])
                                    # Second frame is the message
                                    message_frame = ZMQ.recv(connection["sub_socket"])

                                    # Process the message
                                    _process_message(agent_id, topic, JSON3.read(String(message_frame)))
                                catch e
                                    @warn "Error receiving ZeroMQ message" exception=e
                                    # Sleep briefly to avoid tight loop on error
                                    sleep(1)
                                end
                            end
                        catch e
                            @error "ZeroMQ subscription task crashed" exception=(e, catch_backtrace())
                        finally
                            @debug "ZeroMQ subscription task for agent $agent_id on topic $topic stopped"
                        end
                    end

                    # Start the task
                    schedule(subscription["task"])
                    @debug "Agent $agent_id subscribed to ZeroMQ topic $full_topic"
                catch e
                    @error "Failed to subscribe to ZeroMQ topic $full_topic" exception=e
                    return false
                end
            else
                # NONE backend - just log the subscription
                @info "SWARM: Agent $agent_id subscribed to topic $topic"
            end

            # Store the subscription
            if !haskey(SWARM_SUBSCRIPTIONS, agent_id)
                SWARM_SUBSCRIPTIONS[agent_id] = Dict{String, Any}()
            end
            SWARM_SUBSCRIPTIONS[agent_id][topic] = subscription

            return true
        end
    end

    # Process a received message
    function _process_message(agent_id::String, topic::String, msg::Dict)
        try
            # Get the agent
            ag = getAgent(agent_id)
            if ag === nothing
                @warn "Received message for unknown agent $agent_id"
                return
            end

            # Add topic to the message if not already present
            msg_to_enqueue = copy(msg)
            if !haskey(msg_to_enqueue, "_source_topic")
                msg_to_enqueue["_source_topic"] = topic
            end

            # Determine priority
            prio = -float(get(msg_to_enqueue, "priority", 0.0))

            # Enqueue the message
            enqueue!(ag.queue, msg_to_enqueue, prio)
            @debug "Enqueued message from topic $topic for agent $agent_id"

            # Record metric
            if get_config("metrics.enabled", true)
                record_metric(agent_id, "swarm_messages_received", 1;
                              type=Metrics.COUNTER,
                              tags=Dict("topic" => topic))
            end
        catch e
            @error "Error processing received swarm message on topic '$topic' for agent $agent_id" exception=(e, catch_backtrace())
        end
    end
end

# Import swarm functions
using .Swarm: subscribe_swarm!

# Re-export the publish_to_swarm function from Swarm module
const publish_to_swarm = Swarm.publish_to_swarm

# Wrapper function for backward compatibility
function publish_to_swarm(ag::Agent, topic::String, msg::Dict)
    return Swarm.publish_to_swarm(ag.id, topic, msg)
end

end # module Agents