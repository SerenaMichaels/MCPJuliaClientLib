# MCP Julia Client

A comprehensive Model Context Protocol (MCP) client library and example suite for Julia, demonstrating advanced data management workflows using the [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer) toolkit.

## Overview

This project provides a complete MCP client implementation that orchestrates multiple MCP servers to perform complex data management tasks including database administration, file operations, ETL pipelines, and cross-database migrations.

## Features

- **🔌 MCP Client Library**: Complete Julia MCP client with JSON-RPC communication
- **🎼 Multi-Server Orchestration**: Coordinate multiple MCP servers simultaneously  
- **📊 Database-First Workflows**: Schema-driven development with JSON schema support
- **📂➡️🗄️ ETL Pipelines**: File-to-database data processing pipelines
- **🔄 Database Migration**: Cross-database migration with validation and rollback
- **📈 Analytics Workflows**: End-to-end analytics pipeline orchestration
- **🛡️ Error Handling**: Robust error handling and recovery across servers
- **📋 Comprehensive Examples**: Real-world workflow demonstrations

## Architecture

```
MCP Julia Client
    ├── MCPClient.jl (Core client library)
    └── Examples:
        ├── Database-First Workflow
        ├── File-to-Database Pipeline  
        ├── Cross-Database Migration
        └── Multi-Server Orchestration
            ↓
Julia MCP Servers (MCPJuliaServer)
    ├── File Server → Filesystem Operations
    ├── PostgreSQL Server → Database Queries
    └── Database Admin → Database Management
```

## Prerequisites

1. **Julia MCP Server Suite**: Clone and set up [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer)
2. **PostgreSQL**: Running PostgreSQL instance (tested with PostgreSQL 17)
3. **Julia 1.6+**: Julia programming language

## Installation

```bash
# Clone the repository
git clone https://github.com/SerenaMichaels/MCPJuliaClient.git
cd MCPJuliaClient

# Activate the project
julia --project=.

# Install dependencies
julia -e "using Pkg; Pkg.instantiate()"
```

## Quick Start

### 1. Basic MCP Client Usage

```julia
using Pkg
Pkg.activate(".")

include("src/MCPClient.jl")
using .MCPClient

# Connect to a server
conn = MCPConnection("../julia_mcp_server/db_admin_example.jl", "../julia_mcp_server")

# Initialize and use
initialize_server(conn)
tools = list_tools(conn)
result = call_tool(conn, "create_database", Dict("name" => "test_db"))

close_connection(conn)
```

### 2. Run Example Workflows

```bash
# Database-first workflow
julia examples/database_first_workflow.jl

# File-to-database ETL pipeline  
julia examples/file_to_database_pipeline.jl

# Cross-database migration
julia examples/cross_database_migration.jl

# Multi-server orchestration
julia examples/multi_server_orchestration.jl
```

## Example Workflows

### 🗄️ Database-First Workflow

Creates database structure, users, and tables from JSON schemas:

- **Database Creation**: Create project-specific databases
- **User Management**: Set up database users with appropriate privileges
- **Schema Design**: Convert JSON schemas to SQL tables
- **Data Import**: Load initial data from JSON/CSV
- **Documentation**: Export schemas and generate reports

**Key Features:**
- JSON schema → SQL table conversion
- Role-based access control
- Data validation and import
- Schema version control

### 📂➡️🗄️ File-to-Database Pipeline

Automated ETL pipeline from filesystem to database:

- **File Discovery**: Automatically discover CSV/JSON data files
- **Data Processing**: Validate and transform file data
- **Database Loading**: Import processed data into tables
- **File Management**: Archive processed files
- **Quality Reporting**: Generate data quality reports

**Key Features:**
- Multi-format support (CSV, JSON)
- Data transformation and validation
- Automated file archiving
- Pipeline monitoring and reporting

### 🔄 Cross-Database Migration

Complete database migration with validation:

- **Schema Export**: Extract schemas in SQL and JSON formats
- **Data Export**: Export all table data with consistency
- **Target Preparation**: Create and configure target database
- **Data Import**: Import schema and data to target
- **Validation**: Verify migration integrity
- **Documentation**: Generate migration reports and manifests

**Key Features:**
- Schema and data preservation
- Migration validation and rollback
- Audit trail and documentation
- Environment promotion workflows

