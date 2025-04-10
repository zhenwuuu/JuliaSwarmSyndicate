"""
Unit tests for the LangChain integration with JuliaOS.

This module contains unit tests for the LangChain integration with JuliaOS.
"""

import unittest
import asyncio
from unittest.mock import MagicMock, patch

from juliaos.bridge import JuliaBridge
from juliaos.agents import Agent, AgentType
from juliaos.langchain import (
    JuliaOSAgentAdapter,
    JuliaOSTradingAgentAdapter,
    JuliaOSPortfolioAgentAdapter,
    JuliaOSMarketMakingAgentAdapter,
    JuliaOSLiquidityAgentAdapter,
    JuliaOSYieldFarmingAgentAdapter,
    JuliaOSCrossChainAgentAdapter,
    JuliaOSBaseTool,
    SwarmOptimizationTool,
    CrossChainBridgeTool,
    DEXTradingTool,
    YieldFarmingTool,
    NFTTool,
    DAOTool,
    SocialMediaTool,
    JuliaOSMemory,
    JuliaOSConversationBufferMemory,
    JuliaOSChain,
    SwarmOptimizationChain,
    JuliaOSRetriever,
    serialize_langchain_object,
    deserialize_langchain_object
)


class TestLangChainIntegration(unittest.TestCase):
    """
    Test cases for the LangChain integration with JuliaOS.
    """

    def setUp(self):
        """
        Set up the test environment.
        """
        # Create a mock JuliaBridge
        self.bridge = MagicMock(spec=JuliaBridge)

        # Set up the bridge.execute method to return a mock response
        async def mock_execute(command, args):
            if command == "Agents.createAgent":
                return {
                    "success": True,
                    "agent": {
                        "id": "test-agent-id",
                        "name": "Test Agent",
                        "type": "TRADING",
                        "status": "CREATED",
                        "config": {}
                    }
                }
            elif command == "Agents.getAgent":
                return {
                    "id": "test-agent-id",
                    "name": "Test Agent",
                    "type": "TRADING",
                    "status": "CREATED",
                    "config": {}
                }
            elif command == "Storage.get":
                return {
                    "data": {
                        "messages": [
                            {"type": "human", "content": "Hello"},
                            {"type": "ai", "content": "Hi there!"}
                        ]
                    }
                }
            elif command == "Storage.search_documents":
                return {
                    "documents": [
                        {"content": "Test document", "metadata": {"source": "test"}}
                    ]
                }
            elif command == "Blockchain.query":
                return {
                    "balance": "100.0",
                    "token": "ETH"
                }
            return {}

        self.bridge.execute = mock_execute

        # Create a mock Agent
        self.agent = MagicMock(spec=Agent)
        self.agent.bridge = self.bridge
        self.agent.id = "test-agent-id"
        self.agent.name = "Test Agent"
        self.agent.type = "TRADING"
        self.agent.status = "CREATED"
        self.agent.agent_type = AgentType.TRADING

    def test_agent_adapter_initialization(self):
        """
        Test that the agent adapter can be initialized.
        """
        adapter = JuliaOSAgentAdapter(self.agent)
        self.assertEqual(adapter.agent, self.agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_trading_agent_adapter_initialization(self):
        """
        Test that the trading agent adapter can be initialized.
        """
        adapter = JuliaOSTradingAgentAdapter(self.agent)
        self.assertEqual(adapter.agent, self.agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_portfolio_agent_adapter_initialization(self):
        """
        Test that the portfolio agent adapter can be initialized.
        """
        # Create a mock portfolio agent
        portfolio_agent = MagicMock(spec=Agent)
        portfolio_agent.bridge = self.bridge
        portfolio_agent.agent_type = AgentType.PORTFOLIO

        adapter = JuliaOSPortfolioAgentAdapter(portfolio_agent)
        self.assertEqual(adapter.agent, portfolio_agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_market_making_agent_adapter_initialization(self):
        """
        Test that the market making agent adapter can be initialized.
        """
        # Create a mock market making agent
        market_making_agent = MagicMock(spec=Agent)
        market_making_agent.bridge = self.bridge
        market_making_agent.agent_type = AgentType.MARKET_MAKING

        adapter = JuliaOSMarketMakingAgentAdapter(market_making_agent)
        self.assertEqual(adapter.agent, market_making_agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_liquidity_agent_adapter_initialization(self):
        """
        Test that the liquidity agent adapter can be initialized.
        """
        # Create a mock liquidity agent
        liquidity_agent = MagicMock(spec=Agent)
        liquidity_agent.bridge = self.bridge
        liquidity_agent.agent_type = AgentType.LIQUIDITY

        adapter = JuliaOSLiquidityAgentAdapter(liquidity_agent)
        self.assertEqual(adapter.agent, liquidity_agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_yield_farming_agent_adapter_initialization(self):
        """
        Test that the yield farming agent adapter can be initialized.
        """
        # Create a mock yield farming agent
        yield_farming_agent = MagicMock(spec=Agent)
        yield_farming_agent.bridge = self.bridge
        yield_farming_agent.agent_type = AgentType.YIELD_FARMING

        adapter = JuliaOSYieldFarmingAgentAdapter(yield_farming_agent)
        self.assertEqual(adapter.agent, yield_farming_agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_cross_chain_agent_adapter_initialization(self):
        """
        Test that the cross-chain agent adapter can be initialized.
        """
        # Create a mock cross-chain agent
        cross_chain_agent = MagicMock(spec=Agent)
        cross_chain_agent.bridge = self.bridge
        cross_chain_agent.agent_type = AgentType.CROSS_CHAIN

        adapter = JuliaOSCrossChainAgentAdapter(cross_chain_agent)
        self.assertEqual(adapter.agent, cross_chain_agent)
        self.assertEqual(adapter.bridge, self.bridge)

    def test_base_tool_initialization(self):
        """
        Test that the base tool can be initialized.
        """
        tool = JuliaOSBaseTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)

    def test_swarm_optimization_tool_initialization(self):
        """
        Test that the swarm optimization tool can be initialized.
        """
        tool = SwarmOptimizationTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "swarm_optimization")

    def test_cross_chain_bridge_tool_initialization(self):
        """
        Test that the cross-chain bridge tool can be initialized.
        """
        tool = CrossChainBridgeTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "cross_chain_bridge")

    def test_dex_trading_tool_initialization(self):
        """
        Test that the DEX trading tool can be initialized.
        """
        tool = DEXTradingTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "dex_trading")

    def test_yield_farming_tool_initialization(self):
        """
        Test that the yield farming tool can be initialized.
        """
        tool = YieldFarmingTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "yield_farming")

    def test_nft_tool_initialization(self):
        """
        Test that the NFT tool can be initialized.
        """
        tool = NFTTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "nft")

    def test_dao_tool_initialization(self):
        """
        Test that the DAO tool can be initialized.
        """
        tool = DAOTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "dao")

    def test_social_media_tool_initialization(self):
        """
        Test that the social media tool can be initialized.
        """
        tool = SocialMediaTool(self.bridge)
        self.assertEqual(tool.bridge, self.bridge)
        self.assertEqual(tool.name, "social_media")

    def test_memory_initialization(self):
        """
        Test that the memory can be initialized.
        """
        memory = JuliaOSMemory(self.bridge)
        self.assertEqual(memory.bridge, self.bridge)
        self.assertEqual(memory.memory_key, "memory")
        self.assertEqual(memory.storage_type, "local")
        self.assertEqual(memory.storage_key, "langchain_memory")

    def test_conversation_buffer_memory_initialization(self):
        """
        Test that the conversation buffer memory can be initialized.
        """
        memory = JuliaOSConversationBufferMemory(self.bridge)
        self.assertEqual(memory.bridge, self.bridge)
        self.assertEqual(memory.storage_type, "local")
        self.assertEqual(memory.storage_key, "langchain_conversation_memory")

    def test_chain_initialization(self):
        """
        Test that the chain can be initialized.
        """
        chain = JuliaOSChain(self.bridge)
        self.assertEqual(chain.bridge, self.bridge)
        self.assertEqual(chain.input_keys, ["input"])
        self.assertEqual(chain.output_keys, ["output"])

    @patch("juliaos.langchain.chains.BaseLanguageModel")
    def test_swarm_optimization_chain_initialization(self, mock_llm):
        """
        Test that the swarm optimization chain can be initialized.
        """
        chain = SwarmOptimizationChain(self.bridge, mock_llm)
        self.assertEqual(chain.bridge, self.bridge)
        self.assertEqual(chain.llm, mock_llm)
        self.assertEqual(chain.algorithm, "DE")
        self.assertEqual(chain.input_keys, ["problem_description", "bounds", "config"])
        self.assertEqual(chain.output_keys, ["best_position", "best_fitness", "iterations"])

    def test_retriever_initialization(self):
        """
        Test that the retriever can be initialized.
        """
        retriever = JuliaOSRetriever(self.bridge)
        self.assertEqual(retriever.bridge, self.bridge)
        self.assertEqual(retriever.storage_type, "local")
        self.assertEqual(retriever.collection_name, "langchain_documents")

    def test_serialization_deserialization(self):
        """
        Test that objects can be serialized and deserialized.
        """
        obj = {"test": "value"}
        serialized = serialize_langchain_object(obj)
        deserialized = deserialize_langchain_object(serialized)
        self.assertEqual(obj, deserialized)


if __name__ == "__main__":
    unittest.main()
