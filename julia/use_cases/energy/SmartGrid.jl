module SmartGrid

using JuliaOS
using JuMP
using Ipopt
using Plots
using Statistics
using Random
using Dates
using LinearAlgebra
using Distributions

export PowerGrid, PowerSource, PowerLoad, optimize_grid_operation
export simulate_grid, visualize_results, demo

"""
    PowerSource

Represents a power generation source in the grid.
"""
struct PowerSource
    id::String
    type::String  # "solar", "wind", "hydro", "gas", "coal", "nuclear"
    capacity::Float64  # Maximum power output (MW)
    min_output::Float64  # Minimum power output (MW)
    ramping_rate::Float64  # Maximum change in output per hour (MW/h)
    cost_function::Function  # Cost function: f(output) -> cost
    carbon_intensity::Float64  # kg CO2 per MWh
    availability::Function  # Availability function: f(hour, weather) -> availability factor [0-1]
end

"""
    PowerLoad

Represents a power load (demand) in the grid.
"""
struct PowerLoad
    id::String
    type::String  # "residential", "commercial", "industrial"
    baseline_profile::Vector{Float64}  # 24-hour baseline demand profile (MW)
    flexibility::Float64  # Percentage of load that can be shifted [0-1]
    max_shift_duration::Int  # Maximum hours that flexible load can be shifted
end

"""
    PowerGrid

Represents a power grid with sources and loads.
"""
struct PowerGrid
    sources::Vector{PowerSource}
    loads::Vector{PowerLoad}
    storage_capacity::Float64  # Maximum energy storage (MWh)
    storage_efficiency::Float64  # Round-trip efficiency [0-1]
    transmission_constraints::Matrix{Float64}  # Transmission capacity between nodes
    carbon_limit::Float64  # Maximum allowed carbon emissions (kg CO2)
end

