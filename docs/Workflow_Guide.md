# MCP Julia Client Workflow Guide

This guide provides detailed explanations and best practices for each workflow pattern implemented in the MCP Julia Client examples.

## Prerequisites

### System Requirements

- **Julia 1.6+**: Programming language runtime
- **PostgreSQL**: Database server (tested with PostgreSQL 17)
- **MCPJuliaServer**: The companion server suite

### Setup Checklist

1. Clone and set up [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer)
2. Ensure PostgreSQL is running and accessible
3. Install project dependencies: `julia --project=. -e "using Pkg; Pkg.instantiate()"`
4. Configure PostgreSQL connection (see Environment Variables section)

### Environment Variables

Configure PostgreSQL access for database-related workflows:

```bash
export POSTGRES_HOST="localhost"          # Database host
export POSTGRES_PORT="5432"              # Database port  
export POSTGRES_USER="postgres"          # Database user
export POSTGRES_PASSWORD="your_password" # Database password
export POSTGRES_DB="postgres"            # Default database
```

## Workflow 1: Database-First Development

**File:** `examples/database_first_workflow.jl`

### Overview

The database-first approach prioritizes database schema design, then builds applications around well-defined data structures. This workflow demonstrates:

- Schema-driven database design using JSON schemas
- Role-based access control implementation
- Data validation and import processes
- Documentation generation for schema evolution

### Key Steps

#### 1. Database Infrastructure Setup

```julia
# Create project-specific database
result = call_tool(conn, "create_database", Dict(
    "name" => "project_database",
    "owner" => "postgres"
))

# Create application user with limited privileges  
result = call_tool(conn, "create_user", Dict(
    "username" => "app_user",
    "password" => "secure_password",
    "createdb" => false,
    "login" => true
))

# Grant specific database privileges
result = call_tool(conn, "grant_privileges", Dict(
    "username" => "app_user", 
    "database" => "project_database",
    "privileges" => ["CONNECT", "CREATE", "USAGE"]
))
```

#### 2. Schema Design with JSON Schemas

Define table structures using JSON Schema format:

```julia
user_schema = Dict(
    "properties" => Dict(
        "id" => Dict("type" => "integer", "nullable" => false),
        "username" => Dict("type" => "string", "maxLength" => 50, "nullable" => false),
        "email" => Dict("type" => "string", "format" => "email", "nullable" => false),
        "created_at" => Dict("type" => "string", "format" => "datetime", "nullable" => false),
        "is_active" => Dict("type" => "boolean", "default" => true)
    ),
    "primary_key" => ["id"]
)
```

#### 3. Table Creation from Schemas

```julia
result = call_tool(conn, "create_table_from_json", Dict(
    "table" => "users",
    "schema" => JSON3.write(user_schema)
))
```

The system automatically converts JSON Schema types to appropriate SQL types:
- `"integer"` → `INTEGER`
- `"string"` → `VARCHAR(length)` or `TEXT`
- `"string", "format": "email"` → `VARCHAR(255)`
- `"string", "format": "datetime"` → `TIMESTAMP`
- `"boolean"` → `BOOLEAN`

#### 4. Initial Data Population

```julia
users_data = [
    Dict("id" => 1, "username" => "admin", "email" => "admin@example.com", 
         "created_at" => "2024-01-01T00:00:00", "is_active" => true)
]

result = call_tool(conn, "import_data", Dict(
    "table" => "users",
    "data" => JSON3.write(users_data),
    "format" => "json"
))
```

### Best Practices

1. **Schema Versioning**: Export schemas after each change for version control
2. **Validation**: Always validate data before import
3. **Security**: Use principle of least privilege for database users
4. **Documentation**: Generate and maintain schema documentation

### Use Cases

- **API Development**: Design database schema before implementing endpoints
- **Data Modeling**: Create normalized database structures for complex domains
- **Team Collaboration**: Share schema definitions across development teams
- **Migration Planning**: Plan database changes with clear schema definitions

---

## Workflow 2: File-to-Database ETL Pipeline

**File:** `examples/file_to_database_pipeline.jl`

### Overview

