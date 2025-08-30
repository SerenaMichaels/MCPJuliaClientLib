# MCP Julia Client Examples

This document provides quick-start examples for common MCP Julia Client operations.

## Basic Usage Examples

### Simple Connection and Tool Call

```julia
using Pkg
Pkg.activate(".")

include("src/MCPClient.jl")
using .MCPClient

# Connect to file server
conn = MCPConnection("/path/to/file_server_example.jl", "/path/to/server_dir")

try
    # Initialize connection
    result = initialize_server(conn)
    println("Connected to: $(result["name"])")
    
    # List available tools
    tools = list_tools(conn)
    println("Available tools:")
    for tool in tools
        println("  - $(tool["name"]): $(tool["description"])")
    end
    
    # Create a file
    result = call_tool(conn, "write_file", Dict(
        "path" => "hello.txt",
        "content" => "Hello, MCP World!"
    ))
    println("File creation result: $result")
    
finally
    close_connection(conn)
end
```

### Database Operations

```julia
include("src/MCPClient.jl")
using .MCPClient, JSON3

# Connect to database admin server
conn = MCPConnection("/path/to/db_admin_example.jl", "/path/to/server_dir")

try
    initialize_server(conn)
    
    # Create a new database
    result = call_tool(conn, "create_database", Dict(
        "name" => "my_project",
        "owner" => "postgres"
    ))
    println("Database created: $result")
    
    # Create a table from JSON schema
    user_schema = Dict(
        "properties" => Dict(
            "id" => Dict("type" => "integer", "nullable" => false),
            "name" => Dict("type" => "string", "maxLength" => 100),
            "email" => Dict("type" => "string", "format" => "email")
        ),
        "primary_key" => ["id"]
    )
    
    result = call_tool(conn, "create_table_from_json", Dict(
        "table" => "users",
        "schema" => JSON3.write(user_schema)
    ))
    println("Table created: $result")
    
finally
    close_connection(conn)
end
```

## Workflow Examples

### Quick ETL Pipeline

```julia
include("src/MCPClient.jl")
using .MCPClient, JSON3

function quick_etl_example()
    # Setup connections
    file_conn = MCPConnection("/path/to/file_server_example.jl", "/server/dir")
    db_conn = MCPConnection("/path/to/db_admin_example.jl", "/server/dir")
    
    try
        # Initialize both connections
        initialize_server(file_conn)
        initialize_server(db_conn)
        
        # Step 1: Create sample data file
        sample_data = [
            Dict("id" => 1, "name" => "Alice", "age" => 30),
            Dict("id" => 2, "name" => "Bob", "age" => 25),
            Dict("id" => 3, "name" => "Carol", "age" => 35)
        ]
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "sample_data.json",
            "content" => JSON3.write(sample_data)
        ))
        
        # Step 2: Create target database and table
        call_tool(db_conn, "create_database", Dict("name" => "etl_demo"))
        
        table_schema = Dict(
            "properties" => Dict(
                "id" => Dict("type" => "integer", "nullable" => false),
                "name" => Dict("type" => "string", "maxLength" => 50),
                "age" => Dict("type" => "integer")
            ),
            "primary_key" => ["id"]
        )
        
        call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "people",
            "schema" => JSON3.write(table_schema)
        ))
        
        # Step 3: Load data from file to database
        file_content = call_tool(file_conn, "read_file", Dict("path" => "sample_data.json"))
        
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "people",
            "data" => file_content,
            "format" => "json"
        ))
        
        println("ETL completed: $result")
        
    finally
        close_connection(file_conn)
        close_connection(db_conn)
    end
end

# Run the example
quick_etl_example()
```

### Simple Database Migration

```julia
include("src/MCPClient.jl")
using .MCPClient

function simple_migration_example()
    conn = MCPConnection("/path/to/db_admin_example.jl", "/server/dir")
    
    try
        initialize_server(conn)
        
        # Create source database with sample table
        call_tool(conn, "create_database", Dict("name" => "source_db"))
        
        # Export schema and data
        schema = call_tool(conn, "export_schema", Dict(
            "database" => "source_db",
            "format" => "json"
        ))
        
        # Create target database
        call_tool(conn, "create_database", Dict("name" => "target_db"))
        
        # Import schema to target (would need to parse and recreate tables)
        println("Migration prepared. Schema: $schema")
        
    finally
        close_connection(conn)
    end
end
```

## Advanced Examples

### Multi-Server Data Processing

