#!/usr/bin/env julia

"""
    index_codebase.jl

This script indexes the JuliaOS codebase by scanning all Julia files,
extracting key information, and creating a searchable index.

Usage:
    julia index_codebase.jl [output_path]

Arguments:
    output_path: Optional path to save the index. Defaults to "codebase_index.json"
"""

using JSON
using Dates

# Define the structure for storing file information
struct FileInfo
    path::String
    module_name::String
    imports::Vector{String}
    exports::Vector{String}
    functions::Vector{Dict{String, Any}}
    types::Vector{Dict{String, Any}}
    constants::Vector{Dict{String, Any}}
    docstring::String
    last_modified::String
end

"""
    extract_module_name(content::String)::String

Extract the module name from file content.
"""
function extract_module_name(content::String)::String
    module_match = match(r"module\s+([A-Za-z][A-Za-z0-9_]*)", content)
    return module_match === nothing ? "" : module_match.captures[1]
end

"""
    extract_imports(content::String)::Vector{String}

Extract imported modules from file content.
"""
function extract_imports(content::String)::Vector{String}
    imports = String[]
    
    # Match using, import statements
    using_matches = eachmatch(r"using\s+([A-Za-z0-9_.,: ]+)", content)
    for m in using_matches
        modules = split(m.captures[1], r"[,\s]+")
        for mod in modules
            if !isempty(mod) && !occursin(r"^[.,:]", mod)
                push!(imports, strip(mod))
            end
        end
    end
    
    import_matches = eachmatch(r"import\s+([A-Za-z0-9_.,: ]+)", content)
    for m in import_matches
        modules = split(m.captures[1], r"[,\s]+")
        for mod in modules
            if !isempty(mod) && !occursin(r"^[.,:]", mod)
                push!(imports, strip(mod))
            end
        end
    end
    
    return unique(imports)
end

"""
    extract_exports(content::String)::Vector{String}

Extract exported symbols from file content.
"""
function extract_exports(content::String)::Vector{String}
    exports = String[]
    
    # Match export statements
    export_matches = eachmatch(r"export\s+([A-Za-z0-9_,\s]+)", content)
    for m in export_matches
        symbols = split(m.captures[1], r"[,\s]+")
        for symbol in symbols
            if !isempty(symbol)
                push!(exports, strip(symbol))
            end
        end
    end
    
    return unique(exports)
end

"""
    extract_functions(content::String)::Vector{Dict{String, Any}}

Extract function definitions from file content.
"""
function extract_functions(content::String)::Vector{Dict{String, Any}}
    functions = Dict{String, Any}[]
    
    # Match function definitions
    # This regex captures both standard and compact function definitions
    function_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?function\s+([A-Za-z0-9_!]+(?:\{[^}]*\})?)\s*(\([^)]*\))?.*?end"s, content)
    for m in function_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        name = m.captures[3]
        signature = m.captures[4] !== nothing ? strip(m.captures[4]) : "()"
        
        push!(functions, Dict(
            "name" => name,
            "signature" => signature,
            "docstring" => docstring
        ))
    end
    
    # Match compact function definitions
    compact_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?([A-Za-z0-9_!]+(?:\{[^}]*\})?)\s*(\([^)]*\))\s*=.*?(?:\n|$)"s, content)
    for m in compact_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        name = m.captures[3]
        signature = m.captures[4] !== nothing ? strip(m.captures[4]) : "()"
        
        # Check if this is already captured by the previous regex
        if !any(f -> f["name"] == name && f["signature"] == signature, functions)
            push!(functions, Dict(
                "name" => name,
                "signature" => signature,
                "docstring" => docstring
            ))
        end
    end
    
    return functions
end

"""
    extract_types(content::String)::Vector{Dict{String, Any}}

Extract type and struct definitions from file content.
"""
function extract_types(content::String)::Vector{Dict{String, Any}}
    types = Dict{String, Any}[]
    
    # Match struct definitions
    struct_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?(mutable\s+)?struct\s+([A-Za-z0-9_]+)(?:<:\s*([A-Za-z0-9_]+))?\s*.*?end"s, content)
    for m in struct_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        is_mutable = m.captures[3] !== nothing
        name = m.captures[4]
        supertype = m.captures[5] !== nothing ? m.captures[5] : "Any"
        
        push!(types, Dict(
            "name" => name,
            "kind" => is_mutable ? "mutable struct" : "struct",
            "supertype" => supertype,
            "docstring" => docstring
        ))
    end
    
    # Match abstract type definitions
    abstract_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?abstract\s+type\s+([A-Za-z0-9_]+)(?:<:\s*([A-Za-z0-9_]+))?"s, content)
    for m in abstract_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        name = m.captures[3]
        supertype = m.captures[4] !== nothing ? m.captures[4] : "Any"
        
        push!(types, Dict(
            "name" => name,
            "kind" => "abstract type",
            "supertype" => supertype,
            "docstring" => docstring
        ))
    end
    
    # Match primitive type definitions
    primitive_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?primitive\s+type\s+([A-Za-z0-9_]+)(?:<:\s*([A-Za-z0-9_]+))?\s+(\d+)\s+end"s, content)
    for m in primitive_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        name = m.captures[3]
        supertype = m.captures[4] !== nothing ? m.captures[4] : "Any"
        bits = parse(Int, m.captures[5])
        
        push!(types, Dict(
            "name" => name,
            "kind" => "primitive type",
            "supertype" => supertype,
            "bits" => bits,
            "docstring" => docstring
        ))
    end
    
    return types