ETL (Extract, Transform, Load) pipelines automate the process of moving data from various file sources into database systems. This workflow demonstrates:

- Automated file discovery and processing
- Multi-format data ingestion (CSV, JSON)
- Data transformation and validation
- File archiving and audit trails

### Architecture

```
File System → File Discovery → Data Extraction → Transformation → Database Load → Archival
     ↓              ↓              ↓              ↓             ↓           ↓
Source Files → list_files() → read_file() → Validation → import_data() → Archive
```

### Key Components

#### 1. Multi-Server Coordination

```julia
# Initialize both file and database servers
file_conn = MCPConnection(file_server_path, server_dir)
db_conn = MCPConnection(db_server_path, server_dir)

initialize_server(file_conn)
initialize_server(db_conn)
```

#### 2. Automated File Discovery

```julia
# Discover all data files in directory
files = call_tool(file_conn, "list_files", Dict("path" => data_directory))

# Filter for supported formats
data_files = filter(f -> endswith(f, ".csv") || endswith(f, ".json"), files)
```

#### 3. Data Processing Pipeline

```julia
for file_path in data_files
    # Extract data from file
    content = call_tool(file_conn, "read_file", Dict("path" => file_path))
    
    # Determine format and validate
    format = endswith(file_path, ".csv") ? "csv" : "json"
    
    # Transform data if needed (validation, cleaning, enrichment)
    processed_data = transform_data(content, format)
    
    # Load into database
    result = call_tool(db_conn, "import_data", Dict(
        "table" => determine_table(file_path),
        "data" => processed_data,
        "format" => format
    ))
    
    # Archive processed file
    archive_file(file_conn, file_path)
end
```

#### 4. Data Quality Reporting

```julia
# Generate pipeline execution report
report_content = """
Pipeline Execution Report
========================
Execution Time: $(now())
Files Processed: $(length(processed_files))
Records Imported: $(total_records)
Errors: $(error_count)
Status: $(pipeline_status)
"""

call_tool(file_conn, "write_file", Dict(
    "path" => "reports/pipeline_$(timestamp).txt",
    "content" => report_content
))
```

### Data Transformation Patterns

#### CSV Processing

```julia
function process_csv_data(content::String)
    lines = split(content, '\n')
    headers = split(lines[1], ',')
    
    # Validate headers match expected schema
    validate_headers(headers, expected_schema)
    
    # Process data rows with validation
    processed_rows = []
    for line in lines[2:end]
        if !isempty(strip(line))
            row = parse_csv_row(line, headers)
            validated_row = validate_row(row)
            push!(processed_rows, validated_row)
        end
    end
    
    return format_for_import(processed_rows)
end
```

#### JSON Processing

```julia
function process_json_data(content::String)
    data = JSON3.read(content)
    
    # Handle both single objects and arrays
    records = isa(data, Vector) ? data : [data]
    
    # Validate each record against schema
    validated_records = []
    for record in records
        validated_record = validate_json_record(record, schema)
        push!(validated_records, validated_record)
    end
    
    return JSON3.write(validated_records)
end
```

### Error Handling and Recovery

```julia
function process_file_safely(file_conn, db_conn, file_path)
    try
        # Begin processing
        content = call_tool(file_conn, "read_file", Dict("path" => file_path))
        
        # Import with transaction support
        result = call_tool(db_conn, "import_data", Dict(
            "table" => table_name,
            "data" => content,
            "format" => format
        ))
        
        # Archive on success
        archive_file(file_conn, file_path)
        
        return Dict("status" => "success", "message" => result)
        
    catch e
        # Move to error directory for manual review
        error_path = "errors/$(basename(file_path))"
        call_tool(file_conn, "write_file", Dict(
            "path" => error_path,
            "content" => "Error processing: $e\n\n$(content)"
        ))
        
        return Dict("status" => "error", "message" => string(e))
    end
end
```

### Performance Optimization

1. **Batch Processing**: Process multiple files in batches
2. **Parallel Processing**: Use Julia's parallel processing for independent files
3. **Memory Management**: Stream large files instead of loading entirely
4. **Connection Pooling**: Reuse database connections for multiple operations

### Best Practices

