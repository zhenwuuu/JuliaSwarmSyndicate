module Parallelism

export initialize, parallel_map, parallel_foreach, parallel_reduce
export distribute_task, distribute_data, distributed_calculation
export WorkerPool, TaskGroup, DistributedResult
export @parallel, @distributed_task, @with_workers

using ..EnhancedErrors
using ..StructuredLogging
using ..EnhancedConfig
using ..Metrics
using ..Profiler

using Distributed
using SharedArrays
# Future is now part of the standard library
# No need to import it separately
using Dates
using Statistics

# Ensure we have worker processes available
if nprocs() == 1 && Distributed.nworkers() == 1
    # We're running with only the main process, no workers
    # In a real application, you might add workers automatically here
    StructuredLogging.info("Initializing with default worker configuration")
end

"""
    WorkerPool

A pool of worker processes for parallel computation.
"""
mutable struct WorkerPool
    workers::Vector{Int}
    busy::Dict{Int, Bool}
    tasks::Vector{Future}

    function WorkerPool(worker_ids::Vector{Int}=workers())
        return new(
            worker_ids,
            Dict(w => false for w in worker_ids),
            Future[]
        )
    end
end

"""
    TaskGroup

A group of related tasks for monitoring and management.
"""
mutable struct TaskGroup
    id::String
    tasks::Vector{Future}
    start_time::DateTime
    end_time::Union{DateTime, Nothing}
    metadata::Dict{String, Any}

    function TaskGroup(id::String; metadata::Dict{String, Any}=Dict{String, Any}())
        return new(
            id,
            Future[],
            now(),
            nothing,
            metadata
        )
    end
end

"""
    DistributedResult

Wrapper for results from distributed computations.
"""
struct DistributedResult{T}
    value::T
    worker_id::Int
    execution_time_ms::Float64
    memory_used_bytes::Int64
    metadata::Dict{String, Any}
end

# Singleton instance of default worker pool
const DEFAULT_POOL = WorkerPool()

# Task groups by ID
const TASK_GROUPS = Dict{String, TaskGroup}()

"""
    initialize(config=nothing)

Initialize the parallelism module with the given configuration.
"""
function initialize(config=nothing)
    error_context = EnhancedErrors.with_error_context("Parallelism", "initialize")

    log_context = StructuredLogging.LogContext(
        component="Parallelism",
        operation="initialize"
    )

    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Get configuration
            worker_count = if config !== nothing && haskey(config, "worker_count")
                config["worker_count"]
            elseif EnhancedConfig.has_key("parallelism.worker_count")
                EnhancedConfig.get_value("parallelism.worker_count", 0)
            else
                0  # Default to no additional workers
            end

            # Check if we need to add workers
            current_workers = Distributed.workers()
            if worker_count > 0 && length(current_workers) < worker_count
                # Add workers
                addprocs_args = if config !== nothing && haskey(config, "worker_args")
                    Dict(Symbol(k) => v for (k, v) in pairs(config["worker_args"]))
                elseif EnhancedConfig.has_key("parallelism.worker_args")
                    args = EnhancedConfig.get_value("parallelism.worker_args", Dict())
                    Dict(Symbol(k) => v for (k, v) in pairs(args))
                else
                    Dict()
                end

                # Determine how many workers to add
                to_add = worker_count - length(current_workers)

                StructuredLogging.info("Adding worker processes",
                                      data=Dict(
                                          "count" => to_add,
                                          "args" => addprocs_args
                                      ))

                # Add workers
                if !isempty(addprocs_args)
                    new_workers = addprocs(to_add; addprocs_args...)
                else
                    new_workers = addprocs(to_add)
                end

                # Update default pool
                append!(DEFAULT_POOL.workers, new_workers)
                for w in new_workers
                    DEFAULT_POOL.busy[w] = false
                end

                # Load required packages on workers
                load_packages_on_workers()
            end

            # Register metrics
            register_parallelism_metrics()

            StructuredLogging.info("Parallelism module initialized",
                                  data=Dict("workers" => Distributed.nworkers()))

            return Distributed.nworkers()
        catch e
            StructuredLogging.error("Failed to initialize parallelism module",
                                   exception=e)

            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to initialize parallelism module",
                                                  e, context=error_context))
            end

            return 0
        end
    end
