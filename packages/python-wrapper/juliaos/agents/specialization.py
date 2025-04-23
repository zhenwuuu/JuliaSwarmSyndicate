"""
Agent Specialization module for JuliaOS.

This module provides classes and functions for working with agent skills and specializations.
"""

from enum import Enum
from typing import Dict, List, Optional, Tuple, Union, Any
from datetime import datetime
import json

from ..bridge import JuliaBridge


class SkillCategory(str, Enum):
    """Skill categories."""
    ANALYSIS = "analysis"
    TRADING = "trading"
    COMMUNICATION = "communication"
    RESEARCH = "research"
    OPTIMIZATION = "optimization"
    PREDICTION = "prediction"
    RISK_MANAGEMENT = "risk_management"
    SECURITY = "security"
    GENERAL = "general"


class SkillLevel(int, Enum):
    """Skill levels."""
    NOVICE = 1
    APPRENTICE = 2
    COMPETENT = 3
    PROFICIENT = 4
    EXPERT = 5
    MASTER = 6
    
    @classmethod
    def name(cls, level: int) -> str:
        """Get the name of a skill level."""
        if level == cls.NOVICE:
            return "Novice"
        elif level == cls.APPRENTICE:
            return "Apprentice"
        elif level == cls.COMPETENT:
            return "Competent"
        elif level == cls.PROFICIENT:
            return "Proficient"
        elif level == cls.EXPERT:
            return "Expert"
        elif level == cls.MASTER:
            return "Master"
        else:
            return "Unknown"
    
    @classmethod
    def experience_required(cls, level: int) -> int:
        """Get the experience required for a skill level."""
        if level == cls.NOVICE:
            return 0
        elif level == cls.APPRENTICE:
            return 100
        elif level == cls.COMPETENT:
            return 300
        elif level == cls.PROFICIENT:
            return 600
        elif level == cls.EXPERT:
            return 1000
        elif level == cls.MASTER:
            return 1500
        else:
            return 0
    
    @classmethod
    def performance_bonus(cls, level: int) -> float:
        """Get the performance bonus for a skill level."""
        if level == cls.NOVICE:
            return 1.0  # No bonus
        elif level == cls.APPRENTICE:
            return 1.1  # 10% bonus
        elif level == cls.COMPETENT:
            return 1.25  # 25% bonus
        elif level == cls.PROFICIENT:
            return 1.5  # 50% bonus
        elif level == cls.EXPERT:
            return 1.75  # 75% bonus
        elif level == cls.MASTER:
            return 2.0  # 100% bonus
        else:
            return 1.0
    
    @classmethod
    def for_experience(cls, experience: float) -> int:
        """Get the level for a given experience amount."""
        if experience >= cls.experience_required(cls.MASTER):
            return cls.MASTER
        elif experience >= cls.experience_required(cls.EXPERT):
            return cls.EXPERT
        elif experience >= cls.experience_required(cls.PROFICIENT):
            return cls.PROFICIENT
        elif experience >= cls.experience_required(cls.COMPETENT):
            return cls.COMPETENT
        elif experience >= cls.experience_required(cls.APPRENTICE):
            return cls.APPRENTICE
        else:
            return cls.NOVICE


