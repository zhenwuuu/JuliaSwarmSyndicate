module PyTorchIntegration

using PyCall
using Flux
using BSON
using JSON
using LinearAlgebra
using Statistics

export init_pytorch, load_pytorch_model, save_pytorch_model, predict
export train_model, convert_to_tensor, convert_from_tensor
export create_sequential_model, create_cnn_model, create_lstm_model
export optimize_hyperparameters, serialize_model, deserialize_model
export gpu_available, move_to_device, batch_predict

# Initialize PyTorch via PyCall
function init_pytorch()
    try
        # Import PyTorch
        global torch = pyimport("torch")
        global nn = pyimport("torch.nn")
        global F = pyimport("torch.nn.functional")
        global optim = pyimport("torch.optim")
        global torchvision = pyimport("torchvision")
        
        # Check for CUDA
        has_cuda = torch.cuda.is_available()
        
        return (initialized=true, has_cuda=has_cuda)
    catch e
        @warn "Failed to initialize PyTorch: $e"
        return (initialized=false, has_cuda=false, error=e)
    end
end

# Check if GPU is available
function gpu_available()
    try
        if !@isdefined(torch)
            init_pytorch()
        end
        return torch.cuda.is_available()
    catch e
        return false
    end
end

# Move tensors or model to appropriate device (CPU/GPU)
function move_to_device(obj; device=nothing)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if device === nothing
        device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
    end
    
    return obj.to(device)
end

# Convert Julia array to PyTorch tensor
function convert_to_tensor(data; dtype=nothing, device=nothing)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if device === nothing
        device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
    end
    
    # Handle different data types
    if dtype === nothing
        if eltype(data) <: Integer
            dtype = torch.int64
        elseif eltype(data) <: AbstractFloat
            dtype = torch.float32
        elseif eltype(data) <: Bool
            dtype = torch.bool
        end
    end
    
    # Convert Julia array to PyTorch tensor
    tensor = torch.tensor(data, dtype=dtype)
    return tensor.to(device)
end

# Convert PyTorch tensor to Julia array
function convert_from_tensor(tensor)
    return Array(tensor.cpu().detach().numpy())
end

# Create a sequential neural network model
function create_sequential_model(layer_sizes::Vector{Int}, activation="relu"; dropout_rate=0.0)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    # Map activation function string to PyTorch activation
    activations = Dict(
        "relu" => nn.ReLU(),
        "sigmoid" => nn.Sigmoid(),
        "tanh" => nn.Tanh(),
        "leakyrelu" => nn.LeakyReLU(0.01),
        "elu" => nn.ELU()
    )
    
    activation_fn = get(activations, lowercase(activation), nn.ReLU())
    
    # Build layers
    layers = []
    for i in 1:(length(layer_sizes)-1)
        push!(layers, nn.Linear(layer_sizes[i], layer_sizes[i+1]))
        push!(layers, activation_fn)
        
        if dropout_rate > 0
            push!(layers, nn.Dropout(dropout_rate))
        end
    end
    
    # Create sequential model
    model = nn.Sequential(PyObject.(layers)...)
    return model
end

# Create a CNN model for time series
function create_cnn_model(input_channels::Int, input_length::Int, output_size::Int)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    # Define model architecture for time series data
    @pydef mutable struct CNNTimeSeries <: nn.Module
        function __init__(self, input_channels, input_length, output_size)
            nn.Module.__init__(self)
            self.conv1 = nn.Conv1d(input_channels, 32, 3, padding=1)
            self.conv2 = nn.Conv1d(32, 64, 3, padding=1)
            self.pool = nn.MaxPool1d(2)
            self.dropout = nn.Dropout(0.2)
            
            # Calculate size after convolutions and pooling
            feature_size = div(input_length, 4) * 64
            
            self.fc1 = nn.Linear(feature_size, 128)
            self.fc2 = nn.Linear(128, output_size)
        end
        
        function forward(self, x)
            # x shape: (batch, channels, length)
            x = F.relu(self.conv1(x))
            x = self.pool(x)
            x = F.relu(self.conv2(x))
            x = self.pool(x)
            x = x.view(x.size(0), -1)  # Flatten
            x = self.dropout(x)
            x = F.relu(self.fc1(x))
            x = self.fc2(x)
            return x
        end
    end
    
    return CNNTimeSeries(input_channels, input_length, output_size)
end

# Create an LSTM model for time series forecasting
function create_lstm_model(input_size::Int, hidden_size::Int, output_size::Int, num_layers::Int=1)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    # Define LSTM model
    @pydef mutable struct LSTMModel <: nn.Module
        function __init__(self, input_size, hidden_size, output_size, num_layers)
            nn.Module.__init__(self)
            self.hidden_size = hidden_size
            self.num_layers = num_layers
            
            self.lstm = nn.LSTM(input_size, hidden_size, num_layers, batch_first=true)
            self.fc = nn.Linear(hidden_size, output_size)
        end
        
        function forward(self, x)
            # x shape: (batch, seq_len, input_size)
            h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(x.device)
            c0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(x.device)
            
            out, _ = self.lstm(x, (h0, c0))
            
            # Get output from last time step
            out = self.fc(out[:, -1, :])
            return out
        end
    end
    
    return LSTMModel(input_size, hidden_size, output_size, num_layers)
