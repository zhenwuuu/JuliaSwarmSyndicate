# Tests for the EnhancedConfig module

using JuliaOS
using JuliaOS.EnhancedConfig
using JuliaOS.TestUtils
using Test

# Test suite for EnhancedConfig module
enhanced_config_test_suite = TestSuite(
    "EnhancedConfigModule", 
    "Tests for the EnhancedConfig module",
    test_cases=[
        TestCase(
            "load_config_defaults",
            "Test that load_config correctly applies defaults",
            Dict{String, Any}(
                "config" => Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost"
                    )
                ),
                "schema" => EnhancedConfig.ConfigSchema(
                    name = "test",
                    required = [],
                    types = Dict{String, Any}(
                        "server.host" => String,
                        "server.port" => Int
                    ),
                    defaults = Dict{String, Any}(
                        "server.port" => 8080
                    ),
                    validators = Dict()
                )
            ),
            Dict{String, Any}(
                "server" => Dict{String, Any}(
                    "host" => "localhost",
                    "port" => 8080
                )
            ),
            tags=["config", "defaults"]
        ),
        
        TestCase(
            "config_validation_success",
            "Test that config validation passes for valid config",
            Dict{String, Any}(
                "config" => Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost",
                        "port" => 9000
                    ),
                    "logging" => Dict{String, Any}(
                        "level" => "info"
                    )
                ),
                "schema" => EnhancedConfig.ConfigSchema(
                    name = "test",
                    required = ["logging.level"],
                    types = Dict{String, Any}(
                        "server.host" => String,
                        "server.port" => Int,
                        "logging.level" => String
                    ),
                    defaults = Dict{String, Any}(),
                    validators = Dict(
                        "server.port" => port -> port > 1024 && port < 65535
                    )
                )
            ),
            true,
            tags=["config", "validation", "success"]
        ),
        
        TestCase(
            "config_validation_failure_missing_required",
            "Test that config validation fails when required field is missing",
            Dict{String, Any}(
                "config" => Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost",
                        "port" => 9000
                    )
                ),
                "schema" => EnhancedConfig.ConfigSchema(
                    name = "test",
                    required = ["logging.level"],
                    types = Dict{String, Any}(
                        "server.host" => String,
                        "server.port" => Int,
                        "logging.level" => String
                    ),
                    defaults = Dict{String, Any}(),
                    validators = Dict()
                )
            ),
            false,
            tags=["config", "validation", "failure"]
        ),
        
        TestCase(
            "config_validation_failure_wrong_type",
            "Test that config validation fails when field has wrong type",
            Dict{String, Any}(
                "config" => Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost",
                        "port" => "9000" # String instead of Int
                    ),
                    "logging" => Dict{String, Any}(
                        "level" => "info"
                    )
                ),
                "schema" => EnhancedConfig.ConfigSchema(
                    name = "test",
                    required = ["logging.level"],
                    types = Dict{String, Any}(
                        "server.host" => String,
                        "server.port" => Int,
                        "logging.level" => String
                    ),
                    defaults = Dict{String, Any}(),
                    validators = Dict()
                )
            ),
            false,
            tags=["config", "validation", "failure"]
        ),
        
        TestCase(
            "config_validation_failure_validator",
            "Test that config validation fails when validator fails",
            Dict{String, Any}(
                "config" => Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost",
                        "port" => 80 # Below allowed range
                    ),
                    "logging" => Dict{String, Any}(
                        "level" => "info"
                    )
                ),
                "schema" => EnhancedConfig.ConfigSchema(
                    name = "test",
                    required = ["logging.level"],
                    types = Dict{String, Any}(
                        "server.host" => String,
                        "server.port" => Int,
                        "logging.level" => String
                    ),
                    defaults = Dict{String, Any}(),
                    validators = Dict(
                        "server.port" => port -> port > 1024 && port < 65535
                    )
                )
            ),
            false,
            tags=["config", "validation", "failure"]
        )
    ],
    property_tests=[
        PropertyTest(
            "get_value_always_returns_default_for_missing",
            "Test that get_value always returns the default for missing paths",
            Dict{String, Function}(
                "config" => () -> Dict{String, Any}(
                    "server" => Dict{String, Any}(
                        "host" => "localhost",
                        "port" => rand(1025:65534)
                    ),
                    "logging" => Dict{String, Any}(
                        "level" => rand(["info", "debug", "warn", "error"])
                    )
                ),
                "path" => () -> "nonexistent.path.$(randstring(5))",
                "default_value" => () -> rand([
                    "default", 
                    123, 
                    true, 
                    ["array", "values"], 
                    Dict("key" => "value")
                ])
            ),
            (inputs) -> begin
                config = inputs["config"]
                path = inputs["path"]
                default_value = inputs["default_value"]
                
                # Load the configuration
                EnhancedConfig.load_config(EnhancedConfig.DictConfigSource(config))
                
                # Get the value with default
                result = EnhancedConfig.get_value(path, default_value)
                
                # Should always return the default for a nonexistent path
                return result == default_value
            end,
            num_tests=30,
            tags=["config", "property", "get_value"]
        )
    ],
    setup=() -> begin
        # Setup for the tests - create a clean environment
        EnhancedConfig.reset()
    end,
    teardown=() -> begin
        # Teardown - reset config to avoid affecting other tests
        EnhancedConfig.reset()
    end
)

