#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

include("../src/MCPClient.jl")
using .MCPClient
using JSON3

"""
Multi-Server Orchestration Example

This example demonstrates:
1. Orchestrating multiple MCP servers simultaneously
2. Complex workflows spanning file operations, database management, and queries
3. Error handling and recovery across servers
4. Coordinated data processing pipelines
"""

struct MultiServerOrchestrator
    file_conn::MCPConnection
    db_admin_conn::MCPConnection
    postgres_conn::MCPConnection
    initialized::Bool
    
    function MultiServerOrchestrator(server_dir::String)
        file_conn = MCPConnection("$server_dir/file_server_example.jl", server_dir)
        db_admin_conn = MCPConnection("$server_dir/db_admin_example.jl", server_dir)
        postgres_conn = MCPConnection("$server_dir/postgres_example.jl", server_dir)
        
        new(file_conn, db_admin_conn, postgres_conn, false)
    end
end

function initialize_orchestrator(orch::MultiServerOrchestrator)
    println("🚀 Initializing multi-server orchestrator...")
    
    try
        initialize_server(orch.file_conn)
        println("✅ File server initialized")
        
        initialize_server(orch.db_admin_conn)
        println("✅ Database admin server initialized")
        
        initialize_server(orch.postgres_conn)
        println("✅ PostgreSQL server initialized")
        
        return true
    catch e
        @error "Failed to initialize servers" error=e
        return false
    end
end

function close_orchestrator(orch::MultiServerOrchestrator)
    close_connection(orch.file_conn)
    close_connection(orch.db_admin_conn)
    close_connection(orch.postgres_conn)
    println("🔌 All server connections closed")
end