"""
    create_sample_grid()

Create a sample grid for demonstration purposes.
"""
function create_sample_grid()
    # Create power sources
    sources = [
        PowerSource(
            "solar_farm_1",
            "solar",
            100.0,  # 100 MW capacity
            0.0,    # Can be turned off completely
            80.0,   # Can ramp up/down 80 MW per hour
            output -> 5.0 * output,  # $5 per MWh marginal cost
            0.0,    # No direct carbon emissions
            (hour, weather) -> begin
                # Solar availability peaks at noon
                time_factor = sin(π * (hour - 6) / 12)^2
                time_factor = hour >= 6 && hour <= 18 ? time_factor : 0.0
                # Weather impact
                weather_factor = weather["solar_factor"]
                return max(0, time_factor * weather_factor)
            end
        ),
        
        PowerSource(
            "wind_farm_1",
            "wind",
            80.0,   # 80 MW capacity
            0.0,    # Can be turned off completely
            60.0,   # Can ramp up/down 60 MW per hour
            output -> 3.0 * output,  # $3 per MWh marginal cost
            0.0,    # No direct carbon emissions
            (hour, weather) -> begin
                # Wind availability is stronger at night
                time_factor = 0.7 + 0.3 * sin(π * (hour + 12) / 12)^2
                # Weather impact
                weather_factor = weather["wind_factor"]
                return max(0, time_factor * weather_factor)
            end
        ),
        
        PowerSource(
            "gas_plant_1",
            "gas",
            150.0,  # 150 MW capacity
            30.0,   # Minimum 30 MW output when on
            100.0,  # Can ramp up/down 100 MW per hour
            output -> 40.0 + 60.0 * output,  # $40 fixed + $60 per MWh marginal cost
            400.0,  # 400 kg CO2 per MWh
            (hour, weather) -> 1.0  # Always available
        ),
        
        PowerSource(
            "hydro_plant_1",
            "hydro",
            50.0,   # 50 MW capacity
            10.0,   # Minimum 10 MW output when on
            40.0,   # Can ramp up/down 40 MW per hour
            output -> 10.0 * output,  # $10 per MWh marginal cost
            0.0,    # Negligible direct carbon emissions
            (hour, weather) -> begin
                # Slightly higher availability during daytime
                time_factor = 0.9 + 0.1 * sin(π * (hour - 6) / 12)^2
                # Weather impact
                weather_factor = weather["hydro_factor"]
                return max(0, time_factor * weather_factor)
            end
        )
    ]
    
    # Create load profiles
    # Residential load: peaks in morning and evening
    residential_profile = [
        0.4, 0.3, 0.2, 0.2, 0.3, 0.5,  # 00:00 - 06:00
        0.7, 0.9, 0.8, 0.7, 0.7, 0.8,  # 06:00 - 12:00
        0.7, 0.6, 0.6, 0.7, 0.8, 1.0,  # 12:00 - 18:00
        1.0, 0.9, 0.8, 0.7, 0.6, 0.5   # 18:00 - 00:00
    ]
    
    # Commercial load: peaks during working hours
    commercial_profile = [
        0.3, 0.3, 0.3, 0.3, 0.3, 0.4,  # 00:00 - 06:00
        0.6, 0.8, 1.0, 1.0, 1.0, 0.9,  # 06:00 - 12:00
        0.9, 1.0, 1.0, 1.0, 0.9, 0.8,  # 12:00 - 18:00
        0.7, 0.6, 0.5, 0.4, 0.4, 0.3   # 18:00 - 00:00
    ]
    
    # Industrial load: relatively flat with slight daytime peak
    industrial_profile = [
        0.7, 0.7, 0.7, 0.7, 0.7, 0.8,  # 00:00 - 06:00
        0.9, 1.0, 1.0, 1.0, 1.0, 1.0,  # 06:00 - 12:00
        1.0, 1.0, 1.0, 1.0, 0.9, 0.9,  # 12:00 - 18:00
        0.8, 0.8, 0.8, 0.7, 0.7, 0.7   # 18:00 - 00:00
    ]
    
    # Scale the profiles to average demand in MW
    residential = 80.0 * residential_profile
    commercial = 60.0 * commercial_profile
    industrial = 120.0 * industrial_profile
    
    # Create load objects
    loads = [
        PowerLoad(
            "residential_area_1",
            "residential",
            residential,
            0.2,  # 20% flexibility
            3     # Can shift for up to 3 hours
        ),
        
        PowerLoad(
            "commercial_district_1",
            "commercial",
            commercial,
            0.15,  # 15% flexibility
            2      # Can shift for up to 2 hours
        ),
        
        PowerLoad(
            "industrial_zone_1",
            "industrial",
            industrial,
            0.1,   # 10% flexibility
            4      # Can shift for up to 4 hours
        )
    ]
    
    # Create grid
    grid = PowerGrid(
        sources,
        loads,
        100.0,  # 100 MWh storage capacity
        0.85,   # 85% round-trip efficiency
        ones(length(sources), length(loads)),  # Simple fully connected grid
        5000.0  # 5000 kg CO2 limit per day
    )
    
    return grid
end

