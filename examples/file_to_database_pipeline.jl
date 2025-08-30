#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("../src/MCPClient.jl")
using .MCPClient
using JSON3

"""
File-to-Database Pipeline Example

This example demonstrates:
1. Processing CSV/JSON files from filesystem
2. Validating and transforming data
3. Loading data into database tables
4. Archiving processed files
"""

function main()
    println("📂➡️🗄️  File-to-Database Pipeline Example")
    println("=" ^ 50)
    
    # Setup connections to both file server and database admin
    file_server_path = "../../julia_mcp_server/file_server_example.jl"
    db_server_path = "../../julia_mcp_server/db_admin_example.jl"
    
    file_conn = MCPConnection(file_server_path, "../../julia_mcp_server")
    db_conn = MCPConnection(db_server_path, "../../julia_mcp_server")
    
    try
        # Initialize connections
        println("\n1. Initializing MCP connections...")
        initialize_server(file_conn)
        initialize_server(db_conn)
        println("✅ File server and database server connected")
        
        # Create sample data files
        println("\n2. Creating sample data files...")
        
        # Sample CSV data
        csv_data = """id,name,department,salary,hire_date
1,Alice Johnson,Engineering,75000,2023-01-15
2,Bob Smith,Marketing,65000,2023-02-20
3,Carol Davis,Engineering,80000,2023-01-10
4,David Wilson,Sales,70000,2023-03-05
5,Eve Brown,Marketing,68000,2023-02-28"""
        
        result = call_tool(file_conn, "write_file", Dict(
            "path" => "employees.csv",
            "content" => csv_data
        ))
        println("✅ Created employees.csv")
        
        # Sample JSON data
        json_data = JSON3.write([
            Dict("product_id" => 101, "name" => "Wireless Headphones", "category" => "Electronics", 
                 "price" => 99.99, "stock_quantity" => 50, "last_updated" => "2024-01-15T10:30:00Z"),
            Dict("product_id" => 102, "name" => "Coffee Maker", "category" => "Kitchen", 
                 "price" => 149.99, "stock_quantity" => 25, "last_updated" => "2024-01-16T09:15:00Z"),
            Dict("product_id" => 103, "name" => "Office Chair", "category" => "Furniture", 
                 "price" => 299.99, "stock_quantity" => 15, "last_updated" => "2024-01-17T14:20:00Z")
        ])
        
        result = call_tool(file_conn, "write_file", Dict(
            "path" => "inventory.json",
            "content" => json_data
        ))
        println("✅ Created inventory.json")
        
        # List files in directory
        println("\n3. Discovering data files...")
        files = call_tool(file_conn, "list_files", Dict("path" => "."))
        println("📁 Files found:")
        println(files)
        
        # Create database and tables
        println("\n4. Setting up database...")
        db_name = "pipeline_demo_$(Int(round(time())))"
        
        result = call_tool(db_conn, "create_database", Dict(
            "name" => db_name,
            "owner" => "postgres"
        ))
        println("✅ $result")
        
        # Create employees table
        employees_schema = Dict(
            "properties" => Dict(
                "id" => Dict("type" => "integer", "nullable" => false),
                "name" => Dict("type" => "string", "maxLength" => 100, "nullable" => false),
                "department" => Dict("type" => "string", "maxLength" => 50, "nullable" => false),
                "salary" => Dict("type" => "number", "nullable" => false),
                "hire_date" => Dict("type" => "string", "format" => "date", "nullable" => false)
            ),
            "primary_key" => ["id"]
        )
        
        result = call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "employees",
            "schema" => JSON3.write(employees_schema)
        ))
        println("✅ Employees table created")
        
        # Create inventory table
        inventory_schema = Dict(
            "properties" => Dict(
                "product_id" => Dict("type" => "integer", "nullable" => false),
                "name" => Dict("type" => "string", "maxLength" => 100, "nullable" => false),
                "category" => Dict("type" => "string", "maxLength" => 50, "nullable" => false),
                "price" => Dict("type" => "number", "nullable" => false),
                "stock_quantity" => Dict("type" => "integer", "nullable" => false),
                "last_updated" => Dict("type" => "string", "format" => "datetime", "nullable" => false)
            ),
            "primary_key" => ["product_id"]
        )
        
        result = call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "inventory",
            "schema" => JSON3.write(inventory_schema)
        ))
        println("✅ Inventory table created")
        
        # Process CSV file
        println("\n5. Processing CSV file...")
        csv_content = call_tool(file_conn, "read_file", Dict("path" => "employees.csv"))
        println("📄 Read employees.csv ($(length(split(csv_content, '\\n')) - 1) records)")
        
        # Import CSV data
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "employees",
            "data" => csv_content,
            "format" => "csv"
        ))
        println("✅ CSV data imported: $result")
        
        # Process JSON file
        println("\n6. Processing JSON file...")
        json_content = call_tool(file_conn, "read_file", Dict("path" => "inventory.json"))
        println("📄 Read inventory.json")
        
        # Import JSON data
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "inventory", 
            "data" => json_content,
            "format" => "json"
        ))
        println("✅ JSON data imported: $result")
        
        # Verify data import
        println("\n7. Verifying imported data...")
        employees_data = call_tool(db_conn, "export_data", Dict(
            "table" => "employees",
            "format" => "json",
            "limit" => 10
        ))
        employees_count = length(JSON3.read(employees_data))
        println("👥 Employees table: $employees_count records")
        
        inventory_data = call_tool(db_conn, "export_data", Dict(
            "table" => "inventory",
            "format" => "json",
            "limit" => 10
        ))
        inventory_count = length(JSON3.read(inventory_data))
        println("📦 Inventory table: $inventory_count records")
        
        # Create processed directory and archive files
        println("\n8. Archiving processed files...")
        
        try
            call_tool(file_conn, "create_directory", Dict("path" => "processed"))
            println("📁 Created processed directory")
        catch e
            println("📁 Processed directory already exists")
        end
        
        # Move files to processed directory (simulate by creating copies)
        processed_csv = call_tool(file_conn, "read_file", Dict("path" => "employees.csv"))
        call_tool(file_conn, "write_file", Dict(
            "path" => "processed/employees_$(Int(round(time()))).csv",
            "content" => processed_csv
        ))
        
        processed_json = call_tool(file_conn, "read_file", Dict("path" => "inventory.json"))
        call_tool(file_conn, "write_file", Dict(
            "path" => "processed/inventory_$(Int(round(time()))).json",
            "content" => processed_json
        ))
        
        println("📦 Files archived to processed directory")
        
        # Generate data quality report
        println("\n9. Generating data quality report...")
        
        # Export summary data for reporting
        employees_summary = call_tool(db_conn, "export_data", Dict(
            "table" => "employees",
            "format" => "csv"
        ))
        
        # Save report to file
        report_content = \"\"\"Data Pipeline Execution Report
