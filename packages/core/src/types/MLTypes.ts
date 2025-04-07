/**
 * MLTypes.ts
 * 
 * This file contains TypeScript type definitions for Machine Learning operations
 * that integrate with Julia's ML capabilities.
 */

import { z } from 'zod';
import { JuliaResponse } from './JuliaTypes';

// ===== ML Model Types =====

/**
 * Supported ML model types
 */
export type MLModelType = 
  | 'pytorch'
  | 'flux'
  | 'sklearn'
  | 'custom';

/**
 * Model architecture types
 */
export type ModelArchitecture =
  | 'mlp'      // Multi-layer Perceptron
  | 'cnn'      // Convolutional Neural Network
  | 'rnn'      // Recurrent Neural Network
  | 'lstm'     // Long Short-Term Memory
  | 'gru'      // Gated Recurrent Unit
  | 'transformer' 
  | 'ensemble'
  | 'custom';

/**
 * Base model configuration
 */
export interface BaseModelConfig {
  name: string;
  type: MLModelType;
  architecture: ModelArchitecture;
  inputShape: number[];
  outputShape: number[];
  path?: string;
}

/**
 * PyTorch model configuration
 */
export interface PyTorchModelConfig extends BaseModelConfig {
  type: 'pytorch';
  useGPU?: boolean;
  torchScriptPath?: string;
  optimizerConfig?: {
    type: 'adam' | 'sgd' | 'rmsprop';
    learningRate: number;
    weightDecay?: number;
  };
}

/**
 * Flux model configuration
 */
export interface FluxModelConfig extends BaseModelConfig {
  type: 'flux';
  layers?: Array<{
    type: string;
    units?: number;
    activation?: string;
    kernelSize?: number[];
  }>;
}

/**
 * Scikit-learn model configuration
 */
export interface SklearnModelConfig extends BaseModelConfig {
  type: 'sklearn';
  algorithm: 'svm' | 'random_forest' | 'gradient_boosting' | 'linear_regression';
  hyperparameters?: Record<string, any>;
}

/**
 * Custom model configuration
 */
export interface CustomModelConfig extends BaseModelConfig {
  type: 'custom';
  modulePath: string;
  functionName: string;
  params?: Record<string, any>;
}

/**
 * Union type for all model configurations
 */
export type ModelConfig = 
  | PyTorchModelConfig 
  | FluxModelConfig 
  | SklearnModelConfig 
  | CustomModelConfig;

// ===== Training Types =====

/**
 * Data splitting strategy for training
 */
export interface DataSplitConfig {
  trainRatio: number;
  validationRatio: number;
  testRatio: number;
  shuffleSeed?: number;
  stratify?: boolean;
}

/**
 * Cross-validation configuration
 */
export interface CrossValidationConfig {
  folds: number;
  shuffleSeed?: number;
  stratify?: boolean;
}

/**
 * Early stopping configuration
 */
export interface EarlyStoppingConfig {
  monitor: 'val_loss' | 'val_accuracy';
  minDelta: number;
  patience: number;
  mode: 'min' | 'max';
}

/**
 * Training configuration
 */
export interface TrainingConfig {
  batchSize: number;
  epochs: number;
  validationSplit?: DataSplitConfig;
  crossValidation?: CrossValidationConfig;
  optimizer: {
    type: string;
    learningRate: number;
    momentum?: number;
    weightDecay?: number;
  };
  lossFunction: string;
  metrics: string[];
  callbacks?: {
    earlyStoppingConfig?: EarlyStoppingConfig;
    checkpointPath?: string;
    tensorboardLogDir?: string;
  };
}

// ===== Prediction Types =====

/**
 * Prediction request configuration
 */
export interface PredictionConfig {
  modelPath: string;
  modelType: MLModelType;
  batchSize?: number;
  useGPU?: boolean;
  returnProbabilities?: boolean;
  outputTransform?: 'softmax' | 'sigmoid' | 'none';
}

/**
 * Prediction result
 */
export interface PredictionResult<T = any> {
  predictions: T;
  probabilities?: number[][];
  confidenceScores?: number[];
  inferenceTime: number;
  metadata?: {
    modelType: MLModelType;
    modelPath: string;
    inputShape: number[];
    device: string;
  };
}

// ===== Time Series Types =====

/**
 * Time series forecast configuration
 */
export interface TimeSeriesForecastConfig {
  horizon: number;            // Number of future time points to predict
  historyWindow: number;      // Number of past time points to use
  features: string[];         // Features to include in the forecast
  targetVariable: string;     // Target variable to forecast
  frequency?: string;         // Data frequency (e.g., '1d', '1h', '1min')
  includeExogenous?: boolean; // Whether to include exogenous variables
  decompose?: boolean;        // Whether to decompose time series
  scaler?: 'standard' | 'minmax' | 'robust' | 'none';  // Scaling method
}