"""
    generate_weather_scenario(days=1, seed=nothing)

Generate a realistic weather scenario for simulation.
"""
function generate_weather_scenario(days=1, seed=nothing)
    if seed !== nothing
        Random.seed!(seed)
    end
    
    # Initialize weather data for each hour
    hours = days * 24
    timestamps = [now() + Hour(i) for i in 0:(hours-1)]
    
    # Generate solar availability factors with realistic patterns
    # Base solar pattern with clouds and day/night cycle
    solar_base = [sin(π * (hour % 24 - 6) / 12)^2 for hour in 0:(hours-1)]
    solar_base = [h >= 6 && h <= 18 ? solar_base[i+1] : 0.0 for (i, h) in enumerate(hour.(timestamps) .% 24)]
    
    # Add some randomness for cloud cover
    cloud_cover = rand(Beta(3, 2), hours)
    solar_factor = solar_base .* (1.0 .- 0.7 .* cloud_cover)
    
    # Generate wind patterns
    # Wind tends to be stronger at night and has longer sustained patterns
    wind_base = zeros(hours)
    # Create several "weather fronts" that affect wind
    num_fronts = days * 2
    for _ in 1:num_fronts
        front_start = rand(1:hours)
        front_duration = rand(6:24)  # Weather front lasts 6-24 hours
        front_strength = rand(Float64) * 0.5 + 0.5  # 0.5-1.0 strength
        
        for i in 0:(front_duration-1)
            hour_idx = ((front_start + i - 1) % hours) + 1
            # Gradual ramp up and down of the front
            position = i / front_duration
            factor = sin(π * position)^2
            wind_base[hour_idx] = max(wind_base[hour_idx], front_strength * factor)
        end
    end
    
    # Add daily cycle (stronger at night)
    for i in 1:hours
        hour_of_day = hour(timestamps[i]) % 24
        day_factor = 0.8 + 0.2 * cos(π * hour_of_day / 12)
        wind_base[i] *= day_factor
    end
    
    # Add some noise
    wind_noise = rand(hours) * 0.2
    wind_factor = clamp.(wind_base .+ wind_noise, 0.1, 1.0)
    
    # Hydro availability based on recent rainfall
    # Start with a base availability
    hydro_factor = ones(hours) * 0.8
    
    # Add rainfall events that increase availability
    num_rainfall = days
    for _ in 1:num_rainfall
        rain_start = rand(1:hours)
        rain_duration = rand(2:8)  # Rain lasts 2-8 hours
        rain_intensity = rand(Float64) * 0.3 + 0.2  # 0.2-0.5 increase in availability
        
        # Rain effect persists and gradually decreases over time
        persistence = rand(24:72)  # Effect lasts 1-3 days
        
        for i in 0:(persistence-1)
            hour_idx = ((rain_start + i - 1) % hours) + 1
            
            # Calculate effect strength (decreases over time)
            if i < rain_duration
                # During rainfall, effect increases
                strength = rain_intensity * (i / rain_duration)
            else
                # After rainfall, effect gradually decreases
                decay = (i - rain_duration) / (persistence - rain_duration)
                strength = rain_intensity * (1.0 - decay)
            end
            
            hydro_factor[hour_idx] = min(1.0, hydro_factor[hour_idx] + strength)
        end
    end
    
    # Combine all factors into a weather scenario
    weather = Dict{String, Any}(
        "timestamps" => timestamps,
        "solar_factor" => solar_factor,
        "wind_factor" => wind_factor,
        "hydro_factor" => hydro_factor,
        "temperature" => 15.0 .+ 10.0 .* sin.(2π .* collect(0:(hours-1)) ./ 24) .+ rand(Normal(0, 2), hours)
    )
    
    return weather
end

"""
    get_total_demand(grid::PowerGrid, hour::Int, weather=nothing)

Get the total baseline demand for a given hour.
"""
function get_total_demand(grid::PowerGrid, hour::Int, weather=nothing)
    hour_idx = (hour - 1) % 24 + 1
    total_demand = 0.0
    
    for load in grid.loads
        demand = load.baseline_profile[hour_idx]
        
        # Apply temperature effect if weather is provided
        if weather !== nothing
            temp = weather["temperature"][hour]
            # Higher demand at temperature extremes (heating/cooling)
            temp_factor = 1.0 + 0.1 * (abs(temp - 20.0) / 15.0)^2
            demand *= temp_factor
        end
        
        total_demand += demand
    end
    
    return total_demand
end