1. **Idempotency**: Ensure pipeline can be re-run safely
2. **Validation**: Validate data at each stage
3. **Monitoring**: Track pipeline execution and success rates
4. **Recovery**: Implement retry mechanisms for transient failures
5. **Audit Trails**: Maintain detailed logs of all operations

---

## Workflow 3: Cross-Database Migration

**File:** `examples/cross_database_migration.jl`

### Overview

Database migration involves moving schemas and data between different database instances or environments. This workflow demonstrates:

- Complete schema and data export
- Target database preparation
- Data validation and integrity checks
- Migration rollback capabilities

### Migration Phases

#### Phase 1: Source Analysis and Export

```julia
# Export source database schema
schema_sql = call_tool(db_conn, "export_schema", Dict(
    "database" => source_database,
    "format" => "sql"
))

schema_json = call_tool(db_conn, "export_schema", Dict(
    "database" => source_database, 
    "format" => "json"
))

# Export all table data
for table_name in table_list
    table_data = call_tool(db_conn, "export_data", Dict(
        "table" => table_name,
        "format" => "json"
    ))
    
    # Save to migration workspace
    call_tool(file_conn, "write_file", Dict(
        "path" => "migration/data/$(table_name).json",
        "content" => table_data
    ))
end
```

#### Phase 2: Migration Workspace Setup

```julia
# Create organized migration directory structure
migration_id = "migration_$(timestamp)"

directories = [
    "$migration_id/schemas",
    "$migration_id/data", 
    "$migration_id/scripts",
    "$migration_id/reports"
]

for dir in directories
    call_tool(file_conn, "create_directory", Dict("path" => dir))
end

# Create migration manifest
manifest = Dict(
    "migration_id" => migration_id,
    "source_database" => source_db,
    "target_database" => target_db,
    "created_at" => string(now()),
    "tables" => table_list,
    "status" => "in_progress"
)
```

#### Phase 3: Target Database Preparation

```julia
# Create target database
result = call_tool(db_conn, "create_database", Dict(
    "name" => target_database,
    "owner" => target_owner
))

# Recreate schema structure
schema_data = JSON3.read(schema_json)
for (table_name, table_schema) in schema_data["tables"]
    result = call_tool(db_conn, "create_table_from_json", Dict(
        "table" => table_name,
        "schema" => JSON3.write(table_schema)
    ))
end
```

#### Phase 4: Data Migration with Validation

```julia
migration_results = Dict()

for table_name in table_list
    try
        # Load data from migration workspace
        table_data = call_tool(file_conn, "read_file", Dict(
            "path" => "$migration_id/data/$(table_name).json"
        ))
        
        # Import to target database
        result = call_tool(db_conn, "import_data", Dict(
            "table" => table_name,
            "data" => table_data,
            "format" => "json"
        ))
        
        migration_results[table_name] = Dict(
            "status" => "success",
            "message" => result
        )
        
    catch e
        migration_results[table_name] = Dict(
            "status" => "error", 
            "message" => string(e)
        )
    end
end
```

#### Phase 5: Validation and Verification

```julia
function validate_migration(source_db, target_db, table_list)
    validation_results = Dict()
    
    for table_name in table_list
        # Export data from both databases
        source_data = call_tool(db_conn, "export_data", Dict(
            "database" => source_db,
            "table" => table_name,
            "format" => "json"
        ))
        
        target_data = call_tool(db_conn, "export_data", Dict(
            "database" => target_db,
            "table" => table_name,
            "format" => "json"
        ))
        
        # Compare record counts and key metrics
        source_records = JSON3.read(source_data)
        target_records = JSON3.read(target_data)
        
        validation_results[table_name] = Dict(
            "source_count" => length(source_records),
            "target_count" => length(target_records),
            "count_match" => length(source_records) == length(target_records),
            "data_integrity" => validate_data_integrity(source_records, target_records)
        )
    end
    
    return validation_results
end
```

### Rollback Strategy

