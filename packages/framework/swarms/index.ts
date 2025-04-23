/**
 * JuliaOS Framework - Swarms Module
 * 
 * This module provides interfaces for swarm intelligence algorithms in the JuliaOS framework.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

/**
 * Swarm algorithm types
 */
export enum SwarmAlgorithm {
  DIFFERENTIAL_EVOLUTION = 'DE',
  PARTICLE_SWARM_OPTIMIZATION = 'PSO'
}

/**
 * Swarm status
 */
export enum SwarmStatus {
  CREATED = 'created',
  OPTIMIZING = 'optimizing',
  OPTIMIZED = 'optimized',
  ERROR = 'error'
}

/**
 * Optimization status
 */
export enum OptimizationStatus {
  RUNNING = 'running',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

/**
 * Swarm events
 */
export enum SwarmEvent {
  CREATED = 'swarm:created',
  OPTIMIZING = 'swarm:optimizing',
  OPTIMIZED = 'swarm:optimized',
  ERROR = 'swarm:error'
}

/**
 * Bounds for optimization
 */
export type Bounds = [number, number][];

/**
 * Differential Evolution parameters
 */
export interface DEParameters {
  population_size?: number;
  max_generations?: number;
  crossover_probability?: number;
  differential_weight?: number;
  strategy?: string;
  tolerance?: number;
  max_time_seconds?: number;
  seed?: number;
}

/**
 * Particle Swarm Optimization parameters
 */
export interface PSOParameters {
  swarm_size?: number;
  max_iterations?: number;
  cognitive_coefficient?: number;
  social_coefficient?: number;
  inertia_weight?: number;
  inertia_damping?: number;
  min_inertia?: number;
  velocity_limit_factor?: number;
  tolerance?: number;
  max_time_seconds?: number;
  seed?: number;
}

/**
 * Swarm parameters (union of all algorithm parameters)
 */
export type SwarmParameters = DEParameters | PSOParameters;

/**
 * Optimization result
 */
export interface OptimizationResult {
  best_individual?: number[];
  best_position?: number[];
  best_fitness: number;
  generations?: number;
  iterations?: number;
  converged: boolean;
  elapsed_time: number;
  history: {
    best_fitness: number[];
    mean_fitness: number[];
    std_fitness: number[];
    generation?: number[];
    iteration?: number[];
  };
}

/**
 * Objective function type
 */
export type ObjectiveFunction = (x: number[]) => number;

/**
 * SwarmManager class for managing swarm intelligence algorithms
 */
export class SwarmManager extends EventEmitter {
  private bridge: JuliaBridge;

  /**
   * Create a new SwarmManager
   * 
   * @param bridge - JuliaBridge instance for communicating with the Julia backend
   */
  constructor(bridge: JuliaBridge) {
    super();
    this.bridge = bridge;
  }

  /**
   * Create a swarm for optimization
   * 
   * @param algorithm - The algorithm to use
   * @param dimensions - Number of dimensions
   * @param bounds - Bounds for each dimension
   * @param parameters - Algorithm parameters
   * @returns Promise with swarm creation result
   */
  async createSwarm(
    algorithm: SwarmAlgorithm,
    dimensions: number,
    bounds: Bounds,
    parameters: SwarmParameters = {}
  ): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('Swarms.create_swarm', [
        algorithm,
        dimensions,
        bounds,
        parameters
      ]);

      if (result.success) {
        this.emit(SwarmEvent.CREATED, {
          swarmId: result.swarm_id,
          algorithm,
          dimensions,
          swarmSize: result.swarm_size
        });
      }

      return result;
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Set an objective function for optimization
   * 
   * @param functionId - ID for the objective function
   * @param objectiveFunction - The function to minimize
   * @returns Promise with result of setting the objective function
   */
  async setObjectiveFunction(
    functionId: string,
    objectiveFunction: ObjectiveFunction
  ): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('Swarms.set_objective_function', [
        functionId,
        objectiveFunction
      ]);
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Run an optimization using a swarm
   * 
   * @param swarmId - ID of the swarm to use
   * @param functionId - ID of the objective function
   * @param parameters - Additional optimization parameters
   * @returns Promise with optimization initialization result
   */
  async runOptimization(
    swarmId: string,
    functionId: string,
    parameters: SwarmParameters = {}
  ): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('Swarms.run_optimization', [
        swarmId,
        functionId,
        parameters
      ]);

      if (result.success) {
        this.emit(SwarmEvent.OPTIMIZING, {
          swarmId,
          optimizationId: result.optimization_id,
          functionId
        });
      }

      return result;
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the status of a swarm
   * 
   * @param swarmId - ID of the swarm
   * @returns Promise with swarm status
   */
  async getSwarmStatus(swarmId: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('Swarms.get_swarm_status', [swarmId]);
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the result of an optimization
   * 
   * @param optimizationId - ID of the optimization
   * @returns Promise with optimization result
   */
  async getOptimizationResult(optimizationId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('Swarms.get_optimization_result', [optimizationId]);

      if (result.success && result.status === OptimizationStatus.COMPLETED) {
        this.emit(SwarmEvent.OPTIMIZED, {
          optimizationId,
          swarmId: result.swarm_id,
          result: result.result
        });
      } else if (result.success && result.status === OptimizationStatus.FAILED) {
        this.emit(SwarmEvent.ERROR, {
          optimizationId,
          swarmId: result.swarm_id,
          error: result.error
        });
      }

      return result;
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the list of available swarm algorithms
   * 
   * @returns Promise with list of available algorithms
   */
  async getAvailableAlgorithms(): Promise<string[]> {
    try {
      return await this.bridge.execute('Swarms.get_available_algorithms', []);
    } catch (error) {
      this.emit(SwarmEvent.ERROR, error);
      throw error;
    }
  }
}
