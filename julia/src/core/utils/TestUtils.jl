module TestUtils

export setup_test_environment, teardown_test_environment
export generate_test_cases, run_property_tests
export create_mock, with_mock, verify_mock_calls
export TestCase, PropertyTest, TestSuite, TestResult
export @test_throws_enhancederror, @with_mocks, @verify_called
export measure_coverage, generate_coverage_report

using ..EnhancedErrors
using ..StructuredLogging
using ..Utils
using ..Metrics
using ..Config
using ..EnhancedConfig
using ..Validation

using Test
using Random
using Dates
using Coverage
using DataStructures
using Distributed

"""
    TestCase

Represents a single test case with expected inputs and outputs.
"""
struct TestCase
    name::String
    description::String
    input::Dict{String, Any}
    expected_output::Any
    tags::Vector{String}
    setup::Union{Function, Nothing}
    teardown::Union{Function, Nothing}
    
    function TestCase(name::String, description::String, input::Dict{String, Any}, expected_output;
                     tags::Vector{String}=String[], 
                     setup::Union{Function, Nothing}=nothing,
                     teardown::Union{Function, Nothing}=nothing)
        return new(name, description, input, expected_output, tags, setup, teardown)
    end
end

"""
    PropertyTest

Represents a property-based test with generators and property function.
"""
struct PropertyTest
    name::String
    description::String
    generators::Dict{String, Function}
    property_function::Function
    num_tests::Int
    tags::Vector{String}
    
    function PropertyTest(name::String, description::String, 
                         generators::Dict{String, Function},
                         property_function::Function;
                         num_tests::Int=100,
                         tags::Vector{String}=String[])
        return new(name, description, generators, property_function, num_tests, tags)
    end
end

"""
    TestSuite

Represents a collection of test cases and property tests.
"""
struct TestSuite
    name::String
    description::String
    test_cases::Vector{TestCase}
    property_tests::Vector{PropertyTest}
    setup::Union{Function, Nothing}
    teardown::Union{Function, Nothing}
    
    function TestSuite(name::String, description::String;
                      test_cases::Vector{TestCase}=TestCase[],
                      property_tests::Vector{PropertyTest}=PropertyTest[],
                      setup::Union{Function, Nothing}=nothing,
                      teardown::Union{Function, Nothing}=nothing)
        return new(name, description, test_cases, property_tests, setup, teardown)
    end
end

"""
    TestResult

Represents the result of running a test.
"""
struct TestResult
    test_name::String
    passed::Bool
    execution_time_ms::Float64
    memory_used_bytes::Int64
    error_info::Union{Dict{String, Any}, Nothing}
    output::Vector{String}
    
    function TestResult(test_name::String, passed::Bool;
                       execution_time_ms::Float64=0.0,
                       memory_used_bytes::Int64=0,
                       error_info::Union{Dict{String, Any}, Nothing}=nothing,
                       output::Vector{String}=String[])
        return new(test_name, passed, execution_time_ms, memory_used_bytes, error_info, output)
    end
end

# Mock functionality
"""
    MockFunction

Represents a mocked function with recorded calls and behavior.
"""
mutable struct MockFunction
    original_function::Union{Function, Nothing}
    calls::Vector{Dict{String, Any}}
    return_values::Vector{Any}
    error_to_throw::Union{Exception, Nothing}
    call_original::Bool
    
    function MockFunction(; original_function::Union{Function, Nothing}=nothing,
                         return_values::Vector{Any}=Any[],
                         error_to_throw::Union{Exception, Nothing}=nothing,
                         call_original::Bool=false)
        return new(original_function, Dict{String, Any}[], return_values, error_to_throw, call_original)
    end
end

"""
    MockObject

Represents a collection of mocked functions.
"""
mutable struct MockObject
    name::String
    functions::Dict{Symbol, MockFunction}
    
    function MockObject(name::String)
        return new(name, Dict{Symbol, MockFunction}())
    end
end

# Global storage for mocks
const ACTIVE_MOCKS = Dict{Symbol, MockObject}()

"""
    create_mock(name::Symbol, functions::Dict{Symbol, Any})

Create a mock object with the specified functions.

# Arguments
- `name::Symbol`: Name of the mock object
- `functions::Dict{Symbol, Any}`: Dictionary mapping function names to return values or functions

# Returns
- `MockObject`: The created mock object
"""
function create_mock(name::Symbol, functions::Dict{Symbol, Any})
    mock = MockObject(string(name))
    
    for (func_name, behavior) in functions
        if isa(behavior, Function)
            # If behavior is a function, use it to determine the return value
            mock.functions[func_name] = MockFunction(original_function=behavior, call_original=true)
        elseif isa(behavior, Exception)
            # If behavior is an exception, throw it when the function is called
            mock.functions[func_name] = MockFunction(error_to_throw=behavior)
        elseif isa(behavior, Vector) && !isempty(behavior) && all(b -> isa(b, Exception) || !isa(b, Function), behavior)
            # If behavior is a vector of values (not all functions), return them in sequence
            mock.functions[func_name] = MockFunction(return_values=behavior)
        else
            # Otherwise, just return the value
            mock.functions[func_name] = MockFunction(return_values=[behavior])
        end
    end
    
    ACTIVE_MOCKS[name] = mock
    return mock