```julia
function create_rollback_plan(migration_id)
    rollback_script = """
    -- Rollback script for $migration_id
    -- Generated: $(now())
    
    -- Drop target database
    DROP DATABASE IF EXISTS $target_database;
    
    -- Remove migration user if created
    DROP USER IF EXISTS $migration_user;
    
    -- Restore original state commands here
    """
    
    call_tool(file_conn, "write_file", Dict(
        "path" => "$migration_id/scripts/rollback.sql",
        "content" => rollback_script
    ))
end
```

### Migration Testing

```julia
function test_migration_integrity()
    test_results = []
    
    # Test 1: Record count validation
    for table in tables
        source_count = get_record_count(source_db, table)
        target_count = get_record_count(target_db, table)
        
        push!(test_results, Dict(
            "test" => "record_count_$table",
            "passed" => source_count == target_count,
            "source" => source_count,
            "target" => target_count
        ))
    end
    
    # Test 2: Data type preservation
    # Test 3: Constraint preservation  
    # Test 4: Index preservation
    # Test 5: Sample data validation
    
    return test_results
end
```

### Best Practices

1. **Backup First**: Always backup source database before migration
2. **Staging Environment**: Test migration in staging before production
3. **Incremental Migration**: Consider incremental migration for large datasets
4. **Downtime Planning**: Plan for maintenance windows and communication
5. **Monitoring**: Monitor migration progress and system resources

---

## Workflow 4: Multi-Server Orchestration

**File:** `examples/multi_server_orchestration.jl`

### Overview

Multi-server orchestration coordinates complex workflows across multiple MCP servers, enabling sophisticated data processing pipelines. This example demonstrates a complete e-commerce analytics pipeline.

### Architecture

```
File Server ←→ Database Admin ←→ PostgreSQL Server
     ↓               ↓                   ↓
File Operations  Schema Management   Query Execution
Data Storage     User Management      Analytics
Reporting        Migration Tools      Transactions
```

### Orchestration Patterns

#### 1. Coordinated Initialization

```julia
struct MultiServerOrchestrator
    file_conn::MCPConnection
    db_admin_conn::MCPConnection  
    postgres_conn::MCPConnection
end

function initialize_orchestrator(orch::MultiServerOrchestrator)
    # Initialize all servers in sequence
    initialize_server(orch.file_conn)
    initialize_server(orch.db_admin_conn)
    initialize_server(orch.postgres_conn)
    
    # Verify all connections are healthy
    validate_connections(orch)
end
```

#### 2. Complex Workflow Execution

```julia
function execute_analytics_pipeline(orch::MultiServerOrchestrator)
    # Phase 1: Infrastructure Setup
    setup_infrastructure(orch)
    
    # Phase 2: Data Generation and Storage
    generate_sample_data(orch)
    
    # Phase 3: Database Schema Creation
    create_analytics_schema(orch)
    
    # Phase 4: ETL Processing
    execute_etl_pipeline(orch)
    
    # Phase 5: Analytics and Reporting
    generate_analytics_reports(orch)
    
    # Phase 6: Data Export and Documentation
    export_results(orch)
end
```

#### 3. Error Handling Across Servers

```julia
function robust_pipeline_execution(orch::MultiServerOrchestrator)
    checkpoint_data = Dict()
    
    try
        # Checkpoint 1: Infrastructure
        checkpoint_data["infrastructure"] = setup_infrastructure(orch)
        
        # Checkpoint 2: Data Generation
        checkpoint_data["data_generation"] = generate_data(orch)
        
        # Checkpoint 3: Schema Creation
        checkpoint_data["schema"] = create_schema(orch)
        
        # Each phase can be recovered from its checkpoint
        
    catch e in ["infrastructure", "data_generation"]
        # Partial cleanup and retry
        cleanup_partial_state(orch, checkpoint_data)
        throw(e)
        
    catch e in ["schema", "etl"]
        # More extensive cleanup needed
        cleanup_database_state(orch, checkpoint_data)
        throw(e)
    end
end
```

### Advanced Patterns

#### 1. Data Flow Orchestration