/**
 * Time series forecast result
 */
export interface TimeSeriesForecastResult {
  forecast: number[];
  upperBound?: number[];
  lowerBound?: number[];
  confidenceIntervals?: {
    level: number;
    upper: number[];
    lower: number[];
  }[];
  metrics?: {
    mse: number;
    mae: number;
    mape?: number;
    r2?: number;
  };
  metadata?: {
    forecastStart: string;
    forecastEnd: string;
    model: string;
  };
}

// ===== Explainability Types =====

/**
 * Feature importance result
 */
export interface FeatureImportanceResult {
  features: string[];
  importance: number[];
  method: 'shap' | 'permutation' | 'gradient' | 'integrated_gradients';
}

/**
 * Model explanation configuration
 */
export interface ExplanationConfig {
  method: 'shap' | 'lime' | 'integrated_gradients' | 'counterfactual';
  numSamples?: number;
  targetClass?: number;
  baseline?: any[];
}

/**
 * Model explanation result
 */
export interface ExplanationResult {
  type: 'feature_importance' | 'attribution_map' | 'counterfactual' | 'partial_dependence';
  data: any;
  metadata: {
    method: string;
    modelType: MLModelType;
    computeTime: number;
  };
}

// ===== Validation Schemas =====

/**
 * Zod validation schema for model configuration
 */
export const ModelConfigSchema = z.object({
  name: z.string(),
  type: z.enum(['pytorch', 'flux', 'sklearn', 'custom']),
  architecture: z.enum(['mlp', 'cnn', 'rnn', 'lstm', 'gru', 'transformer', 'ensemble', 'custom']),
  inputShape: z.array(z.number()),
  outputShape: z.array(z.number()),
  path: z.string().optional(),
  useGPU: z.boolean().optional(),
  torchScriptPath: z.string().optional(),
  layers: z.array(z.object({
    type: z.string(),
    units: z.number().optional(),
    activation: z.string().optional(),
    kernelSize: z.array(z.number()).optional()
  })).optional(),
  algorithm: z.enum(['svm', 'random_forest', 'gradient_boosting', 'linear_regression']).optional(),
  hyperparameters: z.record(z.any()).optional(),
  modulePath: z.string().optional(),
  functionName: z.string().optional(),
  params: z.record(z.any()).optional()
});

/**
 * Zod validation schema for training configuration
 */
export const TrainingConfigSchema = z.object({
  batchSize: z.number().positive(),
  epochs: z.number().positive(),
  validationSplit: z.object({
    trainRatio: z.number().min(0).max(1),
    validationRatio: z.number().min(0).max(1),
    testRatio: z.number().min(0).max(1),
    shuffleSeed: z.number().optional(),
    stratify: z.boolean().optional()
  }).optional(),
  crossValidation: z.object({
    folds: z.number().positive(),
    shuffleSeed: z.number().optional(),
    stratify: z.boolean().optional()
  }).optional(),
  optimizer: z.object({
    type: z.string(),
    learningRate: z.number().positive(),
    momentum: z.number().optional(),
    weightDecay: z.number().optional()
  }),
  lossFunction: z.string(),
  metrics: z.array(z.string()),
  callbacks: z.object({
    earlyStoppingConfig: z.object({
      monitor: z.enum(['val_loss', 'val_accuracy']),
      minDelta: z.number(),
      patience: z.number().positive(),
      mode: z.enum(['min', 'max'])
    }).optional(),
    checkpointPath: z.string().optional(),
    tensorboardLogDir: z.string().optional()
  }).optional()
});

/**
 * Zod validation schema for prediction configuration
 */
export const PredictionConfigSchema = z.object({
  modelPath: z.string(),
  modelType: z.enum(['pytorch', 'flux', 'sklearn', 'custom']),
  batchSize: z.number().positive().optional(),
  useGPU: z.boolean().optional(),
  returnProbabilities: z.boolean().optional(),
  outputTransform: z.enum(['softmax', 'sigmoid', 'none']).optional()
});

/**
 * Zod validation schema for time series forecast configuration
 */
export const TimeSeriesForecastConfigSchema = z.object({
  horizon: z.number().positive(),
  historyWindow: z.number().positive(),
  features: z.array(z.string()),
  targetVariable: z.string(),
  frequency: z.string().optional(),
  includeExogenous: z.boolean().optional(),
  decompose: z.boolean().optional(),
  scaler: z.enum(['standard', 'minmax', 'robust', 'none']).optional()
});

/**
 * Zod validation schema for explanation configuration
 */
export const ExplanationConfigSchema = z.object({
  method: z.enum(['shap', 'lime', 'integrated_gradients', 'counterfactual']),
  numSamples: z.number().positive().optional(),
  targetClass: z.number().optional(),
  baseline: z.array(z.any()).optional()
}); 