```julia
include("src/MCPClient.jl")
using .MCPClient, JSON3

function multi_server_example()
    # Connect to multiple servers
    file_conn = MCPConnection("/path/to/file_server_example.jl", "/server/dir")
    db_conn = MCPConnection("/path/to/db_admin_example.jl", "/server/dir")
    query_conn = MCPConnection("/path/to/postgres_example.jl", "/server/dir")
    
    try
        # Initialize all connections
        for conn in [file_conn, db_conn, query_conn]
            initialize_server(conn)
        end
        
        # Create workspace
        call_tool(file_conn, "create_directory", Dict("path" => "analytics"))
        
        # Setup database
        call_tool(db_conn, "create_database", Dict("name" => "analytics_db"))
        
        # Create fact table
        sales_schema = Dict(
            "properties" => Dict(
                "id" => Dict("type" => "integer", "nullable" => false),
                "product" => Dict("type" => "string", "maxLength" => 100),
                "quantity" => Dict("type" => "integer"),
                "amount" => Dict("type" => "number"),
                "sale_date" => Dict("type" => "string", "format" => "date")
            ),
            "primary_key" => ["id"]
        )
        
        call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "sales",
            "schema" => JSON3.write(sales_schema)
        ))
        
        # Generate sample sales data
        sales_data = [
            Dict("id" => 1, "product" => "Widget A", "quantity" => 5, "amount" => 50.0, "sale_date" => "2024-01-15"),
            Dict("id" => 2, "product" => "Widget B", "quantity" => 3, "amount" => 75.0, "sale_date" => "2024-01-16"),
            Dict("id" => 3, "product" => "Widget A", "quantity" => 2, "amount" => 20.0, "sale_date" => "2024-01-17")
        ]
        
        # Import sales data
        call_tool(db_conn, "import_data", Dict(
            "table" => "sales",
            "data" => JSON3.write(sales_data),
            "format" => "json"
        ))
        
        # Run analytics query
        analytics_query = """
        SELECT 
            product,
            SUM(quantity) as total_quantity,
            SUM(amount) as total_amount,
            AVG(amount) as avg_amount
        FROM sales
        GROUP BY product
        ORDER BY total_amount DESC
        """
        
        results = call_tool(query_conn, "execute_query", Dict(
            "query" => analytics_query,
            "limit" => 100
        ))
        
        # Save results to file
        call_tool(file_conn, "write_file", Dict(
            "path" => "analytics/sales_summary.txt",
            "content" => results
        ))
        
        println("Analytics pipeline completed!")
        println("Results: $results")
        
    finally
        for conn in [file_conn, db_conn, query_conn]
            close_connection(conn)
        end
    end
end

# Run the example
multi_server_example()
```

### Error Handling Patterns

```julia
include("src/MCPClient.jl")
using .MCPClient

function robust_operation_example()
    conn = MCPConnection("/path/to/db_admin_example.jl", "/server/dir")
    
    try
        # Initialize with retry logic
        max_retries = 3
        for attempt in 1:max_retries
            try
                initialize_server(conn)
                break
            catch e
                if attempt == max_retries
                    rethrow(e)
                end
                println("Initialization attempt $attempt failed, retrying...")
                sleep(1.0)
            end
        end
        
        # Perform operations with error handling
        operations = [
            ("create_db", () -> call_tool(conn, "create_database", Dict("name" => "test_db"))),
            ("create_user", () -> call_tool(conn, "create_user", Dict("username" => "test_user", "password" => "test123"))),
        ]
        
        results = Dict()
        for (op_name, op_func) in operations
            try
                result = op_func()
                results[op_name] = Dict("status" => "success", "result" => result)
                println("✅ $op_name completed")
            catch e
                results[op_name] = Dict("status" => "error", "error" => string(e))
                println("❌ $op_name failed: $e")
                
                # Decide whether to continue or abort
                if contains(string(e), "critical")
                    throw(e)  # Abort on critical errors
                end
                # Continue with other operations for non-critical errors
            end
        end
        
        # Cleanup on partial failure
        if any(r["status"] == "error" for r in values(results))
            println("Some operations failed, performing cleanup...")
            try
                call_tool(conn, "drop_database", Dict("name" => "test_db", "force" => true))
                call_tool(conn, "drop_user", Dict("username" => "test_user"))
            catch cleanup_error
                println("Cleanup failed: $cleanup_error")
            end
        end
        
        return results
        
    finally
        close_connection(conn)
    end
end

# Run with error handling
results = robust_operation_example()
println("Operation results: $results")
```

## Testing Examples

### Connection Testing

