# JuliaOS Python Wrapper API Reference

This document provides a comprehensive reference for the JuliaOS Python wrapper API.

## Core Classes

### JuliaOS

The main client class for interacting with the JuliaOS Framework.

```python
class JuliaOS:
    def __init__(
        self,
        host: str = "localhost",
        port: int = 8080,
        api_key: Optional[str] = None,
        auto_connect: bool = False
    ):
        """
        Initialize the JuliaOS client.

        Args:
            host: Host address of the JuliaOS server
            port: Port number of the JuliaOS server
            api_key: API key for authentication (optional)
            auto_connect: Whether to automatically connect to the server
        """
        
    async def connect(self) -> bool:
        """
        Connect to the JuliaOS server.

        Returns:
            bool: True if connection was successful

        Raises:
            ConnectionError: If connection fails
        """
        
    async def disconnect(self) -> bool:
        """
        Disconnect from the JuliaOS server.

        Returns:
            bool: True if disconnection was successful
        """
        
    async def ping(self) -> Dict[str, Any]:
        """
        Ping the JuliaOS server to check connectivity.

        Returns:
            Dict[str, Any]: Server response

        Raises:
            ConnectionError: If ping fails
        """
        
    async def get_version(self) -> str:
        """
        Get the version of the JuliaOS server.

        Returns:
            str: Server version

        Raises:
            JuliaOSError: If version retrieval fails
        """
        
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the JuliaOS server.

        Returns:
            Dict[str, Any]: Server status

        Raises:
            JuliaOSError: If status retrieval fails
        """
        
    async def execute_command(self, command: str, args: list = None) -> Dict[str, Any]:
        """
        Execute a raw command on the JuliaOS server.

        Args:
            command: Command to execute
            args: Command arguments

        Returns:
            Dict[str, Any]: Command result

        Raises:
            JuliaOSError: If command execution fails
        """
        
    async def __aenter__(self):
        """
        Async context manager entry point.
        
        Connects to the JuliaOS server when entering the context.
        
        Returns:
            JuliaOS: The JuliaOS instance
        """
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """
        Async context manager exit point.
        
        Disconnects from the JuliaOS server when exiting the context.
        """
```

### JuliaBridge

Low-level bridge for communicating with the JuliaOS server.

```python
class JuliaBridge:
    def __init__(
        self,
        host: str = "localhost",
        port: int = 8080,
        api_key: Optional[str] = None
    ):
        """
        Initialize the JuliaBridge.

        Args:
            host: Host address of the JuliaOS server
            port: Port number of the JuliaOS server
            api_key: API key for authentication (optional)
        """
        
    async def connect(self) -> bool:
        """
        Connect to the JuliaOS server.

        Returns:
            bool: True if connection was successful

        Raises:
            ConnectionError: If connection fails
        """
        
    async def disconnect(self) -> bool:
        """
        Disconnect from the JuliaOS server.

        Returns:
            bool: True if disconnection was successful
        """
        
    async def execute(self, command: str, args: list) -> Dict[str, Any]:
        """
        Execute a command on the JuliaOS server.

        Args:
            command: Command to execute
            args: Command arguments

        Returns:
            Dict[str, Any]: Command result

        Raises:
            JuliaOSError: If command execution fails
        """
```

## Swarm Module

### SwarmManager

Manager for swarm operations.

