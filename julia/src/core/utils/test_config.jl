using Test
using JuliaOS.Configuration

@testset "Configuration Management Tests" begin
    @testset "Configuration Loading" begin
        # Test configuration loading from file
        config = load_configuration("test_config.json")
        
        @test haskey(config, "swarm")
        @test haskey(config, "agents")
        @test haskey(config, "risk_params")
        @test haskey(config, "monitoring")
    end
    
    @testset "Configuration Validation" begin
        # Test valid configuration
        valid_config = Dict(
            "swarm" => Dict(
                "name" => "test_swarm",
                "coordination_type" => "coordinated",
                "max_agents" => 5,
                "min_agents" => 1
            ),
            "agents" => [
                Dict(
                    "type" => "arbitrage",
                    "chain" => "ethereum",
                    "strategy" => "price_arbitrage",
                    "risk_params" => Dict(
                        "max_position_size" => 0.1,
                        "min_profit_threshold" => 0.01
                    )
                )
            ],
            "risk_params" => Dict(
                "max_drawdown" => 0.15,
                "min_capital_ratio" => 0.5
            ),
            "monitoring" => Dict(
                "update_interval" => 60,
                "retention_period" => 86400
            )
        )
        
        @test validate_configuration(valid_config)
        
        # Test invalid configuration
        invalid_config = Dict(
            "swarm" => Dict(
                "name" => "",
                "coordination_type" => "invalid_type"
            )
        )
        
        @test_throws ArgumentError validate_configuration(invalid_config)
    end
    
    @testset "Configuration Templates" begin
        # Test template loading
        templates = load_configuration_templates()
        
        @test haskey(templates, "arbitrage")
        @test haskey(templates, "liquidity")
        @test haskey(templates, "risk")
        
        # Test template application
        base_config = Dict(
            "swarm" => Dict(
                "name" => "test_swarm"
            )
        )
        
        applied_config = apply_template(
            base_config,
            templates["arbitrage"]
        )
        
        @test haskey(applied_config, "agents")
        @test haskey(applied_config, "risk_params")
        @test haskey(applied_config, "monitoring")
    end
    
    @testset "Environment Variables" begin
        # Test environment variable loading
        env_config = load_environment_variables()
        
        @test haskey(env_config, "rpc_urls")
        @test haskey(env_config, "api_keys")
        @test haskey(env_config, "contract_addresses")
        
        # Test environment variable validation
        @test validate_environment_variables(env_config)
    end
    
    @testset "Configuration Merging" begin
        # Test configuration merging
        base_config = Dict(
            "swarm" => Dict(
                "name" => "test_swarm",
                "coordination_type" => "coordinated"
            )
        )
        
        override_config = Dict(
            "swarm" => Dict(
                "coordination_type" => "hierarchical"
            ),
            "risk_params" => Dict(
                "max_drawdown" => 0.2
            )
        )
        
        merged_config = merge_configurations(base_config, override_config)
        
        @test merged_config["swarm"]["name"] == "test_swarm"
        @test merged_config["swarm"]["coordination_type"] == "hierarchical"
        @test merged_config["risk_params"]["max_drawdown"] == 0.2
    end
    
    @testset "Configuration Export" begin
        # Test configuration export
        config = Dict(
            "swarm" => Dict(
                "name" => "test_swarm",
                "coordination_type" => "coordinated"
            ),
            "agents" => [
                Dict(
                    "type" => "arbitrage",
                    "chain" => "ethereum"
                )
            ]
        )
        
        export_configuration(config, "test_export.json")
        @test isfile("test_export.json")
        
        # Test exported configuration loading
        loaded_config = load_configuration("test_export.json")
        @test loaded_config["swarm"]["name"] == "test_swarm"
        @test loaded_config["swarm"]["coordination_type"] == "coordinated"
        @test length(loaded_config["agents"]) == 1
    end
    
    @testset "Configuration Versioning" begin
        # Test configuration versioning
        config = Dict(
            "version" => "1.0.0",
            "swarm" => Dict(
                "name" => "test_swarm"
            )
        )
        
        # Test version validation
        @test validate_configuration_version(config)
        
        # Test version upgrade
        upgraded_config = upgrade_configuration_version(config)
        @test upgraded_config["version"] == "1.0.1"
    end
    
    @testset "Configuration Encryption" begin
        # Test configuration encryption
        sensitive_config = Dict(
            "api_keys" => Dict(
                "alchemy" => "test_key",
                "infura" => "test_key"
            )
        )
        
        # Test encryption
        encrypted_config = encrypt_sensitive_data(sensitive_config)
        @test haskey(encrypted_config, "encrypted_data")
        @test haskey(encrypted_config, "iv")
        
        # Test decryption
        decrypted_config = decrypt_sensitive_data(encrypted_config)
        @test decrypted_config["api_keys"]["alchemy"] == "test_key"
        @test decrypted_config["api_keys"]["infura"] == "test_key"
    end
    
    @testset "Error Handling" begin
        # Test invalid file path
        @test_throws SystemError load_configuration("nonexistent.json")
        
        # Test invalid template
        @test_throws ArgumentError apply_template(
            Dict(),
            Dict("invalid" => "template")
        )
        
        # Test invalid environment variables
        @test_throws ArgumentError validate_environment_variables(Dict())
        
        # Test invalid configuration merge
        @test_throws ArgumentError merge_configurations(
            Dict("invalid" => "config"),
            Dict()
        )
        
        # Test invalid encryption
        @test_throws ArgumentError encrypt_sensitive_data(Dict())
        
        # Test invalid version
        @test_throws ArgumentError validate_configuration_version(
            Dict("version" => "invalid")
        )
    end
end 