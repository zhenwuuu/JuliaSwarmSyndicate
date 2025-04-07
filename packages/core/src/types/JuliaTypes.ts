/**
 * JuliaTypes.ts
 * 
 * This file contains TypeScript type definitions for Julia structures.
 * It serves as a bridge between TypeScript and Julia, ensuring type safety
 * across the integration.
 */

import { z } from 'zod';

// ===== Primitive Type Mappings =====

/**
 * Mapping of Julia primitive types to TypeScript types
 */
export type JuliaInt = number;
export type JuliaFloat64 = number;
export type JuliaString = string;
export type JuliaBoolean = boolean;
export type JuliaNothing = null;
export type JuliaSymbol = string;
export type JuliaChar = string;

// ===== Complex Julia Types =====

/**
 * Represents a Julia Array type
 */
export type JuliaArray<T> = Array<T>;

/**
 * Represents a Julia Tuple type
 */
export type JuliaTuple<T extends any[]> = T;

/**
 * Represents a Julia Dictionary type
 */
export type JuliaDict<K, V> = Record<string, V>;

/**
 * Represents a Julia Set type
 */
export type JuliaSet<T> = Set<T>;

/**
 * Represents a Julia Range type
 */
export interface JuliaRange {
  start: number;
  stop: number;
  step: number;
}

/**
 * Represents a Julia NamedTuple type
 */
export type JuliaNamedTuple<T extends Record<string, any>> = T;

/**
 * Represents a Julia Complex number
 */
export interface JuliaComplex {
  re: number;
  im: number;
}

// ===== Optimization Types =====

/**
 * Supported optimization algorithms in Julia
 */
export type OptimizationAlgorithm = 'pso' | 'aco' | 'abc' | 'firefly';

/**
 * Parameters for the Particle Swarm Optimization algorithm
 */
export interface PSOParams {
  dimensions: number;
  populationSize: number;
  iterations: number;
  inertiaWeight: number;
  cognitiveWeight: number;
  socialWeight: number;
  bounds: {
    min: number[];
    max: number[];
  };
}

/**
 * Parameters for the Ant Colony Optimization algorithm
 */
export interface ACOParams {
  dimensions: number;
  antCount: number;
  iterations: number;
  evaporationRate: number;
  alpha: number;
  beta: number;
  bounds: {
    min: number[];
    max: number[];
  };
}

/**
 * Parameters for the Artificial Bee Colony algorithm
 */
export interface ABCParams {
  dimensions: number;
  colonySize: number;
  iterations: number;
  limitTrials: number;
  bounds: {
    min: number[];
    max: number[];
  };
}

/**
 * Parameters for the Firefly algorithm
 */
export interface FireflyParams {
  dimensions: number;
  fireflyCount: number;
  iterations: number;
  alpha: number;
  betaMin: number;
  gamma: number;
  bounds: {
    min: number[];
    max: number[];
  };
}

/**
 * Union type for all optimization parameters
 */
export type OptimizationParams = {
  algorithm: OptimizationAlgorithm;
  objectiveFunction: string;
} & (PSOParams | ACOParams | ABCParams | FireflyParams);

// ===== Bridge Communication Types =====

/**
 * Type of message being sent to Julia server
 */
export type MessageType = 
  | 'optimize'
  | 'query'
  | 'heartbeat'
  | 'status'
  | 'cancel'
  | 'execute';

/**
 * Julia execution message
 */
export interface JuliaExecuteMessage {
  type: 'execute';
  code: string;
  timeout?: number;
}

/**
 * Julia optimization message
 */
export interface JuliaOptimizeMessage {
  type: 'optimize';
  params: OptimizationParams;
  timeout?: number;
}

/**
 * Julia query message for retrieving data
 */
export interface JuliaQueryMessage {
  type: 'query';
  query: string;
  params?: any;
}

/**
 * Julia cancellation message
 */
export interface JuliaCancelMessage {
  type: 'cancel';
  taskId: string;
}

/**
 * Julia status check message
 */
export interface JuliaStatusMessage {
  type: 'status';
}

/**
 * Julia heartbeat message
 */
export interface JuliaHeartbeatMessage {
  type: 'heartbeat';
  timestamp: number;
}

/**
 * Union type for all Julia messages
 */
export type JuliaMessage = 
  | JuliaExecuteMessage
  | JuliaOptimizeMessage
  | JuliaQueryMessage
  | JuliaCancelMessage
  | JuliaStatusMessage
  | JuliaHeartbeatMessage;

/**
 * Response from Julia server
 */
export interface JuliaResponse<T = any> {
  id: string;
  type: string;
  data: T;
  error?: string;
  metadata?: {
    executionTime?: number;
    memoryUsage?: number;
    workerId?: number;
  };
}

// ===== Validation Schemas =====

/**
 * Zod validation schema for optimization parameters
 */
export const OptimizationParamsSchema = z.object({
  algorithm: z.enum(['pso', 'aco', 'abc', 'firefly']),
  dimensions: z.number().int().positive(),
  populationSize: z.number().int().positive().optional(),
  antCount: z.number().int().positive().optional(),
  colonySize: z.number().int().positive().optional(),
  fireflyCount: z.number().int().positive().optional(),
  iterations: z.number().int().positive(),
  inertiaWeight: z.number().optional(),
  cognitiveWeight: z.number().optional(),
  socialWeight: z.number().optional(),
  evaporationRate: z.number().optional(),
  alpha: z.number().optional(),
  beta: z.number().optional(),
  betaMin: z.number().optional(),
  gamma: z.number().optional(),
  limitTrials: z.number().int().optional(),
  bounds: z.object({
    min: z.array(z.number()),
    max: z.array(z.number())
  }),
  objectiveFunction: z.string()
});

/**
 * Zod validation schema for Julia response
 */
export const JuliaResponseSchema = z.object({
  id: z.string(),
  type: z.string(),
  data: z.any(),
  error: z.string().optional(),
  metadata: z.object({
    executionTime: z.number().optional(),
    memoryUsage: z.number().optional(),
    workerId: z.number().optional()
  }).optional()
});

/**
 * Zod validation schema for Julia execution message
 */
export const JuliaExecuteMessageSchema = z.object({
  type: z.literal('execute'),
  code: z.string(),
  timeout: z.number().optional()
});

/**
 * Zod validation schema for Julia optimization message
 */
export const JuliaOptimizeMessageSchema = z.object({
  type: z.literal('optimize'),
  params: OptimizationParamsSchema,
  timeout: z.number().optional()
}); 