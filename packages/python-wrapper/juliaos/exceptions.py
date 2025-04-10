"""
Exceptions for the JuliaOS Python wrapper.
"""


class JuliaOSError(Exception):
    """Base exception for all JuliaOS errors."""
    pass


class ConnectionError(JuliaOSError):
    """Exception raised when there is an error connecting to the JuliaOS server."""
    pass


class TimeoutError(JuliaOSError):
    """Exception raised when a command execution times out."""
    pass


class AuthenticationError(JuliaOSError):
    """Exception raised when authentication fails."""
    pass


class CommandError(JuliaOSError):
    """Exception raised when a command execution fails."""
    pass


class ValidationError(JuliaOSError):
    """Exception raised when input validation fails."""
    pass


class ResourceNotFoundError(JuliaOSError):
    """Exception raised when a requested resource is not found."""
    pass


class ResourceExistsError(JuliaOSError):
    """Exception raised when a resource already exists."""
    pass


class InsufficientFundsError(JuliaOSError):
    """Exception raised when there are insufficient funds for a transaction."""
    pass


class BlockchainError(JuliaOSError):
    """Exception raised when there is an error interacting with a blockchain."""
    pass


class WalletError(JuliaOSError):
    """Exception raised when there is an error with a wallet operation."""
    pass


class StorageError(JuliaOSError):
    """Exception raised when there is an error with a storage operation."""
    pass


class AgentError(JuliaOSError):
    """Exception raised when there is an error with an agent operation."""
    pass


class SwarmError(JuliaOSError):
    """Exception raised when there is an error with a swarm operation."""
    pass
