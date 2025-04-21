module KeyManager

export initialize, store_key, load_key, delete_key, list_keys, encrypt_key, decrypt_key
export generate_key_pair, create_wallet, get_address_from_private_key, sign_transaction
export KeyType, StorageMethod, KeyChain, KeyInfo

using ..EnhancedErrors
using ..StructuredLogging
using ..EnhancedConfig
using ..Auth
using ..Validation

using Dates
using SHA
using Random
using UUIDs
using Base64
using JSON

using MbedTLS: digest, MD, encrypt, decrypt, generate_key, CipherAES, CIPHER_AES_GCM, PADDING_PKCS7
using Base.Filesystem

# Key types
@enum KeyType begin
    ETHEREUM_PRIVATE_KEY
    SOLANA_PRIVATE_KEY
    BIP39_MNEMONIC
    SSH_KEY
    GENERIC_SECRET
end

# Storage methods
@enum StorageMethod begin
    FILE             # Encrypted file on disk
    SECURE_ENCLAVE   # OS-level secure enclave (when available)
    MEMORY           # In-memory only (volatile)
    HSM              # Hardware Security Module (when available)
end

# Key information structure
struct KeyInfo
    id::String
    name::String
    key_type::KeyType
    created_at::DateTime
    last_accessed::Union{DateTime, Nothing}
    metadata::Dict{String, Any}
    storage::StorageMethod
    
    function KeyInfo(id::String, name::String, key_type::KeyType, storage::StorageMethod;
                    metadata::Dict{String, Any}=Dict{String, Any}())
        return new(id, name, key_type, now(), nothing, metadata, storage)
    end
end

# KeyChain configuration
mutable struct KeyChain
    initialized::Bool
    master_key::Union{Vector{UInt8}, Nothing}
    keys::Dict{String, KeyInfo}
    storage_path::String
    default_storage::StorageMethod
    
    KeyChain() = new(
        false,
        nothing,
        Dict{String, KeyInfo}(),
        "",
        FILE
    )
end

# Singleton instance of keychain
const KEYCHAIN = KeyChain()

"""
    initialize(config=nothing)

Initialize the key management system with the given configuration.
"""
function initialize(config=nothing)
    if KEYCHAIN.initialized
        return true
    end
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "initialize")
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="initialize"
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Get configuration
            master_password = if config !== nothing && get(config, "master_password", nothing) !== nothing
                config["master_password"]
            elseif EnhancedConfig.get_value("security.key_manager.master_password", nothing) !== nothing
                EnhancedConfig.get_value("security.key_manager.master_password")
            else
                # If no master password is provided, generate a temporary one and store it in memory
                # Note: This is not secure for production use as it's lost when the application restarts
                random_bytes = rand(UInt8, 32)
                base64encode(random_bytes)
            end
            
            # Get storage path
            storage_path = if config !== nothing && get(config, "storage_path", nothing) !== nothing
                config["storage_path"]
            elseif EnhancedConfig.get_value("security.key_manager.storage_path", nothing) !== nothing
                EnhancedConfig.get_value("security.key_manager.storage_path")
            else
                joinpath(homedir(), ".juliaos", "keys")
            end
            
            # Get default storage method
            default_storage_str = if config !== nothing && get(config, "default_storage", nothing) !== nothing
                config["default_storage"]
            elseif EnhancedConfig.get_value("security.key_manager.default_storage", nothing) !== nothing
                EnhancedConfig.get_value("security.key_manager.default_storage")
            else
                "FILE"
            end
            
            default_storage = parse_storage_method(default_storage_str)
            
            # Create storage directory if it doesn't exist
            if !isdir(storage_path)
                mkpath(storage_path)
                
                # Secure the directory permissions (UNIX-like systems only)
                if Sys.isunix()
                    try
                        chmod(storage_path, 0o700)  # Read/write/execute only for owner
                    catch
                        StructuredLogging.warn("Could not set secure permissions on key storage directory",
                                             data=Dict("path" => storage_path))
                    end
                end
            end
            
            # Derive master key from master password
            salt = "JuliaOSKeyManager"  # Note: In a production system, this should be unique per installation
            master_key = derive_key(master_password, salt)
            
            # Set up keychain
            KEYCHAIN.master_key = master_key
            KEYCHAIN.storage_path = storage_path
            KEYCHAIN.default_storage = default_storage
            KEYCHAIN.initialized = true
            
            # Load existing keys from storage
            load_keychain()
            
            StructuredLogging.info("Key management system initialized",
                                  data=Dict("storage_path" => storage_path,
                                           "default_storage" => string(default_storage)))
            
            return true
        catch e
            StructuredLogging.error("Failed to initialize key management system",
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to initialize key management system",
                                                  e, context=error_context))
            end
            
            return false
        end
    end