end

"""
    with_mock(name::Symbol, func::Symbol, args...; kwargs...)

Call a mocked function with the given arguments.

# Arguments
- `name::Symbol`: Name of the mock object
- `func::Symbol`: Name of the mocked function
- `args...`: Arguments to pass to the function
- `kwargs...`: Keyword arguments to pass to the function

# Returns
- The return value of the mocked function
"""
function with_mock(name::Symbol, func::Symbol, args...; kwargs...)
    if !haskey(ACTIVE_MOCKS, name) || !haskey(ACTIVE_MOCKS[name].functions, func)
        error("No mock found for $(name).$(func)")
    end
    
    mock_func = ACTIVE_MOCKS[name].functions[func]
    
    # Record the call
    call_record = Dict{String, Any}(
        "timestamp" => now(),
        "args" => collect(args),
        "kwargs" => Dict(kwargs)
    )
    push!(mock_func.calls, call_record)
    
    # Check if we should throw an error
    if mock_func.error_to_throw !== nothing
        throw(mock_func.error_to_throw)
    end
    
    # Handle the return value
    if !isempty(mock_func.return_values)
        if length(mock_func.return_values) == 1
            # Always return the same value
            return mock_func.return_values[1]
        else
            # Return values in sequence, cycling if needed
            call_index = length(mock_func.calls)
            return_index = ((call_index - 1) % length(mock_func.return_values)) + 1
            return mock_func.return_values[return_index]
        end
    elseif mock_func.call_original && mock_func.original_function !== nothing
        # Call the original function
        return mock_func.original_function(args...; kwargs...)
    else
        # Default return value is nothing
        return nothing
    end
end

"""
    verify_mock_calls(name::Symbol, func::Symbol; min_calls::Union{Int, Nothing}=nothing, max_calls::Union{Int, Nothing}=nothing, args_matchers::Vector{Function}=Function[])

Verify that a mocked function was called as expected.

# Arguments
- `name::Symbol`: Name of the mock object
- `func::Symbol`: Name of the mocked function
- `min_calls::Union{Int, Nothing}=nothing`: Minimum number of expected calls, or nothing for no minimum
- `max_calls::Union{Int, Nothing}=nothing`: Maximum number of expected calls, or nothing for no maximum
- `args_matchers::Vector{Function}=Function[]`: Functions to match against the arguments of each call

# Returns
- `Bool`: Whether the verification passed
"""
function verify_mock_calls(name::Symbol, func::Symbol; 
                          min_calls::Union{Int, Nothing}=nothing, 
                          max_calls::Union{Int, Nothing}=nothing,
                          args_matchers::Vector{Function}=Function[])
    
    if !haskey(ACTIVE_MOCKS, name) || !haskey(ACTIVE_MOCKS[name].functions, func)
        @warn "No mock found for $(name).$(func)"
        return false
    end
    
    mock_func = ACTIVE_MOCKS[name].functions[func]
    calls = mock_func.calls
    
    # Check min_calls
    if min_calls !== nothing && length(calls) < min_calls
        @warn "Expected at least $(min_calls) calls to $(name).$(func), but got $(length(calls))"
        return false
    end
    
    # Check max_calls
    if max_calls !== nothing && length(calls) > max_calls
        @warn "Expected at most $(max_calls) calls to $(name).$(func), but got $(length(calls))"
        return false
    end
    
    # Check args_matchers
    if !isempty(args_matchers)
        for (i, call) in enumerate(calls)
            call_args = call["args"]
            for (j, matcher) in enumerate(args_matchers)
                if j <= length(call_args) && !matcher(call_args[j])
                    @warn "Argument $(j) of call $(i) to $(name).$(func) did not match"
                    return false
                end
            end
        end
    end
    
    return true
end

"""
    @with_mocks(expr)

Execute code with mock objects, automatically cleaning up after execution.

# Arguments
- `expr`: The code to execute with mocks

# Returns
- The result of executing the expression
"""
macro with_mocks(expr)
    return quote
        # Save existing mocks
        old_mocks = deepcopy(ACTIVE_MOCKS)
        
        try
            # Execute the expression
            $(esc(expr))
        finally
            # Restore original mocks
            global ACTIVE_MOCKS = old_mocks
        end
    end
end