Generated: $(now())
Database: $db_name

Files Processed:
- employees.csv: $employees_count records imported
- inventory.json: $inventory_count records imported

Tables Created:
- employees: Employee data with departments and salaries
- inventory: Product catalog with stock levels

Status: ✅ SUCCESS
\"\"\"
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "pipeline_report_$(Int(round(time()))).txt",
            "content" => report_content
        ))
        println("📊 Pipeline report generated")
        
        # Cleanup original files
        println("\n10. Cleaning up source files...")
        call_tool(file_conn, "delete_file", Dict("path" => "employees.csv"))
        call_tool(file_conn, "delete_file", Dict("path" => "inventory.json"))
        println("🗑️  Source files removed")
        
        println("\n✅ File-to-Database Pipeline completed successfully!")
        println("📊 Database: $db_name")
        println("📁 Files processed: 2")
        println("📋 Records imported: $(employees_count + inventory_count)")
        
        # Optional: Cleanup database for demo
        println("\n🧹 Demo cleanup...")
        cleanup_result = call_tool(db_conn, "drop_database", Dict(
            "name" => db_name,
            "force" => true
        ))
        println("✅ $cleanup_result")
        
    catch e
        @error "Pipeline failed" error=e
        println("❌ Error: $e")
        rethrow(e)
    finally
        close_connection(file_conn)
        close_connection(db_conn)
        println("\n🔌 Connections closed")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end