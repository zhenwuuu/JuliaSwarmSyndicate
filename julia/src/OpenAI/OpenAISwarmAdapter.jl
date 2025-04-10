module OpenAISwarmAdapter

using JSON
using UUIDs
using Logging
using HTTP
using Dates

export create_openai_swarm, run_openai_task, get_openai_response, initialize_openai

# Store active swarm instances (mapping ID to assistant IDs and thread info)
const ACTIVE_SWARMS = Dict{String, Dict{String, Any}}()

# Store OpenAI API key securely
const OPENAI_API_KEY = Ref{String}()
const OPENAI_INITIALIZED = Ref{Bool}(false)

"""
    initialize_openai(api_key::String)

Initialize the OpenAI module with the provided API key.
"""
function initialize_openai(api_key::String)
    OPENAI_API_KEY[] = api_key
    OPENAI_INITIALIZED[] = true
    @info "OpenAI module initialized with API key."
    return true
end

"""
    is_initialized()

Check if the OpenAI module is initialized with an API key.
"""
function is_initialized()
    return OPENAI_INITIALIZED[] && !isempty(OPENAI_API_KEY[])
end

"""
    create_openai_swarm(config::Dict)

Creates a swarm of OpenAI assistants.

# Arguments
- `config::Dict`: Configuration dictionary containing:
    - `name::String`: Name for this swarm setup.
    - `agents::Vector{Dict}`: A list of agent configurations, where each agent Dict
      should contain at least `name` and `instructions`.

# Returns
- `Dict`: A dictionary indicating success or failure, including a generated ID
  for this swarm setup and potentially error information.
"""
function create_openai_swarm(config::Dict)
    if !is_initialized()
        return Dict(
            "success" => false,
            "error" => "OpenAI module not initialized. Call initialize_openai() first."
        )
    end
    
    @info "Creating OpenAI Swarm..."
    swarm_name = get(config, "name", "Unnamed OpenAI Swarm")
    agent_configs = get(config, "agents", [])

    if isempty(agent_configs)
        return Dict(
            "success" => false,
            "error" => "No agent configurations provided for OpenAI Swarm."
        )
    end

    try
        # Create assistants via OpenAI API
        assistant_ids = Dict{String, String}() # Map agent name to OpenAI Assistant ID
        created_agents_details = [] # Store details including ID
        
        for agent_conf in agent_configs
            agent_name = get(agent_conf, "name", "Unnamed Agent")
            instructions = get(agent_conf, "instructions", "You are a helpful agent.")
            model = get(agent_conf, "model", "gpt-4o") # Default model
            tools = get(agent_conf, "tools", []) # Allow specifying tools
            
            @info "Creating OpenAI Assistant: $agent_name..."
            
            # Create the assistant using the OpenAI API
            assistant_id = create_openai_assistant(agent_name, instructions, model, tools)
            assistant_ids[agent_name] = assistant_id
            
            push!(created_agents_details, Dict(
                "name" => agent_name,
                "assistant_id" => assistant_id,
                "model" => model,
                "status" => "created"
            ))
            
            @info "Created OpenAI Assistant: $agent_name (ID: $assistant_id)"
        end
        
        # Generate a unique ID for this swarm configuration
        swarm_instance_id = string(uuid4())
        
        # Store swarm info in memory
        ACTIVE_SWARMS[swarm_instance_id] = Dict(
            "name" => swarm_name,
            "assistants" => assistant_ids, # Map agent name -> assistant ID
            "agents_details" => created_agents_details,
            "threads" => Dict() # Store threads associated with this swarm later
        )
        
        @info "Successfully created OpenAI Swarm '$swarm_name' (ID: $swarm_instance_id)."
        return Dict(
            "success" => true,
            "swarm_id" => swarm_instance_id,
            "name" => swarm_name,
            "type" => "OpenAI",
            "agents_created" => created_agents_details,
            "message" => "OpenAI Swarm created successfully."
        )
    catch e
        bt = catch_backtrace()
        @error "Failed to create OpenAI Swarm." error_type=typeof(e) full_stacktrace=sprint(show, bt)
        
        return Dict(
            "success" => false,
            "error" => "Failed to create OpenAI Swarm.",
            "details" => sprint(showerror, e)
        )
    end
