using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Storage

function run_storage_tests()
    @testset "Storage Initialization" begin
        # Test initialization
        init_result = Storage.initialize()
        @test init_result["success"] == true
        @test haskey(init_result, "local_storage_dir")
    end
    
    @testset "Local Storage Operations" begin
        # Test saving data
        test_data = Dict(
            "name" => "Test Data",
            "value" => 42,
            "array" => [1, 2, 3],
            "nested" => Dict("key" => "value")
        )
        
        key = "test_" * string(uuid4())
        save_result = Storage.create_agent(Storage.db, key, "Test Agent", 1, test_data)
        
        @test save_result["success"] == true
        @test save_result["id"] == key
        
        # Test loading data
        load_result = Storage.get_agent(Storage.db, key)
        @test load_result["success"] == true
        @test load_result["agent"]["id"] == key
        @test load_result["agent"]["name"] == "Test Agent"
        @test load_result["agent"]["config"] == test_data
        
        # Test listing data
        list_result = Storage.list_agents(Storage.db)
        @test list_result["success"] == true
        @test key in [agent["id"] for agent in list_result["agents"]]
        
        # Test updating data
        update_data = Dict("name" => "Updated Test Agent")
        update_result = Storage.update_agent(Storage.db, key, update_data)
        @test update_result["success"] == true
        @test update_result["agent"]["name"] == "Updated Test Agent"
        
        # Test deleting data
        delete_result = Storage.delete_agent(Storage.db, key)
        @test delete_result["success"] == true
        
        # Verify deletion
        verify_result = Storage.get_agent(Storage.db, key)
        @test verify_result["success"] == false
    end
    
    @testset "Swarm Storage Operations" begin
        # Test saving swarm
        swarm_data = Dict(
            "name" => "Test Swarm",
            "algorithm" => "DE",
            "parameters" => Dict(
                "population_size" => 50,
                "max_generations" => 100
            )
        )
        
        swarm_id = "swarm_" * string(uuid4())
        save_result = Storage.create_swarm(
            Storage.db,
            swarm_id,
            swarm_data["name"],
            1,  # SwarmType.OPTIMIZATION
            swarm_data["algorithm"],
            swarm_data["parameters"]
        )
        
        @test save_result["success"] == true
        @test save_result["id"] == swarm_id
        
        # Test loading swarm
        load_result = Storage.get_swarm(Storage.db, swarm_id)
        @test load_result["success"] == true
        @test load_result["swarm"]["id"] == swarm_id
        @test load_result["swarm"]["name"] == swarm_data["name"]
        @test load_result["swarm"]["algorithm"] == swarm_data["algorithm"]
        
        # Test listing swarms
        list_result = Storage.list_swarms(Storage.db)
        @test list_result["success"] == true
        @test swarm_id in [swarm["id"] for swarm in list_result["swarms"]]
        
        # Test updating swarm
        update_data = Dict("name" => "Updated Test Swarm")
        update_result = Storage.update_swarm(Storage.db, swarm_id, update_data)
        @test update_result["success"] == true
        @test update_result["swarm"]["name"] == "Updated Test Swarm"
        
        # Test deleting swarm
        delete_result = Storage.delete_swarm(Storage.db, swarm_id)
        @test delete_result["success"] == true
        
        # Verify deletion
        verify_result = Storage.get_swarm(Storage.db, swarm_id)
        @test verify_result["success"] == false
    end
    
    @testset "Agent-Swarm Relationships" begin
        # Create test agent and swarm
        agent_id = "agent_" * string(uuid4())
        swarm_id = "swarm_" * string(uuid4())
        
        Storage.create_agent(Storage.db, agent_id, "Test Agent", 1, Dict())
        Storage.create_swarm(Storage.db, swarm_id, "Test Swarm", 1, "DE", Dict())
        
        # Add agent to swarm
        add_result = Storage.add_agent_to_swarm(Storage.db, swarm_id, agent_id)
        @test add_result["success"] == true
        
        # Get swarm agents
        agents_result = Storage.get_swarm_agents(Storage.db, swarm_id)
        @test agents_result["success"] == true
        @test agent_id in [agent["id"] for agent in agents_result["agents"]]
        
        # Remove agent from swarm
        remove_result = Storage.remove_agent_from_swarm(Storage.db, swarm_id, agent_id)
        @test remove_result["success"] == true
        
        # Verify removal
        verify_result = Storage.get_swarm_agents(Storage.db, swarm_id)
        @test verify_result["success"] == true
        @test !(agent_id in [agent["id"] for agent in verify_result["agents"]])
        
        # Clean up
        Storage.delete_agent(Storage.db, agent_id)
        Storage.delete_swarm(Storage.db, swarm_id)
    end
    
    @testset "Settings Storage" begin
        # Test saving setting
        key = "test_setting"
        value = Dict("key1" => "value1", "key2" => 42)
        
        save_result = Storage.save_setting(Storage.db, key, value)
        @test save_result["success"] == true
        
        # Test getting setting
        get_result = Storage.get_setting(Storage.db, key)
        @test get_result["success"] == true
        @test get_result["value"]["key1"] == "value1"
        @test get_result["value"]["key2"] == 42
        
        # Test getting setting with default
        missing_key = "missing_setting"
        default_value = "default"
        
        default_result = Storage.get_setting(Storage.db, missing_key, default_value)
        @test default_result["success"] == true
        @test default_result["value"] == default_value
        
        # Test listing settings
        list_result = Storage.list_settings(Storage.db)
        @test list_result["success"] == true
        @test key in [setting["key"] for setting in list_result["settings"]]
        
        # Test deleting setting
        delete_result = Storage.delete_setting(Storage.db, key)
        @test delete_result["success"] == true
        
        # Verify deletion
        verify_result = Storage.get_setting(Storage.db, key)
        @test verify_result["success"] == false
    end
    
    @testset "Database Operations" begin
        # Test database backup
        backup_result = Storage.backup_database(Storage.db)
        @test backup_result["success"] == true
        @test haskey(backup_result, "backup_path")
        @test isfile(backup_result["backup_path"])
        
        # Test database vacuum
        vacuum_result = Storage.vacuum_database(Storage.db)
        @test vacuum_result["success"] == true
    end
end