end

"""
    register_parallelism_metrics()

Register metrics for the parallelism module.
"""
function register_parallelism_metrics()
    Metrics.register_metric("parallel_tasks_total", Metrics.COUNTER,
                           "Total number of parallel tasks executed",
                           labels=["task_type"])

    Metrics.register_metric("parallel_task_duration_seconds", Metrics.HISTOGRAM,
                           "Distribution of parallel task execution times",
                           buckets=[0.001, 0.01, 0.1, 1.0, 10.0, 60.0, 300.0],
                           labels=["task_type"])

    Metrics.register_metric("workers_active", Metrics.GAUGE,
                           "Number of active worker processes")

    Metrics.register_metric("workers_busy", Metrics.GAUGE,
                           "Number of busy worker processes")

    Metrics.register_metric("task_group_size", Metrics.GAUGE,
                           "Number of tasks in a task group",
                           labels=["group_id"])

    Metrics.register_metric("task_group_duration_seconds", Metrics.HISTOGRAM,
                           "Duration of task group execution",
                           buckets=[0.1, 1.0, 10.0, 60.0, 300.0, 600.0],
                           labels=["group_id"])

    # Update active workers gauge
    Metrics.record_metric("workers_active", Distributed.nworkers())
end

"""
    load_packages_on_workers()

Load required packages on all worker processes.
"""
function load_packages_on_workers()
    # Get the list of currently loaded packages in the main process
    main_packages = keys(Base.loaded_modules)

    # Select essential packages to load on workers
    essential_packages = filter(p ->
        # Filter out internal or runtime packages
        !startswith(string(p), "Base") &&
        !startswith(string(p), "Main") &&
        !startswith(string(p), "InteractiveUtils"),
        main_packages
    )

    # Convert to strings
    package_strings = map(string, essential_packages)

    StructuredLogging.debug("Loading packages on workers",
                           data=Dict("packages" => package_strings))

    # Load packages on all workers
    @everywhere workers() begin
        # Create a list to track loaded packages
        loaded_pkgs = []

        # Dynamically evaluate package loading expressions
        for pkg_name in $package_strings
            try
                # Skip if it's a submodule (contains '.')
                if !contains(pkg_name, ".")
                    # Create and evaluate an expression to load the package
                    expr = Meta.parse("using $pkg_name")
                    eval(expr)
                    push!(loaded_pkgs, pkg_name)
                end
            catch e
                # Log error but continue with other packages
                @error "Failed to load package $pkg_name on worker $(myid())" exception=e
            end
        end

        # Return the list of successfully loaded packages
        loaded_pkgs
    end
end

"""
    parallel_map(f, collection; workers_pool=DEFAULT_POOL, task_group_id=nothing)

Apply function f to each element in collection in parallel.
"""
function parallel_map(f, collection;
                     workers_pool::WorkerPool=DEFAULT_POOL,
                     task_group_id::Union{String, Nothing}=nothing)

    if isempty(collection)
        return []
    end

    # Get a unique task group ID if not provided
    group_id = if task_group_id === nothing
        string("parallel_map_", hash(f), "_", Dates.format(now(), "yyyymmddHHMMSSsss"))
    else
        task_group_id
    end

    # Create or get task group
    task_group = if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id]
    else
        TASK_GROUPS[group_id] = TaskGroup(group_id)
        TASK_GROUPS[group_id]
    end

    # Update metrics
    Metrics.record_metric("parallel_tasks_total", length(collection),
                         labels=Dict("task_type" => "map"))

    # Track execution start time
    start_time = time()

    # Use @distributed for parallel mapping
    results = @distributed (vcat) for item in collection
        # Track item processing time
        item_start = time()

        # Process the item
        result = f(item)

        # Calculate execution time
        execution_time_ms = (time() - item_start) * 1000

        # Create a wrapper with execution metadata
        [DistributedResult(
            result,
            myid(),
            execution_time_ms,
            # This is approximate - in a real implementation we would
            # measure memory more accurately
            Base.summarysize(result),
            Dict{String, Any}("item" => item)
        )]
    end

    # Calculate total execution time
    execution_time = time() - start_time

    # Update task group
    if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id].end_time = now()

        # Record metrics
        Metrics.record_metric("task_group_duration_seconds", execution_time,
                             labels=Dict("group_id" => group_id))
    end

    # Record execution time metric
    Metrics.record_metric("parallel_task_duration_seconds", execution_time,
                         labels=Dict("task_type" => "map"))

    # Extract just the result values if simple mapping is desired
    return results
