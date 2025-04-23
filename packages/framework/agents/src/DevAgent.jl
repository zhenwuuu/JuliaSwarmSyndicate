"""
DevAgent module for JuliaOS

This module provides specialized functionality for development agents.
"""
module DevAgent

export DevAgentConfig, createDevAgent, writeCode, reviewCode, getCodeHistory

using ..Agents
using Dates
using Random

"""
    DevAgentConfig

Configuration for creating a new development agent.

# Fields
- `name::String`: Agent name
- `languages::Vector{String}`: Programming languages the agent can use
- `frameworks::Vector{String}`: Frameworks the agent can use
- `specialties::Vector{String}`: Development specialties
- `code_style::String`: Preferred code style
- `parameters::Dict{String, Any}`: Additional agent-specific parameters
- `llm_config::Dict{String, Any}`: Configuration for the LLM provider
- `memory_config::Dict{String, Any}`: Configuration for agent memory
"""
struct DevAgentConfig
    name::String
    languages::Vector{String}
    frameworks::Vector{String}
    specialties::Vector{String}
    code_style::String
    parameters::Dict{String, Any}
    llm_config::Dict{String, Any}
    memory_config::Dict{String, Any}

    # Constructor with default values
    function DevAgentConfig(
        name::String;
        languages::Vector{String}=["python", "javascript", "julia"],
        frameworks::Vector{String}=["react", "tensorflow", "flask"],
        specialties::Vector{String}=["web", "ai", "blockchain"],
        code_style::String="clean",
        parameters::Dict{String, Any}=Dict{String, Any}(),
        llm_config::Dict{String, Any}=Dict{String, Any}(),
        memory_config::Dict{String, Any}=Dict{String, Any}()
    )
        # Validate code style
        if !(code_style in ["clean", "concise", "verbose", "optimized"])
            throw(ArgumentError("Code style must be one of: clean, concise, verbose, optimized"))
        end

        # Set default LLM config if not provided
        if isempty(llm_config)
            llm_config = Dict(
                "provider" => "openai",
                "model" => "gpt-4",
                "temperature" => 0.5,
                "max_tokens" => 2000
            )
        end

        # Set default memory config if not provided
        if isempty(memory_config)
            memory_config = Dict(
                "max_size" => 5000,
                "retention_policy" => "lru"
            )
        end

        new(
            name,
            languages,
            frameworks,
            specialties,
            code_style,
            parameters,
            llm_config,
            memory_config
        )
    end
end

"""
    createDevAgent(config::DevAgentConfig)

Create a new development agent with the specified configuration.

# Arguments
- `config::DevAgentConfig`: Configuration for the new development agent

# Returns
- `Agent`: The created agent
"""
function createDevAgent(config::DevAgentConfig)
    # Create agent abilities based on languages and specialties
    abilities = String[]
    for language in config.languages
        push!(abilities, "code_$(language)")
    end
    for specialty in config.specialties
        push!(abilities, "dev_$(specialty)")
    end
    push!(abilities, "code_review")
    push!(abilities, "debugging")
    push!(abilities, "testing")

    # Create agent parameters
    parameters = Dict{String, Any}(
        "languages" => config.languages,
        "frameworks" => config.frameworks,
        "specialties" => config.specialties,
        "code_style" => config.code_style
    )

    # Merge with additional parameters
    for (key, value) in config.parameters
        parameters[key] = value
    end

    # Create agent config
    agent_config = Agents.AgentConfig(
        config.name,
        Agents.AgentType.DEV,
        abilities=abilities,
        chains=String[],  # Dev agents don't need chains by default
        parameters=parameters,
        llm_config=config.llm_config,
        memory_config=config.memory_config
    )

    # Create the agent
    return Agents.createAgent(agent_config)
end

"""
    writeCode(agent::Agents.Agent, spec::Dict{String, Any})

Write code with the specified agent based on a specification.

# Arguments
- `agent::Agents.Agent`: The development agent
- `spec::Dict{String, Any}`: Code specification

# Returns
- `Dict`: Code result
"""
function writeCode(agent::Agents.Agent, spec::Dict{String, Any})
    # Validate agent type
    if agent.type != Agents.AgentType.DEV
        throw(ArgumentError("Agent is not a development agent"))
    end

    # Validate spec parameters
    if !haskey(spec, "description")
        throw(ArgumentError("Code spec must include a description"))
    end
    if !haskey(spec, "language")
        throw(ArgumentError("Code spec must specify a language"))
    end

    # Execute the code writing via the agent task system
    task = Dict{String, Any}(
        "action" => "write_code",
        "spec" => spec
    )

    return Agents.executeAgentTask(agent.id, task)
end

"""
    reviewCode(agent::Agents.Agent, code::Dict{String, Any})

Review code with the specified agent.

# Arguments
- `agent::Agents.Agent`: The development agent
- `code::Dict{String, Any}`: Code to review

# Returns
- `Dict`: Review result
"""
function reviewCode(agent::Agents.Agent, code::Dict{String, Any})
    # Validate agent type
    if agent.type != Agents.AgentType.DEV
        throw(ArgumentError("Agent is not a development agent"))
    end

    # Validate code parameters
    if !haskey(code, "content")
        throw(ArgumentError("Code must include content"))
    end
    if !haskey(code, "language")
        throw(ArgumentError("Code must specify a language"))
    end

    # Execute the code review via the agent task system
    task = Dict{String, Any}(
        "action" => "review_code",
        "code" => code
    )

    return Agents.executeAgentTask(agent.id, task)
end

"""
    getCodeHistory(agent::Agents.Agent; limit::Int=10)

Get the code history of a development agent.

# Arguments
- `agent::Agents.Agent`: The development agent
- `limit::Int`: Maximum number of code items to return

# Returns
- `Dict`: Code history
"""
function getCodeHistory(agent::Agents.Agent; limit::Int=10)
    # Validate agent type
    if agent.type != Agents.AgentType.DEV
        throw(ArgumentError("Agent is not a development agent"))
    end

    # Get the code history via the agent task system
    task = Dict{String, Any}(
        "action" => "get_code_history",
        "limit" => limit
    )

    return Agents.executeAgentTask(agent.id, task)
end

end # module