```python
class SwarmManager:
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the SwarmManager.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def create_swarm(
        self,
        name: str,
        swarm_type: Union[SwarmType, str],
        algorithm: str,
        dimensions: int,
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None,
        swarm_id: Optional[str] = None
    ) -> Swarm:
        """
        Create a new swarm.

        Args:
            name: Name of the swarm
            swarm_type: Type of the swarm
            algorithm: Algorithm to use (e.g., "DE", "PSO")
            dimensions: Number of dimensions for the optimization problem
            bounds: List of (min, max) tuples for each dimension
            config: Swarm configuration
            swarm_id: Optional swarm ID (if not provided, a UUID will be generated)

        Returns:
            Swarm: The created swarm

        Raises:
            SwarmError: If swarm creation fails
        """
        
    async def get_swarm(self, swarm_id: str) -> Swarm:
        """
        Get a swarm by ID.

        Args:
            swarm_id: ID of the swarm to retrieve

        Returns:
            Swarm: The retrieved swarm

        Raises:
            ResourceNotFoundError: If swarm is not found
            SwarmError: If swarm retrieval fails
        """
        
    async def list_swarms(self) -> List[Swarm]:
        """
        List all swarms.

        Returns:
            List[Swarm]: List of swarms

        Raises:
            SwarmError: If swarm listing fails
        """
        
    async def delete_swarm(self, swarm_id: str) -> bool:
        """
        Delete a swarm.

        Args:
            swarm_id: ID of the swarm to delete

        Returns:
            bool: True if deletion was successful

        Raises:
            ResourceNotFoundError: If swarm is not found
            SwarmError: If swarm deletion fails
        """
        
    async def get_available_algorithms(self) -> List[str]:
        """
        Get available swarm algorithms.

        Returns:
            List[str]: List of available algorithms

        Raises:
            SwarmError: If algorithm retrieval fails
        """
        
    async def set_objective_function(
        self,
        function_id: str,
        function_code: str,
        function_type: str = "julia"
    ) -> Dict[str, Any]:
        """
        Set an objective function for optimization.

        Args:
            function_id: ID for the function
            function_code: Code for the function
            function_type: Type of the function code (julia, python, etc.)

        Returns:
            Dict[str, Any]: Result of setting the function

        Raises:
            SwarmError: If function setting fails
        """
```

### Swarm

Represents a swarm in the JuliaOS system.

```python
class Swarm:
    def __init__(self, bridge: JuliaBridge, data: Dict[str, Any]):
        """
        Initialize a Swarm.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            data: Swarm data
        """
        
    async def start(self) -> bool:
        """
        Start the swarm.

        Returns:
            bool: True if start was successful

        Raises:
            SwarmError: If swarm start fails
        """
        
    async def stop(self) -> bool:
        """
        Stop the swarm.

        Returns:
            bool: True if stop was successful

        Raises:
            SwarmError: If swarm stop fails
        """
        
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the swarm.

        Returns:
            Dict[str, Any]: Swarm status

        Raises:
            SwarmError: If status retrieval fails
        """
        
    async def delete(self) -> bool:
        """
        Delete the swarm.

        Returns:
            bool: True if deletion was successful

        Raises:
            SwarmError: If swarm deletion fails
        """
        
    async def run_optimization(
        self,
        objective_function: Union[str, Callable],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run an optimization with the swarm.

        Args:
            objective_function: Objective function ID or callable
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
        
    async def get_optimization_result(self, optimization_id: str) -> Dict[str, Any]:
        """
        Get the result of an optimization.

        Args:
            optimization_id: ID of the optimization

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            ResourceNotFoundError: If optimization is not found
            SwarmError: If result retrieval fails
        """
```

### SwarmType

Enum for swarm types.

```python
class SwarmType(Enum):
    OPTIMIZATION = "OPTIMIZATION"
    CONSENSUS = "CONSENSUS"
    COORDINATION = "COORDINATION"
    EXPLORATION = "EXPLORATION"
    CUSTOM = "CUSTOM"
```

### SwarmStatus

Enum for swarm status.

```python
class SwarmStatus(Enum):
    CREATED = "CREATED"
    RUNNING = "RUNNING"
    PAUSED = "PAUSED"
    STOPPED = "STOPPED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
```

### SwarmAlgorithm

Enum for swarm algorithms.

```python
class SwarmAlgorithm(Enum):
    DE = "DE"  # Differential Evolution
    PSO = "PSO"  # Particle Swarm Optimization
    GWO = "GWO"  # Grey Wolf Optimizer
    ACO = "ACO"  # Ant Colony Optimization
    GA = "GA"  # Genetic Algorithm
    WOA = "WOA"  # Whale Optimization Algorithm
    HYBRID_DEPSO = "HYBRID_DEPSO"  # Hybrid DE-PSO Algorithm
```

## Swarm Algorithms

### DifferentialEvolution

Differential Evolution optimization algorithm.