end

"""
    store_key(name::String, key_data::Vector{UInt8}, key_type::KeyType; 
             storage::Union{StorageMethod, Nothing}=nothing, 
             metadata::Dict{String, Any}=Dict{String, Any}())

Store a cryptographic key with the given name, type, and optional metadata.
Returns the key ID if successful.
"""
function store_key(name::String, key_data::Vector{UInt8}, key_type::KeyType;
                  storage::Union{StorageMethod, Nothing}=nothing,
                  metadata::Dict{String, Any}=Dict{String, Any}())
    if !KEYCHAIN.initialized
        initialize()
    end
    
    # Use default storage method if none provided
    actual_storage = storage === nothing ? KEYCHAIN.default_storage : storage
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "store_key",
                                                     metadata=Dict("name" => name,
                                                                  "key_type" => string(key_type)))
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="store_key",
        metadata=Dict("name" => name, "key_type" => string(key_type))
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Generate a unique ID for the key
            key_id = string(uuid4())
            
            # Create key info
            key_info = KeyInfo(key_id, name, key_type, actual_storage, metadata=metadata)
            
            # Store the key info in the keychain
            KEYCHAIN.keys[key_id] = key_info
            
            # Store the actual key data (depends on storage method)
            success = if actual_storage == FILE
                store_key_to_file(key_id, key_data, key_info)
            elseif actual_storage == MEMORY
                store_key_to_memory(key_id, key_data, key_info)
            elseif actual_storage == SECURE_ENCLAVE
                store_key_to_secure_enclave(key_id, key_data, key_info)
            elseif actual_storage == HSM
                store_key_to_hsm(key_id, key_data, key_info)
            else
                false
            end
            
            if !success
                # Remove the key info if storage failed
                delete!(KEYCHAIN.keys, key_id)
                
                StructuredLogging.error("Failed to store key data",
                                       data=Dict("name" => name,
                                                "key_type" => string(key_type),
                                                "storage" => string(actual_storage)))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.StorageError("Failed to store key data",
                                                     context=error_context))
                end
            end
            
            # Save the keychain metadata
            save_keychain()
            
            StructuredLogging.info("Key stored successfully",
                                  data=Dict("id" => key_id,
                                           "name" => name,
                                           "key_type" => string(key_type),
                                           "storage" => string(actual_storage)))
            
            return key_id
        catch e
            StructuredLogging.error("Failed to store key",
                                   data=Dict("name" => name,
                                            "key_type" => string(key_type)),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to store key",
                                                      e, context=error_context))
                end
            end
        end
    end
end

"""
    store_key(name::String, key_data::String, key_type::KeyType;
             storage::Union{StorageMethod, Nothing}=nothing,
             metadata::Dict{String, Any}=Dict{String, Any}())

String wrapper for store_key.
"""
function store_key(name::String, key_data::String, key_type::KeyType;
                  storage::Union{StorageMethod, Nothing}=nothing,
                  metadata::Dict{String, Any}=Dict{String, Any}())
    return store_key(name, Vector{UInt8}(key_data), key_type; storage=storage, metadata=metadata)
end

