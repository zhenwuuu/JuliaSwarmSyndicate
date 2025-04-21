module Skills

export SkillSystem, AgentSpecialization
export initialize_agent_skills, get_agent_skill_set, add_skill_to_agent
export use_skill, train_skill, get_specialization_bonus
export get_agent_specialization, set_agent_specialization
export save_agent_skills, load_agent_skills
export SkillCategory, SkillLevel, SpecializationPath

# Import from JuliaOS core
using JuliaOS.Skills

# Re-export all public symbols
for name in names(JuliaOS.Skills, all=true)
    if !startswith(string(name), "#") && name != :Skills
        @eval export $name
    end
end

end # module