end

"""
    parallel_foreach(f, collection; workers_pool=DEFAULT_POOL, task_group_id=nothing)

Apply function f to each element in collection in parallel, without collecting results.
"""
function parallel_foreach(f, collection;
                         workers_pool::WorkerPool=DEFAULT_POOL,
                         task_group_id::Union{String, Nothing}=nothing)

    if isempty(collection)
        return nothing
    end

    # Get a unique task group ID if not provided
    group_id = if task_group_id === nothing
        string("parallel_foreach_", hash(f), "_", Dates.format(now(), "yyyymmddHHMMSSsss"))
    else
        task_group_id
    end

    # Create or get task group
    task_group = if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id]
    else
        TASK_GROUPS[group_id] = TaskGroup(group_id)
        TASK_GROUPS[group_id]
    end

    # Update metrics
    Metrics.record_metric("parallel_tasks_total", length(collection),
                         labels=Dict("task_type" => "foreach"))

    # Track execution start time
    start_time = time()

    # Use @sync and @distributed for parallel foreach
    @sync @distributed for item in collection
        # Track item processing time
        item_start = time()

        # Process the item
        f(item)

        # Calculate execution time
        execution_time_ms = (time() - item_start) * 1000

        # We could log or accumulate stats here if needed
    end

    # Calculate total execution time
    execution_time = time() - start_time

    # Update task group
    if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id].end_time = now()

        # Record metrics
        Metrics.record_metric("task_group_duration_seconds", execution_time,
                             labels=Dict("group_id" => group_id))
    end

    # Record execution time metric
    Metrics.record_metric("parallel_task_duration_seconds", execution_time,
                         labels=Dict("task_type" => "foreach"))

    return nothing
end

"""
    parallel_reduce(f, op, collection, init; workers_pool=DEFAULT_POOL, task_group_id=nothing)

Apply function f to each element in collection in parallel, then reduce using op.
"""
function parallel_reduce(f, op, collection, init;
                        workers_pool::WorkerPool=DEFAULT_POOL,
                        task_group_id::Union{String, Nothing}=nothing)

    if isempty(collection)
        return init
    end

    # Get a unique task group ID if not provided
    group_id = if task_group_id === nothing
        string("parallel_reduce_", hash(f), "_", hash(op), "_", Dates.format(now(), "yyyymmddHHMMSSsss"))
    else
        task_group_id
    end

    # Create or get task group
    task_group = if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id]
    else
        TASK_GROUPS[group_id] = TaskGroup(group_id)
        TASK_GROUPS[group_id]
    end

    # Update metrics
    Metrics.record_metric("parallel_tasks_total", length(collection),
                         labels=Dict("task_type" => "reduce"))

    # Track execution start time
    start_time = time()

    # Use @distributed for parallel reduction
    result = @distributed (op) for item in collection
        # Track item processing time
        item_start = time()

        # Process the item
        result = f(item)

        # Calculate execution time
        execution_time_ms = (time() - item_start) * 1000

        # Return the processed result for reduction
        result
    end

    # Apply the initial value to the result
    final_result = op(init, result)

    # Calculate total execution time
    execution_time = time() - start_time

    # Update task group
    if haskey(TASK_GROUPS, group_id)
        TASK_GROUPS[group_id].end_time = now()

        # Record metrics
        Metrics.record_metric("task_group_duration_seconds", execution_time,
                             labels=Dict("group_id" => group_id))
    end

    # Record execution time metric
    Metrics.record_metric("parallel_task_duration_seconds", execution_time,
                         labels=Dict("task_type" => "reduce"))

    return final_result
