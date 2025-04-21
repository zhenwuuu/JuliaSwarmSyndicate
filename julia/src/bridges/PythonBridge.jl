module PythonBridge

export initialize, execute_command, check_health

using Logging
using Dates
using JSON
using ..Types
using ..Errors
using ..Utils
using ..Bridge

# Global configuration
global_config = nothing

"""
    initialize(config)

Initialize the Python bridge with the given configuration.
"""
function initialize(config)
    global global_config = config
    
    @info "Initializing Python bridge"
    
    # Register command handlers
    Bridge.register_command_handler("python.execute", execute_command_handler)
    
    @info "Python bridge initialized"
end

"""
    execute_command(command::String, params::Dict)

Execute a command from Python.
"""
function execute_command(command::String, params::Dict)
    @info "Executing command from Python: $command"
    
    # Run the command through the Bridge module
    result = Bridge.run_command(Dict(
        "command" => command,
        "params" => params,
        "id" => Utils.generate_id()
    ))
    
    return result
end

"""
    execute_command_handler(params::Dict)

Handle a command execution request from Python.
"""
function execute_command_handler(params::Dict)
    Utils.validate_required_fields(params, ["command", "params"])
    
    command = params["command"]
    command_params = params["params"]
    
    # Run the command through the Bridge module
    result = Bridge.run_command(Dict(
        "command" => command,
        "params" => command_params,
        "id" => Utils.generate_id()
    ))
    
    return result
end

"""
    check_health()

Check the health of the Python bridge.
"""
function check_health()
    return Dict(
        "status" => "healthy",
        "timestamp" => string(now())
    )
end

end # module
