"""
    DocumentStorage

Module for document storage and retrieval, designed to work with LangChain retrievers.
"""
module DocumentStorage

using SQLite
using DataFrames
using Dates
using JSON
using Logging
using LinearAlgebra

export add_documents, add_vector_documents, search_documents, search_vector_documents, 
       delete_documents, get_document, list_documents, list_collections

# Create document tables if they don't exist
function create_document_tables(db)
    # Create documents table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            collection TEXT NOT NULL,
            content TEXT NOT NULL,
            metadata TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)
    
    # Create vector documents table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS vector_documents (
            id TEXT PRIMARY KEY,
            collection TEXT NOT NULL,
            content TEXT NOT NULL,
            metadata TEXT,
            embedding BLOB,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)
    
    # Create indices for faster queries
    SQLite.execute(db, "CREATE INDEX IF NOT EXISTS idx_documents_collection ON documents (collection)")
    SQLite.execute(db, "CREATE INDEX IF NOT EXISTS idx_vector_documents_collection ON vector_documents (collection)")
    
    @info "Document tables created or already exist"
end

# Add documents to storage
function add_documents(db, storage_type, collection_name, documents)
    if storage_type == "arweave"
        return add_documents_to_arweave(collection_name, documents)
    end
    
    # Default to local storage
    document_ids = []
    
    for doc in documents
        # Generate a unique ID for the document
        id = string(hash(string(collection_name, doc["content"], now())), base=16)
        
        # Convert metadata to JSON if it's not a string
        metadata_json = if haskey(doc, "metadata")
            typeof(doc["metadata"]) == String ? doc["metadata"] : JSON.json(doc["metadata"])
        else
            "{}"
        end
        
        # Insert the document
        SQLite.execute(db, """
            INSERT INTO documents (id, collection, content, metadata, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """, [id, collection_name, doc["content"], metadata_json, string(now()), string(now())])
        
        push!(document_ids, id)
    end
    
    @info "Added $(length(document_ids)) documents to collection $collection_name"
    
    return Dict(
        "success" => true,
        "document_ids" => document_ids,
        "count" => length(document_ids)
    )
end

# Add vector documents to storage
function add_vector_documents(db, storage_type, collection_name, documents)
    if storage_type == "arweave"
        return add_vector_documents_to_arweave(collection_name, documents)
    end
    
    # Default to local storage
    document_ids = []
    
    for doc in documents
        # Generate a unique ID for the document
        id = string(hash(string(collection_name, doc["content"], now())), base=16)
        
        # Convert metadata to JSON if it's not a string
        metadata_json = if haskey(doc, "metadata")
            typeof(doc["metadata"]) == String ? doc["metadata"] : JSON.json(doc["metadata"])
        else
            "{}"
        end
        
        # Convert embedding to binary
        embedding_blob = if haskey(doc, "embedding")
            reinterpret(UInt8, Float32.(doc["embedding"]))
        else
            nothing
        end
        
        # Insert the document
        SQLite.execute(db, """
            INSERT INTO vector_documents (id, collection, content, metadata, embedding, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [id, collection_name, doc["content"], metadata_json, embedding_blob, string(now()), string(now())])
        
        push!(document_ids, id)
    end
    
    @info "Added $(length(document_ids)) vector documents to collection $collection_name"
    
    return Dict(
        "success" => true,
        "document_ids" => document_ids,
        "count" => length(document_ids)
    )
end

# Search documents by text query
function search_documents(db, storage_type, collection_name, query, params=Dict())
    if storage_type == "arweave"
        return search_documents_in_arweave(collection_name, query, params)
    end
    
    # Default to local storage
    # Extract search parameters
    limit = get(params, "limit", 10)
    
    # Simple text search implementation
    # In a real implementation, this would use a more sophisticated text search algorithm
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM documents 
        WHERE collection = ? AND content LIKE ?
        LIMIT ?
    """, [collection_name, "%$(query)%", limit]) |> DataFrame
    
    documents = []
    for row in eachrow(result)
        doc = Dict(
            "id" => row.id,
            "content" => row.content,
            "metadata" => try
                JSON.parse(row.metadata)
            catch
                Dict()
            end
        )
        push!(documents, doc)
    end
    
    @info "Found $(length(documents)) documents matching query in collection $collection_name"
    
    return Dict(
        "success" => true,
        "documents" => documents,
        "count" => length(documents)
    )