end

"""
    distribute_task(f, args...; worker_id=nothing, workers_pool=DEFAULT_POOL)

Distribute a task to a worker process.
"""
function distribute_task(f, args...;
                        worker_id::Union{Int, Nothing}=nothing,
                        workers_pool::WorkerPool=DEFAULT_POOL)

    # Find an available worker
    worker = if worker_id !== nothing
        # Check if the specified worker is available
        if worker_id in workers_pool.workers && !workers_pool.busy[worker_id]
            worker_id
        else
            # Find any available worker
            findfirst(w -> !workers_pool.busy[w], workers_pool.workers)
        end
    else
        # Find any available worker
        findfirst(w -> !workers_pool.busy[w], workers_pool.workers)
    end

    if worker === nothing
        # All workers are busy, use any worker
        worker = rand(workers_pool.workers)
    end

    # Mark worker as busy
    workers_pool.busy[worker] = true

    # Update metrics
    busy_count = count(values(workers_pool.busy))
    Metrics.record_metric("workers_busy", busy_count)

    # Track execution start time
    start_time = time()

    # Distribute the task to the worker
    future = @spawnat worker begin
        # Track execution time and memory
        task_start = time()

        # Execute the function
        result = f(args...)

        # Calculate execution metrics
        execution_time_ms = (time() - task_start) * 1000
        memory_used_bytes = Base.summarysize(result) # Approximate

        # Return result with metadata
        DistributedResult(
            result,
            myid(),
            execution_time_ms,
            memory_used_bytes,
            Dict{String, Any}()
        )
    end

    # Add a finalizer to mark the worker as available when the task completes
    finalizer(future) do _
        # Only update if the worker is still in the pool
        if worker in workers_pool.workers
            workers_pool.busy[worker] = false

            # Update metrics
            busy_count = count(values(workers_pool.busy))
            Metrics.record_metric("workers_busy", busy_count)
        end

        # Record execution time
        execution_time = time() - start_time
        Metrics.record_metric("parallel_task_duration_seconds", execution_time,
                             labels=Dict("task_type" => "distributed_task"))
    end

    # Add to pool's task list
    push!(workers_pool.tasks, future)

    # Update metrics
    Metrics.record_metric("parallel_tasks_total", 1,
                         labels=Dict("task_type" => "distributed_task"))

    return future
end

"""
    distribute_data(data, workers=workers())

Distribute data to multiple worker processes.
"""
function distribute_data(data, workers=workers())
    # Different distribution methods based on data type
    if isa(data, AbstractArray)
        # Use SharedArrays for arrays
        if isa(data, Array) && (eltype(data) <: Number || eltype(data) <: Bool)
            # Create a shared array of the same type and size
            shared_data = SharedArray{eltype(data)}(size(data)..., init=false, pids=workers)

            # Copy data to the shared array
            shared_data[:] = data[:]

            return shared_data
        else
            # Use distributed references for other types
            refs = Dict{Int, Future}()

            # Split data into chunks for each worker
            chunk_size = max(1, ceil(Int, length(data) / length(workers)))
            chunks = [data[i:min(i+chunk_size-1, length(data))] for i in 1:chunk_size:length(data)]

            # Distribute chunks to workers
            for (i, worker) in enumerate(workers)
                if i <= length(chunks)
                    refs[worker] = @spawnat worker chunks[i]
                end
            end

            return refs
        end
    else
        # For non-array data, just copy to all workers
        refs = Dict{Int, Future}()

        for worker in workers
            refs[worker] = @spawnat worker deepcopy(data)
        end

        return refs
    end
