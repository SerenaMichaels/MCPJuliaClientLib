#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("../src/MCPClient.jl")
using .MCPClient
using JSON3

"""
Cross-Database Migration Example

This example demonstrates:
1. Exporting schema and data from source database
2. Storing migration files
3. Creating target database with schema
4. Importing data to target database
5. Validation and rollback capabilities
"""

function main()
    println("🔄 Cross-Database Migration Example")
    println("=" ^ 50)
    
    # Setup connections
    file_server_path = "../../julia_mcp_server/file_server_example.jl"
    db_server_path = "../../julia_mcp_server/db_admin_example.jl"
    
    file_conn = MCPConnection(file_server_path, "../../julia_mcp_server")
    db_conn = MCPConnection(db_server_path, "../../julia_mcp_server")
    
    try
        # Initialize connections
        println("\n1. Initializing connections...")
        initialize_server(file_conn)
        initialize_server(db_conn)
        println("✅ File server and database server connected")
        
        # Create source database with sample data
        println("\n2. Setting up source database...")
        source_db = "migration_source_$(Int(round(time())))"
        
        result = call_tool(db_conn, "create_database", Dict(
            "name" => source_db,
            "owner" => "postgres"
        ))
        println("✅ Source database created: $source_db")
        
        # Create sample tables in source database
        customers_schema = Dict(
            "properties" => Dict(
                "customer_id" => Dict("type" => "integer", "nullable" => false),
                "company_name" => Dict("type" => "string", "maxLength" => 100, "nullable" => false),
                "contact_name" => Dict("type" => "string", "maxLength" => 50),
                "email" => Dict("type" => "string", "format" => "email"),
                "phone" => Dict("type" => "string", "maxLength" => 20),
                "created_at" => Dict("type" => "string", "format" => "datetime", "nullable" => false),
                "status" => Dict("type" => "string", "maxLength" => 20, "default" => "active")
            ),
            "primary_key" => ["customer_id"]
        )
        
        result = call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "customers",
            "schema" => JSON3.write(customers_schema)
        ))
        println("✅ Customers table created")
        
        orders_schema = Dict(
            "properties" => Dict(
                "order_id" => Dict("type" => "integer", "nullable" => false),
                "customer_id" => Dict("type" => "integer", "nullable" => false),
                "order_date" => Dict("type" => "string", "format" => "date", "nullable" => false),
                "total_amount" => Dict("type" => "number", "nullable" => false),
                "status" => Dict("type" => "string", "maxLength" => 20, "default" => "pending"),
                "shipping_address" => Dict("type" => "string", "maxLength" => 200),
                "notes" => Dict("type" => "string")
            ),
            "primary_key" => ["order_id"]
        )
        
        result = call_tool(db_conn, "create_table_from_json", Dict(
            "table" => "orders",
            "schema" => JSON3.write(orders_schema)
        ))
        println("✅ Orders table created")
        
        # Insert sample data
        println("\n3. Populating source database with sample data...")
        
        customers_data = [
            Dict("customer_id" => 1, "company_name" => "Tech Solutions Inc", "contact_name" => "Alice Johnson", 
                 "email" => "alice@techsolutions.com", "phone" => "555-0101", 
                 "created_at" => "2023-01-15T10:00:00", "status" => "active"),
            Dict("customer_id" => 2, "company_name" => "Global Marketing Ltd", "contact_name" => "Bob Smith", 
                 "email" => "bob@globalmarketing.com", "phone" => "555-0102", 
                 "created_at" => "2023-02-10T14:30:00", "status" => "active"),
            Dict("customer_id" => 3, "company_name" => "Creative Designs Co", "contact_name" => "Carol Davis", 
                 "email" => "carol@creativedesigns.com", "phone" => "555-0103", 
                 "created_at" => "2023-03-05T09:15:00", "status" => "inactive")
        ]
        
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "customers",
            "data" => JSON3.write(customers_data),
            "format" => "json"
        ))
        println("✅ Customer data imported: $result")
        
        orders_data = [
            Dict("order_id" => 1001, "customer_id" => 1, "order_date" => "2024-01-15", 
                 "total_amount" => 1250.00, "status" => "completed", 
                 "shipping_address" => "123 Tech St, Silicon Valley, CA", "notes" => "Rush order"),
            Dict("order_id" => 1002, "customer_id" => 2, "order_date" => "2024-01-16", 
                 "total_amount" => 875.50, "status" => "shipped", 
                 "shipping_address" => "456 Marketing Ave, New York, NY", "notes" => "Standard shipping"),
            Dict("order_id" => 1003, "customer_id" => 1, "order_date" => "2024-01-17", 
                 "total_amount" => 2100.75, "status" => "processing", 
                 "shipping_address" => "123 Tech St, Silicon Valley, CA", "notes" => "Large order"),
            Dict("order_id" => 1004, "customer_id" => 3, "order_date" => "2024-01-18", 
                 "total_amount" => 450.25, "status" => "cancelled", 
                 "shipping_address" => "789 Design Rd, Austin, TX", "notes" => "Customer requested cancellation")
        ]
        
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "orders",
            "data" => JSON3.write(orders_data),
            "format" => "json"
        ))
        println("✅ Orders data imported: $result")
        
        # Create migration directory
        println("\n4. Setting up migration workspace...")
        timestamp = Int(round(time()))
        migration_dir = "migration_$timestamp"
        
        call_tool(file_conn, "create_directory", Dict("path" => migration_dir))
        println("📁 Created migration directory: $migration_dir")
        
        # Export source database schema
        println("\n5. Exporting source database schema...")
        schema_sql = call_tool(db_conn, "export_schema", Dict(
            "database" => source_db,
            "format" => "sql"
        ))
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/schema.sql",
            "content" => schema_sql
        ))
        println("📄 Schema exported to $migration_dir/schema.sql")
        
        schema_json = call_tool(db_conn, "export_schema", Dict(
            "database" => source_db,
            "format" => "json"
        ))
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/schema.json",
            "content" => schema_json
        ))
        println("📄 Schema exported to $migration_dir/schema.json")
        
        # Export source database data
        println("\n6. Exporting source database data...")
        customers_export = call_tool(db_conn, "export_data", Dict(
            "table" => "customers",
            "format" => "json"
        ))
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/customers.json",
            "content" => customers_export
        ))
        println("📊 Customers data exported")
        
        orders_export = call_tool(db_conn, "export_data", Dict(
            "table" => "orders",
            "format" => "json"
        ))
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/orders.json",
            "content" => orders_export
        ))
        println("📊 Orders data exported")
        
        # Create migration manifest
        manifest = Dict(
            "migration_id" => "migration_$timestamp",
            "source_database" => source_db,
            "target_database" => "TBD",
            "created_at" => string(now()),
            "tables" => ["customers", "orders"],
            "files" => [
                "schema.sql", "schema.json", 
                "customers.json", "orders.json"
            ],
            "status" => "exported"
        )
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/manifest.json",
            "content" => JSON3.write(manifest, allow_inf=true)
        ))
        println("📋 Migration manifest created")
        
        # Create target database
        println("\n7. Creating target database...")
        target_db = "migration_target_$(timestamp)"
        
        result = call_tool(db_conn, "create_database", Dict(
            "name" => target_db,
            "owner" => "postgres"
        ))
        println("✅ Target database created: $target_db")
        
        # Import schema to target database  
        println("\n8. Importing schema to target database...")
        
        # Read schema definition and recreate tables
        schema_data = JSON3.read(call_tool(file_conn, "read_file", Dict(
            "path" => "$migration_dir/schema.json"
        )))
        
        for (table_name, table_def) in schema_data["tables"]
            println("   Creating table: $table_name")
            result = call_tool(db_conn, "create_table_from_json", Dict(
                "table" => table_name,
                "schema" => JSON3.write(table_def)
            ))
        end
        println("✅ Schema imported to target database")
        
        # Import data to target database
        println("\n9. Importing data to target database...")
        
        customers_data = call_tool(file_conn, "read_file", Dict(
            "path" => "$migration_dir/customers.json"
        ))
        
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "customers",
            "data" => customers_data,
            "format" => "json"
        ))
        println("✅ Customers data imported: $result")
        
        orders_data = call_tool(file_conn, "read_file", Dict(
            "path" => "$migration_dir/orders.json"
        ))
        
        result = call_tool(db_conn, "import_data", Dict(
            "table" => "orders",
            "data" => orders_data,
            "format" => "json"
        ))
        println("✅ Orders data imported: $result")
        
        # Validate migration
        println("\n10. Validating migration...")
        
        # Compare record counts
        source_customers = JSON3.read(customers_export)
        target_customers = JSON3.read(call_tool(db_conn, "export_data", Dict(
            "table" => "customers", "format" => "json"
        )))
        
        source_orders = JSON3.read(orders_export)
        target_orders = JSON3.read(call_tool(db_conn, "export_data", Dict(
            "table" => "orders", "format" => "json"
        )))
        
        customers_match = length(source_customers) == length(target_customers)
        orders_match = length(source_orders) == length(target_orders)
        
        println("📊 Customers: $(length(source_customers)) → $(length(target_customers)) $(customers_match ? "✅" : "❌")")
        println("📊 Orders: $(length(source_orders)) → $(length(target_orders)) $(orders_match ? "✅" : "❌")")
        
        # Update migration manifest
        manifest["target_database"] = target_db
        manifest["status"] = customers_match && orders_match ? "completed" : "failed"
        manifest["completed_at"] = string(now())
        manifest["validation"] = Dict(
            "customers_match" => customers_match,
            "orders_match" => orders_match,
            "customers_count" => length(target_customers),
            "orders_count" => length(target_orders)
        )
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/manifest.json",
            "content" => JSON3.write(manifest, allow_inf=true)
        ))
        
        # Generate migration report
        println("\n11. Generating migration report...")
        report = \"\"\"Database Migration Report
