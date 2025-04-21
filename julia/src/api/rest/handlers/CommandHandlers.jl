module CommandHandlers

export handle_command_with_logging, validate_command_params

using ..EnhancedErrors
using ..StructuredLogging
using ..Validation
using ..Utils
using Dates

"""
    handle_command_with_logging(handler_func, command_name, params)

Execute a command handler with proper error handling and logging.
This function wraps command handlers to provide standardized:
1. Context-aware logging (entry and exit)
2. Performance tracking
3. Error handling with detailed logging
4. Parameter validation (if validation rules are provided)
"""
function handle_command_with_logging(handler_func, command_name, params; 
                                    validations=nothing, 
                                    operation_name=nothing,
                                    component="API")
    # Set up error context and logging context
    error_context = EnhancedErrors.with_error_context("API", command_name, 
                                                     metadata=Dict("params" => params))
    
    log_context = StructuredLogging.LogContext(
        component=component,
        operation=operation_name === nothing ? command_name : operation_name,
        request_id=string(UUIDs.uuid4()),
        metadata=Dict("command" => command_name)
    )
    
    # Execute with proper logging
    return StructuredLogging.with_context(log_context) do
        # Log command entry
        StructuredLogging.info("Executing command", 
                              data=Dict("command" => command_name, 
                                       "params" => params))
        
        # Start performance tracking
        start_time = now()
        
        # Execute the command with validation and error handling
        try
            # Validate parameters if validation rules provided
            if validations !== nothing
                validate_command_params(params, validations)
            end
            
            # Execute the handler function
            result = EnhancedErrors.try_operation(error_context) do
                handler_func(params)
            end
            
            # Calculate execution time
            execution_time_ms = Dates.value(now() - start_time)
            
            # Log command success
            StructuredLogging.info("Command executed successfully", 
                                  data=Dict("command" => command_name,
                                           "execution_time_ms" => execution_time_ms))
            
            return result
        catch e
            # Calculate execution time
            execution_time_ms = Dates.value(now() - start_time)
            
            # Log the error with context
            StructuredLogging.error("Command execution failed", 
                                   data=Dict("command" => command_name,
                                            "execution_time_ms" => execution_time_ms,
                                            "error_type" => string(typeof(e))),
                                   exception=e)
            
            # Re-throw as an enhanced error
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to execute command: $command_name", e, 
                                                      context=error_context))
                end
            end
        end
    end
end

"""
    validate_command_params(params, validations)

Validate command parameters against validation rules.
"""
function validate_command_params(params, validations)
    # If validations is a Dict mapping parameter names to validation rules
    if validations isa Dict
        Validation.validate_input(params, validations)
    # If validations is a function that returns a Dict of validation rules
    elseif validations isa Function
        validation_rules = validations(params)
        Validation.validate_input(params, validation_rules)
    else
        throw(ArgumentError("Unsupported validation type: $(typeof(validations))"))
    end
end

# Validation rule generators for common parameter types

"""
    required_string(field_name)

Create validation rules for a required string parameter.
"""
function required_string(field_name)
    return Validation.compose_rules(
        Validation.RequiredRule("$field_name is required"),
        Validation.TypeRule(String, "$field_name must be a string")
    )
end

"""
    required_id(field_name)

Create validation rules for a required ID parameter.
"""
function required_id(field_name)
    return Validation.compose_rules(
        Validation.RequiredRule("$field_name is required"),
        Validation.TypeRule(String, "$field_name must be a string"),
        Validation.PatternRule(r"^[a-zA-Z0-9\-_]+$", "$field_name must contain only alphanumeric characters, hyphens, and underscores")
    )
end

"""
    required_number(field_name; min=nothing, max=nothing)

Create validation rules for a required numeric parameter.
"""
function required_number(field_name; min=nothing, max=nothing)
    rules = [
        Validation.RequiredRule("$field_name is required"),
        Validation.TypeRule(Number, "$field_name must be a number")
    ]
    
    if min !== nothing || max !== nothing
        push!(rules, Validation.RangeRule(min=min, max=max))
    end
    
    return Validation.compose_rules(rules...)
end

"""
    optional_string(field_name)

Create validation rules for an optional string parameter.
"""
function optional_string(field_name)
    return Validation.TypeRule(String, "$field_name must be a string")
end

"""
    optional_number(field_name; min=nothing, max=nothing)

Create validation rules for an optional numeric parameter.
"""
function optional_number(field_name; min=nothing, max=nothing)
    rules = [
        Validation.TypeRule(Number, "$field_name must be a number")
    ]
    
    if min !== nothing || max !== nothing
        push!(rules, Validation.RangeRule(min=min, max=max))
    end
    
    return Validation.compose_rules(rules...)
end

"""
    required_array(field_name; min_length=nothing, max_length=nothing)

Create validation rules for a required array parameter.
"""
function required_array(field_name; min_length=nothing, max_length=nothing)
    rules = [
        Validation.RequiredRule("$field_name is required"),
        Validation.TypeRule(Array, "$field_name must be an array")
    ]
    
    if min_length !== nothing || max_length !== nothing
        push!(rules, Validation.LengthRule(min=min_length, max=max_length))
    end
    
    return Validation.compose_rules(rules...)
end

"""
    required_dict(field_name; required_keys=nothing)

Create validation rules for a required dictionary parameter.
"""
function required_dict(field_name; required_keys=nothing)
    rules = [
        Validation.RequiredRule("$field_name is required"),
        Validation.TypeRule(Dict, "$field_name must be a dictionary")
    ]
    
    # Add custom validator for required keys if specified
    if required_keys !== nothing && !isempty(required_keys)
        custom_validator = (dict) -> begin
            for key in required_keys
                if !haskey(dict, key)
                    return false
                end
            end
            return true
        end
        
        push!(rules, Validation.CustomRule(
            custom_validator,
            "$field_name must contain the following keys: $(join(required_keys, ", "))"
        ))
    end
    
    return Validation.compose_rules(rules...)
end

"""
    one_of(field_name, allowed_values)

Create validation rules for a parameter that must be one of a set of allowed values.
"""
function one_of(field_name, allowed_values)
    return Validation.OneOfRule(allowed_values, "$field_name must be one of: $(join(allowed_values, ", "))")
end

end # module
