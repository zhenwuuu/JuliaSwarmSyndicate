
#!/usr/bin/env julia

"""
Script to analyze Julia modules and generate basic test scaffolding for modules that lack tests.
This helps ensure all modules have at least basic unit tests.

Usage:
    julia scripts/generate-julia-tests.jl
"""

using Pkg

# Make sure we're at the project root
try
    Pkg.activate("julia")
    @info "Activated Julia project"
catch e
    @error "Failed to activate project" exception=e
    exit(1)
end

# Helper to determine if a file is a module
function is_module_file(filepath)
    # Skip test files, scripts, and non-Julia files
    if endswith(filepath, "Test.jl") || endswith(filepath, "_test.jl") || 
       !endswith(filepath, ".jl") || occursin("test/", filepath)
        return false
    end
    
    # Read the first few lines to check if it looks like a module
    try
        open(filepath) do file
            lines = readlines(file)
            # Look for module definition in first 30 lines
            for i in 1:min(30, length(lines))
                if occursin(r"^module\s+[A-Za-z]", lines[i])
                    return true
                end
            end
        end
    catch e
        @warn "Error reading file $filepath" exception=e
    end
    
    return false
end

# Extract module name from file
function extract_module_name(filepath)
    try
        open(filepath) do file
            for line in eachline(file)
                m = match(r"^module\s+([A-Za-z][A-Za-z0-9_]*)", line)
                if m !== nothing
                    return m.captures[1]
                end
            end
        end
    catch e
        @warn "Error extracting module name from $filepath" exception=e
    end
    
    # Fallback: use filename
    filename = basename(filepath)
    return replace(filename, ".jl" => "")
end

# Check if a module already has tests
function has_tests(module_name, src_dir, test_dir)
    # Check for test file patterns
    test_patterns = [
        joinpath(test_dir, "$(module_name)Test.jl"),
        joinpath(test_dir, "$(module_name)_test.jl"),
        joinpath(test_dir, "$(lowercase(module_name))_test.jl"),
        joinpath(test_dir, "test_$(lowercase(module_name)).jl")
    ]
    
    for pattern in test_patterns
        if isfile(pattern)
            return true
        end
    end
    
    # Also check for tests in the module directory
    if isdir(joinpath(src_dir, module_name))
        module_test_dir = joinpath(src_dir, module_name, "test")
        if isdir(module_test_dir) && !isempty(readdir(module_test_dir))
            return true
        end
    end
    
    return false
end

# Get public exports from a module file
function extract_exports(filepath)
    exports = String[]
    
    try
        open(filepath) do file
            in_export_block = false
            export_line = ""
            
            for line in eachline(file)
                # Skip comments
                stripped = strip(line)
                if startswith(stripped, "#") || isempty(stripped)
                    continue
                end
                
                # Check for export statements
                if occursin(r"^export\s+", stripped)
                    if in_export_block
                        export_line *= " " * stripped
                    else
                        export_line = stripped
                        in_export_block = true
                    end
                    
                    # End of export block
                    if !occursin(r",\s*$", stripped)
                        # Extract names from export block
                        export_match = match(r"export\s+(.*)", export_line)
                        if export_match !== nothing
                            names_str = export_match.captures[1]
                            # Split and clean up names
                            for name in split(names_str, ",")
                                clean_name = strip(name)
                                if !isempty(clean_name)
                                    push!(exports, clean_name)
                                end
                            end
                        end
                        
                        in_export_block = false
                        export_line = ""
                    end
                elseif in_export_block
                    export_line *= " " * stripped
                    
                    # End of export block
                    if !occursin(r",\s*$", stripped)
                        # Extract names from export block
                        export_match = match(r"export\s+(.*)", export_line)
                        if export_match !== nothing
                            names_str = export_match.captures[1]
                            # Split and clean up names
                            for name in split(names_str, ",")
                                clean_name = strip(name)
                                if !isempty(clean_name)
                                    push!(exports, clean_name)
                                end
                            end
                        end
                        
                        in_export_block = false
                        export_line = ""
                    end
                end
                
                # Also look for struct and function definitions
                if occursin(r"^(struct|mutable struct)\s+([A-Za-z][A-Za-z0-9_]*)", line)
                    m = match(r"^(?:mutable\s+)?struct\s+([A-Za-z][A-Za-z0-9_]*)", line)
                    if m !== nothing && !in(m.captures[1], exports)
                        push!(exports, m.captures[1])
                    end
                elseif occursin(r"^function\s+([A-Za-z][A-Za-z0-9_!]*)", line)
                    m = match(r"^function\s+([A-Za-z][A-Za-z0-9_!]*)", line)
                    if m !== nothing && !in(m.captures[1], exports)
                        push!(exports, m.captures[1])
                    end
                end
            end
        end
    catch e
        @warn "Error extracting exports from $filepath" exception=e
    end
    
    return exports
