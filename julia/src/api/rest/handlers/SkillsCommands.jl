"""
    SkillsCommands module for JuliaOS

This module provides command handlers for the Skills module.
"""

module SkillsCommands

using Logging
using Dates
using JSON

# Import Skills module
include("../Skills.jl")
using .Skills

export register_skills_commands

"""
    register_skills_commands(bridge)

Register Skills module commands with the bridge.
"""
function register_skills_commands(bridge)
    @info "Registering Skills module commands"

    # Register command handlers
    bridge.register_command_handler("Skills.get_agent_skill_set", get_agent_skill_set_handler)
    bridge.register_command_handler("Skills.train_skill", train_skill_handler)
    bridge.register_command_handler("Skills.use_skill", use_skill_handler)
    bridge.register_command_handler("Skills.get_agent_specialization", get_agent_specialization_handler)
    bridge.register_command_handler("Skills.set_agent_specialization", set_agent_specialization_handler)
    bridge.register_command_handler("Skills.SpecializationPath.all", specialization_path_all_handler)
    bridge.register_command_handler("Skills.SpecializationPath.recommended_skills", specialization_path_recommended_skills_handler)
    bridge.register_command_handler("Skills.SpecializationPath.primary_category", specialization_path_primary_category_handler)
    bridge.register_command_handler("Skills.SpecializationPath.specialization_bonus", specialization_path_specialization_bonus_handler)
    bridge.register_command_handler("Skills.SpecializationPath.get_details", specialization_path_get_details_handler)
    bridge.register_command_handler("Skills.get_all_specialization_paths", get_all_specialization_paths_handler)
    bridge.register_command_handler("Skills.get_specialization_path_details", get_specialization_path_details_handler)

    # Register new command handlers for CLI menu
    bridge.register_command_handler("skills.list_available_skills", list_available_skills_handler)
    bridge.register_command_handler("skills.get_skill_details", get_skill_details_handler)
    bridge.register_command_handler("skills.list_specializations", list_specializations_handler)

    @info "Skills module commands registered"
end

# Command handlers

"""
    get_agent_skill_set_handler(params)

Handle the Skills.get_agent_skill_set command.
"""
function get_agent_skill_set_handler(params)
    try
        # Extract agent ID from params
        agent_id = params[1]

        # Get agent skills
        agent_skills = Skills.get_agent_skill_set(agent_id)

        # Convert skills to a format suitable for JSON
        skills_dict = Dict()
        for (id, skill) in agent_skills
            skills_dict[id] = Dict(
                "id" => skill.id,
                "name" => skill.name,
                "description" => skill.description,
                "category" => skill.category,
                "level" => skill.level,
                "level_name" => Skills.SkillLevel.get_name(skill.level),
                "experience" => skill.experience,
                "proficiency" => Skills.get_proficiency(skill),
                "performance_bonus" => Skills.get_bonus(skill),
                "usage_count" => skill.usage_count,
                "last_used" => string(skill.last_used)
            )
        end

        return Dict(
            "success" => true,
            "skills" => skills_dict
        )
    catch e
        @error "Error in get_agent_skill_set_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get agent skill set: $(e)"
        )
    end
end

"""
    train_skill_handler(params)

Handle the Skills.train_skill command.
"""
function train_skill_handler(params)
    try
        # Extract parameters
        agent_id = params[1]
        skill_id = params[2]
        intensity = params[3]

        # Train the skill
        agent_skills, leveled_up = Skills.train_skill(agent_id, skill_id, intensity)

        return Dict(
            "success" => true,
            "leveled_up" => leveled_up
        )
    catch e
        @error "Error in train_skill_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to train skill: $(e)"
        )
    end
end

