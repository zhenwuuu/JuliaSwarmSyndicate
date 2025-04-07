module SocialMediaAnalysis

using JSON
using Dates
using Statistics
using Random
using LinearAlgebra
using Distributions
using JuliaOS.SwarmManager.Algorithms

export analyze_trends, detect_communities, rank_content, optimize_engagement
export analyze_influencers, track_topic_evolution, ContentOptimizationConfig
export detect_viral_potential, predict_content_reach

struct ContentOptimizationConfig
    algorithm::String
    parameters::Dict{String, Any}
    swarm_size::Int
    dimension::Int
end

"""
    analyze_trends(posts::Vector{Dict}, config::ContentOptimizationConfig)

Analyze trending topics and content patterns from social media posts.
Uses swarm intelligence to identify important features and weights.
"""
function analyze_trends(posts::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract features from posts
    features = extract_post_features(posts)
    
    # Define bounds for optimization (feature importance weights)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for trend recognition
    fitness_function = position -> evaluate_trend_recognition(position, features, posts)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized feature weights
    best_position = get_best_position(algorithm)
    
    # Calculate trend scores using optimized weights
    trend_scores = calculate_trend_scores(features, best_position)
    
    # Identify top trending topics
    trending_topics = identify_trending_topics(posts, trend_scores)
    
    # Return results
    return Dict(
        "trending_topics" => trending_topics,
        "feature_weights" => best_position,
        "trend_scores" => trend_scores,
        "trend_velocity" => calculate_trend_velocity(posts, trend_scores)
    )
end

"""
    detect_communities(user_interactions::Vector{Dict}, config::ContentOptimizationConfig)

Detect user communities and influence networks in social media data.
Uses swarm intelligence to optimize community detection parameters.
"""
function detect_communities(user_interactions::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Build interaction graph from user interactions
    interaction_graph = build_interaction_graph(user_interactions)
    
    # Define bounds for optimization (community detection parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for community quality
    fitness_function = position -> evaluate_community_quality(position, interaction_graph)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized community detection parameters
    best_position = get_best_position(algorithm)
    
    # Detect communities using optimized parameters
    communities = detect_communities_with_params(interaction_graph, best_position)
    
    # Identify key influencers in each community
    key_influencers = identify_key_influencers(interaction_graph, communities)
    
    # Calculate community metrics
    community_metrics = calculate_community_metrics(interaction_graph, communities)
    
    # Return results
    return Dict(
        "communities" => communities,
        "key_influencers" => key_influencers,
        "community_metrics" => community_metrics,
        "optimized_parameters" => best_position
    )
end

"""
    rank_content(content_items::Vector{Dict}, user_preferences::Vector{Dict}, config::ContentOptimizationConfig)

Rank content items based on relevance to user preferences.
Uses swarm intelligence to optimize ranking parameters.
"""
function rank_content(content_items::Vector{Dict}, user_preferences::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract features from content items
    content_features = [extract_content_features(item) for item in content_items]
    
    # Extract user preference profiles
    user_profiles = [extract_user_profile(prefs) for prefs in user_preferences]
    
    # Define bounds for optimization (ranking parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for ranking quality
    fitness_function = position -> evaluate_ranking_quality(position, content_features, user_profiles)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized ranking parameters
    best_position = get_best_position(algorithm)
    
    # Generate personalized rankings for each user
    personalized_rankings = generate_personalized_rankings(content_features, user_profiles, best_position)
    
    # Calculate diversity and coverage metrics
    diversity_metrics = calculate_diversity_metrics(personalized_rankings, content_items)
    
    # Return results
    return Dict(
        "personalized_rankings" => personalized_rankings,
        "optimized_parameters" => best_position,
        "diversity_metrics" => diversity_metrics,
        "global_ranking" => generate_global_ranking(content_features, best_position)
    )
end

"""
    optimize_engagement(content_features::Vector{Dict}, engagement_history::Vector{Dict}, config::ContentOptimizationConfig)

Optimize content creation parameters to maximize user engagement.
Uses swarm intelligence to find optimal content characteristics.
"""
function optimize_engagement(content_features::Vector{Dict}, engagement_history::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract engagement metrics and content characteristics
    engagement_data = extract_engagement_data(content_features, engagement_history)
    
    # Define bounds for optimization (content parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for engagement optimization
    fitness_function = position -> evaluate_engagement_potential(position, engagement_data)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized content parameters
    best_position = get_best_position(algorithm)
    
    # Generate content recommendations
    content_recommendations = generate_content_recommendations(best_position)
    
    # Predict engagement metrics for optimized content
    predicted_engagement = predict_engagement_metrics(best_position, engagement_data)
    
    # Return results
    return Dict(
        "optimized_parameters" => best_position,
        "content_recommendations" => content_recommendations,
        "predicted_engagement" => predicted_engagement,
        "optimal_posting_schedule" => optimize_posting_schedule(engagement_history)
    )
end

"""
    analyze_influencers(user_data::Vector{Dict}, interaction_data::Vector{Dict}, config::ContentOptimizationConfig)

Analyze influencer networks and impact patterns using swarm intelligence.
"""
function analyze_influencers(user_data::Vector{Dict}, interaction_data::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract influencer metrics and network position
    influence_metrics = extract_influence_metrics(user_data, interaction_data)
    
    # Define bounds for optimization (influence parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for influence score accuracy
    fitness_function = position -> evaluate_influence_model(position, influence_metrics)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized influence parameters
    best_position = get_best_position(algorithm)
    
    # Calculate influencer scores
    influencer_scores = calculate_influencer_scores(influence_metrics, best_position)
    
    # Identify top influencers in different categories
    top_influencers = identify_top_influencers(user_data, influencer_scores)
    
    # Return results
    return Dict(
        "influencer_scores" => influencer_scores,
        "top_influencers" => top_influencers,
        "influence_factors" => identify_influence_factors(best_position),
        "influence_network" => build_influence_network(interaction_data, influencer_scores)
    )
end

"""
    track_topic_evolution(content_over_time::Vector{Dict}, config::ContentOptimizationConfig)

Track the evolution of topics and narratives over time using swarm intelligence.
"""
function track_topic_evolution(content_over_time::Vector{Dict}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract topic features over time
    topic_features = extract_topic_features_over_time(content_over_time)
    
    # Define bounds for optimization (topic evolution parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for topic evolution modeling
    fitness_function = position -> evaluate_topic_evolution_model(position, topic_features)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized topic evolution parameters
    best_position = get_best_position(algorithm)
    
    # Model topic evolution
    topic_evolution = model_topic_evolution(topic_features, best_position)
    
    # Predict future topic trends
    future_trends = predict_future_topics(topic_evolution, best_position)
    
    # Return results
    return Dict(
        "topic_evolution" => topic_evolution,
        "future_trends" => future_trends,
        "topic_lifecycle_patterns" => identify_topic_lifecycle_patterns(topic_evolution),
        "optimized_parameters" => best_position
    )
end

"""
    detect_viral_potential(content_items::Vector{Dict}, network_structure::Dict, config::ContentOptimizationConfig)

Detect viral potential of content using swarm intelligence and network analysis.
"""
function detect_viral_potential(content_items::Vector{Dict}, network_structure::Dict, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract virality features
    virality_features = extract_virality_features(content_items, network_structure)
    
    # Define bounds for optimization (virality parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for viral prediction accuracy
    fitness_function = position -> evaluate_viral_prediction_model(position, virality_features)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized virality parameters
    best_position = get_best_position(algorithm)
    
    # Calculate viral potential scores
    viral_scores = calculate_viral_potential(content_items, best_position, network_structure)
    
    # Return results
    return Dict(
        "viral_potential_scores" => viral_scores,
        "viral_factors" => identify_viral_factors(best_position),
        "viral_threshold" => calculate_viral_threshold(viral_scores),
        "optimized_parameters" => best_position
    )
end

"""
    predict_content_reach(content_items::Vector{Dict}, network_data::Dict, initial_shares::Vector{Int}, config::ContentOptimizationConfig)

Predict content reach and diffusion patterns using swarm intelligence.
"""
function predict_content_reach(content_items::Vector{Dict}, network_data::Dict, initial_shares::Vector{Int}, config::ContentOptimizationConfig)
    # Create an algorithm instance
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Extract diffusion features
    diffusion_features = extract_diffusion_features(content_items, network_data, initial_shares)
    
    # Define bounds for optimization (diffusion parameters)
    bounds = [(0.0, 1.0) for _ in 1:config.dimension]
    
    # Initialize algorithm
    initialize!(algorithm, config.swarm_size, config.dimension, bounds)
    
    # Define fitness function for diffusion prediction accuracy
    fitness_function = position -> evaluate_diffusion_model(position, diffusion_features)
    
    # Run optimization
    for i in 1:100
        update_positions!(algorithm, fitness_function)
    end
    
    # Get optimized diffusion parameters
    best_position = get_best_position(algorithm)
    
    # Predict content reach
    content_reach = predict_reach(content_items, network_data, initial_shares, best_position)
    
    # Simulate diffusion patterns
    diffusion_patterns = simulate_diffusion(content_items, network_data, initial_shares, best_position)
    
    # Return results
    return Dict(
        "predicted_reach" => content_reach,
        "diffusion_patterns" => diffusion_patterns,
        "reach_peak_time" => predict_reach_peak_time(diffusion_patterns),
        "network_coverage" => calculate_network_coverage(diffusion_patterns, network_data)
    )
end

# Helper functions (simplified implementations)

function extract_post_features(posts::Vector{Dict})
    # Simplified implementation
    # Would actually extract text features, engagement metrics, etc.
    return [rand(20) for _ in 1:length(posts)]
end

function evaluate_trend_recognition(position::Vector{Float64}, features::Vector{Vector{Float64}}, posts::Vector{Dict})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function calculate_trend_scores(features::Vector{Vector{Float64}}, weights::Vector{Float64})
    # Calculate trend scores using weights
    return [dot(feature, weights) for feature in features]
end

function identify_trending_topics(posts::Vector{Dict}, trend_scores::Vector{Float64})
    # Identify top trending topics based on scores
    # Simplified implementation
    return ["AI", "Web3", "DeFi", "NFTs", "Metaverse"]
end

function calculate_trend_velocity(posts::Vector{Dict}, trend_scores::Vector{Float64})
    # Calculate rate of change in trends
    # Simplified implementation
    return rand(5)
end

function build_interaction_graph(user_interactions::Vector{Dict})
    # Build a graph representation of user interactions
    # Simplified implementation
    return Dict(
        "nodes" => 1:100,
        "edges" => [(rand(1:100), rand(1:100)) for _ in 1:500]
    )
end

function evaluate_community_quality(position::Vector{Float64}, interaction_graph::Dict)
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function detect_communities_with_params(interaction_graph::Dict, params::Vector{Float64})
    # Detect communities using optimized parameters
    # Simplified implementation
    num_communities = 5
    return [rand(1:num_communities) for _ in 1:100]  # Assign nodes to communities
end

function identify_key_influencers(interaction_graph::Dict, communities::Vector{Int})
    # Identify key influencers in each community
    # Simplified implementation
    num_communities = maximum(communities)
    return [rand(1:100) for _ in 1:num_communities]  # One key influencer per community
end

function calculate_community_metrics(interaction_graph::Dict, communities::Vector{Int})
    # Calculate community metrics
    # Simplified implementation
    return Dict(
        "modularity" => 0.75,
        "cohesion" => 0.82,
        "separation" => 0.68
    )
end

function extract_content_features(item::Dict)
    # Extract features from content item
    # Simplified implementation
    return rand(20)
end

function extract_user_profile(prefs::Dict)
    # Extract user preference profile
    # Simplified implementation
    return rand(20)
end

function evaluate_ranking_quality(position::Vector{Float64}, content_features::Vector{Vector{Float64}}, user_profiles::Vector{Vector{Float64}})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function generate_personalized_rankings(content_features::Vector{Vector{Float64}}, user_profiles::Vector{Vector{Float64}}, params::Vector{Float64})
    # Generate personalized rankings for each user
    # Simplified implementation
    num_users = length(user_profiles)
    num_items = length(content_features)
    
    rankings = []
    for i in 1:num_users
        # Create a ranking of content items for this user
        user_ranking = sortperm([dot(content_features[j], user_profiles[i]) for j in 1:num_items], rev=true)
        push!(rankings, user_ranking)
    end
    
    return rankings
end

function calculate_diversity_metrics(rankings::Vector{Vector{Int}}, content_items::Vector{Dict})
    # Calculate diversity and coverage metrics
    # Simplified implementation
    return Dict(
        "diversity" => 0.78,
        "coverage" => 0.92,
        "serendipity" => 0.65
    )
end

function generate_global_ranking(content_features::Vector{Vector{Float64}}, params::Vector{Float64})
    # Generate a global ranking of content items
    # Simplified implementation
    scores = [dot(feature, params) for feature in content_features]
    return sortperm(scores, rev=true)
end

function extract_engagement_data(content_features::Vector{Dict}, engagement_history::Vector{Dict})
    # Extract engagement data
    # Simplified implementation
    return Dict(
        "features" => [rand(20) for _ in 1:length(content_features)],
        "engagement" => [rand() for _ in 1:length(content_features)]
    )
end

function evaluate_engagement_potential(position::Vector{Float64}, engagement_data::Dict)
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function generate_content_recommendations(params::Vector{Float64})
    # Generate content recommendations based on optimized parameters
    # Simplified implementation
    return [Dict("topic" => t, "length" => rand(300:1500), "media_type" => rand(["image", "video", "text"]))
            for t in ["AI", "Blockchain", "Data Science", "Crypto", "NFTs"]]
end

function predict_engagement_metrics(params::Vector{Float64}, engagement_data::Dict)
    # Predict engagement metrics for optimized content
    # Simplified implementation
    return Dict(
        "likes" => rand(100:1000),
        "shares" => rand(50:500),
        "comments" => rand(20:200),
        "click_through_rate" => rand(0.01:0.01:0.1)
    )
end

function optimize_posting_schedule(engagement_history::Vector{Dict})
    # Optimize posting schedule based on historical engagement
    # Simplified implementation
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    times = ["9:00", "12:00", "15:00", "18:00", "21:00"]
    
    return Dict(
        "best_days" => sample(days, 3, replace=false),
        "best_times" => sample(times, 2, replace=false)
    )
end

function extract_influence_metrics(user_data::Vector{Dict}, interaction_data::Vector{Dict})
    # Extract influence metrics
    # Simplified implementation
    return [Dict("followers" => rand(100:10000), 
                "engagement_rate" => rand(0.01:0.01:0.1),
                "share_rate" => rand(0.01:0.01:0.05))
            for _ in 1:length(user_data)]
end

function evaluate_influence_model(position::Vector{Float64}, influence_metrics::Vector{Dict})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function calculate_influencer_scores(influence_metrics::Vector{Dict}, params::Vector{Float64})
    # Calculate influencer scores using weights
    # Simplified implementation
    return [rand() for _ in 1:length(influence_metrics)]
end

function identify_top_influencers(user_data::Vector{Dict}, influencer_scores::Vector{Float64})
    # Identify top influencers in different categories
    # Simplified implementation
    indices = sortperm(influencer_scores, rev=true)
    return Dict(
        "overall" => indices[1:5],
        "by_topic" => Dict(topic => sample(1:length(user_data), 3) for topic in ["AI", "Blockchain", "DeFi"])
    )
end

function identify_influence_factors(params::Vector{Float64})
    # Identify key influence factors based on weights
    # Simplified implementation
    return ["audience_size", "engagement_rate", "content_quality", "posting_frequency", "response_rate"]
end

function build_influence_network(interaction_data::Vector{Dict}, influencer_scores::Vector{Float64})
    # Build influence network
    # Simplified implementation
    return Dict(
        "nodes" => 1:length(influencer_scores),
        "edges" => [(rand(1:length(influencer_scores)), rand(1:length(influencer_scores))) for _ in 1:500],
        "weights" => [rand() for _ in 1:500]
    )
end

function extract_topic_features_over_time(content_over_time::Vector{Dict})
    # Extract topic features over time
    # Simplified implementation
    time_points = 10
    topics = 5
    return [rand(topics) for _ in 1:time_points]
end

function evaluate_topic_evolution_model(position::Vector{Float64}, topic_features::Vector{Vector{Float64}})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function model_topic_evolution(topic_features::Vector{Vector{Float64}}, params::Vector{Float64})
    # Model topic evolution
    # Simplified implementation
    time_points = length(topic_features)
    topics = length(topic_features[1])
    
    return [topic_features[i] for i in 1:time_points]
end

function predict_future_topics(topic_evolution::Vector{Vector{Float64}}, params::Vector{Float64})
    # Predict future topic trends
    # Simplified implementation
    last_point = topic_evolution[end]
    future_points = 3
    
    future_trends = []
    for i in 1:future_points
        next_point = last_point .+ 0.1 .* randn(length(last_point))
        next_point = max.(0, next_point)  # Ensure non-negative
        next_point = next_point ./ sum(next_point)  # Normalize
        push!(future_trends, next_point)
        last_point = next_point
    end
    
    return future_trends
end

function identify_topic_lifecycle_patterns(topic_evolution::Vector{Vector{Float64}})
    # Identify topic lifecycle patterns
    # Simplified implementation
    return Dict(
        "rising" => [1, 3],
        "falling" => [2],
        "stable" => [4, 5]
    )
end

function extract_virality_features(content_items::Vector{Dict}, network_structure::Dict)
    # Extract virality features
    # Simplified implementation
    return [rand(15) for _ in 1:length(content_items)]
end

function evaluate_viral_prediction_model(position::Vector{Float64}, virality_features::Vector{Vector{Float64}})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function calculate_viral_potential(content_items::Vector{Dict}, params::Vector{Float64}, network_structure::Dict)
    # Calculate viral potential scores
    # Simplified implementation
    return [rand() for _ in 1:length(content_items)]
end

function identify_viral_factors(params::Vector{Float64})
    # Identify key viral factors based on weights
    # Simplified implementation
    return ["emotional_impact", "surprise_factor", "relevance", "shareability", "timeliness"]
end

function calculate_viral_threshold(viral_scores::Vector{Float64})
    # Calculate threshold for viral content
    # Simplified implementation
    return mean(viral_scores) + std(viral_scores)
end

function extract_diffusion_features(content_items::Vector{Dict}, network_data::Dict, initial_shares::Vector{Int})
    # Extract diffusion features
    # Simplified implementation
    return [rand(15) for _ in 1:length(content_items)]
end

function evaluate_diffusion_model(position::Vector{Float64}, diffusion_features::Vector{Vector{Float64}})
    # Simplified implementation - would be replaced with actual evaluation
    return -sum(position) / length(position)
end

function predict_reach(content_items::Vector{Dict}, network_data::Dict, initial_shares::Vector{Int}, params::Vector{Float64})
    # Predict content reach
    # Simplified implementation
    return [rand(1000:100000) for _ in 1:length(content_items)]
end

function simulate_diffusion(content_items::Vector{Dict}, network_data::Dict, initial_shares::Vector{Int}, params::Vector{Float64})
    # Simulate diffusion patterns
    # Simplified implementation
    time_points = 10
    num_items = length(content_items)
    
    patterns = []
    for i in 1:num_items
        # Generate a sigmoid-like diffusion curve
        t = collect(1:time_points)
        midpoint = rand(3:7)
        steepness = rand(0.5:0.1:1.5)
        max_reach = rand(1000:100000)
        
        curve = max_reach ./ (1 .+ exp.(-steepness .* (t .- midpoint)))
        push!(patterns, curve)
    end
    
    return patterns
end

function predict_reach_peak_time(diffusion_patterns::Vector{Vector{Float64}})
    # Predict when reach will peak for each content item
    # Simplified implementation
    return [findmax(pattern)[2] for pattern in diffusion_patterns]
end

function calculate_network_coverage(diffusion_patterns::Vector{Vector{Float64}}, network_data::Dict)
    # Calculate network coverage
    # Simplified implementation
    return [last(pattern) / 1000000 for pattern in diffusion_patterns]  # Assuming 1M total network size
end

function sample(population, size; replace=true)
    # Utility function to sample from a population
    if replace
        return [population[rand(1:length(population))] for _ in 1:size]
    else
        if size > length(population)
            error("Cannot sample size $size from population of size $(length(population)) without replacement")
        end
        indices = randperm(length(population))[1:size]
        return population[indices]
    end
end

end # module 