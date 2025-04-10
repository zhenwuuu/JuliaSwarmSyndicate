"""
Storage types for the JuliaOS Python wrapper.
"""

from enum import Enum, auto


class StorageType(str, Enum):
    """
    Enum for storage types.
    """
    LOCAL = "local"
    ARWEAVE = "arweave"


class StorageEvent(str, Enum):
    """
    Enum for storage events.
    """
    DATA_SAVED = "storage:data:saved"
    DATA_LOADED = "storage:data:loaded"
    DATA_DELETED = "storage:data:deleted"
    ERROR = "storage:error"