end

"""
    extract_constants(content::String)::Vector{Dict{String, Any}}

Extract constant definitions from file content.
"""
function extract_constants(content::String)::Vector{Dict{String, Any}}
    constants = Dict{String, Any}[]
    
    # Match constant definitions
    const_matches = eachmatch(r"(\"\"\"(.*?)\"\"\"\s+)?const\s+([A-Za-z0-9_]+)\s*=\s*([^\n]+)"s, content)
    for m in const_matches
        docstring = m.captures[2] !== nothing ? strip(m.captures[2]) : ""
        name = m.captures[3]
        value = strip(m.captures[4])
        
        push!(constants, Dict(
            "name" => name,
            "value" => value,
            "docstring" => docstring
        ))
    end
    
    return constants
end

"""
    extract_module_docstring(content::String)::String

Extract the module-level docstring from file content.
"""
function extract_module_docstring(content::String)::String
    # Look for a docstring before the module declaration
    module_match = match(r"(\"\"\"(.*?)\"\"\"\s+)?module\s+([A-Za-z][A-Za-z0-9_]*)"s, content)
    if module_match !== nothing && module_match.captures[2] !== nothing
        return strip(module_match.captures[2])
    end
    return ""
end

"""
    process_file(file_path::String)::Union{FileInfo, Nothing}

Process a single Julia file and extract its information.
"""
function process_file(file_path::String)::Union{FileInfo, Nothing}
    try
        content = read(file_path, String)
        
        # Extract information
        module_name = extract_module_name(content)
        imports = extract_imports(content)
        exports = extract_exports(content)
        functions = extract_functions(content)
        types = extract_types(content)
        constants = extract_constants(content)
        docstring = extract_module_docstring(content)
        last_modified = string(Dates.unix2datetime(mtime(file_path)))
        
        return FileInfo(
            file_path,
            module_name,
            imports,
            exports,
            functions,
            types,
            constants,
            docstring,
            last_modified
        )
    catch e
        @warn "Error processing file $file_path: $e"
        return nothing
    end
end

"""
    find_julia_files(dir::String)::Vector{String}

Find all Julia files in a directory and its subdirectories.
"""
function find_julia_files(dir::String)::Vector{String}
    julia_files = String[]
    
    for (root, dirs, files) in walkdir(dir)
        for file in files
            if endswith(file, ".jl")
                push!(julia_files, joinpath(root, file))
            end
        end
    end
    
    return julia_files
end

"""
    index_codebase(root_dir::String, output_path::String)

Index the codebase starting from root_dir and save the index to output_path.
"""
function index_codebase(root_dir::String, output_path::String)
    println("Indexing codebase at $root_dir...")
    
    # Find all Julia files
    julia_files = find_julia_files(root_dir)
    println("Found $(length(julia_files)) Julia files")
    
    # Process each file
    file_infos = FileInfo[]
    for (i, file) in enumerate(julia_files)
        if i % 100 == 0
            println("Processing file $i/$(length(julia_files))")
        end
        
        file_info = process_file(file)
        if file_info !== nothing
            push!(file_infos, file_info)
        end
    end
    
    # Create index
    index = Dict{String, Any}(
        "timestamp" => string(now()),
        "file_count" => length(file_infos),
        "files" => [Dict(
            "path" => info.path,
            "module_name" => info.module_name,
            "imports" => info.imports,
            "exports" => info.exports,
            "functions" => info.functions,
            "types" => info.types,
            "constants" => info.constants,
            "docstring" => info.docstring,
            "last_modified" => info.last_modified
        ) for info in file_infos]
    )
    
    # Add module dependency graph
    module_deps = Dict{String, Vector{String}}()
    for info in file_infos
        if !isempty(info.module_name)
            module_deps[info.module_name] = info.imports
        end
    end
    index["module_dependencies"] = module_deps
    
    # Save index to file
    open(output_path, "w") do io
        JSON.print(io, index, 2)  # Pretty print with 2-space indent
    end
    
    println("Index saved to $output_path")
    return index
end

"""
    main()

Main entry point for the script.
"""
function main()
    # Parse command line arguments
    output_path = length(ARGS) > 0 ? ARGS[1] : "codebase_index.json"
    
    # Get the project root directory
    script_dir = dirname(@__FILE__)
    project_root = abspath(joinpath(script_dir, ".."))
    
    # Index the codebase
    index_codebase(project_root, output_path)
end

# Run the main function if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