end

"""
    run_openai_task(swarm_id::String, agent_name::String, task_prompt::String; thread_id::Union{String, Nothing}=nothing)

Run a task with an OpenAI assistant in a swarm.

# Arguments
- `swarm_id::String`: The ID of the swarm.
- `agent_name::String`: The name of the agent to run the task with.
- `task_prompt::String`: The prompt for the task.
- `thread_id::Union{String, Nothing}`: Optional thread ID to continue a conversation.

# Returns
- `Dict`: A dictionary with the result of the task execution.
"""
function run_openai_task(swarm_id::String, agent_name::String, task_prompt::String; thread_id::Union{String, Nothing}=nothing)
    if !is_initialized()
        return Dict(
            "success" => false,
            "error" => "OpenAI module not initialized. Call initialize_openai() first."
        )
    end
    
    if !haskey(ACTIVE_SWARMS, swarm_id)
        return Dict(
            "success" => false,
            "error" => "Swarm ID not found: $swarm_id"
        )
    end
    
    swarm_info = ACTIVE_SWARMS[swarm_id]
    
    if !haskey(swarm_info["assistants"], agent_name)
        return Dict(
            "success" => false,
            "error" => "Agent '$agent_name' not found in swarm '$swarm_id'"
        )
    end
    
    assistant_id = swarm_info["assistants"][agent_name]
    
    @info "Running task for agent '$agent_name' (Assistant: $assistant_id) in swarm '$swarm_id'..."
    
    try
        current_thread_id = thread_id
        
        # 1. Get or Create Thread
        if isnothing(current_thread_id) || !haskey(swarm_info["threads"], current_thread_id)
            @info "Creating a new thread for task..."
            current_thread_id = create_openai_thread()
            # Store the new thread associated with this swarm instance
            swarm_info["threads"][current_thread_id] = Dict(
                "agent_name" => agent_name,
                "last_activity" => now()
            )
            @info "Created new thread with ID: $current_thread_id"
        else
            @info "Using existing thread: $current_thread_id"
            # Update last activity timestamp
            swarm_info["threads"][current_thread_id]["last_activity"] = now()
        end
        
        # 2. Add Message to Thread
        @info "Adding message to thread: $current_thread_id"
        add_message_to_thread(current_thread_id, task_prompt)
        
        # 3. Run Assistant
        @info "Running assistant on thread..."
        run_id = run_assistant_on_thread(assistant_id, current_thread_id)
        
        return Dict(
            "success" => true,
            "swarm_id" => swarm_id,
            "agent_name" => agent_name,
            "thread_id" => current_thread_id,
            "run_id" => run_id,
            "status" => "queued",
            "message" => "Task submitted successfully. Check status with run ID."
        )
    catch e
        bt = catch_backtrace()
        @error "Failed to run OpenAI task." swarm_id=swarm_id agent_name=agent_name error=e full_stacktrace=sprint(show, bt)
        
        return Dict(
            "success" => false,
            "error" => "Failed to run OpenAI task.",
            "details" => sprint(showerror, e)
        )
    end
end