"""
    @verify_called(mock_expr, min_calls, max_calls)

Verify that a mocked function was called a certain number of times.

# Arguments
- `mock_expr`: Expression of the form `module_name.function_name`
- `min_calls`: Minimum number of expected calls, or nothing for no minimum
- `max_calls`: Maximum number of expected calls, or nothing for no maximum

# Returns
- `Bool`: Whether the verification passed
"""
macro verify_called(mock_expr, min_calls=nothing, max_calls=nothing)
    if isa(mock_expr, Expr) && mock_expr.head == :.
        module_name = mock_expr.args[1]
        function_name = QuoteNode(mock_expr.args[2].value)
        
        return quote
            verify_mock_calls($(QuoteNode(module_name)), $(function_name),
                             min_calls=$(esc(min_calls)),
                             max_calls=$(esc(max_calls)))
        end
    else
        error("Expected mock expression of the form module_name.function_name")
    end
end

"""
    @test_throws_enhancederror(error_type, expr)

Test that an expression throws an EnhancedError of the specified type.

# Arguments
- `error_type`: The expected error type
- `expr`: The expression to evaluate

# Returns
- `Bool`: Whether the test passed
"""
macro test_throws_enhancederror(error_type, expr)
    return quote
        local test_passed = false
        local caught_error = nothing
        
        try
            $(esc(expr))
        catch e
            caught_error = e
            if isa(e, EnhancedErrors.EnhancedError) && e.error_type == $(esc(error_type))
                test_passed = true
            end
        end
        
        if !test_passed
            error("Expected EnhancedError of type $($(esc(error_type))), but got: $(caught_error)")
        end
        
        test_passed
    end
end

"""
    setup_test_environment()

Set up the environment for testing.

# Returns
- `Dict{String, Any}`: The test environment configuration
"""
function setup_test_environment()
    # Create a test configuration
    test_config = Dict{String, Any}(
        "environment" => "test",
        "logging" => Dict{String, Any}(
            "level" => "info",
            "format" => "json",
            "output" => "test.log"
        ),
        "storage" => Dict{String, Any}(
            "adapter" => "memory"
        ),
        "blockchain" => Dict{String, Any}(
            "provider" => "mock"
        ),
        "auth" => Dict{String, Any}(
            "jwt_secret" => "test_secret",
            "token_expiry" => 3600
        )
    )
    
    # Configure logging for tests
    StructuredLogging.configure_logging(
        min_level="warn",  # Reduce log noise during tests
        format="text"
    )
    
    # Initialize metrics with test prefix
    Metrics.initialize(prefix="test_")
    
    # Initialize configuration
    EnhancedConfig.load_config(EnhancedConfig.DictConfigSource(test_config))
    
    # Reset any active mocks
    empty!(ACTIVE_MOCKS)
    
    # Return the test environment for reference
    return test_config
end

"""
    teardown_test_environment()

Clean up after tests.
"""
function teardown_test_environment()
    # Reset metrics
    Metrics.reset()
    
    # Reset configuration
    EnhancedConfig.reset()
    
    # Reset mocks
    empty!(ACTIVE_MOCKS)
    
    # Reset logging
    StructuredLogging.configure_logging(
        min_level="info",
        format="text"
    )
    
    # Perform garbage collection
    GC.gc()
end

