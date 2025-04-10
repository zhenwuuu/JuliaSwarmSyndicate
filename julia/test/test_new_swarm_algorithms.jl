using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Swarms
using Swarms.DifferentialEvolution
using Swarms.ParticleSwarmOptimization
using Swarms.GreyWolfOptimization
using Swarms.AntColonyOptimization
using Swarms.GeneticAlgorithm
using Swarms.WhaleOptimizationAlgorithm

function run_new_swarm_algorithm_tests()
    @testset "New Swarm Algorithms" begin
        # Test functions
        function sphere(x)
            return sum(x.^2)
        end
        
        function rosenbrock(x)
            return sum(100.0 * (x[i+1] - x[i]^2)^2 + (1.0 - x[i])^2 for i in 1:length(x)-1)
        end
        
        function rastrigin(x)
            return 10 * length(x) + sum(x.^2 - 10 * cos.(2π * x))
        end
        
        # Set objective functions
        sphere_id = "sphere"
        rosenbrock_id = "rosenbrock"
        rastrigin_id = "rastrigin"
        
        Swarms.set_objective_function(sphere_id, sphere)
        Swarms.set_objective_function(rosenbrock_id, rosenbrock)
        Swarms.set_objective_function(rastrigin_id, rastrigin)
        
        # Test bounds
        bounds_2d = [(-5.0, 5.0), (-5.0, 5.0)]
        bounds_10d = [(-5.0, 5.0) for _ in 1:10]
        
        @testset "Grey Wolf Optimization" begin
            # Test GWO creation
            gwo_result = Swarms.create_swarm(
                "GWO",
                2,
                bounds_2d,
                Dict("pack_size" => 20)
            )
            
            @test gwo_result["success"] == true
            @test gwo_result["algorithm"] == "GWO"
            @test gwo_result["dimensions"] == 2
            
            # Test GWO optimization
            opt_result = Swarms.run_optimization(
                gwo_result["swarm_id"],
                sphere_id,
                Dict(
                    "pack_size" => 30,
                    "max_iterations" => 50,
                    "max_time_seconds" => 5
                )
            )
            
            @test opt_result["success"] == true
            @test opt_result["status"] == "running"
            
            # Wait for optimization to complete
            sleep(6)
            
            # Check optimization result
            result = Swarms.get_optimization_result(opt_result["optimization_id"])
            
            @test result["success"] == true
            @test result["status"] == "completed"
            @test haskey(result["result"], "best_position")
            @test haskey(result["result"], "best_fitness")
            @test haskey(result["result"], "convergence_curve")
            @test result["result"]["algorithm"] == "GWO"
            
            # Test that the solution is reasonable
            @test result["result"]["best_fitness"] < 1.0
        end
        
        @testset "Ant Colony Optimization" begin
            # Test ACO creation
            aco_result = Swarms.create_swarm(
                "ACO",
                2,
                bounds_2d,
                Dict("colony_size" => 20)
            )
            
            @test aco_result["success"] == true
            @test aco_result["algorithm"] == "ACO"
            @test aco_result["dimensions"] == 2
            
            # Test ACO optimization
            opt_result = Swarms.run_optimization(
                aco_result["swarm_id"],
                sphere_id,
                Dict(
                    "colony_size" => 30,
                    "max_iterations" => 50,
                    "max_time_seconds" => 5
                )
            )
            
            @test opt_result["success"] == true
            @test opt_result["status"] == "running"
            
            # Wait for optimization to complete
            sleep(6)
            
            # Check optimization result
            result = Swarms.get_optimization_result(opt_result["optimization_id"])
            
            @test result["success"] == true
            @test result["status"] == "completed"
            @test haskey(result["result"], "best_position")
            @test haskey(result["result"], "best_fitness")
            @test haskey(result["result"], "convergence_curve")
            @test result["result"]["algorithm"] == "ACO"
            
            # Test that the solution is reasonable
            @test result["result"]["best_fitness"] < 1.0
        end
        
        @testset "Genetic Algorithm" begin
            # Test GA creation
            ga_result = Swarms.create_swarm(
                "GA",
                2,
                bounds_2d,
                Dict("population_size" => 20)
            )
            
            @test ga_result["success"] == true
            @test ga_result["algorithm"] == "GA"
            @test ga_result["dimensions"] == 2
            
            # Test GA optimization
            opt_result = Swarms.run_optimization(
                ga_result["swarm_id"],
                sphere_id,
                Dict(
                    "population_size" => 30,
                    "max_generations" => 50,
                    "max_time_seconds" => 5
                )
            )
            
            @test opt_result["success"] == true
            @test opt_result["status"] == "running"
            
            # Wait for optimization to complete
            sleep(6)
            
            # Check optimization result
            result = Swarms.get_optimization_result(opt_result["optimization_id"])
            
            @test result["success"] == true
            @test result["status"] == "completed"
            @test haskey(result["result"], "best_position")
            @test haskey(result["result"], "best_fitness")
            @test haskey(result["result"], "convergence_curve")
            @test result["result"]["algorithm"] == "GA"
            
            # Test that the solution is reasonable
            @test result["result"]["best_fitness"] < 1.0
        end
        
        @testset "Whale Optimization Algorithm" begin
            # Test WOA creation
            woa_result = Swarms.create_swarm(
                "WOA",
                2,
                bounds_2d,
                Dict("pod_size" => 20)
            )
            
            @test woa_result["success"] == true
            @test woa_result["algorithm"] == "WOA"
            @test woa_result["dimensions"] == 2
            
            # Test WOA optimization
            opt_result = Swarms.run_optimization(
                woa_result["swarm_id"],
                sphere_id,
                Dict(
                    "pod_size" => 30,
                    "max_iterations" => 50,
                    "max_time_seconds" => 5
                )
            )
            
            @test opt_result["success"] == true
            @test opt_result["status"] == "running"
            
            # Wait for optimization to complete
            sleep(6)
            
            # Check optimization result
            result = Swarms.get_optimization_result(opt_result["optimization_id"])
            
            @test result["success"] == true
            @test result["status"] == "completed"
            @test haskey(result["result"], "best_position")
            @test haskey(result["result"], "best_fitness")
            @test haskey(result["result"], "convergence_curve")
            @test result["result"]["algorithm"] == "WOA"
            
            # Test that the solution is reasonable
            @test result["result"]["best_fitness"] < 1.0
        end
        
        @testset "Higher Dimensional Problems" begin
            # Test all algorithms on a 10D problem
            for algorithm in ["GWO", "ACO", "GA", "WOA"]
                swarm_result = Swarms.create_swarm(
                    algorithm,
                    10,
                    bounds_10d
                )
                
                @test swarm_result["success"] == true
                
                opt_result = Swarms.run_optimization(
                    swarm_result["swarm_id"],
                    rastrigin_id,
                    Dict("max_time_seconds" => 5)
                )
                
                @test opt_result["success"] == true
                
                # Wait for optimization to complete
                sleep(6)
                
                # Check optimization result
                result = Swarms.get_optimization_result(opt_result["optimization_id"])
                
                @test result["success"] == true
                @test result["status"] == "completed"
                
                # Higher dimensional problems are harder, so we just check that the optimization ran
                @test haskey(result["result"], "best_position")
                @test haskey(result["result"], "best_fitness")
                @test haskey(result["result"], "convergence_curve")
            end
        end
    end
end

# Run the tests
run_new_swarm_algorithm_tests()