=========================

Migration ID: migration_$timestamp
Timestamp: $(now())

Source Database: $source_db
Target Database: $target_db

Tables Migrated:
- customers: $(length(source_customers)) records
- orders: $(length(source_orders)) records

Validation Results:
- Customers: $(customers_match ? "PASS" : "FAIL")
- Orders: $(orders_match ? "PASS" : "FAIL")

Status: $(manifest["status"])

Files Created:
- $migration_dir/schema.sql (DDL script)
- $migration_dir/schema.json (JSON schema)
- $migration_dir/customers.json (customer data)
- $migration_dir/orders.json (orders data)
- $migration_dir/manifest.json (migration metadata)
\"\"\"
        
        call_tool(file_conn, "write_file", Dict(
            "path" => "$migration_dir/migration_report.txt",
            "content" => report
        ))
        println("📄 Migration report saved")
        
        if customers_match && orders_match
            println("\n✅ Cross-Database Migration completed successfully!")
        else
            println("\n❌ Migration validation failed!")
        end
        
        println("📁 Migration files: $migration_dir/")
        println("🗃️  Source: $source_db")
        println("🗃️  Target: $target_db")
        
        # Cleanup (optional for demo)
        println("\n🧹 Demo cleanup...")
        call_tool(db_conn, "drop_database", Dict("name" => source_db, "force" => true))
        call_tool(db_conn, "drop_database", Dict("name" => target_db, "force" => true))
        println("✅ Databases cleaned up")
        
    catch e
        @error "Migration failed" error=e
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