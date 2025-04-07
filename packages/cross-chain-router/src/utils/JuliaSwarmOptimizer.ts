import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { CrossChainRoute, PathOptimizationParams, SwarmOptimizationResult } from '../types';

/**
 * JuliaSwarmOptimizer - Interface for optimizing routes using Julia's swarm intelligence
 * 
 * This class provides the bridge between TypeScript and Julia's advanced
 * swarm optimization algorithms for finding optimal cross-chain routes.
 */
export class JuliaSwarmOptimizer {
  private juliaPath: string | null = null;
  private juliaScriptPath: string;
  private tempDir: string;
  private juliaAvailable: boolean = false;
  private juliaChecked: boolean = false;
  private resultCache: Map<string, SwarmOptimizationResult> = new Map();

  /**
   * Initialize the Julia swarm optimizer
   */
  constructor() {
    this.tempDir = os.tmpdir();
    this.juliaScriptPath = path.join(this.tempDir, 'route_optimizer.jl');
    this.findJuliaPath();
  }

  /**
   * Find Julia executable path
   */
  private findJuliaPath(): void {
    if (this.juliaChecked) return;
    
    try {
      // First check environment variable for Julia path
      if (process.env.JULIA_PATH) {
        try {
          const result = spawn(process.env.JULIA_PATH, ['--version']);
          result.on('close', (code) => {
            if (code === 0) {
              this.juliaPath = process.env.JULIA_PATH || null;
              this.juliaAvailable = true;
            }
          });
        } catch (error) {
          console.warn('Failed to use Julia from JULIA_PATH:', error);
        }
      }
      
      // Then check common locations if not found via env var
      if (!this.juliaPath) {
        const possiblePaths = [
          'julia', // In PATH
          '/usr/bin/julia',
          '/usr/local/bin/julia',
          'C:\\Program Files\\Julia\\bin\\julia.exe',
          'C:\\Program Files (x86)\\Julia\\bin\\julia.exe'
        ];

        for (const juliaPath of possiblePaths) {
          try {
            const result = spawn(juliaPath, ['--version']);
            let errorOccurred = false;
            
            result.on('error', (err) => {
              errorOccurred = true;
            });
            
            result.on('close', (code) => {
              if (code === 0 && !errorOccurred) {
                this.juliaPath = juliaPath;
                this.juliaAvailable = true;
              }
            });
            
            // Break on first success
            if (this.juliaPath) break;
          } catch (error) {
            // Continue to next path
          }
        }
      }
      
      if (!this.juliaPath) {
        console.warn('Julia not found in any standard location. Running in simulation mode.');
      }
    } catch (error) {
      console.warn('Failed to find Julia executable:', error);
      this.juliaPath = null;
      this.juliaAvailable = false;
    }
    
    this.juliaChecked = true;
  }

  /**
   * Check if Julia is available
   */
  public isJuliaAvailable(): boolean {
    return this.juliaAvailable;
  }

  /**
   * Optimize routes using Julia's swarm algorithms
   * 
   * @param routes Array of possible routes
   * @param params Optimization parameters
   * @returns Optimized routes
   */
  public async optimizeRoutes(
    routes: CrossChainRoute[],
    params: PathOptimizationParams
  ): Promise<SwarmOptimizationResult> {
    // Check cache first using a cache key
    const cacheKey = this.generateCacheKey(routes, params);
    if (this.resultCache.has(cacheKey)) {
      return this.resultCache.get(cacheKey)!;
    }
    
    if (!this.isJuliaAvailable()) {
      // If Julia is not available, use a fallback strategy
      console.warn('Julia is not available, using simple optimization fallback');
      const result = this.fallbackOptimization(routes, params);
      this.resultCache.set(cacheKey, result);
      return result;
    }

    if (routes.length === 0) {
      return {
        optimizedRoutes: [],
        iterations: 0,
        convergenceSpeed: 0,
        improvementPercentage: 0
      };
    }

    try {
      // Generate Julia script for route optimization
      const juliaScript = this.generateJuliaScript(routes, params);
      
      // Write script to temporary file
      fs.writeFileSync(this.juliaScriptPath, juliaScript);
      
      // Execute Julia script
      const result = await this.executeJuliaScript();
      
      // Parse and return the results
      const optimizationResult = this.parseJuliaResults(result);
      
      // Cache the result
      this.resultCache.set(cacheKey, optimizationResult);
      
      return optimizationResult;
    } catch (error) {
      console.error('Failed to optimize routes with Julia:', error);
      
      // Use fallback on error
      const fallbackResult = this.fallbackOptimization(routes, params);
      this.resultCache.set(cacheKey, fallbackResult);
      return fallbackResult;
    }
  }
  
