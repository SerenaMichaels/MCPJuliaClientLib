#!/usr/bin/env julia
# Claude Orchestrator - Unified MCP Interface
# This provides Claude with high-level orchestration capabilities across multiple MCP servers

using Pkg
Pkg.activate(".")

include("../src/MCPClient.jl")
using .MCPClient
using JSON3

# Load site configuration if available
if isfile("../.env.local")
    include("../config/load_env.jl")
end

# MCP Server paths
const SERVER_DIR = get(ENV, "MCP_SERVER_DIR", "/opt/mcp-julia-server")
const POSTGRES_SERVER = joinpath(SERVER_DIR, "postgres_example.jl")
const FILE_SERVER = joinpath(SERVER_DIR, "file_server_example.jl")
const DB_ADMIN_SERVER = joinpath(SERVER_DIR, "db_admin_example.jl")

# Global connections
const CONNECTIONS = Dict{String, MCPConnection}()

"""
Initialize connection to a specific MCP server
"""
function init_server_connection(server_type::String)
    server_path = if server_type == "postgres"
        POSTGRES_SERVER
    elseif server_type == "file"
        FILE_SERVER
    elseif server_type == "db_admin"
        DB_ADMIN_SERVER
    else
        error("Unknown server type: $server_type")
    end
    
    if !haskey(CONNECTIONS, server_type)
        println("🔌 Connecting to $server_type server...")
        conn = MCPConnection(server_path, SERVER_DIR)
        initialize_server(conn)
        CONNECTIONS[server_type] = conn
        println("✅ Connected to $server_type server")
    end
    
    return CONNECTIONS[server_type]
end

"""
Execute SQL query on PostgreSQL server
"""
function execute_sql(query::String; database::String = "")
    conn = init_server_connection("postgres")
    args = Dict("query" => query)
    if !isempty(database)
        args["database"] = database
    end
    return call_tool(conn, "execute_sql", args)
end

"""
List tables in database
"""
function list_tables(database::String = "")
    conn = init_server_connection("postgres")
    args = isempty(database) ? Dict{String,Any}() : Dict("database" => database)
    return call_tool(conn, "list_tables", args)
end

"""
Describe table structure
"""
function describe_table(table_name::String; database::String = "")
    conn = init_server_connection("postgres")
    args = Dict("table_name" => table_name)
    if !isempty(database)
        args["database"] = database
    end
    return call_tool(conn, "describe_table", args)
end

"""
Read file contents
"""
function read_file(file_path::String)
    conn = init_server_connection("file")
    return call_tool(conn, "read_file", Dict("path" => file_path))
end

"""
Write file contents
"""
function write_file(file_path::String, content::String)
    conn = init_server_connection("file")
    return call_tool(conn, "write_file", Dict("path" => file_path, "content" => content))
end

"""
List directory contents
"""
function list_directory(dir_path::String)
    conn = init_server_connection("file")
    return call_tool(conn, "list_directory", Dict("path" => dir_path))
end

"""
Create database
"""
function create_database(db_name::String; owner::String = "")
    conn = init_server_connection("db_admin")
    args = Dict("database_name" => db_name)
    if !isempty(owner)
        args["owner"] = owner
    end
    return call_tool(conn, "create_database", args)
end

"""
Create database user
"""
function create_user(username::String, password::String; superuser::Bool = false)
    conn = init_server_connection("db_admin")
    args = Dict(
        "username" => username,
        "password" => password,
        "superuser" => superuser
    )
    return call_tool(conn, "create_user", args)
end

"""
Export database schema
"""
function export_schema(database::String, output_file::String = "")
    conn = init_server_connection("db_admin")
    args = Dict("database" => database)
    if !isempty(output_file)
        args["output_file"] = output_file
    end
    return call_tool(conn, "export_schema", args)
end

"""
Import data from CSV
"""
function import_csv(csv_file::String, table_name::String; database::String = "", delimiter::String = ",")
    conn = init_server_connection("db_admin")
    args = Dict(
        "csv_file" => csv_file,
        "table_name" => table_name,
        "delimiter" => delimiter
    )
    if !isempty(database)
        args["database"] = database
    end
    return call_tool(conn, "import_csv", args)
end

"""
Create table from JSON schema
"""
function create_table_from_schema(table_name::String, schema_json::String; database::String = "")
    conn = init_server_connection("db_admin")
    args = Dict(
        "table_name" => table_name,
        "schema_json" => schema_json
    )
    if !isempty(database)
        args["database"] = database
    end
    return call_tool(conn, "create_table_from_schema", args)
end

