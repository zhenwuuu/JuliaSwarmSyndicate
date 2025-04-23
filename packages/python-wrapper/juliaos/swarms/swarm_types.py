"""
Swarm types and status enums for the JuliaOS Python wrapper.
"""

from enum import Enum, auto


class SwarmType(str, Enum):
    """
    Enum for swarm types.
    """
    OPTIMIZATION = "OPTIMIZATION"
    TRADING = "TRADING"
    RESEARCH = "RESEARCH"
    MONITORING = "MONITORING"
    GOVERNANCE = "GOVERNANCE"


class SwarmStatus(str, Enum):
    """
    Enum for swarm status.
    """
    CREATED = "CREATED"
    RUNNING = "RUNNING"
    PAUSED = "PAUSED"
    STOPPED = "STOPPED"
    COMPLETED = "COMPLETED"
    ERROR = "ERROR"


class SwarmAlgorithm(str, Enum):
    """
    Enum for swarm algorithms.
    """
    DE = "DE"   # Differential Evolution
    PSO = "PSO"  # Particle Swarm Optimization
    GWO = "GWO"  # Grey Wolf Optimizer
    ACO = "ACO"  # Ant Colony Optimization
    GA = "GA"   # Genetic Algorithm
    WOA = "WOA"  # Whale Optimization Algorithm