function main()
    println("🎼 Multi-Server Orchestration Example")
    println("=" ^ 50)
    
    # Initialize orchestrator
    orch = MultiServerOrchestrator("../../julia_mcp_server")
    
    try
        if !initialize_orchestrator(orch)
            throw(ArgumentError("Failed to initialize orchestrator"))
        end
        
        # Complex workflow: E-commerce analytics pipeline
        println("\n📊 E-commerce Analytics Pipeline")
        println("-" ^ 40)
        
        # Step 1: Create analytics database
        println("\n1. Setting up analytics infrastructure...")
        analytics_db = "ecommerce_analytics_$(Int(round(time())))"
        
        result = call_tool(orch.db_admin_conn, "create_database", Dict(
            "name" => analytics_db,
            "owner" => "postgres"
        ))
        println("✅ $result")
        
        # Create analytics user
        result = call_tool(orch.db_admin_conn, "create_user", Dict(
            "username" => "analytics_user",
            "password" => "analytics_pass_123",
            "createdb" => false,
            "login" => true
        ))
        println("✅ Analytics user created")
        
        # Grant privileges
        result = call_tool(orch.db_admin_conn, "grant_privileges", Dict(
            "username" => "analytics_user",
            "database" => analytics_db,
            "privileges" => ["CONNECT", "CREATE", "SELECT", "INSERT", "UPDATE"]
        ))
        println("✅ Privileges granted")
        
        # Step 2: Create data processing workspace
        println("\n2. Setting up data processing workspace...")
        timestamp = Int(round(time()))
        workspace = "analytics_workspace_$timestamp"
        
        call_tool(orch.file_conn, "create_directory", Dict("path" => workspace))
        call_tool(orch.file_conn, "create_directory", Dict("path" => "$workspace/raw"))
        call_tool(orch.file_conn, "create_directory", Dict("path" => "$workspace/processed"))
        call_tool(orch.file_conn, "create_directory", Dict("path" => "$workspace/reports"))
        println("📁 Workspace structure created")
        
        # Step 3: Generate synthetic e-commerce data
        println("\n3. Generating synthetic e-commerce data...")
        
        # Product catalog
        products = [
            Dict("product_id" => 1, "name" => "Wireless Headphones", "category" => "Electronics", 
                 "price" => 99.99, "cost" => 45.00, "supplier" => "TechCorp"),
            Dict("product_id" => 2, "name" => "Coffee Maker", "category" => "Kitchen", 
                 "price" => 149.99, "cost" => 75.00, "supplier" => "HomeAppliances Inc"),
            Dict("product_id" => 3, "name" => "Running Shoes", "category" => "Sports", 
                 "price" => 129.99, "cost" => 60.00, "supplier" => "SportGear Ltd"),
            Dict("product_id" => 4, "name" => "Office Desk", "category" => "Furniture", 
                 "price" => 299.99, "cost" => 150.00, "supplier" => "OfficePro"),
            Dict("product_id" => 5, "name" => "Smartphone", "category" => "Electronics", 
                 "price" => 699.99, "cost" => 350.00, "supplier" => "MobileTech")
        ]
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/raw/products.json",
            "content" => JSON3.write(products)
        ))
        
        # Sales data
        sales = [
            Dict("sale_id" => 1001, "product_id" => 1, "quantity" => 2, "sale_date" => "2024-01-15", 
                 "customer_segment" => "Premium", "region" => "North", "channel" => "Online"),
            Dict("sale_id" => 1002, "product_id" => 3, "quantity" => 1, "sale_date" => "2024-01-15", 
                 "customer_segment" => "Standard", "region" => "South", "channel" => "Retail"),
            Dict("sale_id" => 1003, "product_id" => 2, "quantity" => 1, "sale_date" => "2024-01-16", 
                 "customer_segment" => "Premium", "region" => "East", "channel" => "Online"),
            Dict("sale_id" => 1004, "product_id" => 5, "quantity" => 3, "sale_date" => "2024-01-16", 
                 "customer_segment" => "Enterprise", "region" => "West", "channel" => "B2B"),
            Dict("sale_id" => 1005, "product_id" => 4, "quantity" => 2, "sale_date" => "2024-01-17", 
                 "customer_segment" => "Standard", "region" => "North", "channel" => "Retail")
        ]
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/raw/sales.json",
            "content" => JSON3.write(sales)
        ))
        
        println("📊 Synthetic data generated")
        
        # Step 4: Create analytics schema
        println("\n4. Creating analytics database schema...")
        
        # Products dimension table
        products_schema = Dict(
            "properties" => Dict(
                "product_id" => Dict("type" => "integer", "nullable" => false),
                "name" => Dict("type" => "string", "maxLength" => 100, "nullable" => false),
                "category" => Dict("type" => "string", "maxLength" => 50, "nullable" => false),
                "price" => Dict("type" => "number", "nullable" => false),
                "cost" => Dict("type" => "number", "nullable" => false),
                "supplier" => Dict("type" => "string", "maxLength" => 100),
                "profit_margin" => Dict("type" => "number")
            ),
            "primary_key" => ["product_id"]
        )
        
        result = call_tool(orch.db_admin_conn, "create_table_from_json", Dict(
            "table" => "dim_products",
            "schema" => JSON3.write(products_schema)
        ))
        println("✅ Products dimension table created")
        
        # Sales fact table
        sales_schema = Dict(
            "properties" => Dict(
                "sale_id" => Dict("type" => "integer", "nullable" => false),
                "product_id" => Dict("type" => "integer", "nullable" => false),
                "quantity" => Dict("type" => "integer", "nullable" => false),
                "sale_date" => Dict("type" => "string", "format" => "date", "nullable" => false),
                "customer_segment" => Dict("type" => "string", "maxLength" => 50),
                "region" => Dict("type" => "string", "maxLength" => 50),
                "channel" => Dict("type" => "string", "maxLength" => 50),
                "revenue" => Dict("type" => "number"),
                "profit" => Dict("type" => "number")
            ),
            "primary_key" => ["sale_id"]
        )
        
        result = call_tool(orch.db_admin_conn, "create_table_from_json", Dict(
            "table" => "fact_sales",
            "schema" => JSON3.write(sales_schema)
        ))
        println("✅ Sales fact table created")
        
        # Step 5: Load and transform data
        println("\n5. Loading and transforming data...")
        
        # Load products with calculated profit margins
        products_data = JSON3.read(call_tool(orch.file_conn, "read_file", Dict(
            "path" => "$workspace/raw/products.json"
        )))
        
        # Add profit margin calculation
        for product in products_data
            product["profit_margin"] = round((product["price"] - product["cost"]) / product["price"] * 100, digits=2)
        end
        
        result = call_tool(orch.db_admin_conn, "import_data", Dict(
            "table" => "dim_products",
            "data" => JSON3.write(products_data),
            "format" => "json"
        ))
        println("✅ Products data loaded: $result")
        
        # Load sales with calculated revenue and profit
        sales_data = JSON3.read(call_tool(orch.file_conn, "read_file", Dict(
            "path" => "$workspace/raw/sales.json"
        )))
        
        # Create product lookup for calculations
        product_lookup = Dict()
        for product in products_data
            product_lookup[product["product_id"]] = product
        end
        
        # Add revenue and profit calculations
        for sale in sales_data
            product = product_lookup[sale["product_id"]]
            sale["revenue"] = round(product["price"] * sale["quantity"], digits=2)
            sale["profit"] = round((product["price"] - product["cost"]) * sale["quantity"], digits=2)
        end
        
        result = call_tool(orch.db_admin_conn, "import_data", Dict(
            "table" => "fact_sales",
            "data" => JSON3.write(sales_data),
            "format" => "json"
        ))
        println("✅ Sales data loaded: $result")
        
        # Step 6: Generate analytics queries and reports
        println("\n6. Generating analytics reports...")
        
        # Revenue by category query
        category_revenue_query = \"\"\"
        SELECT 
            p.category,
            SUM(s.revenue) as total_revenue,
            SUM(s.profit) as total_profit,
            COUNT(s.sale_id) as total_sales,
            AVG(s.revenue) as avg_sale_value
        FROM fact_sales s
        JOIN dim_products p ON s.product_id = p.product_id
        GROUP BY p.category
        ORDER BY total_revenue DESC
        \"\"\"
        
        category_results = call_tool(orch.postgres_conn, "execute_query", Dict(
            "query" => category_revenue_query,
            "limit" => 50
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/reports/revenue_by_category.txt",
            "content" => category_results
        ))
        println("📊 Revenue by category report generated")
        
        # Regional performance query
        regional_query = \"\"\"
        SELECT 
            s.region,
            s.channel,
            COUNT(s.sale_id) as sales_count,
            SUM(s.revenue) as total_revenue,
            AVG(s.quantity) as avg_quantity
        FROM fact_sales s
        GROUP BY s.region, s.channel
        ORDER BY total_revenue DESC
        \"\"\"
        
        regional_results = call_tool(orch.postgres_conn, "execute_query", Dict(
            "query" => regional_query,
            "limit" => 50
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/reports/regional_performance.txt",
            "content" => regional_results
        ))
        println("📊 Regional performance report generated")
        
        # Product profitability query
        profitability_query = \"\"\"
        SELECT 
            p.name,
            p.category,
            p.price,
            p.profit_margin,
            COALESCE(SUM(s.quantity), 0) as units_sold,
            COALESCE(SUM(s.revenue), 0) as total_revenue,
            COALESCE(SUM(s.profit), 0) as total_profit
        FROM dim_products p
        LEFT JOIN fact_sales s ON p.product_id = s.product_id
        GROUP BY p.product_id, p.name, p.category, p.price, p.profit_margin
        ORDER BY total_profit DESC
        \"\"\"
        
        profitability_results = call_tool(orch.postgres_conn, "execute_query", Dict(
            "query" => profitability_query,
            "limit" => 50
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/reports/product_profitability.txt",
            "content" => profitability_results
        ))
        println("📊 Product profitability report generated")
        
        # Step 7: Export processed data
        println("\n7. Exporting processed analytics data...")
        
        # Export dimension and fact tables
        products_export = call_tool(orch.db_admin_conn, "export_data", Dict(
            "table" => "dim_products",
            "format" => "csv"
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/processed/dim_products.csv",
            "content" => products_export
        ))
        
        sales_export = call_tool(orch.db_admin_conn, "export_data", Dict(
            "table" => "fact_sales",
            "format" => "json"
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/processed/fact_sales.json",
            "content" => sales_export
        ))
        
        # Export schema for documentation
        schema_export = call_tool(orch.db_admin_conn, "export_schema", Dict(
            "database" => analytics_db,
            "format" => "json"
        ))
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/processed/analytics_schema.json",
            "content" => schema_export
        ))
        
        println("📦 Analytics data exported")
        
        # Step 8: Generate executive summary
        println("\n8. Generating executive summary...")
        
        # Get summary statistics
        total_revenue_query = "SELECT SUM(revenue) as total_revenue, SUM(profit) as total_profit FROM fact_sales"
        summary_stats = call_tool(orch.postgres_conn, "execute_query", Dict(
            "query" => total_revenue_query
        ))
        
        files_created = call_tool(orch.file_conn, "list_files", Dict("path" => workspace))
        
        executive_summary = \"\"\"E-COMMERCE ANALYTICS PIPELINE SUMMARY