"""
    use_skill_handler(params)

Handle the Skills.use_skill command.
"""
function use_skill_handler(params)
    try
        # Extract parameters
        agent_id = params[1]
        skill_id = params[2]
        task_difficulty = params[3]

        # Use the skill
        agent_skills, leveled_up, bonus = Skills.use_skill(agent_id, skill_id, task_difficulty)

        return Dict(
            "success" => true,
            "leveled_up" => leveled_up,
            "bonus" => bonus
        )
    catch e
        @error "Error in use_skill_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to use skill: $(e)"
        )
    end
end

"""
    get_agent_specialization_handler(params)

Handle the Skills.get_agent_specialization command.
"""
function get_agent_specialization_handler(params)
    try
        # Extract agent ID
        agent_id = params[1]

        # Get agent specialization
        specialization = Skills.get_agent_specialization(agent_id)

        return Dict(
            "success" => true,
            "specialization" => specialization
        )
    catch e
        @error "Error in get_agent_specialization_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get agent specialization: $(e)"
        )
    end
end

"""
    set_agent_specialization_handler(params)

Handle the Skills.set_agent_specialization command.
"""
function set_agent_specialization_handler(params)
    try
        # Extract parameters
        agent_id = params[1]
        specialization = params[2]

        # Set agent specialization
        Skills.set_agent_specialization(agent_id, specialization)

        return Dict(
            "success" => true
        )
    catch e
        @error "Error in set_agent_specialization_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to set agent specialization: $(e)"
        )
    end
end

"""
    specialization_path_all_handler(params)

Handle the Skills.SpecializationPath.all command.
"""
function specialization_path_all_handler(params)
    try
        # Get all specialization paths
        # Make sure we're calling the correct function
        paths = Skills.AgentSpecialization.SpecializationPath.all()

        # Print the paths for debugging
        @info "Specialization paths: $paths"
        @info "Type of paths: $(typeof(paths))"

        # If paths is empty, return an empty array
        if isnothing(paths) || isempty(paths)
            @info "No specialization paths found"
            return Dict(
                "paths" => String[]
            )
        end

        # Create a response dictionary
        response = Dict(
            "paths" => paths
        )

        # Print the response for debugging
        @info "Response: $response"

        # Return the paths directly
        return response
    catch e
        @error "Error in specialization_path_all_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "error" => "Failed to get specialization paths: $(e)"
        )
    end
end

"""
    specialization_path_recommended_skills_handler(params)

Handle the Skills.SpecializationPath.recommended_skills command.
"""
function specialization_path_recommended_skills_handler(params)
    try
        # Extract specialization path
        path = params[1]

        # Get recommended skills for the path
        skills = Skills.AgentSpecialization.SpecializationPath.recommended_skills(path)

        return Dict(
            "skills" => skills
        )
    catch e
        @error "Error in specialization_path_recommended_skills_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "error" => "Failed to get recommended skills: $(e)"
        )
    end
end

"""
    specialization_path_primary_category_handler(params)

Handle the Skills.SpecializationPath.primary_category command.
"""
function specialization_path_primary_category_handler(params)
    try
        # Extract specialization path
        path = params[1]

        # Get primary category for the path
        category = Skills.AgentSpecialization.SpecializationPath.primary_category(path)

        return Dict(
            "category" => string(category)
        )
    catch e
        @error "Error in specialization_path_primary_category_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "error" => "Failed to get primary category: $(e)"
        )
    end
end

"""
    specialization_path_specialization_bonus_handler(params)

Handle the Skills.SpecializationPath.specialization_bonus command.
"""
function specialization_path_specialization_bonus_handler(params)
    try
        # Extract specialization path
        path = params[1]

        # Get specialization bonus for the path
        bonus = Skills.AgentSpecialization.SpecializationPath.specialization_bonus(path)

        return Dict(
            "bonus" => bonus
        )
    catch e
        @error "Error in specialization_path_specialization_bonus_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "error" => "Failed to get specialization bonus: $(e)"
        )
    end
end