end

# Train a PyTorch model
function train_model(model, train_data, train_labels, validation_data=nothing, validation_labels=nothing;
                    epochs=10, batch_size=32, learning_rate=0.001, optimizer_type="adam",
                    loss_function="mse", device=nothing, early_stopping=true, patience=5)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if device === nothing
        device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
    end
    
    # Move model to device
    model = model.to(device)
    
    # Convert data to tensors if they aren't already
    train_data_tensor = isa(train_data, PyObject) ? train_data : convert_to_tensor(train_data, device=device)
    train_labels_tensor = isa(train_labels, PyObject) ? train_labels : convert_to_tensor(train_labels, device=device)
    
    # Create DataLoader for batching
    train_dataset = torch.utils.data.TensorDataset(train_data_tensor, train_labels_tensor)
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=batch_size, shuffle=true)
    
    # Set up validation data if provided
    if validation_data !== nothing && validation_labels !== nothing
        val_data_tensor = isa(validation_data, PyObject) ? validation_data : convert_to_tensor(validation_data, device=device)
        val_labels_tensor = isa(validation_labels, PyObject) ? validation_labels : convert_to_tensor(validation_labels, device=device)
        val_dataset = torch.utils.data.TensorDataset(val_data_tensor, val_labels_tensor)
        val_loader = torch.utils.data.DataLoader(val_dataset, batch_size=batch_size)
    end
    
    # Set up optimizer
    if optimizer_type == "adam"
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    elseif optimizer_type == "sgd"
        optimizer = optim.SGD(model.parameters(), lr=learning_rate)
    elseif optimizer_type == "rmsprop"
        optimizer = optim.RMSprop(model.parameters(), lr=learning_rate)
    else
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    end
    
    # Set up loss function
    if loss_function == "mse"
        criterion = nn.MSELoss()
    elseif loss_function == "cross_entropy"
        criterion = nn.CrossEntropyLoss()
    elseif loss_function == "bce"
        criterion = nn.BCELoss()
    else
        criterion = nn.MSELoss()
    end
    
    # Training loop
    best_val_loss = Inf
    epochs_no_improve = 0
    training_history = Dict("train_loss" => Float64[], "val_loss" => Float64[])
    
    for epoch in 1:epochs
        # Training phase
        model.train()
        train_loss = 0.0
        for (inputs, targets) in train_loader
            # Forward pass
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            
            # Backward and optimize
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
        end
        
        train_loss /= length(train_loader)
        push!(training_history["train_loss"], train_loss)
        
        # Validation phase
        if validation_data !== nothing
            model.eval()
            val_loss = 0.0
            
            with(torch.no_grad()) do
                for (inputs, targets) in val_loader
                    outputs = model(inputs)
                    loss = criterion(outputs, targets)
                    val_loss += loss.item()
                end
            end
            
            val_loss /= length(val_loader)
            push!(training_history["val_loss"], val_loss)
            
            println("Epoch $epoch/$epochs - Train Loss: $(round(train_loss, digits=5)) - Val Loss: $(round(val_loss, digits=5))")
            
            # Early stopping
            if early_stopping
                if val_loss < best_val_loss
                    best_val_loss = val_loss
                    epochs_no_improve = 0
                    # Save best model
                    best_model = deepcopy(model.state_dict())
                else
                    epochs_no_improve += 1
                    if epochs_no_improve >= patience
                        println("Early stopping triggered after $epoch epochs")
                        # Restore best model
                        model.load_state_dict(best_model)
                        break
                    end
                end
            end
        else
            println("Epoch $epoch/$epochs - Train Loss: $(round(train_loss, digits=5))")
        end
    end
    
    return Dict("model" => model, "history" => training_history)
end

# Save PyTorch model to file
function save_pytorch_model(model, filepath; save_architecture=true)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    dir_path = dirname(filepath)
    if !isempty(dir_path) && !isdir(dir_path)
        mkpath(dir_path)
    end
    
    # Save model state
    state_dict_path = filepath
    if !endswith(filepath, ".pt")
        state_dict_path = "$filepath.pt"
    end
    
    torch.save(model.state_dict(), state_dict_path)
    
    # Save architecture if requested
    if save_architecture
        # Try to save the model definition
        script_model = torch.jit.script(model)
        script_path = replace(filepath, r"\.pt$" => "_script.pt")
        if !endswith(script_path, ".pt")
            script_path = "$script_path.pt"
        end
        script_model.save(script_path)
        
        return Dict("state_dict" => state_dict_path, "script" => script_path)
    end
    
    return Dict("state_dict" => state_dict_path)
end

# Load PyTorch model from file
function load_pytorch_model(model_class, state_dict_path)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    # Load state dict
    state_dict = torch.load(state_dict_path)
    
    # Create new model instance and load state
    model = model_class()
    model.load_state_dict(state_dict)
    
    return model
end

