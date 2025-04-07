module UserModules

using JSON
using Dates
using Statistics
using Base.Filesystem

# Export functionality
export register_module, load_user_modules, list_user_modules, get_user_module

# Global registry of user modules
const USER_MODULES = Dict{String, Module}()
const USER_MODULE_PATHS = Dict{String, String}()
const USER_MODULE_METADATA = Dict{String, Dict{String, Any}}()

"""
    register_module(name::String, module::Module, path::String, metadata::Dict{String, Any})

Register a user-defined module with the system.
"""
function register_module(name::String, mod::Module, path::String, metadata::Dict{String, Any}=Dict{String, Any}())
    if haskey(USER_MODULES, name)
        @warn "Module with name '$name' already exists. Overwriting."
    end
    
    USER_MODULES[name] = mod
    USER_MODULE_PATHS[name] = path
    USER_MODULE_METADATA[name] = metadata
    
    @info "Registered user module: $name"
    return true
end

"""
    load_user_modules(directory::String="user_modules")

Load all user-defined modules from the specified directory.
"""
function load_user_modules(directory::String="user_modules")
    # Ensure the user modules directory exists
    user_modules_dir = joinpath(dirname(dirname(@__FILE__)), directory)
    
    if !isdir(user_modules_dir)
        mkpath(user_modules_dir)
        @info "Created user modules directory: $user_modules_dir"
        return Dict{String, Module}()
    end
    
    # Load each module in the directory
    loaded_modules = Dict{String, Module}()
    
    for item in readdir(user_modules_dir)
        item_path = joinpath(user_modules_dir, item)
        
        # Skip non-directories
        if !isdir(item_path)
            continue
        end
        
        # Check if this is a valid Julia module (has a main file with the same name)
        module_file = joinpath(item_path, "$item.jl")
        
        if isfile(module_file)
            try
                # Include the module file
                module_expr = Meta.parse("module $item include(\"$module_file\") end")
                
                # Evaluate to create the module
                mod = Base.eval(Main, module_expr)
                
                # Extract metadata if available
                metadata = Dict{String, Any}()
                metadata_file = joinpath(item_path, "metadata.json")
                
                if isfile(metadata_file)
                    metadata = JSON.parsefile(metadata_file)
                end
                
                # Register the module
                register_module(item, mod, item_path, metadata)
                loaded_modules[item] = mod
                
                @info "Loaded user module: $item"
            catch e
                @error "Failed to load user module $item: $e"
            end
        end
    end
    
    @info "Loaded $(length(loaded_modules)) user modules"
    return loaded_modules
end

"""
    create_user_module_template(name::String, directory::String="user_modules")

Create a template for a new user module.
"""
function create_user_module_template(name::String, directory::String="user_modules")
    # Ensure the user modules directory exists
    user_modules_dir = joinpath(dirname(dirname(@__FILE__)), directory)
    
    if !isdir(user_modules_dir)
        mkpath(user_modules_dir)
    end
    
    # Create module directory
    module_dir = joinpath(user_modules_dir, name)
    
    if isdir(module_dir)
        @warn "Module directory already exists: $module_dir"
        return false
    end
    
    mkpath(module_dir)
    
    # Create module file
    module_file = joinpath(module_dir, "$name.jl")
    
    open(module_file, "w") do io
        write(io, """
        module $name

        using JuliaOS
        using JuliaOS.SwarmManager.Algorithms

        # Export your public functions and types
        export example_function

        # Define your module functionality
        function example_function()
            println("Hello from $name module!")
            return "Success"
        end

        # Initialize function (optional)
        function __init__()
            # This runs when the module is loaded
            @info "$name module initialized"
        end

        end # module
        """)
    end
    
    # Create metadata file
    metadata_file = joinpath(module_dir, "metadata.json")
    
    open(metadata_file, "w") do io
        write(io, JSON.json(Dict(
            "name" => name,
            "description" => "A user-defined module for JuliaOS",
            "author" => "Your Name",
            "version" => "0.1.0",
            "dependencies" => [],
            "created_at" => string(Dates.now())
        ), 4))
    end
    
    # Create README file
    readme_file = joinpath(module_dir, "README.md")
    
    open(readme_file, "w") do io
        write(io, """
        # $name

        A user-defined module for JuliaOS.

        ## Usage

        ```julia
        using JuliaOS.UserModules

        # Load your module
        user_module = get_user_module("$name")

        # Call your module's functions
        user_module.example_function()
        ```

        ## Configuration

        Edit the `metadata.json` file to update module information.
        """)
    end
    
    @info "Created user module template: $name in $module_dir"
    return true
end

"""
    list_user_modules()

List all registered user modules with their metadata.
"""
function list_user_modules()
    return Dict(name => Dict(
        "path" => USER_MODULE_PATHS[name],
        "metadata" => USER_MODULE_METADATA[name]
    ) for name in keys(USER_MODULES))
end

"""
    get_user_module(name::String)

Get a specific user module by name.
"""
function get_user_module(name::String)
    if !haskey(USER_MODULES, name)
        error("User module not found: $name")
    end
    
    return USER_MODULES[name]
end

# Automatically load user modules when this module is included
function __init__()
    @info "Initializing UserModules system"
    load_user_modules()
end

end # module 