"""
    load_key(key_id::String)

Load a cryptographic key by its ID.
Returns the key data if successful, throws an error otherwise.
"""
function load_key(key_id::String)
    if !KEYCHAIN.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "load_key",
                                                     metadata=Dict("key_id" => key_id))
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="load_key",
        metadata=Dict("key_id" => key_id)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Check if key exists
            if !haskey(KEYCHAIN.keys, key_id)
                StructuredLogging.error("Key not found",
                                       data=Dict("key_id" => key_id))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.NotFoundError("Key", key_id,
                                                      context=error_context))
                end
            end
            
            key_info = KEYCHAIN.keys[key_id]
            
            # Load key data (depends on storage method)
            key_data = if key_info.storage == FILE
                load_key_from_file(key_id, key_info)
            elseif key_info.storage == MEMORY
                load_key_from_memory(key_id, key_info)
            elseif key_info.storage == SECURE_ENCLAVE
                load_key_from_secure_enclave(key_id, key_info)
            elseif key_info.storage == HSM
                load_key_from_hsm(key_id, key_info)
            else
                nothing
            end
            
            if key_data === nothing
                StructuredLogging.error("Failed to load key data",
                                       data=Dict("key_id" => key_id,
                                                "name" => key_info.name,
                                                "storage" => string(key_info.storage)))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.StorageError("Failed to load key data",
                                                     context=error_context))
                end
            end
            
            # Update last accessed time
            new_key_info = KeyInfo(
                key_info.id,
                key_info.name,
                key_info.key_type,
                key_info.storage,
                metadata=key_info.metadata
            )
            KEYCHAIN.keys[key_id] = new_key_info
            
            # Save the keychain metadata
            save_keychain()
            
            StructuredLogging.debug("Key loaded successfully",
                                   data=Dict("key_id" => key_id,
                                            "name" => key_info.name))
            
            return key_data
        catch e
            StructuredLogging.error("Failed to load key",
                                   data=Dict("key_id" => key_id),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to load key",
                                                      e, context=error_context))
                end
            end
        end
    end
end

"""
    delete_key(key_id::String)

Delete a cryptographic key by its ID.
Returns true if successful, false otherwise.
"""
function delete_key(key_id::String)
    if !KEYCHAIN.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "delete_key",
                                                     metadata=Dict("key_id" => key_id))
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="delete_key",
        metadata=Dict("key_id" => key_id)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Check if key exists
            if !haskey(KEYCHAIN.keys, key_id)
                StructuredLogging.warn("Key not found",
                                      data=Dict("key_id" => key_id))
                
                return false
            end
            
            key_info = KEYCHAIN.keys[key_id]
            
            # Delete key data (depends on storage method)
            success = if key_info.storage == FILE
                delete_key_from_file(key_id, key_info)
            elseif key_info.storage == MEMORY
                delete_key_from_memory(key_id, key_info)
            elseif key_info.storage == SECURE_ENCLAVE
                delete_key_from_secure_enclave(key_id, key_info)
            elseif key_info.storage == HSM
                delete_key_from_hsm(key_id, key_info)
            else
                false
            end
            
            if !success
                StructuredLogging.warn("Failed to delete key data",
                                      data=Dict("key_id" => key_id,
                                               "name" => key_info.name,
                                               "storage" => string(key_info.storage)))
            end
            
            # Remove the key info from the keychain
            delete!(KEYCHAIN.keys, key_id)
            
            # Save the keychain metadata
            save_keychain()
            
            StructuredLogging.info("Key deleted",
                                  data=Dict("key_id" => key_id,
                                           "name" => key_info.name))
            
            return true
        catch e
            StructuredLogging.error("Failed to delete key",
                                   data=Dict("key_id" => key_id),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to delete key",
                                                  e, context=error_context))
            end
            
            return false
        end
    end
end

"""
    list_keys()

List all keys in the keychain.
Returns a dictionary of key IDs to key info.
"""
function list_keys()
    if !KEYCHAIN.initialized
        initialize()
    end
    
    # Return a copy of the keys dictionary to prevent modification
    result = Dict{String, Dict{String, Any}}()
    
    for (key_id, key_info) in KEYCHAIN.keys
        result[key_id] = Dict{String, Any}(
            "id" => key_info.id,
            "name" => key_info.name,
            "key_type" => string(key_info.key_type),
            "created_at" => string(key_info.created_at),
            "last_accessed" => key_info.last_accessed === nothing ? nothing : string(key_info.last_accessed),
            "metadata" => key_info.metadata,
            "storage" => string(key_info.storage)
        )
    end
    
    return result
end

"""
    encrypt_key(plaintext::Vector{UInt8}, key::Vector{UInt8})

Encrypt a key with another key.
Returns the encrypted key.
"""
function encrypt_key(plaintext::Vector{UInt8}, key::Vector{UInt8})
    # Generate a random IV
    iv = rand(UInt8, 16)
    
    # Encrypt the key
    cipher = CipherAES(copy(key), CIPHER_AES_GCM, iv_size=16)
    encrypted = encrypt(cipher, plaintext, padding=PADDING_PKCS7, iv=iv)
    
    # Combine IV and encrypted key
    return [iv; encrypted]
