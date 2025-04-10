#!/usr/bin/env python3
"""
Test script to verify that the LangChain integration can be imported correctly.
"""

def test_imports():
    """
    Test that the LangChain integration can be imported correctly.
    """
    print("Testing imports...")

    # Test importing the langchain module
    try:
        from juliaos import langchain  # noqa: F401
        print("✅ Successfully imported juliaos.langchain")
    except ImportError as e:
        print(f"❌ Failed to import juliaos.langchain: {e}")
        return False

    # Test importing agent adapters
    try:
        from juliaos.langchain import (  # noqa: F401
            JuliaOSAgentAdapter,
            JuliaOSTradingAgentAdapter,
            JuliaOSMonitorAgentAdapter,
            JuliaOSArbitrageAgentAdapter,
            JuliaOSPortfolioAgentAdapter,
            JuliaOSMarketMakingAgentAdapter,
            JuliaOSLiquidityAgentAdapter,
            JuliaOSYieldFarmingAgentAdapter,
            JuliaOSCrossChainAgentAdapter
        )
        print("✅ Successfully imported agent adapters")
    except ImportError as e:
        print(f"❌ Failed to import agent adapters: {e}")
        return False

    # Test importing tools
    try:
        from juliaos.langchain import (  # noqa: F401
            JuliaOSBaseTool,
            SwarmOptimizationTool,
            BlockchainQueryTool,
            WalletOperationTool,
            StorageQueryTool,
            AgentTaskTool,
            CrossChainBridgeTool,
            DEXTradingTool,
            YieldFarmingTool,
            NFTTool,
            DAOTool,
            SocialMediaTool
        )
        print("✅ Successfully imported tools")
    except ImportError as e:
        print(f"❌ Failed to import tools: {e}")
        return False

    # Test importing memory classes
    try:
        from juliaos.langchain import (  # noqa: F401
            JuliaOSMemory,
            JuliaOSConversationBufferMemory,
            JuliaOSVectorStoreMemory
        )
        print("✅ Successfully imported memory classes")
    except ImportError as e:
        print(f"❌ Failed to import memory classes: {e}")
        return False

    # Test importing chains
    try:
        from juliaos.langchain import (  # noqa: F401
            JuliaOSChain,
            SwarmOptimizationChain,
            BlockchainAnalysisChain,
            TradingStrategyChain
        )
        print("✅ Successfully imported chains")
    except ImportError as e:
        print(f"❌ Failed to import chains: {e}")
        return False

    # Test importing retrievers
    try:
        from juliaos.langchain import (  # noqa: F401
            JuliaOSRetriever,
            JuliaOSVectorStoreRetriever
        )
        print("✅ Successfully imported retrievers")
    except ImportError as e:
        print(f"❌ Failed to import retrievers: {e}")
        return False

    # Test importing utility functions
    try:
        from juliaos.langchain import (  # noqa: F401
            serialize_langchain_object,
            deserialize_langchain_object,
            convert_to_langchain_format,
            convert_from_langchain_format
        )
        print("✅ Successfully imported utility functions")
    except ImportError as e:
        print(f"❌ Failed to import utility functions: {e}")
        return False

    print("All imports successful!")
    return True


if __name__ == "__main__":
    test_imports()