"""
    specialization_path_get_details_handler(params)

Handle the Skills.SpecializationPath.get_details command.
"""
function specialization_path_get_details_handler(params)
    try
        # Extract specialization path
        path = params[1]

        # Get details for the path
        details = Skills.AgentSpecialization.SpecializationPath.get_details(path)

        if isnothing(details)
            return Dict(
                "success" => false,
                "error" => "Invalid specialization path: $(path)"
            )
        end

        return Dict(
            "success" => true,
            "details" => details
        )
    catch e
        @error "Error in specialization_path_get_details_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get specialization path details: $(e)"
        )
    end
end

"""
    get_all_specialization_paths_handler(params)

Handle the Skills.get_all_specialization_paths command.
"""
function get_all_specialization_paths_handler(params)
    try
        # Get all specialization paths
        paths = Skills.get_all_specialization_paths()

        return Dict(
            "success" => true,
            "paths" => paths
        )
    catch e
        @error "Error in get_all_specialization_paths_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get all specialization paths: $(e)"
        )
    end
end

"""
    get_specialization_path_details_handler(params)

Handle the Skills.get_specialization_path_details command.
"""
function get_specialization_path_details_handler(params)
    try
        # Extract specialization path
        path = params[1]

        # Get details for the path
        details = Skills.get_specialization_path_details(path)

        if isnothing(details)
            return Dict(
                "success" => false,
                "error" => "Invalid specialization path: $(path)"
            )
        end

        return Dict(
            "success" => true,
            "details" => details
        )
    catch e
        @error "Error in get_specialization_path_details_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get specialization path details: $(e)"
        )
    end
end

"""
    list_available_skills_handler(params)

Handle the skills.list_available_skills command.
"""
function list_available_skills_handler(params)
    try
        # Define a list of available skills
        available_skills = [
            Dict(
                "id" => "trading_strategy",
                "name" => "Trading Strategy",
                "description" => "Ability to develop and execute trading strategies",
                "category" => "Trading",
                "required_capabilities" => ["basic", "trading"]
            ),
            Dict(
                "id" => "risk_management",
                "name" => "Risk Management",
                "description" => "Ability to assess and manage trading risks",
                "category" => "Trading",
                "required_capabilities" => ["basic", "trading"]
            ),
            Dict(
                "id" => "technical_analysis",
                "name" => "Technical Analysis",
                "description" => "Ability to analyze price charts and indicators",
                "category" => "Analysis",
                "required_capabilities" => ["basic", "analysis"]
            ),
            Dict(
                "id" => "fundamental_analysis",
                "name" => "Fundamental Analysis",
                "description" => "Ability to analyze project fundamentals and tokenomics",
                "category" => "Analysis",
                "required_capabilities" => ["basic", "analysis"]
            ),
            Dict(
                "id" => "sentiment_analysis",
                "name" => "Sentiment Analysis",
                "description" => "Ability to analyze market sentiment from social media and news",
                "category" => "Analysis",
                "required_capabilities" => ["basic", "analysis", "ml"]
            ),
            Dict(
                "id" => "network_optimization",
                "name" => "Network Optimization",
                "description" => "Ability to optimize network connections and protocols",
                "category" => "Networking",
                "required_capabilities" => ["basic", "networking"]
            ),
            Dict(
                "id" => "smart_contract_development",
                "name" => "Smart Contract Development",
                "description" => "Ability to develop and audit smart contracts",
                "category" => "Development",
                "required_capabilities" => ["basic", "development"]
            ),
            Dict(
                "id" => "encryption",
                "name" => "Encryption",
                "description" => "Ability to encrypt and decrypt data securely",
                "category" => "Security",
                "required_capabilities" => ["basic", "security"]
            )
        ]

        return Dict(
            "success" => true,
            "skills" => available_skills
        )
    catch e
        @error "Error in list_available_skills_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to list available skills: $(e)"
        )
    end
end