```julia
include("src/MCPClient.jl")
using .MCPClient

function test_all_servers()
    servers = [
        ("File Server", "/path/to/file_server_example.jl"),
        ("Database Admin", "/path/to/db_admin_example.jl"),
        ("PostgreSQL Server", "/path/to/postgres_example.jl")
    ]
    
    results = []
    
    for (name, path) in servers
        conn = MCPConnection(path, "/server/dir")
        
        try
            start_time = time()
            initialize_server(conn)
            tools = list_tools(conn)
            elapsed = time() - start_time
            
            push!(results, (name, "✅ Connected", "$(length(tools)) tools", "$(round(elapsed, digits=2))s"))
            
        catch e
            push!(results, (name, "❌ Failed", string(e), "N/A"))
        finally
            close_connection(conn)
        end
    end
    
    # Print results table
    println("Server Connection Test Results:")
    println("="^60)
    for (name, status, info, time) in results
        println("$name: $status ($info) - $time")
    end
end

# Run server tests
test_all_servers()
```

### Performance Testing

```julia
include("src/MCPClient.jl")
using .MCPClient

function performance_test()
    conn = MCPConnection("/path/to/file_server_example.jl", "/server/dir")
    
    try
        initialize_server(conn)
        
        # Test file operations performance
        operations = [
            ("Small file write", () -> call_tool(conn, "write_file", Dict("path" => "small.txt", "content" => "Hello"×100))),
            ("Medium file write", () -> call_tool(conn, "write_file", Dict("path" => "medium.txt", "content" => "Hello"×1000))),
            ("File read", () -> call_tool(conn, "read_file", Dict("path" => "small.txt"))),
            ("Directory list", () -> call_tool(conn, "list_files", Dict("path" => "."))),
        ]
        
        println("Performance Test Results:")
        println("="^50)
        
        for (op_name, op_func) in operations
            times = []
            
            # Run operation multiple times
            for i in 1:5
                start_time = time()
                try
                    op_func()
                    elapsed = time() - start_time
                    push!(times, elapsed)
                catch e
                    println("$op_name failed: $e")
                    break
                end
            end
            
            if !isempty(times)
                avg_time = sum(times) / length(times)
                min_time = minimum(times)
                max_time = maximum(times)
                
                println("$op_name:")
                println("  Average: $(round(avg_time*1000, digits=2))ms")
                println("  Range: $(round(min_time*1000, digits=2))-$(round(max_time*1000, digits=2))ms")
            end
        end
        
    finally
        close_connection(conn)
    end
end

# Run performance tests
performance_test()
```

## Configuration Examples

### Environment-Based Configuration

```julia
include("src/MCPClient.jl")
using .MCPClient

function get_server_config()
    server_base = get(ENV, "MCP_SERVER_DIR", "/default/path/to/servers")
    
    return Dict(
        "file_server" => joinpath(server_base, "file_server_example.jl"),
        "db_admin" => joinpath(server_base, "db_admin_example.jl"),
        "postgres" => joinpath(server_base, "postgres_example.jl")
    )
end

function create_configured_connection(server_type::String)
    config = get_server_config()
    
    if !haskey(config, server_type)
        throw(ArgumentError("Unknown server type: $server_type"))
    end
    
    server_path = config[server_type]
    server_dir = dirname(server_path)
    
    return MCPConnection(server_path, server_dir)
end

# Usage
file_conn = create_configured_connection("file_server")
```

### Connection Pool Example

```julia
include("src/MCPClient.jl")
using .MCPClient

mutable struct MCPConnectionPool
    connections::Dict{String, MCPConnection}
    max_connections::Int
    
    MCPConnectionPool(max_conn::Int = 10) = new(Dict(), max_conn)
end

function get_connection(pool::MCPConnectionPool, server_type::String)
    if haskey(pool.connections, server_type)
        return pool.connections[server_type]
    end
    
    if length(pool.connections) >= pool.max_connections
        throw(ArgumentError("Connection pool exhausted"))
    end
    
    # Create new connection
    config = get_server_config()
    conn = MCPConnection(config[server_type], dirname(config[server_type]))
    initialize_server(conn)
    
    pool.connections[server_type] = conn
    return conn
end

function close_pool(pool::MCPConnectionPool)
    for (_, conn) in pool.connections
        close_connection(conn)
    end
    empty!(pool.connections)
end

# Usage
pool = MCPConnectionPool()
try
    file_conn = get_connection(pool, "file_server")
    db_conn = get_connection(pool, "db_admin")
    
    # Use connections...
    
finally
    close_pool(pool)
end
```

These examples provide practical starting points for using the MCP Julia Client in various scenarios, from simple operations to complex multi-server orchestrations.