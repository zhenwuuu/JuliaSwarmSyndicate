/**
 * Swarm Module
 * 
 * This module provides classes and interfaces for managing swarms of agents.
 * A swarm is a collection of agents that work together to achieve a common goal.
 * 
 * Key Features:
 * - Task distribution among agents
 * - Multiple coordination strategies
 * - Metrics tracking and analysis
 * - Resource management and scaling
 * - LLM-powered consensus decision making
 */

// Export base interfaces and classes
export { 
  SwarmConfig, 
  SwarmMetrics, 
  Task, 
  SwarmResult,
  Swarm 
} from './Swarm';

// Export router functionality
export {
  RouterConfig,
  RouterMetrics,
  SwarmRouter
} from './SwarmRouter';

// Export concrete implementations
export {
  StandardSwarmConfig,
  StandardSwarm
} from './StandardSwarm';

// Export default instance for easy access
import { StandardSwarm } from './StandardSwarm';
export default StandardSwarm; 