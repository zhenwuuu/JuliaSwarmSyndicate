"""
Blockchain chain types for the JuliaOS Python wrapper.
"""

from enum import Enum, auto


class Chain(str, Enum):
    """
    Enum for blockchain chains.
    """
    ETHEREUM = "ethereum"
    SOLANA = "solana"
    BSC = "bsc"
    ARBITRUM = "arbitrum"
    AVALANCHE = "avalanche"
    POLYGON = "polygon"
    OPTIMISM = "optimism"
    BASE = "base"
    FANTOM = "fantom"


class Network(str, Enum):
    """
    Enum for blockchain networks.
    """
    MAINNET = "mainnet"
    TESTNET = "testnet"
    DEVNET = "devnet"
    LOCALNET = "localnet"


class TokenType(str, Enum):
    """
    Enum for token types.
    """
    NATIVE = "native"
    ERC20 = "erc20"
    ERC721 = "erc721"
    ERC1155 = "erc1155"
    SPL = "spl"
