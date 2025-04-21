module PyTorchBridge

using PyCall
using LinearAlgebra
using Statistics
using JSON
using Flux

export init_pytorch, load_model, predict, convert_to_tensor, convert_from_tensor
export train_model, export_model, get_model_info, get_available_devices

"""
    init_pytorch()

Initialize PyTorch environment through PyCall.
"""
function init_pytorch()
    try
        # Import PyTorch through PyCall
        global torch = PyNULL()
        global nn = PyNULL()
        global F = PyNULL()
        global optim = PyNULL()
        
        copy!(torch, PyCall.pyimport("torch"))
        copy!(nn, PyCall.pyimport("torch.nn"))
        copy!(F, PyCall.pyimport("torch.nn.functional"))
        copy!(optim, PyCall.pyimport("torch.optim"))
        
        # Check if CUDA is available
        has_cuda = torch.cuda.is_available()
        device = has_cuda ? torch.device("cuda") : torch.device("cpu")
        
        return (initialized=true, has_cuda=has_cuda, device=device)
    catch e
        @warn "Failed to initialize PyTorch: $e"
        return (initialized=false, error=e)
    end
end

"""
    load_model(model_path; device=nothing)

Load a PyTorch model from the specified path.
"""
function load_model(model_path; device=nothing)
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        if device === nothing
            device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
        end
        
        model = torch.jit.load(model_path)
        model = model.to(device)
        model.eval()  # Set to evaluation mode
        
        return (success=true, model=model, device=device)
    catch e
        @warn "Failed to load PyTorch model: $e"
        return (success=false, error=e)
    end
end

"""
    predict(model, inputs; device=nothing)

Run prediction using a PyTorch model.
"""
function predict(model, inputs; device=nothing)
    try
        if !isdefined(Main, :torch)
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
                return (success=true, outputs=convert_from_tensor(outputs))
            else
                return (success=true, outputs=outputs)
            end
        end
    catch e
        @warn "Failed to run prediction: $e"
        return (success=false, error=e)
    end
end

"""
    convert_to_tensor(data; device=nothing)

Convert Julia arrays to PyTorch tensors.
"""
function convert_to_tensor(data; device=nothing)
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        if device === nothing
            device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
        end
        
        # Handle different data types
        if isa(data, Array)
            tensor = torch.tensor(data)
            return tensor.to(device)
        elseif isa(data, Dict)
            tensor_dict = Dict()
            for (k, v) in data
                tensor_dict[k] = convert_to_tensor(v, device=device)
            end
            return tensor_dict
        else
            error("Unsupported data type: $(typeof(data))")
        end
    catch e
        @warn "Failed to convert to tensor: $e"
        rethrow(e)
    end
end

"""
    convert_from_tensor(tensor)

Convert PyTorch tensors to Julia arrays.
"""
function convert_from_tensor(tensor)
    try
        # Check if it's a tensor
        if PyCall.hasproperty(tensor, "numpy")
            return tensor.cpu().numpy()
        elseif PyCall.hasproperty(tensor, "items")  # It's a dict-like object
            result = Dict()
            for (k, v) in tensor.items()
                result[k] = convert_from_tensor(v)
            end
            return result
        elseif PyCall.hasproperty(tensor, "__iter__")  # It's an iterable
            return [convert_from_tensor(t) for t in tensor]
        else
            return tensor  # Return as is if we can't convert
        end
    catch e
        @warn "Failed to convert from tensor: $e"
        rethrow(e)
    end
end

