"""
    Storage interface for JuliaOS

This module defines the interface for storage providers in JuliaOS.
"""

module StorageInterface

export StorageProvider, save, load, delete, list

"""
    StorageProvider

Abstract type for storage providers.
"""
abstract type StorageProvider end

"""
    save(provider::StorageProvider, key::String, data::Any)

Save data to storage.
"""
function save(provider::StorageProvider, key::String, data::Any)
    error("save not implemented for $(typeof(provider))")
end

"""
    load(provider::StorageProvider, key::String)

Load data from storage.
"""
function load(provider::StorageProvider, key::String)
    error("load not implemented for $(typeof(provider))")
end

"""
    delete(provider::StorageProvider, key::String)

Delete data from storage.
"""
function delete(provider::StorageProvider, key::String)
    error("delete not implemented for $(typeof(provider))")
end

"""
    list(provider::StorageProvider, prefix::String="")

List keys in storage.
"""
function list(provider::StorageProvider, prefix::String="")
    error("list not implemented for $(typeof(provider))")
end

end # module StorageInterface