========================================

Pipeline Execution: $(now())
Database: $analytics_db
Workspace: $workspace

DATA PROCESSING SUMMARY:
- Products processed: $(length(products_data))
- Sales transactions: $(length(sales_data))
- Categories analyzed: $(length(unique([p["category"] for p in products_data])))

INFRASTRUCTURE CREATED:
- Analytics database: $analytics_db
- Analytics user: analytics_user
- Dimension tables: 1 (dim_products)
- Fact tables: 1 (fact_sales)

REPORTS GENERATED:
- Revenue by Category Analysis
- Regional Performance Breakdown  
- Product Profitability Analysis

SUMMARY METRICS:
$summary_stats

FILES CREATED:
$files_created

STATUS: ✅ PIPELINE COMPLETED SUCCESSFULLY

Next Steps:
1. Review analytics reports in $workspace/reports/
2. Access processed data in $workspace/processed/
3. Connect BI tools to $analytics_db
4. Schedule regular data updates
\"\"\"
        
        call_tool(orch.file_conn, "write_file", Dict(
            "path" => "$workspace/EXECUTIVE_SUMMARY.txt",
            "content" => executive_summary
        ))
        
        println("📋 Executive summary generated")
        
        println("\n✅ Multi-Server Orchestration completed successfully!")
        println("🎯 E-commerce analytics pipeline executed")
        println("📊 Database: $analytics_db")
        println("📁 Workspace: $workspace")
        println("📈 Reports: 3 analytical reports generated")
        println("🔧 Infrastructure: Database, user, and tables created")
        
        # Optional cleanup
        println("\n🧹 Cleanup (optional)...")
        response = ""
        try
            print("Clean up demo database and user? [y/N]: ")
            response = strip(readline())
        catch
            response = "N"
        end
        
        if lowercase(response) == "y"
            call_tool(orch.db_admin_conn, "drop_user", Dict("username" => "analytics_user"))
            call_tool(orch.db_admin_conn, "drop_database", Dict("name" => analytics_db, "force" => true))
            println("✅ Demo infrastructure cleaned up")
        else
            println("📊 Analytics infrastructure preserved for further exploration")
        end
        
    catch e
        @error "Orchestration failed" error=e
        println("❌ Error: $e")
        rethrow(e)
    finally
        close_orchestrator(orch)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end