end

"""
    distributed_calculation(f, data; workers_pool=DEFAULT_POOL, chunks=nothing)

Perform a distributed calculation on data across multiple workers.
"""
function distributed_calculation(f, data;
                               workers_pool::WorkerPool=DEFAULT_POOL,
                               chunks::Union{Int, Nothing}=nothing)

    # Determine the number of chunks to use
    num_chunks = if chunks !== nothing
        chunks
    else
        min(length(workers_pool.workers), length(data))
    end

    # Create chunks for distribution
    chunk_size = max(1, ceil(Int, length(data) / num_chunks))
    data_chunks = [data[i:min(i+chunk_size-1, length(data))] for i in 1:chunk_size:length(data)]

    # Track execution start time
    start_time = time()

    # Track profile information
    profile_id = Profiler.start_profiling("distributed_calculation",
                                         operations=["chunking", "distribution", "processing", "collection"])

    # Add profile point for chunking phase
    Profiler.add_profile_point(profile_id, "distributed_calculation", "chunking",
                              metadata=Dict("num_chunks" => num_chunks))

    # Update metrics
    Metrics.record_metric("parallel_tasks_total", num_chunks,
                         labels=Dict("task_type" => "distributed_calculation"))

    # Add profile point for distribution phase
    Profiler.add_profile_point(profile_id, "distributed_calculation", "distribution")

    # Process each chunk on a worker
    futures = Future[]

    for (i, chunk) in enumerate(data_chunks)
        # Find a worker for this chunk
        worker_idx = (i - 1) % length(workers_pool.workers) + 1
        worker = workers_pool.workers[worker_idx]

        # Distribute the chunk processing
        future = @spawnat worker begin
            # Track execution time and memory
            chunk_start = time()

            # Process the chunk
            result = f(chunk)

            # Calculate execution metrics
            execution_time_ms = (time() - chunk_start) * 1000
            memory_used_bytes = Base.summarysize(result) # Approximate

            # Return result with metadata
            DistributedResult(
                result,
                myid(),
                execution_time_ms,
                memory_used_bytes,
                Dict{String, Any}("chunk_index" => i, "chunk_size" => length(chunk))
            )
        end

        push!(futures, future)
    end

    # Add profile point for processing phase
    Profiler.add_profile_point(profile_id, "distributed_calculation", "processing")

    # Collect results
    results = [fetch(f) for f in futures]

    # Add profile point for collection phase
    Profiler.add_profile_point(profile_id, "distributed_calculation", "collection")

    # Calculate total execution time
    execution_time = time() - start_time

    # Stop profiling
    Profiler.stop_profiling(profile_id)

    # Record execution time metric
    Metrics.record_metric("parallel_task_duration_seconds", execution_time,
                         labels=Dict("task_type" => "distributed_calculation"))

    return results
end

# Macros for parallelism

"""
    @parallel(expr)

Execute an expression in parallel.
"""
macro parallel(expr)
    return quote
        # Wrap the expression to execute in parallel
        @distributed for i in 1:Distributed.nworkers()
            if i == myid() - 1  # Worker IDs start at 2
                $(esc(expr))
            end
        end
    end
end

"""
    @distributed_task(expr)

Execute an expression as a distributed task.
"""
macro distributed_task(expr)
    return quote
        # Wrap the expression as a distributed task
        distribute_task(() -> $(esc(expr)))
    end
end

"""
    @with_workers(pool, expr)

Execute an expression with a specific worker pool.
"""
macro with_workers(pool, expr)
    return quote
        local workers_pool = $(esc(pool))
        local worker_ids = workers_pool.workers

        # Execute the expression using the specified worker pool
        @sync begin
            for worker_id in worker_ids
                @async remotecall_wait(worker_id) do
                    $(esc(expr))
                end
            end
        end
    end
end

end # module
