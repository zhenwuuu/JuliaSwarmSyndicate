module Validation

export validate_input, ValidationRule, RequiredRule, TypeRule, PatternRule, RangeRule, LengthRule
export CustomRule, OneOfRule, AllOfRule, AnyOfRule, NotRule, compose_rules
export ValidationError, ValidationResult

using ..EnhancedErrors
using ..StructuredLogging

"""
    ValidationRule

Abstract type for all validation rules.
"""
abstract type ValidationRule end

"""
    ValidationResult

Structure representing the result of validation.
"""
struct ValidationResult
    valid::Bool
    errors::Vector{String}
    
    ValidationResult(valid::Bool, errors::Vector{String}=String[]) = new(valid, errors)
end

"""
    RequiredRule <: ValidationRule

Validation rule that checks if a value is present (not nothing and not empty).
"""
struct RequiredRule <: ValidationRule
    message::String
    
    RequiredRule(message::String="Value is required") = new(message)
end

"""
    TypeRule <: ValidationRule

Validation rule that checks if a value is of a specific type.
"""
struct TypeRule <: ValidationRule
    type::Type
    message::String
    
    TypeRule(type::Type, message::String="Value must be of type $type") = new(type, message)
end

"""
    PatternRule <: ValidationRule

Validation rule that checks if a string value matches a regex pattern.
"""
struct PatternRule <: ValidationRule
    pattern::Regex
    message::String
    
    PatternRule(pattern::Regex, message::String="Value must match pattern $pattern") = new(pattern, message)
end

"""
    RangeRule <: ValidationRule

Validation rule that checks if a numeric value is within a range.
"""
struct RangeRule <: ValidationRule
    min::Union{Number, Nothing}
    max::Union{Number, Nothing}
    message::String
    
    function RangeRule(; min::Union{Number, Nothing}=nothing, max::Union{Number, Nothing}=nothing, 
                       message::String="Value must be in range")
        if min === nothing && max === nothing
            throw(ArgumentError("At least one of min or max must be specified"))
        end
        
        msg = if min !== nothing && max !== nothing
            "Value must be between $min and $max"
        elseif min !== nothing
            "Value must be greater than or equal to $min"
        else
            "Value must be less than or equal to $max"
        end
        
        message = message == "Value must be in range" ? msg : message
        
        return new(min, max, message)
    end
end

"""
    LengthRule <: ValidationRule

Validation rule that checks if a collection has a length within a range.
"""
struct LengthRule <: ValidationRule
    min::Union{Int, Nothing}
    max::Union{Int, Nothing}
    message::String
    
    function LengthRule(; min::Union{Int, Nothing}=nothing, max::Union{Int, Nothing}=nothing, 
                        message::String="Length must be in range")
        if min === nothing && max === nothing
            throw(ArgumentError("At least one of min or max must be specified"))
        end
        
        msg = if min !== nothing && max !== nothing
            "Length must be between $min and $max"
        elseif min !== nothing
            "Length must be at least $min"
        else
            "Length must be at most $max"
        end
        
        message = message == "Length must be in range" ? msg : message
        
        return new(min, max, message)
    end
end

"""
    CustomRule <: ValidationRule

Validation rule that uses a custom function for validation.
"""
struct CustomRule <: ValidationRule
    validator::Function
    message::String
    
    CustomRule(validator::Function, message::String="Validation failed") = new(validator, message)
end

"""
    OneOfRule <: ValidationRule

Validation rule that checks if a value is one of the allowed values.
"""
struct OneOfRule <: ValidationRule
    allowed::Vector{Any}
    message::String
    
    OneOfRule(allowed::Vector{Any}, message::String="Value must be one of $(allowed)") = new(allowed, message)
end

"""
    AllOfRule <: ValidationRule

Validation rule that checks if a value passes all of the given rules.
"""
struct AllOfRule <: ValidationRule
    rules::Vector{ValidationRule}
    message::String
    
    AllOfRule(rules::Vector{ValidationRule}, message::String="Value must satisfy all rules") = new(rules, message)
end

"""
    AnyOfRule <: ValidationRule

Validation rule that checks if a value passes any of the given rules.
"""
struct AnyOfRule <: ValidationRule
    rules::Vector{ValidationRule}
    message::String
    
    AnyOfRule(rules::Vector{ValidationRule}, message::String="Value must satisfy at least one rule") = new(rules, message)
end

"""
    NotRule <: ValidationRule

Validation rule that negates another rule.
"""
struct NotRule <: ValidationRule
    rule::ValidationRule
    message::String
    
    NotRule(rule::ValidationRule, message::String="Value must not satisfy the rule") = new(rule, message)
end

"""
    compose_rules(rules::ValidationRule...; all::Bool=true)

Compose multiple validation rules into a single rule.
If all is true, all rules must pass (AllOfRule).
If all is false, at least one rule must pass (AnyOfRule).
"""
function compose_rules(rules::ValidationRule...; all::Bool=true)
    rules_vec = collect(rules)
    return all ? AllOfRule(rules_vec, "All rules must pass") : AnyOfRule(rules_vec, "At least one rule must pass")
end

"""
    validate_rule(value, rule::RequiredRule)

Validate a value against a RequiredRule.
"""
function validate_rule(value, rule::RequiredRule)
    if value === nothing || (isa(value, AbstractString) && isempty(value)) || 
       (isa(value, AbstractArray) && isempty(value)) || (isa(value, AbstractDict) && isempty(value))
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::TypeRule)

Validate a value against a TypeRule.
"""
function validate_rule(value, rule::TypeRule)
    if value === nothing || !isa(value, rule.type)
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::PatternRule)

Validate a value against a PatternRule.
"""
function validate_rule(value, rule::PatternRule)
    if value === nothing || !isa(value, AbstractString) || !occursin(rule.pattern, value)
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::RangeRule)