"""
    get_openai_response(swarm_id::String, thread_id::String, run_id::String)

Get the response from an OpenAI assistant run.

# Arguments
- `swarm_id::String`: The ID of the swarm.
- `thread_id::String`: The ID of the thread.
- `run_id::String`: The ID of the run.

# Returns
- `Dict`: A dictionary with the response from the assistant.
"""
function get_openai_response(swarm_id::String, thread_id::String, run_id::String)
    if !is_initialized()
        return Dict(
            "success" => false,
            "error" => "OpenAI module not initialized. Call initialize_openai() first."
        )
    end
    
    if !haskey(ACTIVE_SWARMS, swarm_id)
        return Dict(
            "success" => false,
            "error" => "Swarm ID not found: $swarm_id"
        )
    end
    
    @info "Getting response for run $run_id in thread $thread_id..."
    
    try
        # 1. Check Run Status
        run_status = get_run_status(thread_id, run_id)
        current_status = run_status["status"]
        
        if current_status == "completed"
            # 2. Get Messages (only if run is completed)
            @info "Run completed. Getting messages..."
            messages = get_thread_messages(thread_id)
            
            # Filter for assistant messages only
            assistant_messages = filter(m -> m["role"] == "assistant", messages)
            
            # Get the latest assistant message
            latest_message = isempty(assistant_messages) ? nothing : assistant_messages[1]
            
            return Dict(
                "success" => true,
                "status" => "completed",
                "response" => latest_message === nothing ? "No response from assistant." : latest_message["content"][1]["text"]["value"],
                "messages" => messages
            )
        elseif current_status == "failed" || current_status == "cancelled" || current_status == "expired"
            @info "Run $run_id failed with status: $current_status"
            return Dict(
                "success" => false,
                "status" => current_status,
                "error" => "Run failed with status: $current_status"
            )
        else
            # Statuses like 'queued', 'in_progress', 'requires_action'
            @info "Run $run_id is still in progress. Status: $current_status"
            return Dict(
                "success" => true,
                "status" => current_status,
                "message" => "Run is still processing."
            )
        end
    catch e
        bt = catch_backtrace()
        @error "Failed to get OpenAI response." swarm_id=swarm_id thread_id=thread_id run_id=run_id error=e full_stacktrace=sprint(show, bt)
        
        return Dict(
            "success" => false,
            "error" => "Failed to retrieve run status or messages.",
            "details" => sprint(showerror, e)
        )
    end
end

# --- OpenAI API Helper Functions ---

"""
    create_openai_assistant(name::String, instructions::String, model::String, tools::Vector{Dict})

Create an OpenAI assistant.
"""
function create_openai_assistant(name::String, instructions::String, model::String, tools::Vector)
    url = "https://api.openai.com/v1/assistants"
    
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    body = Dict(
        "name" => name,
        "instructions" => instructions,
        "model" => model,
        "tools" => tools
    )
    
    response = HTTP.post(url, headers, JSON.json(body))
    result = JSON.parse(String(response.body))
    
    return result["id"]
end

"""
    create_openai_thread()

Create an OpenAI thread.
"""
function create_openai_thread()
    url = "https://api.openai.com/v1/threads"
    
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    response = HTTP.post(url, headers)
    result = JSON.parse(String(response.body))
    
    return result["id"]
end

"""
    add_message_to_thread(thread_id::String, content::String)

Add a message to an OpenAI thread.
"""
function add_message_to_thread(thread_id::String, content::String)
    url = "https://api.openai.com/v1/threads/$(thread_id)/messages"
    
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    body = Dict(
        "role" => "user",
        "content" => content
    )
    
    response = HTTP.post(url, headers, JSON.json(body))
    result = JSON.parse(String(response.body))
    
    return result["id"]
end

"""
    run_assistant_on_thread(assistant_id::String, thread_id::String)

Run an OpenAI assistant on a thread.
"""
function run_assistant_on_thread(assistant_id::String, thread_id::String)
    url = "https://api.openai.com/v1/threads/$(thread_id)/runs"
    
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    body = Dict(
        "assistant_id" => assistant_id
    )
    
    response = HTTP.post(url, headers, JSON.json(body))
    result = JSON.parse(String(response.body))
    
    return result["id"]
end

"""
    get_run_status(thread_id::String, run_id::String)

Get the status of an OpenAI assistant run.
"""
function get_run_status(thread_id::String, run_id::String)
    url = "https://api.openai.com/v1/threads/$(thread_id)/runs/$(run_id)"
    
    headers = [
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    response = HTTP.get(url, headers)
    result = JSON.parse(String(response.body))
    
    return result
end

"""
    get_thread_messages(thread_id::String)

Get messages from an OpenAI thread.
"""
function get_thread_messages(thread_id::String)
    url = "https://api.openai.com/v1/threads/$(thread_id)/messages"
    
    headers = [
        "Authorization" => "Bearer $(OPENAI_API_KEY[])",
        "OpenAI-Beta" => "assistants=v1"
    ]
    
    response = HTTP.get(url, headers)
    result = JSON.parse(String(response.body))
    
    return result["data"]
end

end # module OpenAISwarmAdapter
