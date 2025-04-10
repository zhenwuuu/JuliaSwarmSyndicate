"""
Wallet types for the JuliaOS Python wrapper.
"""

from enum import Enum, auto


class WalletType(str, Enum):
    """
    Enum for wallet types.
    """
    HD = "HD"
    KEYSTORE = "KEYSTORE"
    MNEMONIC = "MNEMONIC"
    PRIVATE_KEY = "PRIVATE_KEY"
    HARDWARE = "HARDWARE"
    EXTERNAL = "EXTERNAL"


class WalletStatus(str, Enum):
    """
    Enum for wallet status.
    """
    ACTIVE = "ACTIVE"
    LOCKED = "LOCKED"
    INACTIVE = "INACTIVE"
    ERROR = "ERROR"
