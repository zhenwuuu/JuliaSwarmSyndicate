import { EventEmitter } from 'events';
import { JuliaBridge } from './JuliaBridge';
import * as MLTypes from '../types/MLTypes';
import { v4 as uuidv4 } from 'uuid';

/**
 * MLBridge provides a high-level interface to Machine Learning operations
 * in Julia from TypeScript.
 */
export class MLBridge extends EventEmitter {
  private bridge: JuliaBridge;
  private models: Map<string, MLTypes.ModelConfig> = new Map();

  /**
   * Create a new MLBridge instance
   * @param bridge An initialized JuliaBridge instance
   */
  constructor(bridge: JuliaBridge) {
    super();
    this.bridge = bridge;
  }

  /**
   * Initialize the ML environment in Julia
   */
  async initialize(): Promise<boolean> {
    try {
      // Initialize ML modules in Julia
      const initCode = `
        # Load required packages
        using Pkg
        
        # Define required packages
        required_packages = [
            "Flux",
            "BSON",
            "Statistics",
            "LinearAlgebra",
            "Random",
            "Distributions",
            "DelimitedFiles",
            "JSON",
            "PyCall"
        ]
        
        # Install missing packages
        for pkg in required_packages
            if !haskey(Pkg.installed(), pkg)
                @info "Installing $pkg..."
                Pkg.add(pkg)
            end
        end
        
        # Load packages
        @info "Loading ML packages..."
        using Flux
        using BSON
        using Statistics
        using LinearAlgebra
        using Random
        using Distributions
        using DelimitedFiles
        using JSON
        
        # PyTorch support if available
        has_pytorch = false
        try
            # Try to initialize PyCall and PyTorch
            using PyCall
            torch = pyimport("torch")
            has_pytorch = true
            @info "PyTorch detected and initialized"
        catch e
            @warn "PyTorch not available: $e"
        end
        
        # Return initialization status
        Dict(
            "status" => "initialized",
            "flux_version" => string(pkgversion(Flux)),
            "has_pytorch" => has_pytorch,
            "has_gpu" => has_pytorch ? torch.cuda.is_available() : false
        )
      `;

      const result = await this.bridge.executeCode(initCode);
      
      if (result.error) {
        throw new Error(`Failed to initialize ML environment: ${result.error}`);
      }
      
      this.emit('initialized', result.data);
      return true;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Load a PyTorch model
   * @param config PyTorch model configuration
   */
  async loadPyTorchModel(config: MLTypes.PyTorchModelConfig): Promise<string> {
    try {
      // Validate config
      MLTypes.ModelConfigSchema.parse(config);
      
      const modelId = config.name || uuidv4();
      
      const loadCode = `
        # Load PyTorch module
        using PyCall
        torch = pyimport("torch")
        
        # Check if GPU is available
        use_gpu = ${config.useGPU === true} && torch.cuda.is_available()
        device = use_gpu ? torch.device("cuda") : torch.device("cpu")
        
        # Load the model
        model_path = "${config.torchScriptPath || config.path}"
        
        try
            model = torch.jit.load(model_path)
            model = model.to(device)
            model.eval()  # Set to evaluation mode
            
            # Store model in global registry
            if !@isdefined(GLOBAL_MODEL_REGISTRY)
                global GLOBAL_MODEL_REGISTRY = Dict()
            end
            
            GLOBAL_MODEL_REGISTRY["${modelId}"] = model
            
            # Return model info
            Dict(
                "model_id" => "${modelId}",
                "type" => "pytorch",
                "device" => string(device),
                "input_shape" => [${config.inputShape.join(',')}],
                "output_shape" => [${config.outputShape.join(',')}],
                "status" => "loaded"
            )
        catch e
            Dict(
                "status" => "error",
                "error" => string(e)
            )
        end
      `;
      
      const result = await this.bridge.executeCode(loadCode);
      
      if (result.error || result.data.status === "error") {
        throw new Error(`Failed to load PyTorch model: ${result.error || result.data.error}`);
      }
      
      // Store model config
      this.models.set(modelId, config);
      
      this.emit('model_loaded', { modelId, config });
      return modelId;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Make predictions with a loaded model
   * @param modelId ID of the loaded model
   * @param inputs Input data for prediction
   * @param config Prediction configuration
   */
  async predict<T = any>(
    modelId: string, 
    inputs: any, 
    config?: Partial<MLTypes.PredictionConfig>
  ): Promise<MLTypes.PredictionResult<T>> {
    try {
      const modelConfig = this.models.get(modelId);
      if (!modelConfig) {
        throw new Error(`Model with ID ${modelId} not found`);
      }
      
      // Create prediction code based on model type
      let predictCode: string;
      
      if (modelConfig.type === 'pytorch') {
        predictCode = `
          # Get model from registry
          if !@isdefined(GLOBAL_MODEL_REGISTRY) || !haskey(GLOBAL_MODEL_REGISTRY, "${modelId}")
              error("Model ${modelId} not found")
          end
          
          model = GLOBAL_MODEL_REGISTRY["${modelId}"]
          
          # Prepare input data
          input_data = ${JSON.stringify(inputs)}
          
          # Convert to tensor
          using PyCall
          torch = pyimport("torch")
          
          # Check if GPU is available
          use_gpu = ${config?.useGPU === true} && torch.cuda.is_available()
          device = use_gpu ? torch.device("cuda") : torch.device("cpu")
          
          # Timer for inference time measurement
          start_time = time()
          
          try
              # Convert input to tensor
              x = torch.tensor(input_data)
              x = x.to(device)
              
              # Run prediction
              model.eval()
              torch.set_grad_enabled(false)
              
              output = model(x)
              
              # Convert output to array
              result = output.cpu().detach().numpy()
              
              # Calculate probabilities if requested
              probabilities = nothing
              if ${config?.returnProbabilities === true}
                  if "${config?.outputTransform || 'none'}" == "softmax"
                      probabilities = torch.nn.functional.softmax(output, dim=1).cpu().detach().numpy()
                  elseif "${config?.outputTransform || 'none'}" == "sigmoid"
                      probabilities = torch.sigmoid(output).cpu().detach().numpy()
                  else
                      probabilities = result
                  end
              end
              
              end_time = time()
              inference_time = (end_time - start_time) * 1000  # Convert to ms
              
              Dict(
                  "predictions" => result,
                  "probabilities" => probabilities,
                  "inference_time" => inference_time,
                  "metadata" => Dict(
                      "model_id" => "${modelId}",
                      "model_type" => "pytorch",
                      "device" => string(device),
                      "input_shape" => size(input_data)
                  )
              )
          catch e
              Dict(
                  "status" => "error",
                  "error" => string(e)
              )
          end
        `;
      } else if (modelConfig.type === 'flux') {
        // Flux model prediction code would go here
        throw new Error("Flux model prediction not yet implemented");
      } else {
        throw new Error(`Unsupported model type: ${modelConfig.type}`);
      }
      
      const result = await this.bridge.executeCode(predictCode);
      
      if (result.error || result.data.status === "error") {
        throw new Error(`Prediction failed: ${result.error || result.data.error}`);
      }
      
      // Format the result
      const predictionResult: MLTypes.PredictionResult<T> = {
        predictions: result.data.predictions,
        probabilities: result.data.probabilities,
        inferenceTime: result.data.inference_time,
        metadata: {
          modelType: modelConfig.type as MLTypes.MLModelType,
          modelPath: modelConfig.path || '',
          inputShape: modelConfig.inputShape,
          device: result.data.metadata.device
        }
      };
      
      this.emit('prediction_completed', { modelId, result: predictionResult });
      return predictionResult;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Train a model
   * @param config Model configuration
   * @param trainData Training data
   * @param trainingConfig Training configuration
   */
  async trainModel(
    config: MLTypes.ModelConfig,
    trainData: [any, any], // [inputs, labels]
    trainingConfig: MLTypes.TrainingConfig
  ): Promise<string> {
    try {
      // Validate configs
      MLTypes.ModelConfigSchema.parse(config);
      MLTypes.TrainingConfigSchema.parse(trainingConfig);
      
      const modelId = config.name || uuidv4();
      
      // Training code depends on model type
      let trainCode: string;
      
      if (config.type === 'pytorch') {
        // PyTorch training code through PyCall
        trainCode = `
          # Load PyTorch modules
          using PyCall
          torch = pyimport("torch")
          nn = pyimport("torch.nn")
          optim = pyimport("torch.optim")
          
          # Check if GPU is available
          use_gpu = torch.cuda.is_available()
          device = use_gpu ? torch.device("cuda") : torch.device("cpu")
          
          # Prepare data
          train_inputs = ${JSON.stringify(trainData[0])}
          train_labels = ${JSON.stringify(trainData[1])}
          
          # Convert to tensors
          x = torch.tensor(train_inputs, dtype=torch.float32).to(device)
          y = torch.tensor(train_labels, dtype=torch.float32).to(device)
          
          # Define model architecture
          if "${config.architecture}" == "mlp"
              layers = []
              input_size = ${config.inputShape[config.inputShape.length - 1]}
              hidden_sizes = [64, 32]  # Example hidden layer sizes
              output_size = ${config.outputShape[config.outputShape.length - 1]}
              
              push!(layers, nn.Linear(input_size, hidden_sizes[1]))
              push!(layers, nn.ReLU())
              push!(layers, nn.Linear(hidden_sizes[1], hidden_sizes[2]))
              push!(layers, nn.ReLU())
              push!(layers, nn.Linear(hidden_sizes[2], output_size))
              
              model = nn.Sequential(PyObject, layers...)
          else
              error("Unsupported architecture: ${config.architecture}")
          end
          
          model = model.to(device)
          
          # Define loss function
          if "${trainingConfig.lossFunction}" == "mse"
              criterion = nn.MSELoss()
          elseif "${trainingConfig.lossFunction}" == "cross_entropy"
              criterion = nn.CrossEntropyLoss()
          else
              error("Unsupported loss function: ${trainingConfig.lossFunction}")
          end
          
          # Define optimizer
          if "${trainingConfig.optimizer.type}" == "adam"
              opt = optim.Adam(model.parameters(), lr=${trainingConfig.optimizer.learningRate})
          elseif "${trainingConfig.optimizer.type}" == "sgd"
              opt = optim.SGD(model.parameters(), lr=${trainingConfig.optimizer.learningRate})
          else
              error("Unsupported optimizer: ${trainingConfig.optimizer.type}")
          end
          
          # Training loop
          epochs = ${trainingConfig.epochs}
          history = Dict("train_loss" => [])
          
          for epoch in 1:epochs
              # Training
              model.train()
              opt.zero_grad()
              
              # Forward pass
              outputs = model(x)
              loss = criterion(outputs, y)
              
              # Backward and optimize
              loss.backward()
              opt.step()
              
              # Record loss
              push!(history["train_loss"], loss.item())
              
              println("Epoch [$epoch/$epochs], Loss: $(loss.item())")
          end
          
          # Save model
          model.eval()
          scripted_model = torch.jit.script(model)
          
          save_path = "models/$(uuid4()).pt"
          mkpath(dirname(save_path))
          scripted_model.save(save_path)
          
          # Store in registry for immediate use
          if !@isdefined(GLOBAL_MODEL_REGISTRY)
              global GLOBAL_MODEL_REGISTRY = Dict()
          end
          
          GLOBAL_MODEL_REGISTRY["${modelId}"] = model
          
          Dict(
              "model_id" => "${modelId}",
              "type" => "pytorch",
              "path" => save_path,
              "history" => history,
              "status" => "trained"
          )
        `;
      } else if (config.type === 'flux') {
        // Flux model training code
        throw new Error("Flux model training not yet implemented");
      } else {
        throw new Error(`Unsupported model type for training: ${config.type}`);
      }
      
      const result = await this.bridge.executeCode(trainCode);
      
      if (result.error || result.data.status === "error") {
        throw new Error(`Training failed: ${result.error || result.data.error}`);
      }
      
      // Update the model config with the saved path
      const updatedConfig: MLTypes.ModelConfig = {
        ...config,
        path: result.data.path
      };
      
      // Store model config
      this.models.set(modelId, updatedConfig);
      
      this.emit('model_trained', { modelId, config: updatedConfig });
      return modelId;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Generate model explanations using methods like SHAP
   * @param modelId ID of the loaded model
   * @param inputs Input data to explain predictions for
   * @param config Explanation configuration
   */
  async explainModel(
    modelId: string,
    inputs: any,
    config: MLTypes.ExplanationConfig
  ): Promise<MLTypes.ExplanationResult> {
    try {
      // Validate config
      MLTypes.ExplanationConfigSchema.parse(config);
      
      const modelConfig = this.models.get(modelId);
      if (!modelConfig) {
        throw new Error(`Model with ID ${modelId} not found`);
      }
      
      // Only SHAP is implemented for now
      if (config.method !== 'shap') {
        throw new Error(`Explanation method not implemented: ${config.method}`);
      }
      
      const explainCode = `
        # Get model from registry
        if !@isdefined(GLOBAL_MODEL_REGISTRY) || !haskey(GLOBAL_MODEL_REGISTRY, "${modelId}")
            error("Model ${modelId} not found")
        end
        
        model = GLOBAL_MODEL_REGISTRY["${modelId}"]
        
        # Install and load SHAP if needed
        using PyCall
        
        try
            shap = pyimport("shap")
        catch
            # Install SHAP if not available
            py"""
            import sys
            import subprocess
            subprocess.check_call([sys.executable, "-m", "pip", "install", "shap"])
            """
            shap = pyimport("shap")
        end
        
        # Prepare input data
        input_data = ${JSON.stringify(inputs)}
        
        # Convert to tensor for PyTorch model
        if "${modelConfig.type}" == "pytorch"
            torch = pyimport("torch")
            x = torch.tensor(input_data)
            
            # Create explainer
            timer_start = time()
            
            # Create a function that calls the PyTorch model
            function predict_fn(X)
                X_tensor = torch.tensor(X)
                model.eval()
                with(torch.no_grad()) do
                    return model(X_tensor).cpu().numpy()
                end
            end
            
            # Create the SHAP explainer
            explainer = shap.Explainer(predict_fn, input_data)
            
            # Calculate SHAP values
            shap_values = explainer(input_data)
            
            timer_end = time()
            compute_time = (timer_end - timer_start) * 1000  # Convert to ms
            
            # Extract and format the results
            values = shap_values.values
            base_values = shap_values.base_values
            features = collect(1:size(input_data, 2))  # Feature indices as placeholders
            
            # Feature importance (mean absolute SHAP values)
            feature_importance = vec(mean(abs.(values), dims=1))
            
            Dict(
                "type" => "feature_importance",
                "data" => Dict(
                    "shap_values" => values,
                    "base_values" => base_values,
                    "features" => features,
                    "feature_importance" => feature_importance
                ),
                "metadata" => Dict(
                    "method" => "shap",
                    "model_type" => "${modelConfig.type}",
                    "compute_time" => compute_time
                )
            )
        else
            error("Explanation not implemented for model type: ${modelConfig.type}")
        end
      `;
      
      const result = await this.bridge.executeCode(explainCode);
      
      if (result.error || result.data.status === "error") {
        throw new Error(`Explanation failed: ${result.error || result.data.error}`);
      }
      
      // Format the explanation result
      const explanationResult: MLTypes.ExplanationResult = {
        type: result.data.type,
        data: result.data.data,
        metadata: {
          method: result.data.metadata.method,
          modelType: modelConfig.type as MLTypes.MLModelType,
          computeTime: result.data.metadata.compute_time
        }
      };
      
      this.emit('explanation_completed', { modelId, result: explanationResult });
      return explanationResult;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Unload a model from memory
   * @param modelId ID of the loaded model
   */
  async unloadModel(modelId: string): Promise<boolean> {
    try {
      if (!this.models.has(modelId)) {
        return false;
      }
      
      const unloadCode = `
        if @isdefined(GLOBAL_MODEL_REGISTRY) && haskey(GLOBAL_MODEL_REGISTRY, "${modelId}")
            delete!(GLOBAL_MODEL_REGISTRY, "${modelId}")
            GC.gc()  # Run garbage collection
            Dict("status" => "unloaded", "model_id" => "${modelId}")
        else
            Dict("status" => "not_found", "model_id" => "${modelId}")
        end
      `;
      
      const result = await this.bridge.executeCode(unloadCode);
      
      if (result.error) {
        throw new Error(`Failed to unload model: ${result.error}`);
      }
      
      if (result.data.status === "unloaded") {
        this.models.delete(modelId);
        this.emit('model_unloaded', { modelId });
        return true;
      }
      
      return false;
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Get information about all loaded models
   */
  getLoadedModels(): {id: string, config: MLTypes.ModelConfig}[] {
    const models: {id: string, config: MLTypes.ModelConfig}[] = [];
    
    for (const [id, config] of this.models.entries()) {
      models.push({id, config});
    }
    
    return models;
  }
} 