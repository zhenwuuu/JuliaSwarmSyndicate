# Tests for the EnhancedErrors module

using JuliaOS
using JuliaOS.EnhancedErrors
using JuliaOS.TestUtils
using Test

# Test suite for EnhancedErrors module
enhanced_errors_test_suite = TestSuite(
    "EnhancedErrorsModule", 
    "Tests for the EnhancedErrors module",
    test_cases=[
        TestCase(
            "create_basic_error",
            "Test creating a basic enhanced error",
            Dict{String, Any}(
                "error_type" => "TestError",
                "message" => "Test error message",
                "code" => "TEST_ERR_001"
            ),
            Dict{String, Any}(
                "error_type" => "TestError",
                "message" => "Test error message",
                "code" => "TEST_ERR_001",
                "has_stack_trace" => true
            ),
            tags=["errors", "basic"]
        ),
        
        TestCase(
            "create_error_with_context",
            "Test creating an enhanced error with context data",
            Dict{String, Any}(
                "error_type" => "DataError",
                "message" => "Invalid data format",
                "code" => "DATA_ERR_001",
                "context" => Dict{String, Any}(
                    "field" => "username",
                    "value" => "test",
                    "allowed_values" => ["admin", "user", "guest"]
                )
            ),
            Dict{String, Any}(
                "error_type" => "DataError",
                "message" => "Invalid data format",
                "code" => "DATA_ERR_001",
                "has_context" => true,
                "context_keys" => ["field", "value", "allowed_values"]
            ),
            tags=["errors", "context"]
        ),
        
        TestCase(
            "create_error_with_cause",
            "Test creating an enhanced error with a cause",
            Dict{String, Any}(
                "error_type" => "NetworkError",
                "message" => "Failed to connect to server",
                "code" => "NET_ERR_001",
                "cause" => ArgumentError("Invalid URL format")
            ),
            Dict{String, Any}(
                "error_type" => "NetworkError",
                "message" => "Failed to connect to server",
                "code" => "NET_ERR_001",
                "has_cause" => true,
                "cause_type" => "ArgumentError"
            ),
            tags=["errors", "cause"]
        )
    ],
    property_tests=[
        PropertyTest(
            "error_preserves_all_fields",
            "Test that creating an error with arbitrary fields preserves them",
            Dict{String, Function}(
                "error_type" => () -> randstring(['A':'Z'; 'a':'z'], rand(5:15)) * "Error",
                "message" => () -> randstring(['A':'Z'; 'a':'z'; ' '], rand(10:100)),
                "code" => () -> join([randstring(['A':'Z'], rand(3:6)), 
                                     lpad(string(rand(1:999)), 3, '0')], "_"),
                "context_fields" => () -> Dict(
                    randstring(['a':'z'], rand(5:10)) => rand([
                        randstring(rand(5:20)),
                        rand(1:1000),
                        rand(Bool),
                        [randstring(rand(3:8)) for _ in 1:rand(1:5)],
                        Dict(randstring(rand(3:5)) => randstring(rand(3:8)) for _ in 1:rand(1:3))
                    ])
                    for _ in 1:rand(1:10)
                )
            ),
            (inputs) -> begin
                error_type = inputs["error_type"]
                message = inputs["message"]
                code = inputs["code"]
                context = inputs["context_fields"]
                
                # Create an enhanced error with the generated inputs
                error = EnhancedErrors.EnhancedError(
                    error_type=error_type,
                    message=message,
                    code=code,
                    context=context
                )
                
                # Verify that all fields were preserved
                result = (error.error_type == error_type &&
                         error.message == message &&
                         error.code == code)
                
                # Check that all context fields are preserved
                for (key, value) in context
                    if !haskey(error.context, key) || error.context[key] != value
                        return false
                    end
                end
                
                return result
            end,
            num_tests=50,
            tags=["errors", "property", "context"]
        )
    ],
    setup=() -> begin
        # No special setup needed for EnhancedErrors tests
    end,
    teardown=() -> begin
        # No special teardown needed for EnhancedErrors tests
    end
)

# Test the built-in error types
function test_builtin_error_types()
    # Test ValidationError
    validation_err = EnhancedErrors.ValidationError(
        "username",
        "cannot be empty", 
        Dict("min_length" => 3)
    )
    @test validation_err.error_type == "ValidationError"
    @test validation_err.message == "Validation failed: username cannot be empty"
    @test validation_err.code == "VALIDATION_ERROR"
    @test validation_err.context["field"] == "username"
    @test validation_err.context["reason"] == "cannot be empty"
    @test validation_err.context["details"]["min_length"] == 3
    
    # Test NotFoundError
    not_found_err = EnhancedErrors.NotFoundError("User", "123")
    @test not_found_err.error_type == "NotFoundError"
    @test not_found_err.message == "User with id 123 not found"
    @test not_found_err.code == "NOT_FOUND_ERROR"
    @test not_found_err.context["resource_type"] == "User"
    @test not_found_err.context["resource_id"] == "123"
    
    # Test AuthenticationError
    auth_err = EnhancedErrors.AuthenticationError("Invalid credentials")
    @test auth_err.error_type == "AuthenticationError"
    @test auth_err.message == "Authentication failed: Invalid credentials"
    @test auth_err.code == "AUTH_ERROR"
    
    # Test AuthorizationError
    authz_err = EnhancedErrors.AuthorizationError("admin", "User", "123")
    @test authz_err.error_type == "AuthorizationError"
    @test authz_err.message == "Authorization failed: Required role admin to access User 123"
    @test authz_err.code == "AUTHZ_ERROR"
    @test authz_err.context["required_role"] == "admin"
    @test authz_err.context["resource_type"] == "User"
    @test authz_err.context["resource_id"] == "123"
    
    # Test InternalError
    internal_err = EnhancedErrors.InternalError("Database connection failed", cause=ErrorException("Connection timeout"))
    @test internal_err.error_type == "InternalError"
    @test internal_err.message == "Internal error: Database connection failed"
    @test internal_err.code == "INTERNAL_ERROR"
    @test internal_err.cause isa ErrorException
