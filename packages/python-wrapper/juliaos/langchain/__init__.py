"""
LangChain integration for JuliaOS Python wrapper.

This module provides integration between LangChain and JuliaOS,
allowing users to use JuliaOS components with LangChain.
"""

from .agents import (
    JuliaOSAgentAdapter,
    JuliaOSTradingAgentAdapter,
    JuliaOSMonitorAgentAdapter,
    JuliaOSArbitrageAgentAdapter
)
from .agents_advanced import (
    JuliaOSPortfolioAgentAdapter,
    JuliaOSMarketMakingAgentAdapter,
    JuliaOSLiquidityAgentAdapter,
    JuliaOSYieldFarmingAgentAdapter,
    JuliaOSCrossChainAgentAdapter
)
from .tools import (
    JuliaOSBaseTool,
    SwarmOptimizationTool,
    BlockchainQueryTool,
    WalletOperationTool,
    StorageQueryTool,
    AgentTaskTool
)
from .tools_advanced import (
    CrossChainBridgeTool,
    DEXTradingTool,
    YieldFarmingTool,
    NFTTool,
    DAOTool,
    SocialMediaTool
)
from .memory import (
    JuliaOSMemory,
    JuliaOSConversationBufferMemory,
    JuliaOSVectorStoreMemory
)
from .chains import (
    JuliaOSChain,
    SwarmOptimizationChain,
    BlockchainAnalysisChain,
    TradingStrategyChain
)
from .retrievers import (
    JuliaOSRetriever,
    JuliaOSVectorStoreRetriever
)
from .utils import (
    serialize_langchain_object,
    deserialize_langchain_object,
    convert_to_langchain_format,
    convert_from_langchain_format
)

__all__ = [
    # Agents
    "JuliaOSAgentAdapter",
    "JuliaOSTradingAgentAdapter",
    "JuliaOSMonitorAgentAdapter",
    "JuliaOSArbitrageAgentAdapter",
    "JuliaOSPortfolioAgentAdapter",
    "JuliaOSMarketMakingAgentAdapter",
    "JuliaOSLiquidityAgentAdapter",
    "JuliaOSYieldFarmingAgentAdapter",
    "JuliaOSCrossChainAgentAdapter",

    # Tools
    "JuliaOSBaseTool",
    "SwarmOptimizationTool",
    "BlockchainQueryTool",
    "WalletOperationTool",
    "StorageQueryTool",
    "AgentTaskTool",
    "CrossChainBridgeTool",
    "DEXTradingTool",
    "YieldFarmingTool",
    "NFTTool",
    "DAOTool",
    "SocialMediaTool",

    # Memory
    "JuliaOSMemory",
    "JuliaOSConversationBufferMemory",
    "JuliaOSVectorStoreMemory",

    # Chains
    "JuliaOSChain",
    "SwarmOptimizationChain",
    "BlockchainAnalysisChain",
    "TradingStrategyChain",

    # Retrievers
    "JuliaOSRetriever",
    "JuliaOSVectorStoreRetriever",

    # Utils
    "serialize_langchain_object",
    "deserialize_langchain_object",
    "convert_to_langchain_format",
    "convert_from_langchain_format"
]