"""
    optimize_grid_operation(grid::PowerGrid, hours::Int, weather::Dict)

Optimize the operation of the power grid for a given time period and weather scenario.
"""
function optimize_grid_operation(grid::PowerGrid, hours::Int, weather::Dict)
    # Create optimization model
    model = Model(Ipopt.Optimizer)
    set_silent(model)  # Suppress solver output
    
    num_sources = length(grid.sources)
    
    # Variables: power output from each source for each hour
    @variable(model, output[1:num_sources, 1:hours] >= 0)
    
    # Variables: energy storage level at each hour
    @variable(model, 0 <= storage[1:hours] <= grid.storage_capacity)
    
    # Variables: charge and discharge rates
    @variable(model, storage_charge[1:hours] >= 0)
    @variable(model, storage_discharge[1:hours] >= 0)
    
    # Constraint: source output limits
    for s in 1:num_sources, h in 1:hours
        source = grid.sources[s]
        availability = source.availability(h, weather)
        max_output = source.capacity * availability
        
        @constraint(model, output[s, h] <= max_output)
        @constraint(model, output[s, h] >= source.min_output * (output[s, h] > 0))
    end
    
    # Constraint: ramping limits
    for s in 1:num_sources, h in 2:hours
        source = grid.sources[s]
        @constraint(model, output[s, h] - output[s, h-1] <= source.ramping_rate)
        @constraint(model, output[s, h-1] - output[s, h] <= source.ramping_rate)
    end
    
    # Constraint: storage dynamics
    @constraint(model, storage[1] == 0)  # Start with empty storage
    for h in 2:hours
        @constraint(model, storage[h] == storage[h-1] + 
                            storage_charge[h-1] * grid.storage_efficiency - 
                            storage_discharge[h-1])
    end
    
    # Constraint: total supply meets demand
    for h in 1:hours
        total_demand = get_total_demand(grid, h, weather)
        @constraint(model, sum(output[s, h] for s in 1:num_sources) + 
                           storage_discharge[h] - storage_charge[h] == total_demand)
    end
    
    # Constraint: carbon emissions limit
    total_carbon = @expression(model, sum(grid.sources[s].carbon_intensity * output[s, h] 
                                         for s in 1:num_sources, h in 1:hours))
    @constraint(model, total_carbon <= grid.carbon_limit)
    
    # Objective: minimize total cost
    total_cost = @expression(model, sum(grid.sources[s].cost_function(output[s, h]) 
                                       for s in 1:num_sources, h in 1:hours))
    @objective(model, Min, total_cost)
    
    # Solve the optimization problem
    optimize!(model)
    
    # Check if the optimization was successful
    if termination_status(model) != MOI.OPTIMAL && termination_status(model) != MOI.LOCALLY_SOLVED
        @warn "Optimization did not find an optimal solution. Status: $(termination_status(model))"
    end
    
    # Extract results
    result = Dict{String, Any}()
    
    # Extract source outputs
    source_outputs = Dict{String, Vector{Float64}}()
    for s in 1:num_sources
        source_outputs[grid.sources[s].id] = [value(output[s, h]) for h in 1:hours]
    end
    result["source_outputs"] = source_outputs
    
    # Extract storage levels and charge/discharge
    result["storage_level"] = [value(storage[h]) for h in 1:hours]
    result["storage_charge"] = [value(storage_charge[h]) for h in 1:hours]
    result["storage_discharge"] = [value(storage_discharge[h]) for h in 1:hours]
    
    # Calculate actual demand and supply
    total_supply = zeros(hours)
    for s in 1:num_sources, h in 1:hours
        total_supply[h] += value(output[s, h])
    end
    result["total_supply"] = total_supply
    
    total_demand = [get_total_demand(grid, h, weather) for h in 1:hours]
    result["total_demand"] = total_demand
    
    # Calculate cost and carbon emissions
    result["total_cost"] = value(total_cost)
    result["total_carbon"] = value(total_carbon)
    result["average_cost_per_mwh"] = result["total_cost"] / sum(total_demand)
    result["carbon_intensity"] = result["total_carbon"] / sum(total_demand)
    
    # Calculate renewable percentage
    renewable_output = 0.0
    total_output = 0.0
    for s in 1:num_sources, h in 1:hours
        source_output = value(output[s, h])
        total_output += source_output
        if grid.sources[s].type in ["solar", "wind", "hydro"]
            renewable_output += source_output
        end
    end
    result["renewable_percentage"] = renewable_output / total_output * 100
    
    return result
end

"""
    simulate_grid(grid::PowerGrid, days=1; seed=nothing)

Run a full grid simulation for a given number of days.
"""
function simulate_grid(grid::PowerGrid, days=1; seed=nothing)
    # Generate weather scenario
    weather = generate_weather_scenario(days, seed)
    hours = days * 24
    
    # Optimize grid operation
    result = optimize_grid_operation(grid, hours, weather)
    
    # Add weather data to results
    result["weather"] = weather
    result["timestamps"] = weather["timestamps"]
    
    return result
end

