# MCP Julia Client API Reference

## Core Types

### `MCPConnection`

The main connection object for communicating with MCP servers.

```julia
mutable struct MCPConnection
    process::Union{Base.Process, Nothing}
    server_path::String
    working_dir::String
    initialized::Bool
    request_id::Int
end
```

#### Constructor

```julia
MCPConnection(server_path::String, working_dir::String = ".")
```

**Parameters:**
- `server_path`: Absolute path to the MCP server executable (e.g., `/path/to/server.jl`)
- `working_dir`: Working directory for the server process (default: current directory)

**Example:**
```julia
conn = MCPConnection("/home/user/servers/db_admin.jl", "/home/user/servers")
```

## Core Functions

### Connection Management

#### `initialize_server(conn::MCPConnection)`

Starts the MCP server process and performs the MCP initialization handshake.

**Returns:** Initialization result dictionary containing server information

**Throws:** `ArgumentError` if server fails to start or initialize

**Example:**
```julia
conn = MCPConnection(server_path, working_dir)
result = initialize_server(conn)
println("Connected to: $(result["name"])")
```

#### `close_connection(conn::MCPConnection)`

Gracefully closes the connection to the MCP server and terminates the process.

**Example:**
```julia
close_connection(conn)
```

### Tool Operations

#### `list_tools(conn::MCPConnection)`

Retrieves a list of all available tools from the MCP server.

**Returns:** Array of tool dictionaries, each containing:
- `name`: Tool identifier
- `description`: Tool description
- `inputSchema`: JSON schema for tool parameters

**Example:**
```julia
tools = list_tools(conn)
for tool in tools
    println("Tool: $(tool["name"]) - $(tool["description"])")
end
```

#### `call_tool(conn::MCPConnection, tool_name::String, arguments::Dict{String,Any})`

Executes a specific tool with the provided arguments.

**Parameters:**
- `tool_name`: Name of the tool to execute
- `arguments`: Dictionary of parameters for the tool

**Returns:** String containing the tool's response

**Throws:** `ArgumentError` if tool call fails

**Example:**
```julia
result = call_tool(conn, "create_database", Dict(
    "name" => "my_database",
    "owner" => "postgres"
))
println(result)  # "Database 'my_database' created successfully"
```

## Error Handling

All functions may throw `ArgumentError` with descriptive messages for various failure conditions:

- **Connection errors**: Server process fails to start or becomes unresponsive
- **Communication errors**: JSON-RPC protocol violations or network issues
- **Tool errors**: Invalid tool names, parameters, or tool execution failures

### Best Practices

Always use try-catch blocks and ensure connections are closed:

```julia
conn = MCPConnection(server_path, working_dir)
try
    initialize_server(conn)
    result = call_tool(conn, "my_tool", arguments)
    # Process result
catch e
    @error "Operation failed" error=e
    # Handle error appropriately
finally
    close_connection(conn)
end
```

## Advanced Usage

### Connection Reuse

Once initialized, a connection can be reused for multiple tool calls:

```julia
conn = MCPConnection(server_path, working_dir)
initialize_server(conn)

# Multiple tool calls on same connection
db_result = call_tool(conn, "create_database", db_args)
table_result = call_tool(conn, "create_table", table_args)
data_result = call_tool(conn, "import_data", data_args)

close_connection(conn)
```

### Multi-Server Orchestration

Manage multiple servers simultaneously:

```julia
file_conn = MCPConnection(file_server_path, server_dir)
db_conn = MCPConnection(db_server_path, server_dir)

try
    initialize_server(file_conn)
    initialize_server(db_conn)
    
    # Coordinate operations across servers
    data = call_tool(file_conn, "read_file", Dict("path" => "data.json"))
    result = call_tool(db_conn, "import_data", Dict("data" => data))
    
finally
    close_connection(file_conn)
    close_connection(db_conn)
end
```

## Internal Functions

These functions are used internally and generally don't need to be called directly:

### `start_server(conn::MCPConnection)`

Low-level function to start the server process without initialization.

### `send_request(conn::MCPConnection, request::Dict)`

Low-level function to send JSON-RPC requests and receive responses.

## Configuration

### Julia Executable Path

The client uses a hardcoded path to Julia. To use a different Julia installation, modify the `julia_cmd` variable in `src/MCPClient.jl`:

```julia
julia_cmd = "/path/to/your/julia"
```

### Timeouts and Retries

The client includes basic timeout handling. Server startup waits 0.5 seconds for process initialization. For long-running operations, consider implementing application-level timeouts.

## Debugging

### Enable Verbose Logging

Add debug prints to understand communication flow:

```julia
@info "Sending request: $request_json"
@info "Received response: $response_line"
```

### Common Issues

1. **"Failed to start MCP server"**: Check server path and Julia executable path
2. **"Empty response from server"**: Server may have crashed or has dependency issues
3. **"Invalid JSON"**: Server is printing non-JSON output (status messages, errors)
4. **"Tool call failed"**: Check tool name and parameter format

### Testing Connections

Use a simple test to verify connectivity:

```julia
conn = MCPConnection(server_path, working_dir)
try
    result = initialize_server(conn)
    tools = list_tools(conn)
    println("Successfully connected to $(result["name"]) with $(length(tools)) tools")
catch e
    println("Connection failed: $e")
finally
    close_connection(conn)
end
```