"""
    generate_test_cases(input_space::Dict{String, Vector}, 
                       output_function::Function;
                       sample_size::Union{Int, Nothing}=nothing,
                       coverage::Symbol=:full)

Generate test cases from an input space.

# Arguments
- `input_space::Dict{String, Vector}`: Dictionary mapping parameter names to possible values
- `output_function::Function`: Function to calculate expected output for inputs
- `sample_size::Union{Int, Nothing}=nothing`: Number of test cases to generate, or nothing for all combinations
- `coverage::Symbol=:full`: Coverage strategy (:full, :pairwise, :random)

# Returns
- `Vector{TestCase}`: Generated test cases
"""
function generate_test_cases(input_space::Dict{String, Vector}, 
                            output_function::Function;
                            sample_size::Union{Int, Nothing}=nothing,
                            coverage::Symbol=:full)
    
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="generate_test_cases",
        data=Dict(
            "input_space_size" => Dict(k => length(v) for (k, v) in input_space),
            "coverage" => coverage,
            "sample_size" => sample_size
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        # Calculate the total number of combinations
        total_combinations = prod(length(values) for values in values(input_space))
        
        StructuredLogging.debug("Generating test cases", 
                               data=Dict("total_combinations" => total_combinations))
        
        test_cases = TestCase[]
        
        if coverage == :full
            # Generate all combinations
            parameter_names = collect(keys(input_space))
            parameter_values = [input_space[name] for name in parameter_names]
            
            # Generate all combinations of parameter values
            for values in Iterators.product(parameter_values...)
                input = Dict(zip(parameter_names, values))
                
                # Calculate expected output
                expected_output = output_function(input)
                
                # Create a test case
                test_case = TestCase(
                    "Generated test: $(input)",
                    "Automatically generated test case",
                    input,
                    expected_output
                )
                
                push!(test_cases, test_case)
                
                # Break if we've reached the sample size
                if sample_size !== nothing && length(test_cases) >= sample_size
                    break
                end
            end
        elseif coverage == :pairwise
            # Pairwise testing (all pairs of parameter values)
            parameter_names = collect(keys(input_space))
            
            # For each pair of parameters
            for i in 1:length(parameter_names)
                for j in (i+1):length(parameter_names)
                    param1 = parameter_names[i]
                    param2 = parameter_names[j]
                    
                    # For each combination of values for this pair
                    for val1 in input_space[param1]
                        for val2 in input_space[param2]
                            # Create a baseline input with random values for other parameters
                            input = Dict{String, Any}()
                            for param in parameter_names
                                if param != param1 && param != param2
                                    input[param] = rand(input_space[param])
                                end
                            end
                            
                            # Set the values for the current pair
                            input[param1] = val1
                            input[param2] = val2
                            
                            # Calculate expected output
                            expected_output = output_function(input)
                            
                            # Create a test case
                            test_case = TestCase(
                                "Generated pairwise test: $(param1)=$(val1), $(param2)=$(val2)",
                                "Automatically generated pairwise test case",
                                input,
                                expected_output
                            )
                            
                            push!(test_cases, test_case)
                            
                            # Break if we've reached the sample size
                            if sample_size !== nothing && length(test_cases) >= sample_size
                                break
                            end
                        end
                        
                        if sample_size !== nothing && length(test_cases) >= sample_size
                            break
                        end
                    end
                    
                    if sample_size !== nothing && length(test_cases) >= sample_size
                        break
                    end
                end
                
                if sample_size !== nothing && length(test_cases) >= sample_size
                    break
                end
            end
        elseif coverage == :random
            # Random sampling of the input space
            parameter_names = collect(keys(input_space))
            
            # Determine how many random samples to generate
            num_samples = sample_size !== nothing ? sample_size : min(100, total_combinations)
            
            for _ in 1:num_samples
                # Generate a random input
                input = Dict(param => rand(input_space[param]) for param in parameter_names)
                
                # Calculate expected output
                expected_output = output_function(input)
                
                # Create a test case
                test_case = TestCase(
                    "Generated random test: $(input)",
                    "Automatically generated random test case",
                    input,
                    expected_output
                )
                
                push!(test_cases, test_case)
            end
        else
            error("Unknown coverage strategy: $(coverage)")
        end
        
        StructuredLogging.info("Generated test cases", 
                              data=Dict(
                                  "strategy" => coverage,
                                  "count" => length(test_cases)
                              ))
        
        return test_cases
    end
end

"""
    run_property_tests(test::PropertyTest)

Run a property-based test.

# Arguments
- `test::PropertyTest`: The property test to run

# Returns
- `TestResult`: The result of the property test
"""
function run_property_tests(test::PropertyTest)
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="run_property_tests",
        data=Dict(
            "test_name" => test.name,
            "num_tests" => test.num_tests
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        # Output buffer for capturing test output
        output = String[]
        
        # Track execution time and memory
        start_time = time()
        start_memory = Sys.total_memory() - Sys.free_memory()
        
        passed = true
        error_info = nothing
        failed_inputs = Dict{String, Any}[]
        
        try
            for i in 1:test.num_tests
                # Generate inputs for this test
                inputs = Dict{String, Any}()
                for (param_name, generator) in test.generators
                    inputs[param_name] = generator()
                end
                
                # Run the property function
                property_result = test.property_function(inputs)
                
                # Check if the property holds
                if !property_result
                    passed = false
                    push!(failed_inputs, inputs)
                    push!(output, "Property failed for inputs: $(inputs)")
                    
                    # Only keep a limited number of failed inputs
                    if length(failed_inputs) >= 10
                        push!(output, "Too many failures, stopping test")
                        break
                    end
                end
            end
            
            if passed
                push!(output, "All $(test.num_tests) tests passed")
            else
                push!(output, "Failed $(length(failed_inputs)) out of $(test.num_tests) tests")
                error_info = Dict{String, Any}(
                    "failed_inputs" => failed_inputs
                )
            end
        catch e
            passed = false
            error_info = Dict{String, Any}(
                "exception" => string(e),
                "stacktrace" => string(catch_stacktrace())
            )
            push!(output, "Exception: $(e)")
            push!(output, "$(stacktrace())")
        end
        
        # Calculate execution time and memory usage
        execution_time_ms = (time() - start_time) * 1000
        end_memory = Sys.total_memory() - Sys.free_memory()
        memory_used_bytes = max(0, end_memory - start_memory)
        
        return TestResult(
            test.name,
            passed,
            execution_time_ms=execution_time_ms,
            memory_used_bytes=memory_used_bytes,
            error_info=error_info,
            output=output
        )
    end
end

"""
    run_test_suite(suite::TestSuite; filter_tags::Vector{String}=String[])

Run a test suite and return the results.

# Arguments
- `suite::TestSuite`: The test suite to run
- `filter_tags::Vector{String}=String[]`: Optional tags to filter tests by

# Returns
- `Dict{String, Any}`: The test suite results
"""
function run_test_suite(suite::TestSuite; filter_tags::Vector{String}=String[])
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="run_test_suite",
        data=Dict(
            "suite_name" => suite.name,
            "test_cases" => length(suite.test_cases),
            "property_tests" => length(suite.property_tests),
            "filter_tags" => filter_tags
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        results = Dict{String, Any}(
            "name" => suite.name,
            "description" => suite.description,
            "start_time" => now(),
            "end_time" => nothing,
            "duration_ms" => 0.0,
            "passed" => true,
            "test_results" => Dict{String, TestResult}(),
            "summary" => Dict{String, Any}()
        )
        
        # Filter test cases by tags
        test_cases = suite.test_cases
        property_tests = suite.property_tests
        
        if !isempty(filter_tags)
            test_cases = filter(tc -> any(tag -> tag in filter_tags, tc.tags), test_cases)
            property_tests = filter(pt -> any(tag -> tag in filter_tags, pt.tags), property_tests)
        end
        
        # Run setup if provided
        if suite.setup !== nothing
            try
                suite.setup()
            catch e
                StructuredLogging.error("Test suite setup failed", 
                                      exception=e,
                                      data=Dict("suite" => suite.name))
                
                results["passed"] = false
                results["error"] = Dict{String, Any}(
                    "message" => "Suite setup failed: $(e)",
                    "stacktrace" => string(stacktrace())
                )
                
                results["end_time"] = now()
                results["duration_ms"] = 0.0
                
                return results
            end
        end
        
        # Track suite execution time
        suite_start_time = time()
        
        # Run test cases
        for test_case in test_cases
            # Run test case setup if provided
            if test_case.setup !== nothing
                try
                    test_case.setup()
                catch e
                    StructuredLogging.error("Test case setup failed", 
                                          exception=e,
                                          data=Dict(
                                              "suite" => suite.name,
                                              "test_case" => test_case.name
                                          ))
                    
                    results["test_results"][test_case.name] = TestResult(
                        test_case.name,
                        false,
                        error_info=Dict{String, Any}(
                            "message" => "Test case setup failed: $(e)",
                            "stacktrace" => string(stacktrace())
                        ),
                        output=["Test case setup failed: $(e)"]
                    )
                    
                    results["passed"] = false
                    continue
                end
            end
            
            # Track test case execution time and memory
            test_start_time = time()
            test_start_memory = Sys.total_memory() - Sys.free_memory()
            
            # Run the test case
            test_output = String[]
            test_passed = false
            test_error_info = nothing
            
            try
                # Run the test function with the input
                actual_output = test_case.input  # Placeholder for actual test function call
                
                # Compare actual output with expected output
                if actual_output == test_case.expected_output
                    test_passed = true
                    push!(test_output, "Test passed")
                else
                    test_passed = false
                    push!(test_output, "Test failed: expected $(test_case.expected_output) but got $(actual_output)")
                    test_error_info = Dict{String, Any}(
                        "expected" => test_case.expected_output,
                        "actual" => actual_output
                    )
                end
            catch e
                test_passed = false
                test_error_info = Dict{String, Any}(
                    "exception" => string(e),
                    "stacktrace" => string(catch_stacktrace())
                )
                push!(test_output, "Exception: $(e)")
                push!(test_output, "$(stacktrace())")
            end
            
            # Calculate execution time and memory usage
            test_execution_time_ms = (time() - test_start_time) * 1000
            test_end_memory = Sys.total_memory() - Sys.free_memory()
            test_memory_used_bytes = max(0, test_end_memory - test_start_memory)
            
            # Create test result
            results["test_results"][test_case.name] = TestResult(
                test_case.name,
                test_passed,
                execution_time_ms=test_execution_time_ms,
                memory_used_bytes=test_memory_used_bytes,
                error_info=test_error_info,
                output=test_output
            )
            
            # Update suite pass/fail status
            if !test_passed
                results["passed"] = false
            end
            
            # Run test case teardown if provided
            if test_case.teardown !== nothing
                try
                    test_case.teardown()
                catch e
                    StructuredLogging.error("Test case teardown failed", 
                                          exception=e,
                                          data=Dict(
                                              "suite" => suite.name,
                                              "test_case" => test_case.name
                                          ))
                    
                    push!(results["test_results"][test_case.name].output, "Test case teardown failed: $(e)")
                end
            end
        end
        
        # Run property tests
        for property_test in property_tests
            property_result = run_property_tests(property_test)
            results["test_results"][property_test.name] = property_result
            
            # Update suite pass/fail status
            if !property_result.passed
                results["passed"] = false
            end
        end
        
        # Calculate suite execution time
        suite_execution_time_ms = (time() - suite_start_time) * 1000
        
        # Update suite results
        results["end_time"] = now()
        results["duration_ms"] = suite_execution_time_ms
        
        # Generate summary
        total_tests = length(results["test_results"])
        passed_tests = count(result -> result.passed, values(results["test_results"]))
        failed_tests = total_tests - passed_tests
        
        results["summary"] = Dict{String, Any}(
            "total_tests" => total_tests,
            "passed_tests" => passed_tests,
            "failed_tests" => failed_tests,
            "pass_rate" => total_tests > 0 ? passed_tests / total_tests : 0.0
        )
        
        # Run teardown if provided
        if suite.teardown !== nothing
            try
                suite.teardown()
            catch e
                StructuredLogging.error("Test suite teardown failed", 
                                      exception=e,
                                      data=Dict("suite" => suite.name))
                
                results["teardown_error"] = Dict{String, Any}(
                    "message" => "Suite teardown failed: $(e)",
                    "stacktrace" => string(stacktrace())
                )
            end
        end
        
        return results
    end
end

"""
    measure_coverage(dir::String; exclude_patterns::Vector{String}=String[])

Measure code coverage for Julia files in a directory.

# Arguments
- `dir::String`: The directory to measure coverage for
- `exclude_patterns::Vector{String}=String[]`: Patterns to exclude from coverage

# Returns
- `Dict{String, Any}`: The coverage results
"""
function measure_coverage(dir::String; exclude_patterns::Vector{String}=String[])
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="measure_coverage",
        data=Dict(
            "dir" => dir,
            "exclude_patterns" => exclude_patterns
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        # Check if directory exists
        if !isdir(dir)
            StructuredLogging.error("Directory not found", data=Dict("dir" => dir))
            return Dict{String, Any}(
                "error" => "Directory not found: $(dir)"
            )
        end
        
        # Process coverage data
        coverage = Coverage.process_folder(dir)
        
        # Filter out excluded files
        if !isempty(exclude_patterns)
            coverage = filter(c -> !any(pattern -> occursin(pattern, c.filename), exclude_patterns), coverage)
        end
        
        # Calculate coverage statistics
        total_lines = 0
        covered_lines = 0
        uncovered_lines = 0
        
        file_coverage = Dict{String, Dict{String, Any}}()
        
        for file_coverage_data in coverage
            filename = file_coverage_data.filename
            file_total_lines = length(file_coverage_data.coverage)
            file_covered_lines = count(c -> c !== nothing && c > 0, file_coverage_data.coverage)
            file_uncovered_lines = count(c -> c !== nothing && c == 0, file_coverage_data.coverage)
            file_coverage_percentage = file_total_lines > 0 ? file_covered_lines / file_total_lines : 0.0
            
            total_lines += file_total_lines
            covered_lines += file_covered_lines
            uncovered_lines += file_uncovered_lines
            
            # Collect uncovered line numbers
            uncovered_line_numbers = findall(c -> c !== nothing && c == 0, file_coverage_data.coverage)
            
            # Store file coverage data
            file_coverage[filename] = Dict{String, Any}(
                "total_lines" => file_total_lines,
                "covered_lines" => file_covered_lines,
                "uncovered_lines" => file_uncovered_lines,
                "coverage_percentage" => file_coverage_percentage,
                "uncovered_line_numbers" => uncovered_line_numbers
            )
        end
        
        # Calculate overall coverage percentage
        overall_coverage_percentage = total_lines > 0 ? covered_lines / total_lines : 0.0
        
        # Sort files by coverage percentage (ascending)
        sorted_files = sort(collect(keys(file_coverage)), by=fn -> file_coverage[fn]["coverage_percentage"])
        
        return Dict{String, Any}(
            "total_lines" => total_lines,
            "covered_lines" => covered_lines,
            "uncovered_lines" => uncovered_lines,
            "coverage_percentage" => overall_coverage_percentage,
            "file_coverage" => file_coverage,
            "sorted_files" => sorted_files
        )
    end
end

"""
    generate_coverage_report(coverage_data::Dict{String, Any}, output_dir::String)

Generate a coverage report from coverage data.

# Arguments
- `coverage_data::Dict{String, Any}`: The coverage data from measure_coverage
- `output_dir::String`: The directory to write the report to

# Returns
- `String`: The path to the generated report
"""
function generate_coverage_report(coverage_data::Dict{String, Any}, output_dir::String)
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="generate_coverage_report",
        data=Dict(
            "output_dir" => output_dir
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        # Check if output directory exists
        if !isdir(output_dir)
            mkpath(output_dir)
        end
        
        # Generate HTML report
        report_path = joinpath(output_dir, "coverage_report.html")
        
        open(report_path, "w") do io
            # Write HTML header
            write(io, """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>JuliaOS Coverage Report</title>
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        line-height: 1.6;
                        max-width: 1200px;
                        margin: 0 auto;
                        padding: 20px;
                    }
                    h1, h2, h3 {
                        color: #333;
                    }
                    table {
                        border-collapse: collapse;
                        width: 100%;
                        margin-bottom: 20px;
                    }
                    th, td {
                        border: 1px solid #ddd;
                        padding: 8px;
                        text-align: left;
                    }
                    th {
                        background-color: #f2f2f2;
                    }
                    tr:nth-child(even) {
                        background-color: #f9f9f9;
                    }
                    .progress-bar {
                        width: 100%;
                        background-color: #e0e0e0;
                        border-radius: 3px;
                    }
                    .progress {
                        height: 20px;
                        border-radius: 3px;
                        background-color: #4CAF50;
                        text-align: center;
                        line-height: 20px;
                        color: white;
                    }
                    .warning {
                        background-color: #ff9800;
                    }
                    .danger {
                        background-color: #f44336;
                    }
                    .summary {
                        display: flex;
                        justify-content: space-between;
                        margin-bottom: 20px;
                    }
                    .summary-box {
                        flex: 1;
                        margin: 10px;
                        padding: 15px;
                        background-color: #f2f2f2;
                        border-radius: 5px;
                        text-align: center;
                    }
                </style>
            </head>
            <body>
                <h1>JuliaOS Coverage Report</h1>
                <div class="summary">
                    <div class="summary-box">
                        <h3>Total Lines</h3>
                        <p>$(coverage_data["total_lines"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Covered Lines</h3>
                        <p>$(coverage_data["covered_lines"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Uncovered Lines</h3>
                        <p>$(coverage_data["uncovered_lines"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Coverage</h3>
                        <p>$(round(coverage_data["coverage_percentage"] * 100, digits=2))%</p>
                    </div>
                </div>
                
                <h2>Coverage by File</h2>
                <table>
                    <tr>
                        <th>File</th>
                        <th>Coverage</th>
                        <th>Covered/Total Lines</th>
                    </tr>
            """)
            
            # Write file coverage data
            for filename in coverage_data["sorted_files"]
                file_data = coverage_data["file_coverage"][filename]
                coverage_pct = file_data["coverage_percentage"] * 100
                
                # Determine bar color based on coverage
                bar_class = coverage_pct >= 80.0 ? "" : (coverage_pct >= 50.0 ? "warning" : "danger")
                
                write(io, """
                <tr>
                    <td>$(filename)</td>
                    <td>
                        <div class="progress-bar">
                            <div class="progress $(bar_class)" style="width: $(min(100, round(coverage_pct, digits=1)))%">
                                $(round(coverage_pct, digits=2))%
                            </div>
                        </div>
                    </td>
                    <td>$(file_data["covered_lines"])/$(file_data["total_lines"])</td>
                </tr>
                """)
            end
            
            # Write HTML footer
            write(io, """
                </table>
                
                <h2>Files with Low Coverage (< 50%)</h2>
                <table>
                    <tr>
                        <th>File</th>
                        <th>Coverage</th>
                        <th>Uncovered Lines</th>
                    </tr>
            """)
            
            # Write files with low coverage
            low_coverage_files = filter(fn -> coverage_data["file_coverage"][fn]["coverage_percentage"] < 0.5, coverage_data["sorted_files"])
            
            if isempty(low_coverage_files)
                write(io, """
                <tr>
                    <td colspan="3">No files with low coverage!</td>
                </tr>
                """)
            else
                for filename in low_coverage_files
                    file_data = coverage_data["file_coverage"][filename]
                    coverage_pct = file_data["coverage_percentage"] * 100
                    uncovered_lines = join(file_data["uncovered_line_numbers"][1:min(10, length(file_data["uncovered_line_numbers"]))], ", ")
                    
                    if length(file_data["uncovered_line_numbers"]) > 10
                        uncovered_lines *= ", ..."
                    end
                    
                    write(io, """
                    <tr>
                        <td>$(filename)</td>
                        <td>$(round(coverage_pct, digits=2))%</td>
                        <td>$(uncovered_lines)</td>
                    </tr>
                    """)
                end
            end
            
            # Finish HTML
            write(io, """
                </table>
                
                <p>Report generated at $(now())</p>
            </body>
            </html>
            """)
        end
        
        return report_path
    end
end

"""
    generate_test_report(test_results::Dict{String, Any}, output_dir::String)

Generate a test report from test results.

# Arguments
- `test_results::Dict{String, Any}`: The test results
- `output_dir::String`: The directory to write the report to

# Returns
- `String`: The path to the generated report
"""
function generate_test_report(test_results::Dict{String, Any}, output_dir::String)
    log_context = StructuredLogging.LogContext(
        component="TestUtils",
        operation="generate_test_report",
        data=Dict(
            "output_dir" => output_dir
        )
    )
    
    return StructuredLogging.with_context(log_context) do
        # Check if output directory exists
        if !isdir(output_dir)
            mkpath(output_dir)
        end
        
        # Generate HTML report
        report_path = joinpath(output_dir, "test_report.html")
        
        open(report_path, "w") do io
            # Write HTML header
            write(io, """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>JuliaOS Test Report</title>
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        line-height: 1.6;
                        max-width: 1200px;
                        margin: 0 auto;
                        padding: 20px;
                    }
                    h1, h2, h3 {
                        color: #333;
                    }
                    table {
                        border-collapse: collapse;
                        width: 100%;
                        margin-bottom: 20px;
                    }
                    th, td {
                        border: 1px solid #ddd;
                        padding: 8px;
                        text-align: left;
                    }
                    th {
                        background-color: #f2f2f2;
                    }
                    tr:nth-child(even) {
                        background-color: #f9f9f9;
                    }
                    .passed {
                        color: green;
                    }
                    .failed {
                        color: red;
                    }
                    .summary {
                        display: flex;
                        justify-content: space-between;
                        margin-bottom: 20px;
                    }
                    .summary-box {
                        flex: 1;
                        margin: 10px;
                        padding: 15px;
                        background-color: #f2f2f2;
                        border-radius: 5px;
                        text-align: center;
                    }
                    .test-details {
                        margin-top: 10px;
                        padding: 10px;
                        background-color: #f9f9f9;
                        border-radius: 5px;
                        display: none;
                    }
                    .test-details pre {
                        white-space: pre-wrap;
                        word-wrap: break-word;
                    }
                    .show-details {
                        cursor: pointer;
                        color: blue;
                        text-decoration: underline;
                    }
                </style>
                <script>
                    function toggleDetails(id) {
                        var details = document.getElementById(id);
                        if (details.style.display === "none" || details.style.display === "") {
                            details.style.display = "block";
                        } else {
                            details.style.display = "none";
                        }
                    }
                </script>
            </head>
            <body>
                <h1>JuliaOS Test Report</h1>
                <div class="summary">
                    <div class="summary-box">
                        <h3>Total Tests</h3>
                        <p>$(test_results["summary"]["total_tests"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Passed Tests</h3>
                        <p class="passed">$(test_results["summary"]["passed_tests"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Failed Tests</h3>
                        <p class="failed">$(test_results["summary"]["failed_tests"])</p>
                    </div>
                    <div class="summary-box">
                        <h3>Pass Rate</h3>
                        <p>$(round(test_results["summary"]["pass_rate"] * 100, digits=2))%</p>
                    </div>
                </div>
                
                <h2>Test Results</h2>
                <table>
                    <tr>
                        <th>Test</th>
                        <th>Status</th>
                        <th>Duration (ms)</th>
                        <th>Memory (KB)</th>
                        <th>Details</th>
                    </tr>
            """)
            
            # Write test results
            test_count = 0
            for (test_name, result) in test_results["test_results"]
                test_count += 1
                status_class = result.passed ? "passed" : "failed"
                status_text = result.passed ? "Passed" : "Failed"
                memory_kb = round(Int, result.memory_used_bytes / 1024)
                
                write(io, """
                <tr>
                    <td>$(test_name)</td>
                    <td class="$(status_class)">$(status_text)</td>
                    <td>$(round(result.execution_time_ms, digits=2))</td>
                    <td>$(memory_kb)</td>
                    <td><span class="show-details" onclick="toggleDetails('test-$(test_count)')">Show details</span></td>
                </tr>
                <tr>
                    <td colspan="5">
                        <div id="test-$(test_count)" class="test-details">
                            <pre>$(join(result.output, "\n"))</pre>
                            $(if result.error_info !== nothing
                                """<h4>Error Information</h4>
                                <pre>$(result.error_info)</pre>"""
                            else
                                ""
                            end)
                        </div>
                    </td>
                </tr>
                """)
            end
            
            # Write HTML footer
            write(io, """
                </table>
                
                <h2>Test Duration</h2>
                <p>Start Time: $(test_results["start_time"])</p>
                <p>End Time: $(test_results["end_time"])</p>
                <p>Total Duration: $(round(test_results["duration_ms"], digits=2)) ms</p>
                
                <p>Report generated at $(now())</p>
            </body>
            </html>
            """)
        end
        
        return report_path
    end
end

end # module
