# /Users/rabban/Desktop/JuliaOS/julia/src/OpenAISwarmAdapter.jl

module OpenAISwarmAdapter

using JSON
using UUIDs
using Logging
using HTTP
using OpenAI # Import the OpenAI library

export create_openai_swarm, run_openai_task, get_openai_response

# Store active swarm instances (mapping ID to assistant IDs and thread info)
const ACTIVE_SWARMS = Dict{String, Dict{String, Any}}()

# Store OpenAI API key securely
const OPENAI_API_KEY = Ref{String}()

function __init__()
    # Initialize with API key from environment
    OPENAI_API_KEY[] = get(ENV, "OPENAI_API_KEY", "")
    if isempty(OPENAI_API_KEY[])
        @warn "OPENAI_API_KEY not set in environment. OpenAI Swarm functionality will be limited."
    end
end

"""
    create_openai_swarm(config::Dict)

Creates a conceptual swarm setup for OpenAI agents.

# Arguments
- `config::Dict`: Configuration dictionary containing:
    - `name::String`: Name for this conceptual swarm setup.
    - `agents::Vector{Dict}`: A list of agent configurations, where each agent Dict
      should contain at least `name` and `instructions`.

# Returns
- `Dict`: A dictionary indicating success or failure, including a generated ID
  for this swarm setup and potentially error information.
"""
function create_openai_swarm(config::Dict)
    if isempty(OPENAI_API_KEY[])
        return Dict(
            "success" => false,
            "error" => "OpenAI API key not configured. Please set OPENAI_API_KEY environment variable."
        )
    end
    
    @info "Creating OpenAI Swarm via API..."
    swarm_name = get(config, "name", "Unnamed OpenAI Swarm")
    agent_configs = get(config, "agents", [])

    if isempty(agent_configs)
        return Dict(
            "success" => false,
            "error" => "No agent configurations provided for OpenAI Swarm."
        )
    end

    try
        # --- Create Assistants via OpenAI API --- 
        assistant_ids = Dict{String, String}() # Map agent name to OpenAI Assistant ID
        created_agents_details = [] # Store details including ID
         
         for agent_conf in agent_configs
             agent_name = get(agent_conf, "name", "Unnamed Agent")
             instructions = get(agent_conf, "instructions", "You are a helpful agent.")
             model = get(agent_conf, "model", "gpt-4o") # Default model
             tools = get(agent_conf, "tools", []) # Allow specifying tools
             
             @info "Creating OpenAI Assistant: $agent_name..."
             try
                 # Use OpenAI.jl to create the assistant
                 # NOTE: Error handling here is crucial
                 create_resp = OpenAI.create_assistant(;
                     client = OpenAI.Client(OPENAI_API_KEY[]),
                     model = model,
                     name = agent_name,
                     instructions = instructions,
                     tools = tools
                 )

                 assistant_id = create_resp.id
                 assistant_ids[agent_name] = assistant_id
                 
                 push!(created_agents_details, Dict(
                     "name" => agent_name,
                     "assistant_id" => assistant_id,
                     "model" => model,
                     "status" => "created"
                 ))
                 @info "Successfully created OpenAI Assistant '$agent_name' (ID: $assistant_id)"
             catch api_error
                  @error "Failed to create OpenAI Assistant '$agent_name'" error=api_error
                  # Decide how to handle partial failures - stop or continue?
                  # For now, log and continue, but return overall failure later if any agent fails.
                  push!(created_agents_details, Dict(
                      "name" => agent_name,
                      "status" => "failed",
                      "error" => sprint(showerror, api_error)
                  ))
             end
         end

         # Check if all assistants were created successfully
         if any(agent -> agent["status"] == "failed", created_agents_details)
              @error "One or more OpenAI Assistants failed to create for swarm '$swarm_name'."
              # TODO: Consider deleting successfully created assistants for cleanup?
              return Dict(
                  "success" => false,
                  "error" => "Failed to create one or more OpenAI Assistants.",
                  "details" => created_agents_details
              )
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

         @info "Successfully defined OpenAI Swarm configuration '$swarm_name' (ID: $swarm_instance_id)."
         return Dict(
             "success" => true,
             "swarm_id" => swarm_instance_id,
             "name" => swarm_name,
             "type" => "OpenAI",
             "agents_created" => created_agents_details,
             "message" => "OpenAI Swarm configuration created successfully."
         )

    catch e
        bt = catch_backtrace()
        @error "Failed to create OpenAI Swarm configuration." error_type=typeof(e) full_stacktrace=sprint(show, bt)
        
        return Dict(
            "success" => false,
            "error" => "Failed to create OpenAI Swarm configuration.",
            "details" => sprint(showerror, e)
        )
    end
end