"""
    visualize_results(result::Dict, title="Power Grid Simulation")

Create visualization plots for the simulation results.
"""
function visualize_results(result::Dict, title="Power Grid Simulation")
    timestamps = result["timestamps"]
    hours = length(timestamps)
    
    # Extract data
    source_outputs = result["source_outputs"]
    total_demand = result["total_demand"]
    storage_level = result["storage_level"]
    storage_charge = result["storage_charge"]
    storage_discharge = result["storage_discharge"]
    weather = result["weather"]
    
    # Plot 1: Power supply by source and demand
    p1 = plot(
        title="Power Supply and Demand",
        xlabel="Time",
        ylabel="Power (MW)",
        legend=:outertopright,
        size=(800, 400)
    )
    
    # Stacked area chart for power sources
    source_types = Dict(
        "solar" => :orange,
        "wind" => :skyblue,
        "hydro" => :blue,
        "gas" => :grey,
        "coal" => :black,
        "nuclear" => :purple
    )
    
    # Sort sources by type for better visualization
    sorted_keys = sort(collect(keys(source_outputs)))
    sorted_data = Matrix{Float64}(undef, hours, length(sorted_keys))
    
    for (i, key) in enumerate(sorted_keys)
        sorted_data[:, i] = source_outputs[key]
    end
    
    # Cumulative sum for stacked area
    cumulative_data = cumsum(sorted_data, dims=2)
    
    # Plot each source as a filled area
    for i in length(sorted_keys):-1:1
        source_id = sorted_keys[i]
        source_type = split(source_id, "_")[1]
        color = get(source_types, source_type, :green)
        
        y_bottom = i > 1 ? cumulative_data[:, i-1] : zeros(hours)
        y_top = cumulative_data[:, i]
        
        plot!(p1, timestamps, y_top, fillrange=y_bottom, label=source_id, color=color, alpha=0.8)
    end
    
    # Add demand line
    plot!(p1, timestamps, total_demand, label="Demand", line=(:black, 2, :dash))
    
    # Plot 2: Storage charge, discharge, and level
    p2 = plot(
        title="Energy Storage",
        xlabel="Time",
        ylabel="Power (MW) / Energy (MWh)",
        legend=:topright,
        size=(800, 400)
    )
    
    plot!(p2, timestamps, storage_level, label="Storage Level (MWh)", line=(:blue, 2))
    plot!(p2, timestamps, storage_charge, label="Charging Rate (MW)", line=(:green, 1))
    plot!(p2, timestamps, storage_discharge, label="Discharging Rate (MW)", line=(:red, 1))
    
    # Plot 3: Weather conditions
    p3 = plot(
        title="Weather Conditions",
        xlabel="Time",
        ylabel="Factor (0-1)",
        legend=:topright,
        size=(800, 400)
    )
    
    plot!(p3, timestamps, weather["solar_factor"], label="Solar Availability", line=(:orange, 2))
    plot!(p3, timestamps, weather["wind_factor"], label="Wind Availability", line=(:skyblue, 2))
    plot!(p3, timestamps, weather["hydro_factor"], label="Hydro Availability", line=(:blue, 2))
    
    # Add secondary y-axis for temperature
    plot!(twinx(p3), timestamps, weather["temperature"], label="Temperature (°C)", line=(:red, 2), legend=:bottomright)
    
    # Plot 4: Summary metrics
    metrics = [
        "Total cost: \$$(round(result["total_cost"]/1000, digits=2)) thousand",
        "Avg cost: \$$(round(result["average_cost_per_mwh"], digits=2))/MWh",
        "Carbon emissions: $(round(result["total_carbon"]/1000, digits=2)) tons CO2",
        "Carbon intensity: $(round(result["carbon_intensity"], digits=2)) kg CO2/MWh",
        "Renewable percentage: $(round(result["renewable_percentage"], digits=1))%"
    ]
    
    p4 = plot(
        title="Summary Metrics",
        showaxis=false,
        grid=false,
        ticks=false,
        size=(800, 200)
    )
    
    annotate!(p4, 0.5, 0.8, text(join(metrics, "\n"), :center, 12))
    
    # Combine all plots
    p = plot(p1, p3, p2, p4, layout=(4, 1), size=(1000, 1200))
    
    return p
end

"""
    demo()

Run a demonstration of the smart grid optimization.
"""
function demo()
    println("Creating sample power grid...")
    grid = create_sample_grid()
    
    println("Running 3-day simulation...")
    result = simulate_grid(grid, 3, seed=42)
    
    println("Simulation completed!")
    println("Summary:")
    println("  Total cost: \$$(round(result["total_cost"]/1000, digits=2)) thousand")
    println("  Avg. cost per MWh: \$$(round(result["average_cost_per_mwh"], digits=2))")
    println("  Carbon emissions: $(round(result["total_carbon"]/1000, digits=2)) tons CO2")
    println("  Carbon intensity: $(round(result["carbon_intensity"], digits=2)) kg CO2/MWh")
    println("  Renewable percentage: $(round(result["renewable_percentage"], digits=1))%")
    
    println("Generating visualization...")
    p = visualize_results(result, "3-Day Smart Grid Simulation")
    
    # Save the plot
    savefig(p, "smart_grid_simulation.png")
    display(p)
    
    return grid, result, p
end

end # module 