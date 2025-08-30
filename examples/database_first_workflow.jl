#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("../src/MCPClient.jl")
using .MCPClient
using JSON3

"""
Database-First Workflow Example

This example demonstrates:
1. Creating a database structure
2. Setting up users and permissions  
3. Creating tables from JSON schemas
4. Importing initial data
"""

function main()
    println("🗄️  Database-First Workflow Example")
    println("=" ^ 50)
    
    # Connect to database admin server
    server_dir = "/home/seren/julia_mcp_server"
    server_path = joinpath(server_dir, "db_admin_example.jl")
    conn = MCPConnection(server_path, server_dir)
    
    try
        # Initialize connection
        println("\n1. Initializing MCP connection...")
        result = initialize_server(conn)
        println("✅ Server initialized: $(result["name"])")
        
        # List available tools
        println("\n2. Available tools:")
        tools = list_tools(conn)
        for tool in tools
            println("   - $(tool["name"]): $(tool["description"])")
        end
        
        # Create a new database for our project
        println("\n3. Creating project database...")
        db_name = "project_demo_$(Int(round(time())))"
        result = call_tool(conn, "create_database", Dict(
            "name" => db_name,
            "owner" => "postgres"
        ))
        println("✅ $result")
        
        # Create a project user
        println("\n4. Creating project user...")
        username = "demo_user"
        result = call_tool(conn, "create_user", Dict(
            "username" => username,
            "password" => "demo_password_123",
            "createdb" => false,
            "login" => true
        ))
        println("✅ $result")
        
        # Grant privileges to user
        println("\n5. Granting database privileges...")
        result = call_tool(conn, "grant_privileges", Dict(
            "username" => username,
            "database" => db_name,
            "privileges" => ["CONNECT", "CREATE", "USAGE"]
        ))
        println("✅ $result")
        
        # Create tables from JSON schemas
        println("\n6. Creating tables from JSON schemas...")
        
        # Users table schema
        users_schema = Dict(
            "properties" => Dict(
                "id" => Dict("type" => "integer", "nullable" => false),
                "username" => Dict("type" => "string", "maxLength" => 50, "nullable" => false),
                "email" => Dict("type" => "string", "format" => "email", "nullable" => false),
                "created_at" => Dict("type" => "string", "format" => "datetime", "nullable" => false),
                "is_active" => Dict("type" => "boolean", "default" => true)
            ),
            "primary_key" => ["id"]
        )
        
        # Create connection for the new database
        new_conn = MCPConnection(server_path, "../../julia_mcp_server")
        
        # We need to modify the connection to use the new database
        # This is a limitation - in practice you'd restart with different env vars
        println("   Creating users table...")
        result = call_tool(conn, "create_table_from_json", Dict(
            "table" => "users",
            "schema" => JSON3.write(users_schema)
        ))
        println("✅ Users table created")
        
        # Products table schema
        products_schema = Dict(
            "properties" => Dict(
                "id" => Dict("type" => "integer", "nullable" => false),
                "name" => Dict("type" => "string", "maxLength" => 100, "nullable" => false),
                "description" => Dict("type" => "string", "nullable" => true),
                "price" => Dict("type" => "number", "nullable" => false),
                "category" => Dict("type" => "string", "maxLength" => 50),
                "in_stock" => Dict("type" => "boolean", "default" => true),
                "created_at" => Dict("type" => "string", "format" => "datetime")
            ),
            "primary_key" => ["id"]
        )
        
        println("   Creating products table...")
        result = call_tool(conn, "create_table_from_json", Dict(
            "table" => "products",
            "schema" => JSON3.write(products_schema)
        ))
        println("✅ Products table created")
        
        # Import sample data
        println("\n7. Importing sample data...")
        
        # Sample users data
        users_data = [
            Dict("id" => 1, "username" => "alice", "email" => "alice@example.com", 
                 "created_at" => "2024-01-15T10:30:00", "is_active" => true),
            Dict("id" => 2, "username" => "bob", "email" => "bob@example.com", 
                 "created_at" => "2024-01-16T14:20:00", "is_active" => true),
            Dict("id" => 3, "username" => "carol", "email" => "carol@example.com", 
                 "created_at" => "2024-01-17T09:15:00", "is_active" => false)
        ]
        
        result = call_tool(conn, "import_data", Dict(
            "table" => "users",
            "data" => JSON3.write(users_data),
            "format" => "json"
        ))
        println("✅ Users data imported: $result")
        
        # Sample products data  
        products_data = [
            Dict("id" => 1, "name" => "Laptop", "description" => "Gaming laptop", 
                 "price" => 1299.99, "category" => "Electronics", "in_stock" => true, 
                 "created_at" => "2024-01-15T10:00:00"),
            Dict("id" => 2, "name" => "Mouse", "description" => "Wireless mouse", 
                 "price" => 29.99, "category" => "Electronics", "in_stock" => true, 
                 "created_at" => "2024-01-15T10:05:00"),
            Dict("id" => 3, "name" => "Desk", "description" => "Standing desk", 
                 "price" => 399.99, "category" => "Furniture", "in_stock" => false, 
                 "created_at" => "2024-01-15T10:10:00")
        ]
        
        result = call_tool(conn, "import_data", Dict(
            "table" => "products",
            "data" => JSON3.write(products_data),
            "format" => "json"
        ))
        println("✅ Products data imported: $result")
        
        # Export schema for version control
        println("\n8. Exporting schema for documentation...")
        result = call_tool(conn, "export_schema", Dict(
            "database" => db_name,
            "format" => "sql"
        ))
        println("📄 Schema exported:")
        println(result)
        
        # Export data for backup
        println("\n9. Exporting data as backup...")
        users_export = call_tool(conn, "export_data", Dict(
            "table" => "users",
            "format" => "json"
        ))
        println("📊 Users data exported ($(length(JSON3.read(users_export))) records)")
        
        products_export = call_tool(conn, "export_data", Dict(
            "table" => "products", 
            "format" => "csv"
        ))
        println("📊 Products data exported as CSV")
        
        println("\n✅ Database-First Workflow completed successfully!")
        println("Database: $db_name")
        println("User: $username")
        println("Tables: users, products")
        
        # Cleanup (optional)
        println("\n🧹 Cleanup...")
        cleanup_result = call_tool(conn, "drop_database", Dict(
            "name" => db_name,
            "force" => true
        ))
        println("✅ $cleanup_result")
        
        user_cleanup = call_tool(conn, "drop_user", Dict(
            "username" => username
        ))
        println("✅ $user_cleanup")
        
    catch e
        @error "Workflow failed" error=e
        println("❌ Error: $e")
    finally
        close_connection(conn)
        println("\n🔌 Connection closed")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end