end

"""
    decrypt_key(ciphertext::Vector{UInt8}, key::Vector{UInt8})

Decrypt a key with another key.
Returns the decrypted key.
"""
function decrypt_key(ciphertext::Vector{UInt8}, key::Vector{UInt8})
    # Extract IV and encrypted key
    iv = ciphertext[1:16]
    encrypted = ciphertext[17:end]
    
    # Decrypt the key
    cipher = CipherAES(copy(key), CIPHER_AES_GCM, iv_size=16)
    decrypted = decrypt(cipher, encrypted, padding=PADDING_PKCS7, iv=iv)
    
    return decrypted
end

"""
    derive_key(password::String, salt::String)

Derive a key from a password and salt using PBKDF2.
"""
function derive_key(password::String, salt::String)
    # Use SHA-256 to derive a key from the password and salt
    # Note: In a production system, we should use a proper PBKDF2 implementation
    # with a high iteration count
    
    # Convert password and salt to bytes
    password_bytes = Vector{UInt8}(password)
    salt_bytes = Vector{UInt8}(salt)
    
    # Combine password and salt
    combined = [password_bytes; salt_bytes]
    
    # Hash the combined bytes (multiple rounds for better security)
    hashed = digest(MD.MD_SHA256, combined)
    for _ in 1:10000  # 10,000 rounds
        hashed = digest(MD.MD_SHA256, hashed)
    end
    
    return hashed
end

"""
    generate_key_pair(key_type::KeyType)

Generate a new key pair for the specified key type.
Returns a tuple of (private_key, public_key) and metadata.
"""
function generate_key_pair(key_type::KeyType)
    if key_type == ETHEREUM_PRIVATE_KEY
        # Generate a random private key
        private_key = rand(UInt8, 32)
        
        # TODO: Derive the public key and address
        # This is a placeholder - in a real implementation, we would use a proper
        # Ethereum library to derive the public key and address from the private key
        metadata = Dict{String, Any}(
            "address" => "0x" * bytes2hex(digest(MD.MD_SHA256, private_key))[1:40]
        )
        
        return private_key, metadata
    elseif key_type == SOLANA_PRIVATE_KEY
        # Generate a random private key (placeholder)
        private_key = rand(UInt8, 64)
        
        # TODO: Derive the public key and address
        metadata = Dict{String, Any}(
            "address" => bytes2hex(digest(MD.MD_SHA256, private_key))[1:44]
        )
        
        return private_key, metadata
    elseif key_type == SSH_KEY
        # Generate a random private key (placeholder)
        private_key = rand(UInt8, 1024)
        
        # TODO: Derive the public key
        metadata = Dict{String, Any}(
            "fingerprint" => bytes2hex(digest(MD.MD_SHA256, private_key))[1:40]
        )
        
        return private_key, metadata
    elseif key_type == BIP39_MNEMONIC
        # Generate a random seed (placeholder)
        seed = rand(UInt8, 32)
        
        # TODO: Convert to BIP39 mnemonic
        # This is a placeholder - in a real implementation, we would use a proper
        # BIP39 library to generate the mnemonic
        mnemonic_words = [
            "abandon", "ability", "able", "about", "above", "absent",
            "absorb", "abstract", "absurd", "abuse", "access", "accident"
        ]
        mnemonic = join(mnemonic_words, " ")
        
        metadata = Dict{String, Any}(
            "seed" => base64encode(seed)
        )
        
        return Vector{UInt8}(mnemonic), metadata
    else  # GENERIC_SECRET
        # Generate a random secret
        secret = rand(UInt8, 32)
        
        metadata = Dict{String, Any}()
        
        return secret, metadata
    end
end