# Load a TorchScript model
function load_script_model(script_path; device=nothing)
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if device === nothing
        device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
    end
    
    # Load the scripted model
    model = torch.jit.load(script_path)
    model = model.to(device)
    
    return model
end

# Make predictions with a model
function predict(model, inputs; device=nothing)
    try
        if !@isdefined(torch)
            init_pytorch()
        end
        
        if device === nothing
            device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
        end
        
        # Convert inputs to PyTorch tensors if they're not already
        if !(PyObject <: typeof(inputs))
            inputs = convert_to_tensor(inputs, device=device)
        end
        
        # Set to evaluation mode and disable gradient calculation for inference
        model.eval()
        
        # Run prediction
        with(torch.no_grad()) do
            outputs = model(inputs)
            
            # Convert outputs back to Julia arrays
            if PyCall.hasproperty(outputs, "numpy")
                return Dict("success" => true, "outputs" => convert_from_tensor(outputs))
            else
                return Dict("success" => true, "outputs" => outputs)
            end
        end
    catch e
        @warn "Failed to run prediction: $e"
        return Dict("success" => false, "error" => e)
    end
end

# Run prediction on batches (for large datasets)
function batch_predict(model, inputs; batch_size=32, device=nothing)
    try
        if !@isdefined(torch)
            init_pytorch()
        end
        
        if device === nothing
            device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
        end
        
        # Convert inputs to PyTorch tensors if they're not already
        if !(PyObject <: typeof(inputs))
            inputs = convert_to_tensor(inputs, device=device)
        end
        
        # Prepare data loader
        dataset = torch.utils.data.TensorDataset(inputs)
        loader = torch.utils.data.DataLoader(dataset, batch_size=batch_size)
        
        # Set to evaluation mode
        model.eval()
        
        # Run predictions in batches
        all_outputs = []
        with(torch.no_grad()) do
            for (batch,) in loader
                batch_output = model(batch)
                push!(all_outputs, batch_output.cpu())
            end
        end
        
        # Concatenate all batches
        if length(all_outputs) > 0
            outputs = torch.cat(all_outputs, dim=0)
            return Dict("success" => true, "outputs" => convert_from_tensor(outputs))
        else
            return Dict("success" => true, "outputs" => [])
        end
    catch e
        @warn "Failed to run batch prediction: $e"
        return Dict("success" => false, "error" => e)
    end
end

# Optimize hyperparameters using random search
function optimize_hyperparameters(model_fn, train_data, train_labels, val_data, val_labels; 
                                param_grid, n_trials=10, metric="val_loss")
    if !@isdefined(torch)
        init_pytorch()
    end
    
    best_score = (metric == "val_loss") ? Inf : -Inf
    best_params = nothing
    best_model = nothing
    
    for i in 1:n_trials
        # Sample parameters from the grid
        params = Dict()
        for (key, values) in param_grid
            params[key] = rand(values)
        end
        
        println("Trial $i/$n_trials with params: $params")
        
        # Create and train model with sampled parameters
        model = model_fn(params)
        result = train_model(
            model, train_data, train_labels, val_data, val_labels;
            epochs=params["epochs"],
            batch_size=params["batch_size"],
            learning_rate=params["learning_rate"],
            early_stopping=true
        )
        
        # Evaluate based on metric
        if metric == "val_loss"
            score = result["history"]["val_loss"][end]
            is_better = score < best_score
        else
            score = result["history"]["val_accuracy"][end]
            is_better = score > best_score
        end
        
        # Update best if improved
        if is_better
            best_score = score
            best_params = params
            best_model = result["model"]
            println("New best score: $best_score with params: $best_params")
        end
    end
    
    return Dict(
        "best_model" => best_model,
        "best_params" => best_params,
        "best_score" => best_score
    )
end

# Serialize model architecture and weights
function serialize_model(model; include_weights=true, format="torch")
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if format == "torch"
        # Create buffer to serialize to
        buffer = PyObject(torch.jit.script(model))
        if include_weights
            return buffer
        else
            # TODO: Implement state_dict filtering for architecture only
            return buffer
        end
    elseif format == "onnx"
        try
            onnx = pyimport("torch.onnx")
            io_buffer = PyObject(torch.ByteStorage)()
            # Create example input based on first layer
            example_input_shape = (1, model.input_size) # Adjust based on model 
            example_input = torch.randn(example_input_shape)
            
            # Export to ONNX format
            onnx.export(model, example_input, io_buffer)
            return io_buffer.data()
        catch e
            @warn "Failed to serialize to ONNX: $e"
            return nothing
        end
    end
end

# Deserialize model
function deserialize_model(serialized_data; format="torch")
    if !@isdefined(torch)
        init_pytorch()
    end
    
    if format == "torch"
        # Load TorchScript model
        model = torch.jit.load(serialized_data)
        return model
    elseif format == "onnx"
        try
            onnx = pyimport("torch.onnx")
            ort = pyimport("onnxruntime")
            
            # Create ONNX inference session
            session = ort.InferenceSession(serialized_data)
            
            # Return wrapped session for inference
            return session
        catch e
            @warn "Failed to deserialize ONNX model: $e"
            return nothing
        end
    end
end

end # module 