### 🎼 Multi-Server Orchestration

Complex analytics pipeline using all MCP servers:

- **Infrastructure Setup**: Create databases, users, and workspaces
- **Data Generation**: Generate synthetic e-commerce data
- **ETL Processing**: Transform and load data into analytics tables
- **Analytics Queries**: Execute complex analytical queries
- **Report Generation**: Create executive dashboards and reports
- **Data Export**: Export processed data for external tools

**Key Features:**
- Coordinated multi-server operations
- Complex data transformations
- Analytics query execution
- Executive reporting
- Data warehouse patterns

## MCP Client API

### Core Functions

```julia
# Connection management
conn = MCPConnection(server_path, working_directory)
initialize_server(conn)
close_connection(conn)

# Server interaction
tools = list_tools(conn)
result = call_tool(conn, "tool_name", arguments_dict)
```

### Error Handling

```julia
try
    result = call_tool(conn, "risky_operation", args)
catch e
    @error "Operation failed" error=e
    # Implement recovery logic
finally
    close_connection(conn)
end
```

## Testing

Run individual examples to test different workflows:

```bash
# Test all examples
julia scripts/test_all_examples.jl

# Test specific workflow
julia examples/database_first_workflow.jl
```

## Project Structure

```
MCPJuliaClient/
├── Project.toml              # Julia project configuration
├── README.md                 # This file
├── src/
│   └── MCPClient.jl          # Core MCP client library
├── examples/
│   ├── database_first_workflow.jl
│   ├── file_to_database_pipeline.jl
│   ├── cross_database_migration.jl
│   └── multi_server_orchestration.jl
├── scripts/
│   └── test_all_examples.jl  # Test runner
└── data/                     # Sample data files
```

## Configuration

### Server Paths

Update server paths in examples to match your MCPJuliaServer installation:

```julia
# Update these paths in examples
server_path = "../../julia_mcp_server/db_admin_example.jl"
working_dir = "../../julia_mcp_server"
```

### PostgreSQL Configuration  

Configure PostgreSQL connection via environment variables:

```bash
export POSTGRES_HOST="localhost"
export POSTGRES_PORT="5432"
export POSTGRES_USER="postgres"
export POSTGRES_PASSWORD="your_password"
export POSTGRES_DB="postgres"
```

## Use Cases

### Development Workflows
- **Schema Evolution**: Manage database schema changes across environments
- **Data Seeding**: Populate development databases with test data
- **Environment Sync**: Keep development and staging databases in sync

### Data Engineering
- **ETL Pipelines**: Extract, transform, and load data from various sources
- **Data Migration**: Move data between different database systems
- **Data Validation**: Ensure data quality and consistency

### Analytics & Reporting
- **Data Warehousing**: Build dimensional models and fact tables
- **Report Generation**: Create automated analytical reports
- **Data Export**: Prepare data for BI tools and external systems

### Operations & DevOps
- **Database Provisioning**: Automated database and user creation
- **Backup & Recovery**: Automated backup and restore procedures
- **Monitoring**: Database health checks and performance monitoring

## Advanced Features

### Multi-Server Coordination
- Orchestrate file, database, and query operations
- Handle complex dependencies between operations
- Implement sophisticated error recovery

### Data Lineage Tracking
- Track data transformations across pipeline stages
- Maintain audit trails for compliance
- Version control for schemas and transformations

### Performance Optimization
- Connection pooling and reuse
- Parallel processing where applicable
- Efficient data transfer formats

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality  
4. Submit a pull request

## Dependencies

- **JSON3.jl**: JSON parsing and generation
- **UUIDs.jl**: Unique identifier generation
- **Dates.jl**: Date and time handling
- **MCPJuliaServer**: The MCP server suite (separate repository)

## License

This is a demonstration implementation of MCP client workflows in Julia.

## Related Projects

- [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer): The companion MCP server suite
- [Model Context Protocol](https://modelcontextprotocol.io/): Official MCP specification

## Support

For issues and questions:
- Check existing [Issues](https://github.com/SerenaMichaels/MCPJuliaClient/issues)
- Review the MCPJuliaServer [documentation](https://github.com/SerenaMichaels/MCPJuliaServer)
- Ensure PostgreSQL is properly configured and accessible