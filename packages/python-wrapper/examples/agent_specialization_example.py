"""
Example script demonstrating the use of the Agent Specialization Framework.

This script shows how to create and manage agent skills and specializations.
"""

import asyncio
import json
from datetime import datetime

from juliaos import JuliaOS
from juliaos.agents import (
    AgentSkills, Skill, SkillCategory, SkillLevel, SpecializationPath
)


async def print_skill_info(skill):
    """Print detailed information about a skill."""
    print(f"Skill: {skill.name} ({skill.id})")
    print(f"  Category: {skill.category}")
    print(f"  Description: {skill.description}")
    print(f"  Level: {skill.level} ({skill.level_name})")
    print(f"  Experience: {skill.experience:.2f}")
    print(f"  Proficiency: {skill.proficiency * 100:.1f}% to next level")
    print(f"  Performance Bonus: {(skill.performance_bonus - 1.0) * 100:.1f}%")
    print(f"  Usage Count: {skill.usage_count}")
    print(f"  Last Used: {skill.last_used.strftime('%Y-%m-%d %H:%M:%S')}")


async def print_agent_skills(agent_skills):
    """Print detailed information about an agent's skills."""
    agent_id = agent_skills.agent_id
    specialization = await agent_skills.get_specialization()
    
    print(f"Agent: {agent_id}")
    print(f"Specialization: {specialization}")
    
    # Get all skills
    skills = await agent_skills.get_skills()
    
    print(f"Total Skills: {len(skills)}")
    
    # Group skills by category
    skills_by_category = {}
    
    for skill_id, skill in skills.items():
        if skill.category not in skills_by_category:
            skills_by_category[skill.category] = []
        skills_by_category[skill.category].append(skill)
    
    # Print skills by category
    for category in sorted(skills_by_category.keys()):
        print(f"\n== {category.upper()} ==")
        
        # Sort skills by level
        category_skills = sorted(skills_by_category[category], key=lambda s: s.level, reverse=True)
        
        for skill in category_skills:
            print(f"  {skill.name} (Level {skill.level} - {skill.level_name})")


async def main():
    """Main function to run the example."""
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    print("=== Agent Specialization Example ===")
    
    try:
        # Create a new agent with initial skills
        print("\nCreating a new agent...")
        agent_id = f"agent-{hash(datetime.now()) % 10000}"
        agent_skills = AgentSkills(juliaos.bridge, agent_id)
        await agent_skills.initialize()
        
        print("\nInitial agent skills:")
        await print_agent_skills(agent_skills)
        
        # Add some specialized skills
        print("\nAdding specialized skills...")
        
        # Add a trading skill
        trading_skill = Skill(
            id="trading_strategy",
            name="Trading Strategy",
            description="Ability to develop and execute trading strategies",
            category=SkillCategory.TRADING
        )
        await agent_skills.add_skill(trading_skill)
        
        # Add an optimization skill
        optimization_skill = Skill(
            id="parameter_tuning",
            name="Parameter Tuning",
            description="Ability to optimize algorithm parameters",
            category=SkillCategory.OPTIMIZATION
        )
        await agent_skills.add_skill(optimization_skill)
        
        print("\nAgent skills after adding specialized skills:")
        await print_agent_skills(agent_skills)
        
        # Specialize the agent as a trader
        print("\nSpecializing agent as a trader...")
        await agent_skills.set_specialization(SpecializationPath.TRADER)
        
        print("\nAgent skills after specialization:")
        await print_agent_skills(agent_skills)
        
        # Use and train skills
        print("\nUsing and training skills...")
        
        # Use the trading strategy skill (medium difficulty task)
        print("\nUsing trading strategy skill (medium difficulty)...")
        result = await agent_skills.use_skill("trading_strategy", 0.5)
        if result.get("leveled_up", False):
            print("  Skill leveled up!")
        print(f"  Performance bonus: {(result.get('bonus', 1.0) - 1.0) * 100:.1f}%")
        
        # Train the parameter tuning skill (high intensity)
        print("\nTraining parameter tuning skill (high intensity)...")
        result = await agent_skills.train_skill("parameter_tuning", 0.8)
        if result.get("leveled_up", False):
            print("  Skill leveled up!")
        
        # Use the communication skill (low difficulty task)
        print("\nUsing communication skill (low difficulty)...")
        result = await agent_skills.use_skill("communication", 0.2)
        if result.get("leveled_up", False):
            print("  Skill leveled up!")
        print(f"  Performance bonus: {(result.get('bonus', 1.0) - 1.0) * 100:.1f}%")
        
        print("\nAgent skills after using and training:")
        await print_agent_skills(agent_skills)
        
        # Print detailed information about a specific skill
        print("\nDetailed information about trading strategy skill:")
        trading_skill = await agent_skills.get_skill("trading_strategy")
        await print_skill_info(trading_skill)
        
        # Save agent skills to a file
        print("\nSaving agent skills to file...")
        save_path = f"agent_{agent_id}_skills.json"
        success = await agent_skills.save(save_path)
        if success:
            print(f"  Saved to {save_path}")
        else:
            print("  Failed to save agent skills")
        
        # Load agent skills from file
        print("\nLoading agent skills from file...")
        loaded_agent_skills = await AgentSkills.load(juliaos.bridge, save_path)
        print(f"  Loaded agent: {loaded_agent_skills.agent_id}")
        
        # Demonstrate specialization bonuses
        print("\nDemonstrating specialization bonuses:")
        trading_bonus = await agent_skills.get_specialization_bonus("trading_strategy")
        print(f"  Trading skill bonus (in specialization): {(trading_bonus - 1.0) * 100:.1f}%")
        
        optimization_bonus = await agent_skills.get_specialization_bonus("parameter_tuning")
        print(f"  Optimization skill bonus (outside specialization): {(optimization_bonus - 1.0) * 100:.1f}%")
        
        # Change specialization to optimizer
        print("\nChanging specialization to optimizer...")
        await agent_skills.set_specialization(SpecializationPath.OPTIMIZER)
        
        print("\nSpecialization bonuses after change:")
        trading_bonus = await agent_skills.get_specialization_bonus("trading_strategy")
        print(f"  Trading skill bonus (outside specialization): {(trading_bonus - 1.0) * 100:.1f}%")
        
        optimization_bonus = await agent_skills.get_specialization_bonus("parameter_tuning")
        print(f"  Optimization skill bonus (in specialization): {(optimization_bonus - 1.0) * 100:.1f}%")
        
        # Print recommended skills for current specialization
        print("\nRecommended skills for optimizer specialization:")
        recommended = SpecializationPath.recommended_skills(SpecializationPath.OPTIMIZER)
        for skill_id in recommended:
            print(f"  - {skill_id}")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("\nDisconnected from JuliaOS")


if __name__ == "__main__":
    asyncio.run(main())