end

# Generate test file content
function generate_test_file(module_name, exports, import_path="JuliaOS.$(module_name)")
    test_template = """
    # Tests for the $module_name module

    using Test
    using JuliaOS
    using $import_path

    @testset "$module_name" begin
        @testset "Basic functionality" begin
            # Verify the module can be loaded
            @test isdefined(JuliaOS, Symbol("$module_name"))
        end
    
    """
    
    # Add test sections for exported items
    for export_name in exports
        # Skip operators and symbols
        if occursin(r"^[A-Za-z]", export_name)
            test_template *= """
        @testset "$export_name" begin
            # Test that $export_name exists and is callable
            @test isdefined($module_name, Symbol("$export_name"))
            
            # TODO: Add specific tests for $export_name
            # Example: 
            # @test $export_name(...) == expected_result
        end
    
    """
        end
    end
    
    # Close the main testset
    test_template *= "end\n"
    
    return test_template
end

# Main function to scan source directories and generate tests
function main()
    # Base directories
    project_dir = joinpath(pwd(), "julia")
    src_dir = joinpath(project_dir, "src")
    test_dir = joinpath(project_dir, "test")
    
    # Ensure test directory exists
    if !isdir(test_dir)
        mkdir(test_dir)
    end
    
    # Find all potential module files
    julia_files = String[]
    for (root, dirs, files) in walkdir(src_dir)
        for file in files
            if endswith(file, ".jl")
                push!(julia_files, joinpath(root, file))
            end
        end
    end
    
    # Filter to actual module files
    module_files = filter(is_module_file, julia_files)
    
    # Generate tests for modules without them
    modules_without_tests = 0
    modules_with_tests = 0
    
    for module_file in module_files
        module_name = extract_module_name(module_file)
        
        # Ensure the module name was extracted correctly
        if isempty(module_name)
            @warn "Could not determine module name for $module_file, skipping"
            continue
        end
        
        # Check if it already has tests
        if has_tests(module_name, src_dir, test_dir)
            @info "Module $module_name already has tests"
            modules_with_tests += 1
            continue
        end
        
        # Extract exports
        exports = extract_exports(module_file)
        
        # Determine proper import path (namespace)
        rel_path = replace(module_file, src_dir * "/" => "")
        parts = split(rel_path, "/")
        
        import_path = if length(parts) > 1
            # For nested modules, use the full path
            "JuliaOS." * join(map(p -> replace(p, ".jl" => ""), parts[1:end-1]), ".")
        else
            "JuliaOS"
        end
        
        # Generate test file
        test_content = generate_test_file(module_name, exports, import_path)
        test_file_path = joinpath(test_dir, "$(lowercase(module_name))_test.jl")
        
        # Write test file
        try
            open(test_file_path, "w") do file
                write(file, test_content)
            end
            @info "Generated test file for $module_name at $test_file_path"
            modules_without_tests += 1
        catch e
            @error "Failed to write test file for $module_name" exception=e
        end
    end
    
    # Summary
    total_modules = modules_with_tests + modules_without_tests
    @info "Test generation complete" total_modules modules_with_tests new_tests_generated=modules_without_tests
    
    if modules_without_tests > 0
        @info """
        ------------------------------------------------------------------------------
        Generated $modules_without_tests new test files.
        
        Next steps:
        1. Review the generated test files and expand them with meaningful tests
        2. Run the tests with: cd julia && julia run_tests.jl
        3. Check the coverage report to identify areas needing more tests
        ------------------------------------------------------------------------------
        """
    else
        @info "All modules already have test files. Good job!"
    end
end

# Run the main function
main()
