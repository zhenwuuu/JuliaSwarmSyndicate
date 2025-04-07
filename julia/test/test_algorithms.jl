using Test
using JuliaOS
using JuliaOS.SwarmManager
using JuliaOS.SwarmManager.Algorithms
using Random
using Dates

# Set a fixed seed for reproducibility
Random.seed!(42)

@testset "Swarm Intelligence Algorithms" begin
    # Define a simple test function (sphere function - easy to minimize)
    function sphere(x)
        return sum(x.^2)
    end

    # Test dimensions and bounds
    dimension = 3
    bounds = [(i==1 ? (-5.0, 5.0) : (-5.0, 5.0)) for i in 1:dimension]
    swarm_size = 20
    iterations = 20
    
    # Expected range for results (algorithms should be able to get close to global minimum at 0)
    max_expected_fitness = 0.1
    
    @testset "PSO Algorithm" begin
        # Create and initialize PSO
        pso_params = Dict("inertia_weight" => 0.7, "cognitive_coef" => 1.5, "social_coef" => 1.5)
        pso = create_algorithm("pso", pso_params)
        initialize!(pso, swarm_size, dimension, bounds)
        
        # Run iterations
        for i in 1:iterations
            update_positions!(pso, sphere)
        end
        
        # Test results
        @test get_best_fitness(pso) isa Float64
        @test get_best_position(pso) isa Vector{Float64}
        @test length(get_best_position(pso)) == dimension
        @test get_best_fitness(pso) < max_expected_fitness
        @test get_convergence_data(pso) isa Vector{Float64}
        @test length(get_convergence_data(pso)) == iterations
    end
    
    @testset "GWO Algorithm" begin
        # Create and initialize GWO
        gwo_params = Dict("alpha_param" => 2.0, "decay_rate" => 0.01)
        gwo = create_algorithm("gwo", gwo_params)
        initialize!(gwo, swarm_size, dimension, bounds)
        
        # Run iterations
        for i in 1:iterations
            update_positions!(gwo, sphere)
        end
        
        # Test results
        @test get_best_fitness(gwo) isa Float64
        @test get_best_position(gwo) isa Vector{Float64}
        @test length(get_best_position(gwo)) == dimension
        @test get_best_fitness(gwo) < max_expected_fitness
        @test get_convergence_data(gwo) isa Vector{Float64}
        @test length(get_convergence_data(gwo)) == iterations
    end
    
    @testset "WOA Algorithm" begin
        # Create and initialize WOA
        woa_params = Dict("a_decrease_factor" => 2.0, "spiral_constant" => 1.0)
        woa = create_algorithm("woa", woa_params)
        initialize!(woa, swarm_size, dimension, bounds)
        
        # Run iterations
        for i in 1:iterations
            update_positions!(woa, sphere)
        end
        
        # Test results
        @test get_best_fitness(woa) isa Float64
        @test get_best_position(woa) isa Vector{Float64}
        @test length(get_best_position(woa)) == dimension
        @test get_best_fitness(woa) < max_expected_fitness
        @test get_convergence_data(woa) isa Vector{Float64}
        @test length(get_convergence_data(woa)) == iterations
    end
    
    @testset "Genetic Algorithm" begin
        # Create and initialize GA
        ga_params = Dict("crossover_rate" => 0.8, "mutation_rate" => 0.1)
        ga = create_algorithm("genetic", ga_params)
        initialize!(ga, swarm_size, dimension, bounds)
        
        # Run iterations
        for i in 1:iterations
            update_positions!(ga, sphere)
        end
        
        # Test results
        @test get_best_fitness(ga) isa Float64
        @test get_best_position(ga) isa Vector{Float64}
        @test length(get_best_position(ga)) == dimension
        @test get_best_fitness(ga) < max_expected_fitness
        @test get_convergence_data(ga) isa Vector{Float64}
        @test length(get_convergence_data(ga)) == iterations
    end
    
    @testset "ACO Algorithm" begin
        # Create and initialize ACO
        aco_params = Dict("evaporation_rate" => 0.1, "alpha" => 1.0, "beta" => 2.0)
        aco = create_algorithm("aco", aco_params)
        initialize!(aco, swarm_size, dimension, bounds)
        
        # Run iterations
        for i in 1:iterations
            update_positions!(aco, sphere)
        end
        
        # Test results
        @test get_best_fitness(aco) isa Float64
        @test get_best_position(aco) isa Vector{Float64}
        @test length(get_best_position(aco)) == dimension
        @test get_best_fitness(aco) < max_expected_fitness
        @test get_convergence_data(aco) isa Vector{Float64}
        @test length(get_convergence_data(aco)) == iterations
    end
    
    @testset "Algorithm Factory" begin
        # Test factory function with all algorithm types
        @test create_algorithm("pso", Dict()) isa PSO.PSOAlgorithm
        @test create_algorithm("gwo", Dict()) isa GWO.GWOAlgorithm
        @test create_algorithm("woa", Dict()) isa WOA.WOAAlgorithm
        @test create_algorithm("genetic", Dict()) isa GeneticAlgorithm.GAPopulation
        @test create_algorithm("ga", Dict()) isa GeneticAlgorithm.GAPopulation
        @test create_algorithm("aco", Dict()) isa ACO.ACOAlgorithm
        
        # Test with unknown algorithm type
        @test_throws ErrorException create_algorithm("unknown", Dict())
    end
    
    @testset "Trading Optimization" begin
        # Generate synthetic market data
        function generate_test_market_data(n)
            market_data = Vector{MarketData.MarketDataPoint}()
            
            price = 100.0
            for i in 1:n
                price *= (1.0 + randn() * 0.02)  # 2% daily volatility
                
                # Create indicators
                indicators = Dict{String, Float64}()
                indicators["rsi"] = 20.0 + 60.0 * rand()  # Random RSI between 20-80
                indicators["bb_upper"] = price * 1.05
                indicators["bb_lower"] = price * 0.95
                
                data_point = MarketData.MarketDataPoint(
                    now() + Dates.Day(i),
                    price,
                    10000.0,
                    10000.0 * price,
                    indicators
                )
                
                push!(market_data, data_point)
            end
            
            return market_data
        end
        
        # Create a simple swarm for trading
        config = SwarmConfig(
            "test_swarm",
            20,
            "pso",
            ["TEST/USDC"],
            Dict("inertia_weight" => 0.7, "cognitive_coef" => 1.5, "social_coef" => 1.5)
        )
        
        swarm = create_swarm(config)
        market_data = generate_test_market_data(100)
        
        # Test swarm initialization with market data
        start_swarm!(swarm, market_data)
        @test haskey(swarm.performance_metrics, "best_fitness")
        @test haskey(swarm.performance_metrics, "entry_threshold")
        @test haskey(swarm.performance_metrics, "exit_threshold")
        @test haskey(swarm.performance_metrics, "stop_loss")
        @test haskey(swarm.performance_metrics, "take_profit")
        
        # Test swarm update with new data
        new_data = generate_test_market_data(10)
        update_swarm!(swarm, new_data)
        @test length(swarm.market_data) == 110
        
        # Test trading signal generation
        signals = generate_trading_signals(swarm, market_data[end])
        @test isa(signals, Vector{Dict{String, Any}})
    end
end 