"""
    create_wallet(name::String, key_type::KeyType; storage::Union{StorageMethod, Nothing}=nothing)

Create a new wallet for the specified key type.
Returns the key ID and wallet address if successful.
"""
function create_wallet(name::String, key_type::KeyType; storage::Union{StorageMethod, Nothing}=nothing)
    if !KEYCHAIN.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "create_wallet",
                                                     metadata=Dict("name" => name,
                                                                  "key_type" => string(key_type)))
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="create_wallet",
        metadata=Dict("name" => name, "key_type" => string(key_type))
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Generate a new key pair
            private_key, metadata = generate_key_pair(key_type)
            
            # Store the key
            key_id = store_key(name, private_key, key_type, storage=storage, metadata=metadata)
            
            StructuredLogging.info("Wallet created",
                                  data=Dict("key_id" => key_id,
                                           "name" => name,
                                           "key_type" => string(key_type),
                                           "address" => get(metadata, "address", "unknown")))
            
            return Dict{String, Any}(
                "key_id" => key_id,
                "name" => name,
                "address" => get(metadata, "address", nothing),
                "metadata" => metadata
            )
        catch e
            StructuredLogging.error("Failed to create wallet",
                                   data=Dict("name" => name,
                                            "key_type" => string(key_type)),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to create wallet",
                                                      e, context=error_context))
                end
            end
        end
    end
end

"""
    get_address_from_private_key(private_key::Vector{UInt8}, key_type::KeyType)

Get the address from a private key.
Returns the address if successful.
"""
function get_address_from_private_key(private_key::Vector{UInt8}, key_type::KeyType)
    if key_type == ETHEREUM_PRIVATE_KEY
        # TODO: Derive the address from the private key
        # This is a placeholder - in a real implementation, we would use a proper
        # Ethereum library to derive the address from the private key
        return "0x" * bytes2hex(digest(MD.MD_SHA256, private_key))[1:40]
    elseif key_type == SOLANA_PRIVATE_KEY
        # TODO: Derive the address from the private key
        return bytes2hex(digest(MD.MD_SHA256, private_key))[1:44]
    else
        return nothing
    end
end