"""
    train_model(model, train_data, val_data; 
                epochs=10, learning_rate=0.001, 
                batch_size=32, optimizer="adam",
                loss_function="mse", device=nothing)

Train a PyTorch model using provided data.
"""
function train_model(model, train_data, val_data; 
                    epochs=10, learning_rate=0.001, 
                    batch_size=32, optimizer="adam",
                    loss_function="mse", device=nothing)
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        if device === nothing
            device = torch.cuda.is_available() ? torch.device("cuda") : torch.device("cpu")
        end
        
        # Set model to training mode
        model.train()
        
        # Create optimizer
        if optimizer == "adam"
            opt = optim.Adam(model.parameters(), lr=learning_rate)
        elseif optimizer == "sgd"
            opt = optim.SGD(model.parameters(), lr=learning_rate)
        else
            error("Unsupported optimizer: $optimizer")
        end
        
        # Create loss function
        if loss_function == "mse"
            criterion = nn.MSELoss()
        elseif loss_function == "cross_entropy"
            criterion = nn.CrossEntropyLoss()
        else
            error("Unsupported loss function: $loss_function")
        end
        
        # Convert data to tensors if needed
        train_inputs, train_labels = train_data
        val_inputs, val_labels = val_data
        
        train_inputs = convert_to_tensor(train_inputs, device=device)
        train_labels = convert_to_tensor(train_labels, device=device)
        val_inputs = convert_to_tensor(val_inputs, device=device)
        val_labels = convert_to_tensor(val_labels, device=device)
        
        # Training loop
        history = Dict("train_loss" => [], "val_loss" => [])
        
        for epoch in 1:epochs
            # Training
            model.train()
            train_loss = 0.0
            
            # TODO: Implement proper batching here
            opt.zero_grad()
            outputs = model(train_inputs)
            loss = criterion(outputs, train_labels)
            loss.backward()
            opt.step()
            
            train_loss = loss.item()
            push!(history["train_loss"], train_loss)
            
            # Validation
            model.eval()
            with(torch.no_grad()) do
                val_outputs = model(val_inputs)
                val_loss = criterion(val_outputs, val_labels).item()
                push!(history["val_loss"], val_loss)
            end
            
            @info "Epoch $epoch/$epochs: train_loss=$train_loss, val_loss=$(history["val_loss"][end])"
        end
        
        return (success=true, history=history, model=model)
    catch e
        @warn "Failed to train model: $e"
        return (success=false, error=e)
    end
end

"""
    export_model(model, save_path; format="torch_script")

Export a PyTorch model to a file.
"""
function export_model(model, save_path; format="torch_script")
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        # Set model to evaluation mode
        model.eval()
        
        if format == "torch_script"
            # Export as TorchScript
            scripted_model = torch.jit.script(model)
            scripted_model.save(save_path)
        elseif format == "onnx"
            # Export as ONNX (requires sample input)
            sample_input = torch.randn(1, model.input_size)  # Adjust as needed
            torch.onnx.export(model, sample_input, save_path)
        else
            error("Unsupported export format: $format")
        end
        
        return (success=true, path=save_path)
    catch e
        @warn "Failed to export model: $e"
        return (success=false, error=e)
    end
end

"""
    get_model_info(model)

Get information about a PyTorch model.
"""
function get_model_info(model)
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        # Count parameters
        param_count = sum(p.numel() for p in model.parameters())
        
        # Get model structure as string
        model_str = string(model)
        
        # Check if on GPU
        on_gpu = begin
            try
                next(model.parameters()).is_cuda
            catch
                false
            end
        end
        
        return (
            success=true,
            param_count=param_count,
            structure=model_str,
            on_gpu=on_gpu
        )
    catch e
        @warn "Failed to get model info: $e"
        return (success=false, error=e)
    end
end

"""
    get_available_devices()

Get information about available computing devices.
"""
function get_available_devices()
    try
        if !isdefined(Main, :torch)
            init_pytorch()
        end
        
        has_cuda = torch.cuda.is_available()
        
        devices = ["cpu"]
        if has_cuda
            gpu_count = torch.cuda.device_count()
            for i in 0:(gpu_count-1)
                push!(devices, "cuda:$i")
                
                # Get device properties
                props = torch.cuda.get_device_properties(i)
                @info "GPU $i: $(props.name), Memory: $(props.total_memory / 1024^3) GB"
            end
        end
        
        return (success=true, devices=devices, has_cuda=has_cuda)
    catch e
        @warn "Failed to get available devices: $e"
        return (success=false, error=e)
    end
end

# Initialize PyTorch when module is loaded
function __init__()
    @info "Initializing PyTorchBridge module"
    try
        init_result = init_pytorch()
        if init_result.initialized
            @info "PyTorch initialized successfully. CUDA available: $(init_result.has_cuda)"
        else
            @warn "PyTorch initialization failed. Some functions might not work."
        end
    catch e
        @warn "Error during PyTorchBridge initialization: $e"
    end
end

end # module 