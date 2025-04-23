"""
Agent types and status enums for the JuliaOS Python wrapper.
"""

from enum import Enum


class AgentType(str, Enum):
    """
    Enum for agent types.
    """
    # Core agent types
    GENERIC = "GENERIC"
    TRADING = "TRADING"
    MONITOR = "MONITOR"
    ARBITRAGE = "ARBITRAGE"
    DATA = "DATA"
    RESEARCH = "RESEARCH"
    SOCIAL = "SOCIAL"
    GOVERNANCE = "GOVERNANCE"

    # Trading-related agent types
    MARKET_MAKING = "MARKET_MAKING"
    LIQUIDITY = "LIQUIDITY"
    PORTFOLIO = "PORTFOLIO"
    YIELD_FARMING = "YIELD_FARMING"
    LENDING = "LENDING"
    BORROWING = "BORROWING"
    STAKING = "STAKING"

    # Analysis-related agent types
    SENTIMENT = "SENTIMENT"
    NEWS = "NEWS"
    ANALYTICS = "ANALYTICS"
    PREDICTION = "PREDICTION"
    RISK = "RISK"

    # Specialized agent types
    NFT = "NFT"
    DAO = "DAO"
    CROSS_CHAIN = "CROSS_CHAIN"
    DEX = "DEX"
    CEX = "CEX"


class AgentStatus(str, Enum):
    """
    Enum for agent status.
    """
    CREATED = "CREATED"
    INITIALIZING = "INITIALIZING"
    RUNNING = "RUNNING"
    PAUSED = "PAUSED"
    STOPPED = "STOPPED"
    ERROR = "ERROR"
    RECOVERING = "RECOVERING"
    DELETED = "DELETED"


class AgentEvent(str, Enum):
    """
    Enum for agent events.
    """
    CREATED = "agent:created"
    INITIALIZED = "agent:initialized"
    STARTED = "agent:started"
    PAUSED = "agent:paused"
    STOPPED = "agent:stopped"
    ERROR = "agent:error"
    DELETED = "agent:deleted"
    TASK_CREATED = "agent:task:created"
    TASK_COMPLETED = "agent:task:completed"
    TASK_FAILED = "agent:task:failed"
    CONFIG_UPDATED = "agent:config:updated"
    MESSAGE_RECEIVED = "agent:message:received"
    MESSAGE_SENT = "agent:message:sent"
