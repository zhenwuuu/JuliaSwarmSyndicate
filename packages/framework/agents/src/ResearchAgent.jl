"""
ResearchAgent module for JuliaOS

This module provides specialized functionality for research agents.
"""
module ResearchAgent

export ResearchAgentConfig, createResearchAgent, conductResearch, getResearchHistory

using ..Agents
using Dates
using Random

"""
    ResearchAgentConfig

Configuration for creating a new research agent.

# Fields
- `name::String`: Agent name
- `research_areas::Vector{String}`: Areas of research
- `data_sources::Vector{String}`: Data sources to use
- `analysis_methods::Vector{String}`: Analysis methods to use
- `output_formats::Vector{String}`: Output formats for research results
- `parameters::Dict{String, Any}`: Additional agent-specific parameters
- `llm_config::Dict{String, Any}`: Configuration for the LLM provider
- `memory_config::Dict{String, Any}`: Configuration for agent memory
"""
struct ResearchAgentConfig
    name::String
    research_areas::Vector{String}
    data_sources::Vector{String}
    analysis_methods::Vector{String}
    output_formats::Vector{String}
    parameters::Dict{String, Any}
    llm_config::Dict{String, Any}
    memory_config::Dict{String, Any}

    # Constructor with default values
    function ResearchAgentConfig(
        name::String;
        research_areas::Vector{String}=["market", "technology", "sentiment"],
        data_sources::Vector{String}=["web", "api", "database"],
        analysis_methods::Vector{String}=["statistical", "nlp", "trend"],
        output_formats::Vector{String}=["text", "json", "chart"],
        parameters::Dict{String, Any}=Dict{String, Any}(),
        llm_config::Dict{String, Any}=Dict{String, Any}(),
        memory_config::Dict{String, Any}=Dict{String, Any}()
    )
        # Set default LLM config if not provided
        if isempty(llm_config)
            llm_config = Dict(
                "provider" => "openai",
                "model" => "gpt-4",
                "temperature" => 0.7,
                "max_tokens" => 2000
            )
        end

        # Set default memory config if not provided
        if isempty(memory_config)
            memory_config = Dict(
                "max_size" => 2000,
                "retention_policy" => "lru"
            )
        end

        new(
            name,
            research_areas,
            data_sources,
            analysis_methods,
            output_formats,
            parameters,
            llm_config,
            memory_config
        )
    end
end

"""
    createResearchAgent(config::ResearchAgentConfig)

Create a new research agent with the specified configuration.

# Arguments
- `config::ResearchAgentConfig`: Configuration for the new research agent

# Returns
- `Agent`: The created agent
"""
function createResearchAgent(config::ResearchAgentConfig)
    # Create agent abilities based on research areas and methods
    abilities = String[]
    for area in config.research_areas
        push!(abilities, "research_$(area)")
    end
    for method in config.analysis_methods
        push!(abilities, "analysis_$(method)")
    end
    push!(abilities, "data_collection")
    push!(abilities, "report_generation")

    # Create agent parameters
    parameters = Dict{String, Any}(
        "research_areas" => config.research_areas,
        "data_sources" => config.data_sources,
        "analysis_methods" => config.analysis_methods,
        "output_formats" => config.output_formats
    )

    # Merge with additional parameters
    for (key, value) in config.parameters
        parameters[key] = value
    end

    # Create agent config
    agent_config = Agents.AgentConfig(
        config.name,
        Agents.AgentType.RESEARCH,
        abilities=abilities,
        chains=String[],  # Research agents don't need chains by default
        parameters=parameters,
        llm_config=config.llm_config,
        memory_config=config.memory_config
    )

    # Create the agent
    return Agents.createAgent(agent_config)
end

"""
    conductResearch(agent::Agents.Agent, research::Dict{String, Any})

Conduct research with the specified agent.

# Arguments
- `agent::Agents.Agent`: The research agent
- `research::Dict{String, Any}`: Research specification

# Returns
- `Dict`: Research result
"""
function conductResearch(agent::Agents.Agent, research::Dict{String, Any})
    # Validate agent type
    if agent.type != Agents.AgentType.RESEARCH
        throw(ArgumentError("Agent is not a research agent"))
    end

    # Validate research parameters
    if !haskey(research, "topic")
        throw(ArgumentError("Research must specify a topic"))
    end
    if !haskey(research, "depth")
        research["depth"] = "medium"  # Default depth
    end

    # Execute the research via the agent task system
    task = Dict{String, Any}(
        "action" => "conduct_research",
        "research" => research
    )

    return Agents.executeAgentTask(agent.id, task)
end

"""
    getResearchHistory(agent::Agents.Agent; limit::Int=10)

Get the research history of a research agent.

# Arguments
- `agent::Agents.Agent`: The research agent
- `limit::Int`: Maximum number of research items to return

# Returns
- `Dict`: Research history
"""
function getResearchHistory(agent::Agents.Agent; limit::Int=10)
    # Validate agent type
    if agent.type != Agents.AgentType.RESEARCH
        throw(ArgumentError("Agent is not a research agent"))
    end

    # Get the research history via the agent task system
    task = Dict{String, Any}(
        "action" => "get_research_history",
        "limit" => limit
    )

    return Agents.executeAgentTask(agent.id, task)
end

end # module