```julia
function orchestrate_data_flow(orch::MultiServerOrchestrator)
    # Step 1: Generate synthetic data (File Server)
    raw_data = generate_synthetic_data(orch.file_conn)
    
    # Step 2: Create target schema (Database Admin)
    schema_result = create_target_schema(orch.db_admin_conn, raw_data.schema)
    
    # Step 3: Load and transform data (coordinated)
    load_result = load_transformed_data(orch, raw_data, schema_result)
    
    # Step 4: Execute analytics queries (PostgreSQL Server)
    analytics = execute_analytics_queries(orch.postgres_conn, load_result.tables)
    
    # Step 5: Export results (File Server)
    export_analytics_results(orch.file_conn, analytics)
end
```

#### 2. Transaction Coordination

```julia
function coordinated_transaction(orch::MultiServerOrchestrator, operations)
    transaction_id = generate_transaction_id()
    
    try
        # Phase 1: Prepare all operations
        for op in operations
            prepare_operation(orch, op, transaction_id)
        end
        
        # Phase 2: Execute all operations atomically
        results = []
        for op in operations
            result = execute_operation(orch, op, transaction_id)
            push!(results, result)
        end
        
        # Phase 3: Commit all changes
        commit_all_operations(orch, transaction_id)
        
        return results
        
    catch e
        # Rollback all operations on any failure
        rollback_all_operations(orch, transaction_id)
        rethrow(e)
    end
end
```

#### 3. Performance Monitoring

```julia
function monitor_pipeline_performance(orch::MultiServerOrchestrator, operations)
    metrics = Dict()
    
    for (name, operation) in operations
        start_time = time()
        
        try
            result = operation(orch)
            
            metrics[name] = Dict(
                "duration" => time() - start_time,
                "status" => "success",
                "result_size" => estimate_result_size(result)
            )
            
        catch e
            metrics[name] = Dict(
                "duration" => time() - start_time,
                "status" => "error",
                "error" => string(e)
            )
        end
    end
    
    # Generate performance report
    generate_performance_report(orch.file_conn, metrics)
    
    return metrics
end
```

### Real-World Applications

#### 1. Data Warehouse ETL

```julia
function data_warehouse_pipeline(orch::MultiServerOrchestrator)
    # Extract from multiple source systems
    sources = ["crm_data.csv", "sales_data.json", "inventory_data.xml"]
    
    extracted_data = []
    for source in sources
        data = call_tool(orch.file_conn, "read_file", Dict("path" => source))
        processed = transform_source_data(data, source)
        push!(extracted_data, processed)
    end
    
    # Create dimensional model
    create_dimensional_schema(orch.db_admin_conn)
    
    # Load into fact and dimension tables
    load_dimensional_data(orch.db_admin_conn, extracted_data)
    
    # Build aggregation tables
    build_aggregations(orch.postgres_conn)
    
    # Generate business reports
    generate_business_reports(orch)
end
```

#### 2. Machine Learning Pipeline

```julia
function ml_pipeline_orchestration(orch::MultiServerOrchestrator)
    # Data preparation phase
    training_data = prepare_training_data(orch)
    
    # Feature engineering (using database analytical functions)
    features = call_tool(orch.postgres_conn, "execute_query", Dict(
        "query" => build_feature_query(training_data.schema)
    ))
    
    # Export for ML training
    call_tool(orch.file_conn, "write_file", Dict(
        "path" => "ml/training_features.csv",
        "content" => features
    ))
    
    # Store model metadata in database
    store_model_metadata(orch.db_admin_conn, model_info)
end
```

### Best Practices for Orchestration

1. **Dependency Management**: Clearly define dependencies between operations
2. **State Management**: Maintain clear state and checkpoint recovery
3. **Resource Monitoring**: Monitor system resources across all servers
4. **Graceful Degradation**: Design for partial failure scenarios
5. **Logging and Tracing**: Implement distributed tracing across servers
6. **Testing**: Test orchestration patterns with synthetic failures

### Common Orchestration Patterns

1. **Pipeline Pattern**: Sequential processing with checkpoints
2. **Scatter-Gather**: Parallel processing with result aggregation  
3. **Saga Pattern**: Distributed transactions with compensation
4. **Event-Driven**: Reactive processing based on events
5. **Batch Processing**: Scheduled bulk operations

This orchestration capability enables building sophisticated data platforms that leverage the full power of the MCP server ecosystem while maintaining reliability and observability.