Validate a value against a RangeRule.
"""
function validate_rule(value, rule::RangeRule)
    if value === nothing || !isa(value, Number) ||
       (rule.min !== nothing && value < rule.min) ||
       (rule.max !== nothing && value > rule.max)
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::LengthRule)

Validate a value against a LengthRule.
"""
function validate_rule(value, rule::LengthRule)
    if value === nothing || 
       !(isa(value, AbstractString) || isa(value, AbstractArray) || isa(value, AbstractDict)) ||
       (rule.min !== nothing && length(value) < rule.min) ||
       (rule.max !== nothing && length(value) > rule.max)
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::CustomRule)

Validate a value against a CustomRule.
"""
function validate_rule(value, rule::CustomRule)
    try
        if !rule.validator(value)
            return ValidationResult(false, [rule.message])
        end
    catch e
        return ValidationResult(false, ["Validator error: $e"])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::OneOfRule)

Validate a value against a OneOfRule.
"""
function validate_rule(value, rule::OneOfRule)
    if value === nothing || !(value in rule.allowed)
        return ValidationResult(false, [rule.message])
    end
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::AllOfRule)

Validate a value against an AllOfRule.
"""
function validate_rule(value, rule::AllOfRule)
    errors = String[]
    
    for subrule in rule.rules
        result = validate_rule(value, subrule)
        if !result.valid
            append!(errors, result.errors)
        end
    end
    
    if !isempty(errors)
        return ValidationResult(false, unique(errors))
    end
    
    return ValidationResult(true)
end

"""
    validate_rule(value, rule::AnyOfRule)

Validate a value against an AnyOfRule.
"""
function validate_rule(value, rule::AnyOfRule)
    all_errors = String[]
    
    for subrule in rule.rules
        result = validate_rule(value, subrule)
        if result.valid
            return ValidationResult(true)
        end
        append!(all_errors, result.errors)
    end
    
    # If we get here, no rule passed
    return ValidationResult(false, [rule.message, unique(all_errors)...])
end

"""
    validate_rule(value, rule::NotRule)

Validate a value against a NotRule.
"""
function validate_rule(value, rule::NotRule)
    result = validate_rule(value, rule.rule)
    return ValidationResult(!result.valid, result.valid ? [rule.message] : String[])
end

"""
    validate_input(value, rule::ValidationRule)

Validate an input value against a validation rule.
Returns true if validation passes, throws a ValidationError otherwise.
"""
function validate_input(value, rule::ValidationRule; field::Union{String, Nothing}=nothing)
    context = EnhancedErrors.with_error_context("Validation", "validate_input", 
                                               metadata=Dict("field" => field))
    
    result = validate_rule(value, rule)
    if result.valid
        return true
    else
        if isempty(result.errors)
            errors = ["Validation failed"]
        else
            errors = result.errors
        end
        
        # Log the validation failure
        if field !== nothing
            StructuredLogging.warn("Validation failed for field '$field'", 
                                  data=Dict("errors" => errors, "field" => field, "value" => value))
        else
            StructuredLogging.warn("Validation failed", 
                                  data=Dict("errors" => errors, "value" => value))
        end
        
        # Throw a ValidationError
        EnhancedErrors.try_operation(context) do
            if field !== nothing
                throw(EnhancedErrors.ValidationError(join(errors, "; "), field, context=context))
            else
                throw(EnhancedErrors.ValidationError(join(errors, "; "), context=context))
            end
        end
    end
end

"""
    validate_input(data::Dict, field::String, rule::ValidationRule)

Validate a field in a dictionary against a validation rule.
Returns true if validation passes, throws a ValidationError otherwise.
"""
function validate_input(data::Dict, field::String, rule::ValidationRule)
    if !haskey(data, field)
        if isa(rule, RequiredRule)
            context = EnhancedErrors.with_error_context("Validation", "validate_input", 
                                                       metadata=Dict("field" => field))
            
            StructuredLogging.warn("Missing required field", 
                                  data=Dict("field" => field))
            
            EnhancedErrors.try_operation(context) do
                throw(EnhancedErrors.ValidationError("Missing required field: $field", field, context=context))
            end
        end
        return true
    end
    
    return validate_input(data[field], rule; field=field)
end

"""
    validate_input(data::Dict, validations::Dict{String, ValidationRule})

Validate multiple fields in a dictionary against validation rules.
Returns true if all validations pass, throws a ValidationError otherwise.
"""
function validate_input(data::Dict, validations::Dict{String, ValidationRule})
    all_errors = Dict{String, Vector{String}}()
    
    # First pass: collect all errors without throwing
    for (field, rule) in validations
        try
            validate_input(data, field, rule)
        catch e
            if e isa EnhancedErrors.ValidationError
                all_errors[field] = [e.message]
            else
                all_errors[field] = ["Unexpected error: $(e)"]
            end
        end
    end
    
    # If there are errors, throw a ValidationError with all of them
    if !isempty(all_errors)
        context = EnhancedErrors.with_error_context("Validation", "validate_input", 
                                                   metadata=Dict("fields" => collect(keys(all_errors))))
        
        error_messages = String[]
        for (field, errors) in all_errors
            append!(error_messages, ["$field: $error" for error in errors])
        end
        
        message = join(error_messages, "; ")
        
        StructuredLogging.warn("Multiple validation errors", 
                              data=Dict("errors" => all_errors))
        
        EnhancedErrors.try_operation(context) do
            throw(EnhancedErrors.ValidationError(message, context=context))
        end
    end
    
    return true
end

end # module