  /**
   * Generate a cache key for optimization results
   */
  private generateCacheKey(routes: CrossChainRoute[], params: PathOptimizationParams): string {
    const routesHash = JSON.stringify(routes).length.toString(16);
    const paramsHash = JSON.stringify(params);
    return `${routesHash}-${paramsHash}`;
  }
  
  /**
   * Fallback optimization when Julia is not available
   */
  private fallbackOptimization(
    routes: CrossChainRoute[],
    params: PathOptimizationParams
  ): SwarmOptimizationResult {
    // Copy routes to avoid modifying the original
    const sortedRoutes = [...routes];
    
    // Sort routes based on optimization objective
    switch (params.optimizeFor) {
      case 'speed':
        sortedRoutes.sort((a, b) => a.totalTimeEstimate - b.totalTimeEstimate);
        break;
      case 'cost':
        sortedRoutes.sort((a, b) => a.totalGasEstimate - b.totalGasEstimate);
        break;
      case 'value':
        sortedRoutes.sort((a, b) => {
          const aValue = parseFloat(a.totalValue.outputAmount);
          const bValue = parseFloat(b.totalValue.outputAmount);
          return bValue - aValue; // Higher value first
        });
        break;
      case 'balanced':
      default:
        // Simple balanced score
        sortedRoutes.sort((a, b) => {
          const aScore = this.calculateBalancedScore(a);
          const bScore = this.calculateBalancedScore(b);
          return bScore - aScore; // Higher score first
        });
    }
    
    return {
      optimizedRoutes: sortedRoutes.slice(0, params.maxRoutes),
      iterations: 1,
      convergenceSpeed: 1,
      improvementPercentage: 0
    };
  }
  
  /**
   * Calculate a balanced score for route ranking
   */
  private calculateBalancedScore(route: CrossChainRoute): number {
    const timeScore = 1 / (route.totalTimeEstimate + 1);
    const costScore = 1 / (route.totalGasEstimate + 1);
    const valueScore = parseFloat(route.totalValue.outputAmount);
    const impactPenalty = route.totalValue.priceImpact / 100;
    
    return (timeScore * 0.3 + costScore * 0.3 + valueScore * 0.4) * (1 - impactPenalty);
  }