# New function to run a task within an OpenAI swarm (using a thread)
function run_openai_task(swarm_id::String, agent_name::String, task_prompt::String; thread_id::Union{String, Nothing}=nothing)
    if !haskey(ACTIVE_SWARMS, swarm_id)
        return Dict("success" => false, "error" => "Swarm ID not found: $swarm_id")
    end
    swarm_info = ACTIVE_SWARMS[swarm_id]
    
    if !haskey(swarm_info["assistants"], agent_name)
        return Dict("success" => false, "error" => "Agent '$agent_name' not found in swarm '$swarm_id'")
    end
    assistant_id = swarm_info["assistants"][agent_name]
    
    @info "Running task for agent '$agent_name' (Assistant: $assistant_id) in swarm '$swarm_id'..."
    
    try
        client = OpenAI.Client(OPENAI_API_KEY[])
        current_thread_id = thread_id

        # 1. Get or Create Thread
        if isnothing(current_thread_id) || !haskey(swarm_info["threads"], current_thread_id)
            @info "Creating a new thread for task..."
            create_thread_resp = OpenAI.create_thread(client)
            current_thread_id = create_thread_resp.id
            # Store the new thread associated with this swarm instance
            swarm_info["threads"][current_thread_id] = Dict("agent_name" => agent_name, "last_activity" => now())
            @info "Created new thread with ID: $current_thread_id"
        else
            @info "Using existing thread: $current_thread_id"
            # Update last activity timestamp
            swarm_info["threads"][current_thread_id]["last_activity"] = now()
        end

        # 2. Add Message to Thread
        @info "Adding message to thread $current_thread_id: $task_prompt"
        create_msg_resp = OpenAI.create_message(client, current_thread_id; 
            content=task_prompt,
            role="user"
        )
        message_id = create_msg_resp.id
        @info "Message added (ID: $message_id)"

        # 3. Create Run
        @info "Creating run for assistant $assistant_id on thread $current_thread_id..."
        # TODO: Add assistant-specific instructions override if needed?
        create_run_resp = OpenAI.create_run(client, current_thread_id, assistant_id)
        run_id = create_run_resp.id
        @info "Run created (ID: $run_id), Status: $(create_run_resp.status)"

        # Store run info associated with the thread for later retrieval
        if !haskey(swarm_info["threads"][current_thread_id], "runs")
             swarm_info["threads"][current_thread_id]["runs"] = Dict()
        end
        swarm_info["threads"][current_thread_id]["runs"][run_id] = Dict(
            "status" => create_run_resp.status,
            "start_time" => now()
        )

        return Dict(
            "success" => true,
            "swarm_id" => swarm_id,
            "agent_name" => agent_name,
            "thread_id" => current_thread_id,
            "run_id" => run_id,
            "status" => create_run_resp.status,
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

# New function to get the response/status of an OpenAI run
function get_openai_response(swarm_id::String, thread_id::String, run_id::String)
    # Implementation placeholder
    # return Dict("success" => false, "error" => "get_openai_response not fully implemented yet.")
    if isempty(OPENAI_API_KEY[])
        return Dict("success" => false, "error" => "OpenAI API key not configured.")
    end

    if !haskey(ACTIVE_SWARMS, swarm_id)
        return Dict("success" => false, "error" => "Swarm ID not found: $swarm_id")
    end
    swarm_info = ACTIVE_SWARMS[swarm_id]

    if !haskey(swarm_info["threads"], thread_id)
        return Dict("success" => false, "error" => "Thread ID not found in swarm: $thread_id")
    end
    thread_info = swarm_info["threads"][thread_id]

    if !haskey(thread_info, "runs") || !haskey(thread_info["runs"], run_id)
        return Dict("success" => false, "error" => "Run ID not found in thread: $run_id")
    end
    
    @info "Getting status/response for run $run_id in thread $thread_id (Swarm: $swarm_id)..."

    try
        client = OpenAI.Client(OPENAI_API_KEY[])

        # 1. Retrieve the Run status
        retrieve_run_resp = OpenAI.retrieve_run(client, thread_id, run_id)
        current_status = retrieve_run_resp.status

        # Update status in our storage
        thread_info["runs"][run_id]["status"] = current_status
        thread_info["runs"][run_id]["last_checked"] = now()

        # 2. Check if the run is completed
        if current_status == "completed"
            @info "Run $run_id completed. Fetching messages..."
            
            # 3. List messages from the thread (limit to recent ones, maybe after the run started?)
            # For simplicity, we fetch all messages for now. Consider pagination/filtering.
            list_messages_resp = OpenAI.list_messages(client, thread_id)
            
            # Extract assistant messages
            assistant_messages = []
            if !isempty(list_messages_resp.data)
                for message in list_messages_resp.data
                    if message.role == "assistant"
                        # Extract content - assuming text content for now
                        content_text = ""
                        if !isempty(message.content)
                            # Content is an array, usually with one text element
                            content_item = first(message.content)
                            if hasproperty(content_item, :text) && hasproperty(content_item.text, :value)
                                content_text = content_item.text.value
                            end
                        end
                        push!(assistant_messages, Dict("message_id" => message.id, "content" => content_text))
                    end
                end
            end

            # Return the latest assistant message (or all?)
            latest_message = !isempty(assistant_messages) ? first(assistant_messages) : nothing

            return Dict(
                "success" => true,
                "swarm_id" => swarm_id,
                "thread_id" => thread_id,
                "run_id" => run_id,
                "status" => current_status,
                "response" => latest_message # Return the latest message object
            )
        elseif current_status in ["failed", "cancelled", "expired"]
             @error "Run $run_id finished with status: $current_status" details=retrieve_run_resp
             return Dict(
                 "success" => false, 
                 "status" => current_status, 
                 "error" => "Run finished unsuccessfully: $current_status",
                 "run_details" => retrieve_run_resp # Include full run details on error
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

end # module OpenAISwarmAdapter 