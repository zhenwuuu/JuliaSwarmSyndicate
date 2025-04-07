using Test
using JuliaOS.Monitoring

@testset "Monitoring and Metrics Tests" begin
    @testset "Metrics Collection" begin
        # Test metrics collector initialization
        collector = MetricsCollector(
            Dict(
                "update_interval" => 60,  # seconds
                "retention_period" => 86400,  # 24 hours
                "metrics_path" => "test_metrics"
            )
        )
        
        @test collector.update_interval == 60
        @test collector.retention_period == 86400
        @test collector.metrics_path == "test_metrics"
        
        # Test metrics recording
        metrics = Dict(
            "timestamp" => now(),
            "total_profit" => 1000.0,
            "trade_count" => 10,
            "success_rate" => 0.8,
            "gas_cost" => 50.0
        )
        
        record_metrics!(collector, metrics)
        @test length(collector.metrics_history) > 0
        @test collector.metrics_history[end]["total_profit"] == 1000.0
    end
    
    @testset "Performance Analytics" begin
        # Test performance analytics calculation
        collector = MetricsCollector(
            Dict(
                "update_interval" => 60,
                "retention_period" => 86400,
                "metrics_path" => "test_metrics"
            )
        )
        
        # Add some test metrics
        for i in 1:10
            record_metrics!(collector, Dict(
                "timestamp" => now(),
                "total_profit" => rand() * 1000,
                "trade_count" => rand(1:100),
                "success_rate" => rand(),
                "gas_cost" => rand() * 100
            ))
        end
        
        # Test analytics calculation
        analytics = calculate_performance_analytics(collector)
        
        @test haskey(analytics, "total_profit")
        @test haskey(analytics, "average_success_rate")
        @test haskey(analytics, "total_trades")
        @test haskey(analytics, "total_gas_cost")
        @test haskey(analytics, "profit_per_trade")
    end
    
    @testset "Health Monitoring" begin
        # Test health monitor initialization
        monitor = HealthMonitor(
            Dict(
                "check_interval" => 30,  # seconds
                "timeout" => 5,  # seconds
                "retry_count" => 3
            )
        )
        
        @test monitor.check_interval == 30
        @test monitor.timeout == 5
        @test monitor.retry_count == 3
        
        # Test health check
        health_status = check_health(monitor)
        @test haskey(health_status, "status")
        @test haskey(health_status, "timestamp")
        @test haskey(health_status, "components")
    end
    
    @testset "Alert System" begin
        # Test alert system initialization
        alert_system = AlertSystem(
            Dict(
                "alert_thresholds" => Dict(
                    "max_drawdown" => 0.15,
                    "min_success_rate" => 0.7,
                    "max_gas_price" => 100.0
                ),
                "notification_channels" => ["console", "email"]
            )
        )
        
        @test haskey(alert_system.alert_thresholds, "max_drawdown")
        @test haskey(alert_system.alert_thresholds, "min_success_rate")
        @test haskey(alert_system.alert_thresholds, "max_gas_price")
        
        # Test alert generation
        alert = generate_alert(
            alert_system,
            Dict(
                "type" => "high_drawdown",
                "severity" => "warning",
                "message" => "Drawdown exceeds threshold",
                "value" => 0.2,
                "threshold" => 0.15
            )
        )
        
        @test alert.type == "high_drawdown"
        @test alert.severity == "warning"
        @test alert.message == "Drawdown exceeds threshold"
        @test alert.value == 0.2
        @test alert.threshold == 0.15
    end
    
    @testset "Logging System" begin
        # Test logging system initialization
        logger = LoggingSystem(
            Dict(
                "log_level" => "INFO",
                "log_path" => "test_logs",
                "rotation_size" => 10485760,  # 10MB
                "max_files" => 5
            )
        )
        
        @test logger.log_level == "INFO"
        @test logger.log_path == "test_logs"
        @test logger.rotation_size == 10485760
        @test logger.max_files == 5
        
        # Test log recording
        log_entry = LogEntry(
            "INFO",
            "Test message",
            Dict(
                "component" => "test",
                "timestamp" => now()
            )
        )
        
        record_log!(logger, log_entry)
        @test length(logger.log_history) > 0
        @test logger.log_history[end].message == "Test message"
    end
    
    @testset "Dashboard Integration" begin
        # Test dashboard data preparation
        dashboard_data = prepare_dashboard_data(
            Dict(
                "metrics" => Dict(
                    "total_profit" => 1000.0,
                    "trade_count" => 10,
                    "success_rate" => 0.8
                ),
                "health" => Dict(
                    "status" => "healthy",
                    "components" => Dict(
                        "arbitrage" => "operational",
                        "liquidity" => "operational"
                    )
                ),
                "alerts" => []
            )
        )
        
        @test haskey(dashboard_data, "metrics")
        @test haskey(dashboard_data, "health")
        @test haskey(dashboard_data, "alerts")
        @test dashboard_data["health"]["status"] == "healthy"
    end
    
    @testset "Data Persistence" begin
        # Test metrics persistence
        collector = MetricsCollector(
            Dict(
                "update_interval" => 60,
                "retention_period" => 86400,
                "metrics_path" => "test_metrics"
            )
        )
        
        # Add test metrics
        record_metrics!(collector, Dict(
            "timestamp" => now(),
            "total_profit" => 1000.0,
            "trade_count" => 10
        ))
        
        # Test saving metrics
        save_metrics!(collector)
        @test isfile("test_metrics/metrics.json")
        
        # Test loading metrics
        loaded_collector = load_metrics!("test_metrics/metrics.json")
        @test length(loaded_collector.metrics_history) > 0
        @test loaded_collector.metrics_history[end]["total_profit"] == 1000.0
    end
    
    @testset "Error Handling" begin
        # Test invalid metrics collector
        @test_throws ArgumentError MetricsCollector(
            Dict(
                "update_interval" => -60,
                "retention_period" => 86400,
                "metrics_path" => "test_metrics"
            )
        )
        
        # Test invalid health monitor
        @test_throws ArgumentError HealthMonitor(
            Dict(
                "check_interval" => -30,
                "timeout" => 5,
                "retry_count" => 3
            )
        )
        
        # Test invalid alert system
        @test_throws ArgumentError AlertSystem(
            Dict(
                "alert_thresholds" => Dict(
                    "max_drawdown" => -0.15
                ),
                "notification_channels" => ["invalid_channel"]
            )
        )
        
        # Test invalid logging system
        @test_throws ArgumentError LoggingSystem(
            Dict(
                "log_level" => "INVALID",
                "log_path" => "test_logs",
                "rotation_size" => -10485760,
                "max_files" => -5
            )
        )
    end
end 