end

# Search vector documents by embedding
function search_vector_documents(db, storage_type, collection_name, query_embedding, params=Dict())
    if storage_type == "arweave"
        return search_vector_documents_in_arweave(collection_name, query_embedding, params)
    end
    
    # Default to local storage
    # Extract search parameters
    limit = get(params, "limit", 10)
    similarity_threshold = get(params, "similarity_threshold", 0.7)
    
    # Convert query embedding to the right format
    query_vector = Float32.(query_embedding)
    
    # Get all documents in the collection
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM vector_documents 
        WHERE collection = ?
    """, [collection_name]) |> DataFrame
    
    # Calculate similarity scores
    documents_with_scores = []
    for row in eachrow(result)
        # Skip documents without embeddings
        if ismissing(row.embedding) || row.embedding === nothing
            continue
        end
        
        # Convert blob back to vector
        doc_vector = reinterpret(Float32, row.embedding)
        
        # Calculate cosine similarity
        similarity = dot(query_vector, doc_vector) / (norm(query_vector) * norm(doc_vector))
        
        if similarity >= similarity_threshold
            doc = Dict(
                "id" => row.id,
                "content" => row.content,
                "metadata" => try
                    JSON.parse(row.metadata)
                catch
                    Dict()
                end,
                "similarity" => similarity
            )
            push!(documents_with_scores, doc)
        end
    end
    
    # Sort by similarity (highest first) and limit results
    sort!(documents_with_scores, by = d -> d["similarity"], rev = true)
    documents = length(documents_with_scores) > limit ? documents_with_scores[1:limit] : documents_with_scores
    
    @info "Found $(length(documents)) vector documents matching query in collection $collection_name"
    
    return Dict(
        "success" => true,
        "documents" => documents,
        "count" => length(documents)
    )
end

# Delete documents
function delete_documents(db, storage_type, collection_name, document_ids)
    if storage_type == "arweave"
        return Dict(
            "success" => false,
            "error" => "Cannot delete documents from Arweave as it is immutable"
        )
    end
    
    # Default to local storage
    # Delete from both tables to ensure all documents are removed
    for id in document_ids
        SQLite.execute(db, "DELETE FROM documents WHERE id = ? AND collection = ?", [id, collection_name])
        SQLite.execute(db, "DELETE FROM vector_documents WHERE id = ? AND collection = ?", [id, collection_name])
    end
    
    @info "Deleted $(length(document_ids)) documents from collection $collection_name"
    
    return Dict(
        "success" => true,
        "deleted_count" => length(document_ids)
    )
end

# Get a document by ID
function get_document(db, storage_type, collection_name, document_id)
    if storage_type == "arweave"
        return get_document_from_arweave(collection_name, document_id)
    end
    
    # Default to local storage
    # Try to get from regular documents first
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM documents 
        WHERE id = ? AND collection = ?
    """, [document_id, collection_name]) |> DataFrame
    
    if size(result, 1) > 0
        row = result[1, :]
        return Dict(
            "success" => true,
            "document" => Dict(
                "id" => row.id,
                "content" => row.content,
                "metadata" => try
                    JSON.parse(row.metadata)
                catch
                    Dict()
                end
            )
        )
    end
    
    # Try to get from vector documents
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM vector_documents 
        WHERE id = ? AND collection = ?
    """, [document_id, collection_name]) |> DataFrame
    
    if size(result, 1) > 0
        row = result[1, :]
        doc = Dict(
            "id" => row.id,
            "content" => row.content,
            "metadata" => try
                JSON.parse(row.metadata)
            catch
                Dict()
            end
        )
        
        # Add embedding if available
        if !ismissing(row.embedding) && row.embedding !== nothing
            doc["embedding"] = Array(reinterpret(Float32, row.embedding))
        end
        
        return Dict(
            "success" => true,
            "document" => doc
        )
    end
    
    return Dict(
        "success" => false,
        "error" => "Document not found"
    )
end

# List documents in a collection
function list_documents(db, storage_type, collection_name, limit=100, offset=0)
    if storage_type == "arweave"
        return list_documents_in_arweave(collection_name, limit, offset)
    end
    
    # Default to local storage
    # Get regular documents
    regular_docs = SQLite.DBInterface.execute(db, """
        SELECT * FROM documents 
        WHERE collection = ?
        LIMIT ? OFFSET ?
    """, [collection_name, limit, offset]) |> DataFrame
    
    # Get vector documents
    vector_docs = SQLite.DBInterface.execute(db, """
        SELECT * FROM vector_documents 
        WHERE collection = ?
        LIMIT ? OFFSET ?
    """, [collection_name, limit, offset]) |> DataFrame
    
    documents = []
    
    # Process regular documents
    for row in eachrow(regular_docs)
        doc = Dict(
            "id" => row.id,
            "content" => row.content,
            "metadata" => try
                JSON.parse(row.metadata)
            catch
                Dict()
            end,
            "type" => "document"
        )
        push!(documents, doc)
    end
    
    # Process vector documents
    for row in eachrow(vector_docs)
        doc = Dict(
            "id" => row.id,
            "content" => row.content,
            "metadata" => try
                JSON.parse(row.metadata)
            catch
                Dict()
            end,
            "type" => "vector_document"
        )
        
        # Add embedding if available
        if !ismissing(row.embedding) && row.embedding !== nothing
            doc["has_embedding"] = true
        else
            doc["has_embedding"] = false
        end
        
        push!(documents, doc)
    end
    
    @info "Listed $(length(documents)) documents in collection $collection_name"
    
    return Dict(
        "success" => true,
        "documents" => documents,
        "count" => length(documents)
    )
end

# List all collections
function list_collections(db, storage_type)
    if storage_type == "arweave"
        return list_collections_in_arweave()
    end
    
    # Default to local storage
    # Get collections from regular documents
    regular_collections = SQLite.DBInterface.execute(db, """
        SELECT DISTINCT collection FROM documents
    """) |> DataFrame
    
    # Get collections from vector documents
    vector_collections = SQLite.DBInterface.execute(db, """
        SELECT DISTINCT collection FROM vector_documents
    """) |> DataFrame
    
    # Combine and deduplicate
    collections = unique(vcat(regular_collections.collection, vector_collections.collection))
    
    @info "Listed $(length(collections)) collections"
    
    return Dict(
        "success" => true,
        "collections" => collections,
        "count" => length(collections)
    )
end

# Arweave storage functions (stubs - to be implemented)
function add_documents_to_arweave(collection_name, documents)
    @warn "Arweave document storage not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave document storage not fully implemented"
    )
end

function add_vector_documents_to_arweave(collection_name, documents)
    @warn "Arweave vector document storage not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave vector document storage not fully implemented"
    )
end

function search_documents_in_arweave(collection_name, query, params)
    @warn "Arweave document search not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave document search not fully implemented"
    )
end

function search_vector_documents_in_arweave(collection_name, query_embedding, params)
    @warn "Arweave vector document search not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave vector document search not fully implemented"
    )
end

function get_document_from_arweave(collection_name, document_id)
    @warn "Arweave document retrieval not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave document retrieval not fully implemented"
    )
end

function list_documents_in_arweave(collection_name, limit, offset)
    @warn "Arweave document listing not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave document listing not fully implemented"
    )
end

function list_collections_in_arweave()
    @warn "Arweave collection listing not fully implemented"
    return Dict(
        "success" => false,
        "error" => "Arweave collection listing not fully implemented"
    )
end

end # module DocumentStorage