class SpecializationPath(str, Enum):
    """Agent specialization paths."""
    ANALYST = "analyst"
    TRADER = "trader"
    RESEARCHER = "researcher"
    OPTIMIZER = "optimizer"
    PREDICTOR = "predictor"
    RISK_MANAGER = "risk_manager"
    SECURITY_EXPERT = "security_expert"
    GENERALIST = "generalist"
    
    @classmethod
    def primary_category(cls, path: str) -> str:
        """Get the primary skill category for a specialization path."""
        if path == cls.ANALYST:
            return SkillCategory.ANALYSIS
        elif path == cls.TRADER:
            return SkillCategory.TRADING
        elif path == cls.RESEARCHER:
            return SkillCategory.RESEARCH
        elif path == cls.OPTIMIZER:
            return SkillCategory.OPTIMIZATION
        elif path == cls.PREDICTOR:
            return SkillCategory.PREDICTION
        elif path == cls.RISK_MANAGER:
            return SkillCategory.RISK_MANAGEMENT
        elif path == cls.SECURITY_EXPERT:
            return SkillCategory.SECURITY
        else:
            return SkillCategory.GENERAL
    
    @classmethod
    def specialization_bonus(cls, path: str) -> float:
        """Get the specialization bonus for a path."""
        if path == cls.GENERALIST:
            return 1.1  # 10% bonus for all skills
        else:
            return 1.25  # 25% bonus for skills in the primary category
    
    @classmethod
    def recommended_skills(cls, path: str) -> List[str]:
        """Get recommended skills for a specialization path."""
        if path == cls.ANALYST:
            return [
                "data_analysis", "pattern_recognition", "market_analysis",
                "technical_analysis", "fundamental_analysis", "sentiment_analysis"
            ]
        elif path == cls.TRADER:
            return [
                "order_execution", "market_timing", "position_sizing",
                "risk_assessment", "portfolio_management", "trading_strategy"
            ]
        elif path == cls.RESEARCHER:
            return [
                "data_collection", "hypothesis_testing", "literature_review",
                "experiment_design", "statistical_analysis", "report_writing"
            ]
        elif path == cls.OPTIMIZER:
            return [
                "parameter_tuning", "algorithm_design", "performance_optimization",
                "constraint_handling", "multi_objective_optimization", "metaheuristics"
            ]
        elif path == cls.PREDICTOR:
            return [
                "time_series_forecasting", "machine_learning", "feature_engineering",
                "model_validation", "ensemble_methods", "anomaly_detection"
            ]
        elif path == cls.RISK_MANAGER:
            return [
                "risk_assessment", "risk_mitigation", "compliance",
                "scenario_analysis", "stress_testing", "risk_reporting"
            ]
        elif path == cls.SECURITY_EXPERT:
            return [
                "threat_detection", "vulnerability_assessment", "security_protocols",
                "encryption", "authentication", "incident_response"
            ]
        else:  # GENERALIST
            return [
                "communication", "problem_solving", "critical_thinking",
                "adaptability", "time_management", "decision_making"
            ]


class Skill:
    """A skill that an agent can acquire and improve."""
    
    def __init__(
        self,
        id: str,
        name: str,
        description: str,
        category: str,
        experience: float = 0.0,
        last_used: Optional[datetime] = None,
        usage_count: int = 0
    ):
        """
        Initialize a skill.
        
        Args:
            id: Unique identifier for the skill
            name: Display name for the skill
            description: Description of what the skill enables
            category: Category of the skill (from SkillCategory)
            experience: Current experience points
            last_used: When the skill was last used
            usage_count: How many times the skill has been used
        """
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.experience = experience
        self.last_used = last_used or datetime.now()
        self.usage_count = usage_count
    
    @property
    def level(self) -> int:
        """Get the current level of the skill."""
        return SkillLevel.for_experience(self.experience)
    
    @property
    def level_name(self) -> str:
        """Get the name of the current level."""
        return SkillLevel.name(self.level)
    
    @property
    def proficiency(self) -> float:
        """Get the proficiency as a percentage to the next level."""
        current_level = self.level
        
        # If at max level, return 1.0
        if current_level == SkillLevel.MASTER:
            return 1.0
        
        # Calculate progress to next level
        current_level_exp = SkillLevel.experience_required(current_level)
        next_level_exp = SkillLevel.experience_required(current_level + 1)
        
        # Calculate percentage
        return (self.experience - current_level_exp) / (next_level_exp - current_level_exp)
    
    @property
    def performance_bonus(self) -> float:
        """Get the performance bonus for the skill."""
        return SkillLevel.performance_bonus(self.level)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the skill to a dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "category": self.category,
            "experience": self.experience,
            "last_used": self.last_used.isoformat(),
            "usage_count": self.usage_count,
            "level": self.level,
            "level_name": self.level_name,
            "proficiency": self.proficiency,
            "performance_bonus": self.performance_bonus
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Skill':
        """Create a skill from a dictionary."""
        return cls(
            id=data["id"],
            name=data["name"],
            description=data["description"],
            category=data["category"],
            experience=data["experience"],
            last_used=datetime.fromisoformat(data["last_used"]) if "last_used" in data else None,
            usage_count=data["usage_count"]
        )