"""
    get_skill_details_handler(params)

Handle the skills.get_skill_details command.
"""
function get_skill_details_handler(params)
    try
        # Extract skill ID
        skill_id = get(params, "skill_id", "")

        if skill_id == ""
            return Dict(
                "success" => false,
                "error" => "Missing required parameter: skill_id"
            )
        end

        # Define skill details based on skill_id
        skill_details = nothing

        if skill_id == "trading_strategy"
            skill_details = Dict(
                "id" => "trading_strategy",
                "name" => "Trading Strategy",
                "description" => "Ability to develop and execute trading strategies",
                "category" => "Trading",
                "required_capabilities" => ["basic", "trading"],
                "levels" => [
                    Dict("level" => 1, "name" => "Novice", "description" => "Basic understanding of trading concepts"),
                    Dict("level" => 2, "name" => "Apprentice", "description" => "Can implement simple trading strategies"),
                    Dict("level" => 3, "name" => "Journeyman", "description" => "Can develop and optimize trading strategies"),
                    Dict("level" => 4, "name" => "Expert", "description" => "Can develop complex trading strategies with multiple indicators"),
                    Dict("level" => 5, "name" => "Master", "description" => "Can develop and execute advanced trading strategies with high success rates")
                ],
                "related_skills" => ["risk_management", "technical_analysis", "fundamental_analysis"]
            )
        elseif skill_id == "risk_management"
            skill_details = Dict(
                "id" => "risk_management",
                "name" => "Risk Management",
                "description" => "Ability to assess and manage trading risks",
                "category" => "Trading",
                "required_capabilities" => ["basic", "trading"],
                "levels" => [
                    Dict("level" => 1, "name" => "Novice", "description" => "Basic understanding of risk concepts"),
                    Dict("level" => 2, "name" => "Apprentice", "description" => "Can implement simple risk management techniques"),
                    Dict("level" => 3, "name" => "Journeyman", "description" => "Can develop and optimize risk management strategies"),
                    Dict("level" => 4, "name" => "Expert", "description" => "Can develop complex risk management strategies"),
                    Dict("level" => 5, "name" => "Master", "description" => "Can develop and execute advanced risk management strategies with high success rates")
                ],
                "related_skills" => ["trading_strategy", "technical_analysis"]
            )
        elseif skill_id == "technical_analysis"
            skill_details = Dict(
                "id" => "technical_analysis",
                "name" => "Technical Analysis",
                "description" => "Ability to analyze price charts and indicators",
                "category" => "Analysis",
                "required_capabilities" => ["basic", "analysis"],
                "levels" => [
                    Dict("level" => 1, "name" => "Novice", "description" => "Basic understanding of technical indicators"),
                    Dict("level" => 2, "name" => "Apprentice", "description" => "Can use common technical indicators"),
                    Dict("level" => 3, "name" => "Journeyman", "description" => "Can develop and optimize technical analysis strategies"),
                    Dict("level" => 4, "name" => "Expert", "description" => "Can develop complex technical analysis strategies"),
                    Dict("level" => 5, "name" => "Master", "description" => "Can develop and execute advanced technical analysis with high accuracy")
                ],
                "related_skills" => ["trading_strategy", "pattern_recognition"]
            )
        else
            return Dict(
                "success" => false,
                "error" => "Skill not found: $skill_id"
            )
        end

        return Dict(
            "success" => true,
            "skill" => skill_details
        )
    catch e
        @error "Error in get_skill_details_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to get skill details: $(e)"
        )
    end
end

"""
    list_specializations_handler(params)

Handle the skills.list_specializations command.
"""
function list_specializations_handler(params)
    try
        # Get all specialization paths
        paths = Skills.get_all_specialization_paths()

        # Get details for each path
        specializations = []
        for path in paths
            details = Skills.get_specialization_path_details(path)
            if details !== nothing
                push!(specializations, details)
            end
        end

        return Dict(
            "success" => true,
            "specializations" => specializations
        )
    catch e
        @error "Error in list_specializations_handler: $e" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Failed to list specializations: $(e)"
        )
    end
end

end # module