# Test the ConfigSource implementations
function test_dict_config_source()
    # Test with a simple dictionary
    config = Dict{String, Any}(
        "server" => Dict{String, Any}(
            "host" => "localhost",
            "port" => 8080
        ),
        "logging" => Dict{String, Any}(
            "level" => "info"
        )
    )
    
    source = EnhancedConfig.DictConfigSource(config)
    
    # Test getting existing values
    @test source.get_value("server.host") == "localhost"
    @test source.get_value("server.port") == 8080
    @test source.get_value("logging.level") == "info"
    
    # Test getting non-existent values
    @test source.get_value("nonexistent") === nothing
    @test source.get_value("server.nonexistent") === nothing
    
    # Test setting values
    @test source.set_value("server.host", "127.0.0.1") == true
    @test source.get_value("server.host") == "127.0.0.1"
    
    # Test setting nested values that don't exist yet
    @test source.set_value("database.url", "postgresql://localhost/db") == true
    @test source.get_value("database.url") == "postgresql://localhost/db"
    
    # Test the raw_config method
    raw_config = source.raw_config()
    @test isa(raw_config, Dict)
    @test raw_config["server"]["host"] == "127.0.0.1"
    @test raw_config["database"]["url"] == "postgresql://localhost/db"
end

# Test the ConfigSchema validation
function test_config_schema_validation()
    # Create a schema with various constraints
    schema = EnhancedConfig.ConfigSchema(
        name = "test_schema",
        required = ["logging.level", "server.host"],
        types = Dict{String, Any}(
            "server.host" => String,
            "server.port" => Int,
            "logging.level" => String,
            "max_connections" => Int
        ),
        defaults = Dict{String, Any}(
            "server.port" => 8080,
            "max_connections" => 100
        ),
        validators = Dict(
            "server.port" => port -> port > 1024 && port < 65535,
            "max_connections" => conn -> conn > 0
        )
    )
    
    # Valid config
    valid_config = Dict{String, Any}(
        "server" => Dict{String, Any}(
            "host" => "localhost",
            "port" => 8080
        ),
        "logging" => Dict{String, Any}(
            "level" => "info"
        )
    )
    
    # Test validation success
    @test EnhancedConfig.validate_config(valid_config, schema) == true
    
    # Test with missing required field
    missing_required = Dict{String, Any}(
        "server" => Dict{String, Any}(
            "host" => "localhost"
        )
    )
    @test EnhancedConfig.validate_config(missing_required, schema) == false
    
    # Test with wrong type
    wrong_type = Dict{String, Any}(
        "server" => Dict{String, Any}(
            "host" => "localhost",
            "port" => "8080" # String instead of Int
        ),
        "logging" => Dict{String, Any}(
            "level" => "info"
        )
    )
    @test EnhancedConfig.validate_config(wrong_type, schema) == false
    
    # Test with failed validator
    failed_validator = Dict{String, Any}(
        "server" => Dict{String, Any}(
            "host" => "localhost",
            "port" => 80 # Below allowed range
        ),
        "logging" => Dict{String, Any}(
            "level" => "info"
        )
    )
    @test EnhancedConfig.validate_config(failed_validator, schema) == false
end

# Test the config reload mechanism
function test_config_hot_reload()
    @with_mocks begin
        # Create mock config source with auto-reload
        config_data = Dict{String, Any}(
            "server" => Dict{String, Any}(
                "host" => "localhost",
                "port" => 8080
            )
        )
        
        source = EnhancedConfig.DictConfigSource(config_data)
        source.auto_reload = true
        
        # Create a mock watcher function
        watcher_called = 0
        watcher_old_value = nothing
        watcher_new_value = nothing
        
        watcher = (new_config, old_config) -> begin
            watcher_called += 1
            watcher_old_value = old_config
            watcher_new_value = new_config
        end
        
        # Load the config and register the watcher
        EnhancedConfig.load_config(source)
        EnhancedConfig.register_config_listener(watcher)
        
        # Initial state
        @test EnhancedConfig.get_value("server.port") == 8080
        @test watcher_called == 0
        
        # Simulate an external change to the config source
        config_data["server"]["port"] = 9000
        
        # Signal that the config has changed
        EnhancedConfig.notify_config_changed(source)
        
        # Test that the config was reloaded and the watcher was called
        @test EnhancedConfig.get_value("server.port") == 9000
        @test watcher_called == 1
        @test watcher_old_value["server"]["port"] == 8080
        @test watcher_new_value["server"]["port"] == 9000
    end
end

# Create the generated test suite with additional test cases
generated_config_test_suite = test_config_schema_validation()