end

# Test error throwing and catching
function test_error_throwing_and_catching()
    # Define a function that throws an enhanced error
    function validate_user(user)
        if !haskey(user, "username")
            throw(EnhancedErrors.ValidationError("username", "is required"))
        elseif length(user["username"]) < 3
            throw(EnhancedErrors.ValidationError("username", "too short",
                    Dict("min_length" => 3, "actual_length" => length(user["username"]))))
        end
        return true
    end
    
    # Test with missing username
    @test_throws_enhancederror "ValidationError" validate_user(Dict())
    
    # Test with too short username
    @test_throws_enhancederror "ValidationError" validate_user(Dict("username" => "a"))
    
    # Test with valid username
    @test validate_user(Dict("username" => "admin")) == true
    
    # Test catching and inspecting error details
    try
        validate_user(Dict("username" => "a"))
        @test false  # Should not reach here
    catch e
        @test e isa EnhancedErrors.EnhancedError
        @test e.error_type == "ValidationError"
        @test e.context["field"] == "username"
        @test e.context["reason"] == "too short"
        @test e.context["details"]["min_length"] == 3
        @test e.context["details"]["actual_length"] == 1
    end
end

# Test error formatting
function test_error_formatting()
    # Create an error with various fields
    error = EnhancedErrors.EnhancedError(
        error_type="TestError",
        message="Test error message",
        code="TEST_ERR_001",
        context=Dict(
            "field" => "name",
            "value" => "test",
            "nested" => Dict("key" => "value")
        ),
        cause=ArgumentError("Original error")
    )
    
    # Test default string representation
    str_repr = string(error)
    @test occursin("TestError", str_repr)
    @test occursin("Test error message", str_repr)
    @test occursin("TEST_ERR_001", str_repr)
    
    # Test JSON representation
    json_repr = EnhancedErrors.to_json(error)
    @test json_repr isa String
    @test occursin("\"error_type\":\"TestError\"", json_repr)
    @test occursin("\"code\":\"TEST_ERR_001\"", json_repr)
    @test occursin("\"field\":\"name\"", json_repr)
    
    # Test detailed representation
    detailed = EnhancedErrors.detailed_error_info(error)
    @test detailed isa Dict
    @test detailed["error_type"] == "TestError"
    @test detailed["message"] == "Test error message"
    @test detailed["code"] == "TEST_ERR_001"
    @test detailed["context"]["field"] == "name"
    @test detailed["context"]["nested"]["key"] == "value"
    @test haskey(detailed, "stack_trace")
    @test haskey(detailed, "cause")
end

# Test withcontext function for adding context to try/catch blocks
function test_with_context()
    # Define a function that will fail
    function divide_numbers(a, b)
        return a / b
    end
    
    # Test with context
    result = EnhancedErrors.with_context(
        Dict("operation" => "division", "inputs" => Dict("a" => 10, "b" => 0))
    ) do
        divide_numbers(10, 0)
    end
    
    # Check that the operation failed and returned an enhanced error
    @test result.success == false
    @test result.error isa EnhancedErrors.EnhancedError
    @test result.error.error_type == "InternalError"
    @test result.error.context["operation"] == "division"
    @test result.error.context["inputs"]["a"] == 10
    @test result.error.context["inputs"]["b"] == 0
    @test result.error.cause isa DivideError
    
    # Test successful operation
    result = EnhancedErrors.with_context(
        Dict("operation" => "division", "inputs" => Dict("a" => 10, "b" => 2))
    ) do
        divide_numbers(10, 2)
    end
    
    # Check that the operation succeeded
    @test result.success == true
    @test result.value == 5
    @test result.error === nothing
end

# Gather the tests into test suites
builtin_error_types_suite = TestSuite(
    "BuiltinErrorTypes",
    "Tests for the built-in error types",
    setup=test_builtin_error_types
)

error_handling_suite = TestSuite(
    "ErrorHandling",
    "Tests for error throwing and catching",
    setup=test_error_throwing_and_catching
)

error_formatting_suite = TestSuite(
    "ErrorFormatting",
    "Tests for error formatting functions",
    setup=test_error_formatting
)

error_context_suite = TestSuite(
    "ErrorContext",
    "Tests for the with_context function",
    setup=test_with_context
)