```python
class DifferentialEvolution(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a DifferentialEvolution.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Differential Evolution optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### ParticleSwarmOptimization

Particle Swarm Optimization algorithm.

```python
class ParticleSwarmOptimization(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a ParticleSwarmOptimization.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Particle Swarm Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### GreyWolfOptimizer

Grey Wolf Optimizer (GWO) algorithm.

```python
class GreyWolfOptimizer(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a GreyWolfOptimizer.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Grey Wolf Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### AntColonyOptimization

Ant Colony Optimization (ACO) algorithm for continuous domains.

```python
class AntColonyOptimization(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize an AntColonyOptimization.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run an Ant Colony Optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### GeneticAlgorithm

Genetic Algorithm (GA) optimization.

```python
class GeneticAlgorithm(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a GeneticAlgorithm.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Genetic Algorithm optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### WhaleOptimizationAlgorithm

Whale Optimization Algorithm (WOA).

```python
class WhaleOptimizationAlgorithm(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a WhaleOptimizationAlgorithm.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Whale Optimization Algorithm optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

### HybridDEPSO

Hybrid Differential Evolution and Particle Swarm Optimization algorithm.

```python
class HybridDEPSO(OptimizationAlgorithm):
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a HybridDEPSO.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        
    async def optimize(
        self,
        objective_function: Union[str, Callable],
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run a Hybrid DE-PSO optimization.

        Args:
            objective_function: Objective function ID or callable
            bounds: List of (min, max) tuples for each dimension
            config: Optimization configuration

        Returns:
            Dict[str, Any]: Optimization result

        Raises:
            SwarmError: If optimization fails
        """
```

## NumPy Utilities

### numpy_objective_wrapper

Wrap a NumPy-based objective function to make it compatible with JuliaOS swarm algorithms.

```python
def numpy_objective_wrapper(func: Callable) -> Callable:
    """
    Wrap a NumPy-based objective function to make it compatible with JuliaOS swarm algorithms.
    
    Args:
        func: NumPy-based objective function that takes a numpy array and returns a scalar
        
    Returns:
        Callable: Wrapped function that takes a list and returns a scalar
    """
```

### numpy_bounds_converter

Convert NumPy-style bounds to JuliaOS-compatible bounds.

```python
def numpy_bounds_converter(bounds: Union[List[Tuple[float, float]], np.ndarray]) -> List[Tuple[float, float]]:
    """
    Convert NumPy-style bounds to JuliaOS-compatible bounds.
    
    Args:
        bounds: NumPy-style bounds (n x 2 array) or list of tuples
        
    Returns:
        List[Tuple[float, float]]: JuliaOS-compatible bounds
    """
```

### numpy_result_converter

Convert JuliaOS optimization result to include NumPy arrays.

```python
def numpy_result_converter(result: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert JuliaOS optimization result to include NumPy arrays.
    
    Args:
        result: JuliaOS optimization result
        
    Returns:
        Dict[str, Any]: Result with NumPy arrays
    """
```

## Exceptions

### JuliaOSError

Base exception for JuliaOS errors.

```python
class JuliaOSError(Exception):
    """
    Base exception for JuliaOS errors.
    """
    
    def __init__(self, message: str, code: Optional[str] = None):
        """
        Initialize a JuliaOSError.

        Args:
            message: Error message
            code: Error code (optional)
        """
        self.message = message
        self.code = code
        super().__init__(message)
```

### ConnectionError

Exception for connection errors.

```python
class ConnectionError(JuliaOSError):
    """
    Exception for connection errors.
    """
    
    def __init__(self, message: str):
        """
        Initialize a ConnectionError.

        Args:
            message: Error message
        """
        super().__init__(message, "CONNECTION_ERROR")
```

### TimeoutError

Exception for timeout errors.

```python
class TimeoutError(JuliaOSError):
    """
    Exception for timeout errors.
    """
    
    def __init__(self, message: str):
        """
        Initialize a TimeoutError.

        Args:
            message: Error message
        """
        super().__init__(message, "TIMEOUT_ERROR")
```

### SwarmError

Exception for swarm errors.

```python
class SwarmError(JuliaOSError):
    """
    Exception for swarm errors.
    """
    
    def __init__(self, message: str):
        """
        Initialize a SwarmError.

        Args:
            message: Error message
        """
        super().__init__(message, "SWARM_ERROR")
```

### ResourceNotFoundError

Exception for resource not found errors.

```python
class ResourceNotFoundError(JuliaOSError):
    """
    Exception for resource not found errors.
    """
    
    def __init__(self, message: str):
        """
        Initialize a ResourceNotFoundError.

        Args:
            message: Error message
        """
        super().__init__(message, "RESOURCE_NOT_FOUND")
```
