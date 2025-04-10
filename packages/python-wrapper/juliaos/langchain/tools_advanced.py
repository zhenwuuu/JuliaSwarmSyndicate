"""
Advanced LangChain tools for JuliaOS.

This module provides advanced LangChain tools that wrap JuliaOS functionality.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
import json
from pydantic import BaseModel, Field

from langchain.tools import BaseTool
from langchain.callbacks.manager import AsyncCallbackManagerForToolRun, CallbackManagerForToolRun

from ..agents import Agent, AgentType
from ..bridge import JuliaBridge
from .tools import JuliaOSBaseTool


class CrossChainBridgeTool(JuliaOSBaseTool):
    """
    Tool for cross-chain bridge operations.
    
    This tool allows LangChain agents to perform cross-chain bridge operations using JuliaOS.
    """
    
    name = "cross_chain_bridge"
    description = """
    Perform cross-chain bridge operations to transfer assets between different blockchains.
    
    Input should be a JSON object with the following fields:
    - source_chain: The source blockchain (ethereum, solana, etc.)
    - target_chain: The target blockchain (ethereum, solana, etc.)
    - token: The token to transfer
    - amount: The amount to transfer
    - bridge_type: The bridge to use (wormhole, stargate, etc.)
    - parameters: Additional parameters for the bridge operation
    
    Example:
    {
        "source_chain": "ethereum",
        "target_chain": "solana",
        "token": "USDC",
        "amount": "100",
        "bridge_type": "wormhole",
        "parameters": {
            "slippage": 0.5
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a cross-chain bridge operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            source_chain = input_data.get("source_chain", "")
            target_chain = input_data.get("target_chain", "")
            token = input_data.get("token", "")
            amount = input_data.get("amount", "")
            bridge_type = input_data.get("bridge_type", "wormhole")
            parameters = input_data.get("parameters", {})
            
            # Execute the bridge operation
            result = await self.bridge.execute("Bridge.execute_bridge", [
                source_chain,
                target_chain,
                token,
                amount,
                bridge_type,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing cross-chain bridge operation: {str(e)}"


class DEXTradingTool(JuliaOSBaseTool):
    """
    Tool for DEX trading operations.
    
    This tool allows LangChain agents to perform DEX trading operations using JuliaOS.
    """
    
    name = "dex_trading"
    description = """
    Perform DEX trading operations such as swapping tokens, adding liquidity, and removing liquidity.
    
    Input should be a JSON object with the following fields:
    - chain: The blockchain to use (ethereum, solana, etc.)
    - dex: The DEX to use (uniswap, sushiswap, etc.)
    - operation: The operation to perform (swap, add_liquidity, remove_liquidity)
    - parameters: Parameters for the operation
    
    Example:
    {
        "chain": "ethereum",
        "dex": "uniswap",
        "operation": "swap",
        "parameters": {
            "token_in": "ETH",
            "token_out": "USDC",
            "amount_in": "1.0",
            "slippage": 0.5
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a DEX trading operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            chain = input_data.get("chain", "ethereum")
            dex = input_data.get("dex", "uniswap")
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the DEX operation
            result = await self.bridge.execute("DEX.execute_operation", [
                chain,
                dex,
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing DEX trading operation: {str(e)}"


class YieldFarmingTool(JuliaOSBaseTool):
    """
    Tool for yield farming operations.
    
    This tool allows LangChain agents to perform yield farming operations using JuliaOS.
    """
    
    name = "yield_farming"
    description = """
    Perform yield farming operations such as staking, unstaking, and claiming rewards.
    
    Input should be a JSON object with the following fields:
    - chain: The blockchain to use (ethereum, solana, etc.)
    - protocol: The yield farming protocol to use (aave, compound, etc.)
    - operation: The operation to perform (stake, unstake, claim)
    - parameters: Parameters for the operation
    
    Example:
    {
        "chain": "ethereum",
        "protocol": "aave",
        "operation": "stake",
        "parameters": {
            "token": "USDC",
            "amount": "1000.0"
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a yield farming operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            chain = input_data.get("chain", "ethereum")
            protocol = input_data.get("protocol", "aave")
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the yield farming operation
            result = await self.bridge.execute("YieldFarming.execute_operation", [
                chain,
                protocol,
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing yield farming operation: {str(e)}"


class NFTTool(JuliaOSBaseTool):
    """
    Tool for NFT operations.
    
    This tool allows LangChain agents to perform NFT operations using JuliaOS.
    """
    
    name = "nft"
    description = """
    Perform NFT operations such as minting, transferring, and querying NFTs.
    
    Input should be a JSON object with the following fields:
    - chain: The blockchain to use (ethereum, solana, etc.)
    - operation: The operation to perform (mint, transfer, query)
    - parameters: Parameters for the operation
    
    Example:
    {
        "chain": "ethereum",
        "operation": "query",
        "parameters": {
            "address": "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
            "collection": "cryptopunks"
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform an NFT operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            chain = input_data.get("chain", "ethereum")
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the NFT operation
            result = await self.bridge.execute("NFT.execute_operation", [
                chain,
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing NFT operation: {str(e)}"


class DAOTool(JuliaOSBaseTool):
    """
    Tool for DAO operations.
    
    This tool allows LangChain agents to perform DAO operations using JuliaOS.
    """
    
    name = "dao"
    description = """
    Perform DAO operations such as voting, proposing, and querying DAO information.
    
    Input should be a JSON object with the following fields:
    - chain: The blockchain to use (ethereum, solana, etc.)
    - dao: The DAO to interact with
    - operation: The operation to perform (vote, propose, query)
    - parameters: Parameters for the operation
    
    Example:
    {
        "chain": "ethereum",
        "dao": "uniswap",
        "operation": "query",
        "parameters": {
            "proposal_id": "123"
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a DAO operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            chain = input_data.get("chain", "ethereum")
            dao = input_data.get("dao", "")
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the DAO operation
            result = await self.bridge.execute("DAO.execute_operation", [
                chain,
                dao,
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing DAO operation: {str(e)}"


class SocialMediaTool(JuliaOSBaseTool):
    """
    Tool for social media operations.
    
    This tool allows LangChain agents to perform social media operations using JuliaOS.
    """
    
    name = "social_media"
    description = """
    Perform social media operations such as posting, querying, and analyzing social media data.
    
    Input should be a JSON object with the following fields:
    - platform: The social media platform (twitter, discord, telegram, lens, farcaster)
    - operation: The operation to perform (post, query, analyze)
    - parameters: Parameters for the operation
    
    Example:
    {
        "platform": "twitter",
        "operation": "query",
        "parameters": {
            "query": "bitcoin",
            "limit": 10
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a social media operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            platform = input_data.get("platform", "twitter")
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the social media operation
            result = await self.bridge.execute("SocialMedia.execute_operation", [
                platform,
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing social media operation: {str(e)}"
