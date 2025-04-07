# User Modules Directory

This directory is where you can create and store your own custom modules for the JuliaOS framework.

## How to Create a Module

To create a new module:

1. Create a subdirectory with your module name (e.g., `MyModule`)
2. Create a main Julia file with the same name (e.g., `MyModule/MyModule.jl`)
3. Add a `metadata.json` file with module information
4. Optionally add a `README.md` file with documentation

Alternatively, you can use the built-in template generator:

```julia
using JuliaOS.UserModules

# Create a new module template
create_user_module_template("MyModule")
```

## Module Structure

A user module should have the following structure:

```
user_modules/
└── MyModule/
    ├── MyModule.jl        # Main module file
    ├── metadata.json      # Module metadata
    └── README.md          # Documentation
```

## Using Your Modules

To use your modules:

```julia
using JuliaOS
using JuliaOS.UserModules

# Load all user modules
load_user_modules()

# Get a specific module
my_module = get_user_module("MyModule")

# Use the module's functionality
my_module.some_function()
```

## Examples

Check out the example modules in the `examples/user_modules/` directory:

- `CustomTrading`: Custom trading strategy module
- Other examples...

## More Information

See the full documentation in `docs/Creating_User_Modules.md` for detailed instructions and best practices. 