class AgentSkills:
    """Skills and specialization of an agent."""
    
    def __init__(self, bridge: JuliaBridge, agent_id: str):
        """
        Initialize agent skills.
        
        Args:
            bridge: JuliaBridge instance
            agent_id: ID of the agent
        """
        self.bridge = bridge
        self.agent_id = agent_id
    
    async def initialize(self) -> Dict[str, Any]:
        """
        Initialize skills for a new agent.
        
        Returns:
            Dict: Result of the initialization
        """
        result = await self.bridge.execute("Skills.initialize_agent_skills", [self.agent_id])
        return result
    
    async def get_skills(self) -> Dict[str, Skill]:
        """
        Get all skills of the agent.
        
        Returns:
            Dict[str, Skill]: Dictionary of skills
        """
        result = await self.bridge.execute("Skills.get_agent_skill_set", [self.agent_id])
        
        skills = {}
        for skill_id, skill_data in result["skills"].items():
            skills[skill_id] = Skill.from_dict(skill_data)
        
        return skills
    
    async def get_skill(self, skill_id: str) -> Optional[Skill]:
        """
        Get a specific skill of the agent.
        
        Args:
            skill_id: ID of the skill to get
        
        Returns:
            Optional[Skill]: The skill if found, None otherwise
        """
        skills = await self.get_skills()
        return skills.get(skill_id)
    
    async def add_skill(self, skill: Skill) -> Dict[str, Any]:
        """
        Add a skill to the agent.
        
        Args:
            skill: Skill to add
        
        Returns:
            Dict: Result of the operation
        """
        result = await self.bridge.execute("Skills.add_skill_to_agent", [
            self.agent_id,
            skill.to_dict()
        ])
        return result
    
    async def use_skill(self, skill_id: str, task_difficulty: float) -> Dict[str, Any]:
        """
        Use a skill, gaining experience based on the task difficulty.
        
        Args:
            skill_id: ID of the skill to use
            task_difficulty: Difficulty of the task (0.0 to 1.0)
        
        Returns:
            Dict: Result of the operation
        """
        result = await self.bridge.execute("Skills.use_skill", [
            self.agent_id,
            skill_id,
            task_difficulty
        ])
        return result
    
    async def train_skill(self, skill_id: str, training_intensity: float) -> Dict[str, Any]:
        """
        Deliberately train a skill to improve it.
        
        Args:
            skill_id: ID of the skill to train
            training_intensity: Intensity of training (0.0 to 1.0)
        
        Returns:
            Dict: Result of the operation
        """
        result = await self.bridge.execute("Skills.train_skill", [
            self.agent_id,
            skill_id,
            training_intensity
        ])
        return result
    
    async def get_specialization(self) -> str:
        """
        Get the specialization path of the agent.
        
        Returns:
            str: Specialization path
        """
        result = await self.bridge.execute("Skills.get_agent_specialization", [self.agent_id])
        return result
    
    async def set_specialization(self, specialization: str) -> Dict[str, Any]:
        """
        Set the specialization path of the agent.
        
        Args:
            specialization: Specialization path to set
        
        Returns:
            Dict: Result of the operation
        """
        result = await self.bridge.execute("Skills.set_agent_specialization", [
            self.agent_id,
            specialization
        ])
        return result
    
    async def get_specialization_bonus(self, skill_id: str) -> float:
        """
        Get the performance bonus for a skill based on the agent's specialization.
        
        Args:
            skill_id: ID of the skill to check
        
        Returns:
            float: Performance bonus as a multiplier
        """
        result = await self.bridge.execute("Skills.get_specialization_bonus", [
            self.agent_id,
            skill_id
        ])
        return result
    
    async def save(self, file_path: str) -> bool:
        """
        Save agent skills to a file.
        
        Args:
            file_path: Path to save to
        
        Returns:
            bool: True if successful, False otherwise
        """
        result = await self.bridge.execute("Skills.save_agent_skills", [
            self.agent_id,
            file_path
        ])
        return result
    
    @classmethod
    async def load(cls, bridge: JuliaBridge, file_path: str) -> 'AgentSkills':
        """
        Load agent skills from a file.
        
        Args:
            bridge: JuliaBridge instance
            file_path: Path to load from
        
        Returns:
            AgentSkills: Loaded agent skills
        """
        result = await bridge.execute("Skills.load_agent_skills", [file_path])
        agent_id = result["agent_id"]
        
        agent_skills = cls(bridge, agent_id)
        return agent_skills