"""
    sign_transaction(key_id::String, transaction_data::Vector{UInt8})

Sign a transaction with the specified key.
Returns the signature if successful.
"""
function sign_transaction(key_id::String, transaction_data::Vector{UInt8})
    if !KEYCHAIN.initialized
        initialize()
    end
    
    error_context = EnhancedErrors.with_error_context("KeyManager", "sign_transaction",
                                                     metadata=Dict("key_id" => key_id))
    
    log_context = StructuredLogging.LogContext(
        component="KeyManager",
        operation="sign_transaction",
        metadata=Dict("key_id" => key_id)
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Load the private key
            private_key = load_key(key_id)
            
            # Check if the key exists
            if private_key === nothing
                StructuredLogging.error("Key not found",
                                       data=Dict("key_id" => key_id))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.NotFoundError("Key", key_id,
                                                      context=error_context))
                end
            end
            
            key_info = KEYCHAIN.keys[key_id]
            
            # Sign the transaction (depends on key type)
            signature = if key_info.key_type == ETHEREUM_PRIVATE_KEY
                sign_ethereum_transaction(private_key, transaction_data)
            elseif key_info.key_type == SOLANA_PRIVATE_KEY
                sign_solana_transaction(private_key, transaction_data)
            else
                nothing
            end
            
            if signature === nothing
                StructuredLogging.error("Unsupported key type for signing",
                                       data=Dict("key_id" => key_id,
                                                "key_type" => string(key_info.key_type)))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(EnhancedErrors.ValidationError("Unsupported key type for signing",
                                                        context=error_context))
                end
            end
            
            StructuredLogging.info("Transaction signed",
                                  data=Dict("key_id" => key_id,
                                           "key_type" => string(key_info.key_type)))
            
            return signature
        catch e
            StructuredLogging.error("Failed to sign transaction",
                                   data=Dict("key_id" => key_id),
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                if e isa EnhancedErrors.JuliaOSError
                    rethrow(e)
                else
                    throw(EnhancedErrors.InternalError("Failed to sign transaction",
                                                      e, context=error_context))
                end
            end
        end
    end
end

"""
    sign_ethereum_transaction(private_key::Vector{UInt8}, transaction_data::Vector{UInt8})

Sign an Ethereum transaction with the specified private key.
Returns the signature if successful.
"""
function sign_ethereum_transaction(private_key::Vector{UInt8}, transaction_data::Vector{UInt8})
    # TODO: Implement Ethereum transaction signing
    # This is a placeholder - in a real implementation, we would use a proper
    # Ethereum library to sign the transaction
    
    # For now, just return a dummy signature
    return digest(MD.MD_SHA256, [private_key; transaction_data])
end

"""
    sign_solana_transaction(private_key::Vector{UInt8}, transaction_data::Vector{UInt8})

Sign a Solana transaction with the specified private key.
Returns the signature if successful.
"""
function sign_solana_transaction(private_key::Vector{UInt8}, transaction_data::Vector{UInt8})
    # TODO: Implement Solana transaction signing
    # This is a placeholder - in a real implementation, we would use a proper
    # Solana library to sign the transaction
    
    # For now, just return a dummy signature
    return digest(MD.MD_SHA256, [private_key; transaction_data])
end

# Storage implementations

"""
    store_key_to_file(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)

Store a key to a file.
Returns true if successful, false otherwise.
"""
function store_key_to_file(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)
    # Encrypt the key data with the master key
    encrypted_data = encrypt_key(key_data, KEYCHAIN.master_key)
    
    # Construct the file path
    file_path = joinpath(KEYCHAIN.storage_path, key_id * ".key")
    
    # Write the encrypted key to the file
    try
        open(file_path, "w") do io
            write(io, encrypted_data)
        end
        
        # Secure the file permissions (UNIX-like systems only)
        if Sys.isunix()
            try
                chmod(file_path, 0o600)  # Read/write only for owner
            catch
                StructuredLogging.warn("Could not set secure permissions on key file",
                                     data=Dict("path" => file_path))
            end
        end
        
        return true
    catch e
        StructuredLogging.error("Failed to write key to file",
                               data=Dict("path" => file_path),
                               exception=e)
        return false
    end
end

"""
    load_key_from_file(key_id::String, key_info::KeyInfo)

Load a key from a file.
Returns the key data if successful, nothing otherwise.
"""
function load_key_from_file(key_id::String, key_info::KeyInfo)
    # Construct the file path
    file_path = joinpath(KEYCHAIN.storage_path, key_id * ".key")
    
    # Check if the file exists
    if !isfile(file_path)
        StructuredLogging.error("Key file not found",
                               data=Dict("path" => file_path))
        return nothing
    end
    
    # Read the encrypted key from the file
    try
        encrypted_data = read(file_path)
        
        # Decrypt the key data with the master key
        return decrypt_key(encrypted_data, KEYCHAIN.master_key)
    catch e
        StructuredLogging.error("Failed to read key from file",
                               data=Dict("path" => file_path),
                               exception=e)
        return nothing
    end
end

"""
    delete_key_from_file(key_id::String, key_info::KeyInfo)

Delete a key file.
Returns true if successful, false otherwise.
"""
function delete_key_from_file(key_id::String, key_info::KeyInfo)
    # Construct the file path
    file_path = joinpath(KEYCHAIN.storage_path, key_id * ".key")
    
    # Check if the file exists
    if !isfile(file_path)
        StructuredLogging.warn("Key file not found",
                              data=Dict("path" => file_path))
        return true  # Consider it a success if the file doesn't exist
    end
    
    # Delete the file
    try
        rm(file_path)
        return true
    catch e
        StructuredLogging.error("Failed to delete key file",
                               data=Dict("path" => file_path),
                               exception=e)
        return false
    end
end

# In-memory key storage
# Note: This is not secure for production use as keys are stored in memory

# Global dictionary for in-memory key storage
const MEMORY_KEYS = Dict{String, Vector{UInt8}}()

"""
    store_key_to_memory(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)

Store a key in memory.
Returns true if successful, false otherwise.
"""
function store_key_to_memory(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)
    # Encrypt the key data with the master key
    encrypted_data = encrypt_key(key_data, KEYCHAIN.master_key)
    
    # Store the encrypted key in memory
    MEMORY_KEYS[key_id] = encrypted_data
    
    return true
end

"""
    load_key_from_memory(key_id::String, key_info::KeyInfo)

Load a key from memory.
Returns the key data if successful, nothing otherwise.
"""
function load_key_from_memory(key_id::String, key_info::KeyInfo)
    # Check if the key exists in memory
    if !haskey(MEMORY_KEYS, key_id)
        StructuredLogging.error("Key not found in memory",
                               data=Dict("key_id" => key_id))
        return nothing
    end
    
    # Get the encrypted key from memory
    encrypted_data = MEMORY_KEYS[key_id]
    
    # Decrypt the key data with the master key
    return decrypt_key(encrypted_data, KEYCHAIN.master_key)
end

"""
    delete_key_from_memory(key_id::String, key_info::KeyInfo)

Delete a key from memory.
Returns true if successful, false otherwise.
"""
function delete_key_from_memory(key_id::String, key_info::KeyInfo)
    # Check if the key exists in memory
    if !haskey(MEMORY_KEYS, key_id)
        return true  # Consider it a success if the key doesn't exist
    end
    
    # Delete the key from memory
    delete!(MEMORY_KEYS, key_id)
    
    return true
end

"""
    store_key_to_secure_enclave(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)

Store a key in the secure enclave.
Returns true if successful, false otherwise.
"""
function store_key_to_secure_enclave(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)
    # TODO: Implement secure enclave storage
    # This is a placeholder - in a real implementation, we would use the OS's
    # secure enclave or keychain API to store the key
    
    StructuredLogging.warn("Secure enclave storage not implemented, falling back to file storage",
                          data=Dict("key_id" => key_id))
    
    return store_key_to_file(key_id, key_data, key_info)
end

"""
    load_key_from_secure_enclave(key_id::String, key_info::KeyInfo)

Load a key from the secure enclave.
Returns the key data if successful, nothing otherwise.
"""
function load_key_from_secure_enclave(key_id::String, key_info::KeyInfo)
    # TODO: Implement secure enclave loading
    # This is a placeholder - in a real implementation, we would use the OS's
    # secure enclave or keychain API to load the key
    
    StructuredLogging.warn("Secure enclave loading not implemented, falling back to file loading",
                          data=Dict("key_id" => key_id))
    
    return load_key_from_file(key_id, key_info)
end

"""
    delete_key_from_secure_enclave(key_id::String, key_info::KeyInfo)

Delete a key from the secure enclave.
Returns true if successful, false otherwise.
"""
function delete_key_from_secure_enclave(key_id::String, key_info::KeyInfo)
    # TODO: Implement secure enclave deletion
    # This is a placeholder - in a real implementation, we would use the OS's
    # secure enclave or keychain API to delete the key
    
    StructuredLogging.warn("Secure enclave deletion not implemented, falling back to file deletion",
                          data=Dict("key_id" => key_id))
    
    return delete_key_from_file(key_id, key_info)
end

"""
    store_key_to_hsm(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)

Store a key in a hardware security module (HSM).
Returns true if successful, false otherwise.
"""
function store_key_to_hsm(key_id::String, key_data::Vector{UInt8}, key_info::KeyInfo)
    # TODO: Implement HSM storage
    # This is a placeholder - in a real implementation, we would use a proper
    # HSM library or API to store the key
    
    StructuredLogging.warn("HSM storage not implemented, falling back to file storage",
                          data=Dict("key_id" => key_id))
    
    return store_key_to_file(key_id, key_data, key_info)
end

"""
    load_key_from_hsm(key_id::String, key_info::KeyInfo)

Load a key from a hardware security module (HSM).
Returns the key data if successful, nothing otherwise.
"""
function load_key_from_hsm(key_id::String, key_info::KeyInfo)
    # TODO: Implement HSM loading
    # This is a placeholder - in a real implementation, we would use a proper
    # HSM library or API to load the key
    
    StructuredLogging.warn("HSM loading not implemented, falling back to file loading",
                          data=Dict("key_id" => key_id))
    
    return load_key_from_file(key_id, key_info)
end

"""
    delete_key_from_hsm(key_id::String, key_info::KeyInfo)

Delete a key from a hardware security module (HSM).
Returns true if successful, false otherwise.
"""
function delete_key_from_hsm(key_id::String, key_info::KeyInfo)
    # TODO: Implement HSM deletion
    # This is a placeholder - in a real implementation, we would use a proper
    # HSM library or API to delete the key
    
    StructuredLogging.warn("HSM deletion not implemented, falling back to file deletion",
                          data=Dict("key_id" => key_id))
    
    return delete_key_from_file(key_id, key_info)
end

"""
    parse_storage_method(storage_method::String)

Parse a storage method string into a StorageMethod enum.
"""
function parse_storage_method(storage_method::String)
    upper_method = uppercase(storage_method)
    
    if upper_method == "FILE"
        return FILE
    elseif upper_method == "SECURE_ENCLAVE"
        return SECURE_ENCLAVE
    elseif upper_method == "MEMORY"
        return MEMORY
    elseif upper_method == "HSM"
        return HSM
    else
        StructuredLogging.warn("Unknown storage method: $storage_method, using FILE",
                              data=Dict("storage_method" => storage_method))
        return FILE
    end
end

"""
    load_keychain()

Load the keychain metadata from the keychain file.
"""
function load_keychain()
    # Construct the keychain file path
    keychain_path = joinpath(KEYCHAIN.storage_path, "keychain.json")
    
    # Check if the keychain file exists
    if !isfile(keychain_path)
        StructuredLogging.info("No keychain file found, creating new keychain")
        return
    end
    
    # Read the keychain file
    try
        keychain_data = open(keychain_path, "r") do io
            read(io, String)
        end
        
        # Parse the keychain data
        keychain_json = JSON.parse(keychain_data)
        
        # Load the keys
        if haskey(keychain_json, "keys") && keychain_json["keys"] isa Vector
            for key_data in keychain_json["keys"]
                key_id = key_data["id"]
                key_type_str = key_data["key_type"]
                key_type = parse_key_type(key_type_str)
                storage_str = key_data["storage"]
                storage = parse_storage_method(storage_str)
                
                # Create key info
                key_info = KeyInfo(
                    key_id,
                    key_data["name"],
                    key_type,
                    storage,
                    metadata=key_data["metadata"]
                )
                
                # Store the key info in the keychain
                KEYCHAIN.keys[key_id] = key_info
            end
        end
        
        StructuredLogging.info("Keychain loaded",
                              data=Dict("key_count" => length(KEYCHAIN.keys)))
    catch e
        StructuredLogging.error("Failed to load keychain",
                               data=Dict("path" => keychain_path),
                               exception=e)
    end
end

"""
    save_keychain()

Save the keychain metadata to the keychain file.
"""
function save_keychain()
    # Construct the keychain file path
    keychain_path = joinpath(KEYCHAIN.storage_path, "keychain.json")
    
    # Prepare the keychain data
    keys_data = []
    for (key_id, key_info) in KEYCHAIN.keys
        push!(keys_data, Dict{String, Any}(
            "id" => key_info.id,
            "name" => key_info.name,
            "key_type" => string(key_info.key_type),
            "created_at" => string(key_info.created_at),
            "last_accessed" => key_info.last_accessed === nothing ? nothing : string(key_info.last_accessed),
            "metadata" => key_info.metadata,
            "storage" => string(key_info.storage)
        ))
    end
    
    keychain_json = Dict{String, Any}(
        "version" => "1.0",
        "last_updated" => string(now()),
        "keys" => keys_data
    )
    
    # Write the keychain file
    try
        keychain_data = JSON.json(keychain_json, 4)  # Pretty-print with 4 spaces
        
        open(keychain_path, "w") do io
            write(io, keychain_data)
        end
        
        # Secure the file permissions (UNIX-like systems only)
        if Sys.isunix()
            try
                chmod(keychain_path, 0o600)  # Read/write only for owner
            catch
                StructuredLogging.warn("Could not set secure permissions on keychain file",
                                     data=Dict("path" => keychain_path))
            end
        end
        
        StructuredLogging.debug("Keychain saved",
                               data=Dict("path" => keychain_path))
    catch e
        StructuredLogging.error("Failed to save keychain",
                               data=Dict("path" => keychain_path),
                               exception=e)
    end
end

"""
    parse_key_type(key_type::String)

Parse a key type string into a KeyType enum.
"""
function parse_key_type(key_type::String)
    upper_type = uppercase(key_type)
    
    if upper_type == "ETHEREUM_PRIVATE_KEY"
        return ETHEREUM_PRIVATE_KEY
    elseif upper_type == "SOLANA_PRIVATE_KEY"
        return SOLANA_PRIVATE_KEY
    elseif upper_type == "BIP39_MNEMONIC"
        return BIP39_MNEMONIC
    elseif upper_type == "SSH_KEY"
        return SSH_KEY
    elseif upper_type == "GENERIC_SECRET"
        return GENERIC_SECRET
    else
        StructuredLogging.warn("Unknown key type: $key_type, using GENERIC_SECRET",
                              data=Dict("key_type" => key_type))
        return GENERIC_SECRET
    end
end

end # module
