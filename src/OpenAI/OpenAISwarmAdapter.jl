module OpenAISwarmAdapter

using JSON
using UUIDs
using Logging
using HTTP
using Dates

export initialize_openai, is_initialized, create_openai_swarm, run_openai_task, get_openai_response

# Store active swarm instances (mapping ID to assistant IDs and thread info)
const ACTIVE_SWARMS = Dict{String, Dict{String, Any}}()

# Store OpenAI API key securely
const OPENAI_API_KEY = Ref{String}("")
const IS_INITIALIZED = Ref{Bool}(false)

"""
    initialize_openai(api_key::String)

Initialize the OpenAI module with the given API key.
"""
function initialize_openai(api_key::String)
    OPENAI_API_KEY[] = api_key
    IS_INITIALIZED[] = true
    @info "OpenAI module initialized."
end

"""
    is_initialized()

Check if the OpenAI module is initialized.
"""
function is_initialized()
    return IS_INITIALIZED[] && !isempty(OPENAI_API_KEY[])
end

"""
    create_openai_assistant(name::String, instructions::String, model::String, tools::Vector)

Create an OpenAI assistant with the given parameters.
"""
function create_openai_assistant(name::String, instructions::String, model::String, tools::Vector)
    @info "Creating OpenAI Assistant: $name..."
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just generate a mock assistant ID
    assistant_id = "asst_" * string(uuid4())[1:10]
    
    @info "Created OpenAI Assistant: $name (ID: $assistant_id)"
    return assistant_id
end

"""
    create_openai_thread()

Create a new OpenAI thread.
"""
function create_openai_thread()
    @info "Creating OpenAI Thread..."
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just generate a mock thread ID
    thread_id = "thread_" * string(uuid4())[1:10]
    
    @info "Created OpenAI Thread: $thread_id"
    return thread_id
end

"""
    add_message_to_thread(thread_id::String, content::String)

Add a message to an OpenAI thread.
"""
function add_message_to_thread(thread_id::String, content::String)
    @info "Adding message to thread: $thread_id"
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just log the message
    @info "Added message to thread: $thread_id"
    return true
end

"""
    run_assistant_on_thread(assistant_id::String, thread_id::String)

Run an OpenAI assistant on a thread.
"""
function run_assistant_on_thread(assistant_id::String, thread_id::String)
    @info "Running assistant $assistant_id on thread $thread_id..."
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just generate a mock run ID
    run_id = "run_" * string(uuid4())[1:10]
    
    @info "Started run $run_id for assistant $assistant_id on thread $thread_id"
    return run_id
end

"""
    get_run_status(thread_id::String, run_id::String)

Get the status of an OpenAI assistant run.
"""
function get_run_status(thread_id::String, run_id::String)
    @info "Getting status of run $run_id on thread $thread_id..."
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just return a mock status
    statuses = ["queued", "in_progress", "completed", "requires_action", "failed", "cancelled", "expired"]
    status = statuses[min(length(statuses), rand(1:3))]
    
    @info "Run $run_id status: $status"
    return status
end

"""
    get_thread_messages(thread_id::String)

Get messages from an OpenAI thread.
"""
function get_thread_messages(thread_id::String)
    @info "Getting messages from thread $thread_id..."
    
    # In a real implementation, this would call the OpenAI API
    # For now, we'll just return a mock message
    messages = [
        Dict{String, Any}(
            "id" => "msg_" * string(uuid4())[1:10],
            "role" => "assistant",
            "content" => [
                Dict{String, Any}(
                    "type" => "text",
                    "text" => Dict{String, Any}(
                        "value" => "This is a mock response from the OpenAI assistant.",
                        "annotations" => []
                    )
                )
            ],
            "created_at" => Int(floor(time()))
        )
    ]
    
    @info "Retrieved $(length(messages)) messages from thread $thread_id"
    return messages
end

"""
    create_openai_swarm(config::Dict)

Create a swarm of OpenAI assistants.

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
            
            # Create the assistant using the OpenAI API
            assistant_id = create_openai_assistant(agent_name, instructions, model, tools)
            assistant_ids[agent_name] = assistant_id
            
            push!(created_agents_details, Dict(
                "name" => agent_name,
                "assistant_id" => assistant_id,
                "model" => model,
                "status" => "created"
            ))
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
            "error" => "Swarm not found: $swarm_id"
        )
    end
    
    swarm_info = ACTIVE_SWARMS[swarm_id]
    
    if !haskey(swarm_info["assistants"], agent_name)
        return Dict(
            "success" => false,
            "error" => "Agent not found in swarm: $agent_name"
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
            "error" => "Swarm not found: $swarm_id"
        )
    end
    
    swarm_info = ACTIVE_SWARMS[swarm_id]
    
    if !haskey(swarm_info["threads"], thread_id)
        return Dict(
            "success" => false,
            "error" => "Thread not found in swarm: $thread_id"
        )
    end
    
    @info "Getting response for run $run_id on thread $thread_id in swarm $swarm_id..."
    
    try
        # 1. Check Run Status
        status = get_run_status(thread_id, run_id)
        
        if status == "completed"
            # 2. Get Thread Messages
            messages = get_thread_messages(thread_id)
            
            # 3. Extract Assistant's Response
            assistant_messages = filter(m -> get(m, "role", "") == "assistant", messages)
            
            if isempty(assistant_messages)
                return Dict(
                    "success" => true,
                    "status" => status,
                    "response" => "No assistant messages found.",
                    "messages" => messages
                )
            end
            
            # Get the latest assistant message
            latest_message = assistant_messages[end]
            
            # Extract the text content
            content = get(latest_message, "content", [])
            text_content = ""
            
            for item in content
                if get(item, "type", "") == "text"
                    text_content = get(item["text"], "value", "")
                    break
                end
            end
            
            return Dict(
                "success" => true,
                "status" => status,
                "response" => text_content,
                "message_id" => get(latest_message, "id", ""),
                "created_at" => get(latest_message, "created_at", 0)
            )
        else
            return Dict(
                "success" => true,
                "status" => status,
                "message" => "Run is still in progress. Check again later."
            )
        end
    catch e
        bt = catch_backtrace()
        @error "Failed to get OpenAI response." swarm_id=swarm_id thread_id=thread_id run_id=run_id error=e full_stacktrace=sprint(show, bt)
        
        return Dict(
            "success" => false,
            "error" => "Failed to get OpenAI response.",
            "details" => sprint(showerror, e)
        )
    end
end

end # module OpenAISwarmAdapter