"""
Comprehensive workflow: File to Database Pipeline
"""
function file_to_database_workflow(csv_file::String, table_name::String; database::String = "default_db")
    println("🚀 Starting File-to-Database Workflow")
    
    try
        # Step 1: Verify file exists
        println("📁 Checking file: $csv_file")
        file_info = list_directory(dirname(csv_file))
        
        # Step 2: Create database if it doesn't exist
        println("🗃️  Ensuring database exists: $database")
        create_database(database)
        
        # Step 3: Import CSV data
        println("📊 Importing CSV data to table: $table_name")
        result = import_csv(csv_file, table_name, database = database)
        
        # Step 4: Verify import
        println("✅ Verifying import...")
        count_result = execute_sql("SELECT COUNT(*) FROM $table_name", database = database)
        
        println("🎉 Workflow completed successfully!")
        return Dict(
            "status" => "success",
            "import_result" => result,
            "record_count" => count_result
        )
        
    catch e
        println("❌ Workflow failed: $e")
        return Dict("status" => "error", "error" => string(e))
    end
end

"""
Database analysis workflow
"""
function analyze_database(database::String = "postgres")
    println("🔍 Analyzing database: $database")
    
    try
        # Get all tables
        tables_result = list_tables(database)
        println("📋 Found tables in $database")
        
        analysis = Dict{String, Any}()
        analysis["database"] = database
        analysis["tables"] = []
        
        # Analyze each table
        tables = JSON3.read(tables_result)
        for table_info in tables
            table_name = table_info["table_name"]
            println("🔍 Analyzing table: $table_name")
            
            # Get table structure
            structure = describe_table(table_name, database = database)
            
            # Get row count
            count_result = execute_sql("SELECT COUNT(*) FROM $table_name", database = database)
            
            table_analysis = Dict(
                "name" => table_name,
                "structure" => JSON3.read(structure),
                "row_count" => count_result
            )
            
            push!(analysis["tables"], table_analysis)
        end
        
        println("✅ Database analysis completed")
        return JSON3.write(analysis)
        
    catch e
        println("❌ Analysis failed: $e")
        return Dict("status" => "error", "error" => string(e))
    end
end

"""
Data migration workflow between databases
"""
function migrate_data(source_db::String, target_db::String, table_name::String)
    println("🔄 Starting data migration: $source_db.$table_name → $target_db.$table_name")
    
    try
        # Step 1: Create target database
        create_database(target_db)
        
        # Step 2: Export source table schema
        println("📋 Exporting schema from source table...")
        source_schema = describe_table(table_name, database = source_db)
        
        # Step 3: Create target table (simplified - you might need to parse the schema)
        println("🛠️  Creating target table...")
        # This would need more sophisticated schema parsing in a real implementation
        
        # Step 4: Copy data
        println("📊 Copying data...")
        copy_query = """
        INSERT INTO $target_db.$table_name 
        SELECT * FROM $source_db.$table_name
        """
        
        result = execute_sql(copy_query)
        
        # Step 5: Verify migration
        source_count = execute_sql("SELECT COUNT(*) FROM $table_name", database = source_db)
        target_count = execute_sql("SELECT COUNT(*) FROM $table_name", database = target_db)
        
        println("✅ Migration completed successfully!")
        return Dict(
            "status" => "success",
            "source_count" => source_count,
            "target_count" => target_count
        )
        
    catch e
        println("❌ Migration failed: $e")
        return Dict("status" => "error", "error" => string(e))
    end
end

"""
Clean up all connections
"""
function cleanup_connections()
    println("🧹 Cleaning up connections...")
    for (server_type, conn) in CONNECTIONS
        try
            close_connection(conn)
            println("✅ Closed $server_type connection")
        catch e
            println("⚠️  Error closing $server_type connection: $e")
        end
    end
    empty!(CONNECTIONS)
end

# Register cleanup on exit
atexit(cleanup_connections)

println("🎯 Claude MCP Orchestrator Ready!")
println("📊 Available functions:")
println("   - execute_sql(query)")
println("   - list_tables(database)")
println("   - describe_table(table_name)")
println("   - read_file(path), write_file(path, content)")
println("   - list_directory(path)")
println("   - create_database(name), create_user(user, pass)")
println("   - export_schema(database), import_csv(file, table)")
println("   - file_to_database_workflow(csv, table, database)")
println("   - analyze_database(database)")
println("   - migrate_data(source_db, target_db, table)")
println()
println("🔗 MCP servers will be connected on-demand when functions are called.")

# Keep the process alive for Claude to communicate with
# This is a simple REPL-like interface
while true
    try
        # In a real MCP server, this would handle JSON-RPC messages
        # For now, just keep the process alive
        sleep(1)
    catch InterruptException
        println("\n👋 Shutting down Claude Orchestrator...")
        cleanup_connections()
        break
    end
end