  /**
   * Generate Julia script for route optimization
   */
  private generateJuliaScript(routes: CrossChainRoute[], params: PathOptimizationParams): string {
    // Convert routes to JSON for Julia
    const routesJson = JSON.stringify(routes);
    const paramsJson = JSON.stringify(params);
    
    return `
      # Route optimization using swarm intelligence
      # Generated by JuliaOS Cross-Chain Router

      using JSON
      using SwarmOptimization

      # Parse input data
      routes_data = JSON.parse("""${routesJson}""")
      params_data = JSON.parse("""${paramsJson}""")

      # Define the optimization function
      function optimize_routes(routes, params)
          # Extract parameters
          optimize_for = params["optimizeFor"]
          swarm_size = get(params, "swarmSize", 30)
          learning_rate = get(params, "learningRate", 0.2)
          max_iterations = get(params, "maxIterations", 100)
          
          # Convert routes to optimization format
          route_vectors = []
          for route in routes
              # Create feature vector for optimization
              # [time, gas, output_amount, price_impact]
              push!(route_vectors, [
                  route["totalTimeEstimate"],
                  route["totalGasEstimate"],
                  parse(Float64, route["totalValue"]["outputAmount"]),
                  route["totalValue"]["priceImpact"]
              ])
          end
          
          # Run appropriate swarm optimization algorithm
          if optimize_for == "speed"
              weights = [0.7, 0.1, 0.2, 0.0]  # Prioritize time
          elseif optimize_for == "cost"
              weights = [0.1, 0.7, 0.2, 0.0]  # Prioritize gas cost
          elseif optimize_for == "value"
              weights = [0.1, 0.1, 0.8, 0.0]  # Prioritize output amount
          else # balanced
              weights = [0.3, 0.3, 0.3, 0.1]  # Balanced approach
          end
          
          # Run PSO (Particle Swarm Optimization)
          result = particle_swarm_optimization(
              route_vectors,
              weights,
              swarm_size=swarm_size,
              learning_rate=learning_rate,
              max_iterations=max_iterations
          )
          
          # Reorder routes based on optimization results
          ordered_indices = result["ordered_indices"]
          optimized_routes = routes[ordered_indices]
          
          return Dict(
              "optimizedRoutes" => optimized_routes,
              "iterations" => result["iterations"],
              "convergenceSpeed" => result["convergence_speed"],
              "improvementPercentage" => result["improvement_percentage"]
          )
      end

      # Run optimization
      result = optimize_routes(routes_data, params_data)

      # Output results as JSON
      println(JSON.json(result))
    `;
  }

  /**
   * Execute Julia script and return the results
   */
  private async executeJuliaScript(): Promise<string> {
    return new Promise((resolve, reject) => {
      if (!this.juliaPath) {
        reject(new Error('Julia executable not found'));
        return;
      }

      const julia = spawn(this.juliaPath, [this.juliaScriptPath]);
      let output = '';
      let error = '';

      julia.stdout.on('data', (data) => {
        output += data.toString();
      });

      julia.stderr.on('data', (data) => {
        error += data.toString();
      });

      julia.on('close', (code) => {
        if (code === 0) {
          resolve(output);
        } else {
          reject(new Error(`Julia process exited with code ${code}: ${error}`));
        }
      });
    });
  }

  /**
   * Parse Julia optimization results
   */
  private parseJuliaResults(juliaOutput: string): SwarmOptimizationResult {
    try {
      // Parse JSON output from Julia
      const result = JSON.parse(juliaOutput);

      return {
        optimizedRoutes: result.optimizedRoutes || [],
        iterations: result.iterations || 0,
        convergenceSpeed: result.convergenceSpeed || 0,
        improvementPercentage: result.improvementPercentage || 0
      };
    } catch (error) {
      console.error('Failed to parse Julia output:', error);
      throw new Error(`Failed to parse Julia output: ${error}`);
    }
  }

  /**
   * Generate optimization script for a specific algorithm
   */
  public generateOptimizationScript(algorithm: string): string {
    switch (algorithm) {
      case 'pso':
        return `
          # Particle Swarm Optimization (PSO) for route optimization
          function particle_swarm_optimization(routes, weights; swarm_size=30, learning_rate=0.2, max_iterations=100)
              # Implementation details would go here
              # This is a placeholder for the actual PSO algorithm
          end
        `;
      
      case 'gwo':
        return `
          # Grey Wolf Optimizer (GWO) for route optimization
          function grey_wolf_optimization(routes, weights; pack_size=30, alpha_score=0.3, max_iterations=100)
              # Implementation details would go here
              # This is a placeholder for the actual GWO algorithm
          end
        `;
      
      case 'woa':
        return `
          # Whale Optimization Algorithm (WOA) for route optimization
          function whale_optimization_algorithm(routes, weights; population_size=30, a_decrease_factor=0.1, max_iterations=100)
              # Implementation details would go here
              # This is a placeholder for the actual WOA algorithm
          end
        `;
      
      default:
        return `
          # Generic optimization algorithm
          function optimize(routes, weights; population_size=30, learning_rate=0.2, max_iterations=100)
              # Implementation details would go here
              # This is a placeholder for a generic optimization algorithm
          end
        `;
    }
  }
} 