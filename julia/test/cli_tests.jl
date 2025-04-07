using Test
using JuliaOS
using JuliaOS.CLI
using JuliaOS.CLI.Interactive
using JuliaOS.Config
using JuliaOS.SwarmManager
using JuliaOS.MarketData
using JuliaOS.Bridge
using TestUtils
using Dates

@testset "CLI Tests" begin
    @testset "Command Completion" begin
        # Test command completion
        completions = Interactive.get_command_completions("br")
        @test "bridge" in completions
        
        completions = Interactive.get_command_completions("sw")
        @test "swarm" in completions
        
        completions = Interactive.get_command_completions("ma")
        @test "market" in completions
        
        # Test invalid command completion
        completions = Interactive.get_command_completions("invalid")
        @test isempty(completions)
    end

    @testset "Input Validation" begin
        # Test float validation
        valid, _ = Interactive.validate_input("0.5", :float, min=0.0, max=1.0)
        @test valid
        
        valid, _ = Interactive.validate_input("1.5", :float, min=0.0, max=1.0)
        @test !valid
        
        # Test integer validation
        valid, _ = Interactive.validate_input("10", :int, min=1, max=100)
        @test valid
        
        valid, _ = Interactive.validate_input("0", :int, min=1, max=100)
        @test !valid
        
        # Test address validation
        valid, _ = Interactive.validate_input(
            "0x1234567890123456789012345678901234567890",
            :address
        )
        @test valid
        
        valid, _ = Interactive.validate_input("invalid_address", :address)
        @test !valid
        
        # Test date validation
        valid, _ = Interactive.validate_input(
            string(Dates.now()),
            :date
        )
        @test valid
        
        valid, _ = Interactive.validate_input("invalid_date", :date)
        @test !valid
    end

    @testset "Command Handling" begin
        # Test valid command handling
        result = Interactive.handle_command("bridge status")
        @test result !== nothing
        
        result = Interactive.handle_command("swarm create test_swarm")
        @test result !== nothing
        
        result = Interactive.handle_command("market data ETH/USDC")
        @test result !== nothing
        
        # Test invalid command handling
        @test_throws ArgumentError Interactive.handle_command("invalid command")
        @test_throws ArgumentError Interactive.handle_command("bridge")
        @test_throws ArgumentError Interactive.handle_command("swarm")
    end

    @testset "Interactive Mode" begin
        # Test interactive mode initialization
        mode = Interactive.start_interactive_mode()
        @test mode !== nothing
        
        # Test menu display
        menu = Interactive.display_menu()
        @test menu !== nothing
        @test haskey(menu, "options")
        @test haskey(menu, "commands")
        
        # Test command execution
        result = Interactive.execute_command("help")
        @test result !== nothing
        
        result = Interactive.execute_command("exit")
        @test result === nothing
    end

    @testset "Progress Display" begin
        # Test progress bar creation
        progress = Interactive.create_progress_bar("Test Progress", 100)
        @test progress !== nothing
        @test progress.total == 100
        @test progress.current == 0
        
        # Test progress bar update
        Interactive.update_progress(progress, 50)
        @test progress.current == 50
        
        # Test progress bar completion
        Interactive.complete_progress(progress)
        @test progress.current == progress.total
    end

    @testset "Status Display" begin
        # Test status box creation
        status = Interactive.create_status_box(
            "Test Status",
            "Running",
            "green"
        )
        @test status !== nothing
        @test status.title == "Test Status"
        @test status.message == "Running"
        @test status.color == "green"
        
        # Test status box update
        Interactive.update_status(status, "Completed", "blue")
        @test status.message == "Completed"
        @test status.color == "blue"
    end

    @testset "Error Handling" begin
        # Test command error handling
        @test_throws ArgumentError Interactive.handle_command("")
        @test_throws ArgumentError Interactive.handle_command(" ")
        @test_throws ArgumentError Interactive.handle_command("invalid")
        
        # Test input validation error handling
        @test_throws ArgumentError Interactive.validate_input("", :float)
        @test_throws ArgumentError Interactive.validate_input("", :int)
        @test_throws ArgumentError Interactive.validate_input("", :address)
        @test_throws ArgumentError Interactive.validate_input("", :date)
        
        # Test progress bar error handling
        @test_throws ArgumentError Interactive.create_progress_bar("", -1)
        @test_throws ArgumentError Interactive.update_progress(nothing, 50)
        
        # Test status box error handling
        @test_throws ArgumentError Interactive.create_status_box("", "", "invalid_color")
        @test_throws ArgumentError Interactive.update_status(nothing, "message", "color")
    end

    @testset "Configuration Management" begin
        # Test configuration loading
        config = Interactive.load_config()
        @test config !== nothing
        @test config isa Config.JuliaOSConfig
        
        # Test configuration saving
        success = Interactive.save_config(config)
        @test success
        
        # Test configuration validation
        valid, errors = Interactive.validate_config(config)
        @test valid
        @test isempty(errors)
        
        # Test invalid configuration
        invalid_config = Dict()
        valid, errors = Interactive.validate_config(invalid_config)
        @test !valid
        @test !isempty(errors)
    end

    @testset "Help System" begin
        # Test help command
        help_text = Interactive.show_help()
        @test help_text !== nothing
        @test !isempty(help_text)
        
        # Test command-specific help
        command_help = Interactive.show_command_help("bridge")
        @test command_help !== nothing
        @test !isempty(command_help)
        
        # Test invalid command help
        @test_throws ArgumentError Interactive.show_command_help("invalid")
    end
end 