# Troubleshooting Guide

This guide helps diagnose and resolve common issues with the MCP Julia Client.

## Common Issues and Solutions

### Connection Problems

#### "Failed to start MCP server"

**Symptoms:**
- `ArgumentError: Failed to start MCP server`
- Server process fails to spawn

**Causes and Solutions:**

1. **Incorrect Julia Path**
   ```julia
   # In src/MCPClient.jl, verify julia_cmd path
   julia_cmd = "/correct/path/to/julia"
   ```

2. **Invalid Server Path**
   ```julia
   # Use absolute paths
   server_path = "/home/user/servers/db_admin_example.jl"  # ✅ Correct
   server_path = "../../servers/db_admin_example.jl"      # ❌ May fail
   ```

3. **Missing Server Dependencies**
   ```bash
   # Install server dependencies
   cd /path/to/julia_mcp_server
   julia --project=. -e "using Pkg; Pkg.instantiate()"
   ```

4. **File Permissions**
   ```bash
   # Ensure server files are executable
   chmod +x /path/to/server.jl
   ```

#### "Empty response from server"

**Symptoms:**
- Server starts but returns empty responses
- JSON parsing errors

**Causes and Solutions:**

1. **Server Startup Errors**
   - Check if server has dependency issues
   - Test server manually: `julia server.jl`
   - Review server error output

2. **Non-JSON Output Contamination**
   - Server may print status messages that interfere with JSON-RPC
   - Check server logs for println statements

3. **PostgreSQL Connection Issues** (for database servers)
   ```bash
   # Verify PostgreSQL is running
   systemctl status postgresql
   
   # Test connection
   psql -h localhost -U postgres -d postgres
   ```

#### "Communication error with MCP server"

**Symptoms:**
- `ArgumentError: invalid JSON at byte position X`
- Protocol violations

**Solutions:**

1. **Check Server Output Format**
   ```bash
   # Test server manually to see raw output
   echo '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | julia server.jl
   ```

2. **Server Process Management**
   ```julia
   # Ensure proper process cleanup
   close_connection(conn)  # Always call in finally block
   ```

### Database-Related Issues

#### "Package LibPQ not found"

**Symptoms:**
- Database servers fail to start
- Missing dependency errors

**Solutions:**

1. **Install LibPQ in Server Environment**
   ```bash
   cd /path/to/julia_mcp_server
   julia --project=. -e "using Pkg; Pkg.add(\"LibPQ\")"
   ```

2. **Verify Installation**
   ```bash
   julia --project=. -e "using LibPQ; println(\"LibPQ loaded\")"
   ```

#### "Database connection failed"

**Symptoms:**
- PostgreSQL connection timeouts
- Authentication failures

**Solutions:**

1. **Check PostgreSQL Status**
   ```bash
   systemctl status postgresql
   netstat -ln | grep 5432
   ```

2. **Verify Connection Parameters**
   ```bash
   export POSTGRES_HOST="localhost"
   export POSTGRES_PORT="5432"
   export POSTGRES_USER="postgres"
   export POSTGRES_PASSWORD="your_password"
   ```

3. **Test Direct Connection**
   ```bash
   psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB
   ```

4. **Check pg_hba.conf Configuration**
   ```
   # Add line for your connection method
   host    all             all             127.0.0.1/32            scram-sha-256
   ```

### Tool Execution Issues

#### "Tool call failed"

**Symptoms:**
- Specific tools return error messages
- Parameter validation failures

**Solutions:**

1. **Verify Tool Parameters**
   ```julia
   # Check required parameters
   tools = list_tools(conn)
   target_tool = filter(t -> t["name"] == "your_tool", tools)[1]
   println(target_tool["inputSchema"])
   ```

2. **Parameter Type Validation**
   ```julia
   # Ensure correct parameter types
   args = Dict{String,Any}(
       "name" => "string_value",        # String
       "count" => 42,                   # Integer
       "enabled" => true,               # Boolean
       "items" => ["a", "b", "c"]       # Array
   )
   ```

3. **Database-Specific Issues**
   ```julia
   # For database tools, check database exists and is accessible
   result = call_tool(conn, "list_databases", Dict())
   ```

### Performance Issues

#### "Server response timeout"

**Symptoms:**
- Long delays in server responses
- Operations appear to hang

**Solutions:**

1. **Increase Timeout Values**
   ```julia
   # In MCPClient.jl, adjust sleep duration
   sleep(1.0)  # Increase from 0.5 seconds
   ```

2. **Database Performance**
   ```sql
   -- Check for slow queries
   SELECT query, mean_exec_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_exec_time DESC;
   ```

3. **Resource Monitoring**
   ```bash
   # Monitor system resources
   htop
   iostat -x 1
   ```

### Memory Issues

#### "Out of memory errors"

**Symptoms:**
- Julia processes crash with memory errors
- System becomes unresponsive

**Solutions:**

1. **Limit Data Processing Size**
   ```julia
   # Use pagination for large datasets
   result = call_tool(conn, "export_data", Dict(
       "table" => "large_table",
       "limit" => 1000  # Process in chunks
   ))
   ```

2. **Stream Large Files**
   ```julia
   # Instead of loading entire file
   # Process files in chunks
   ```

## Debugging Techniques

### Enable Verbose Logging

Add debugging output to understand execution flow:

```julia
function debug_call_tool(conn, tool_name, args)
    @info "Calling tool: $tool_name with args: $args"
    
    try
        result = call_tool(conn, tool_name, args)
        @info "Tool result: $result"
        return result
    catch e
        @error "Tool failed: $e"
        rethrow(e)
    end
end
```

### Test Individual Components

#### Test Server Startup
```julia
function test_server_startup(server_path, working_dir)
    conn = MCPConnection(server_path, working_dir)
    
    try
        if MCPClient.start_server(conn)
            println("✅ Server started successfully")
            return true
        else
            println("❌ Server failed to start")
            return false
        end
    finally
        close_connection(conn)
    end
end
```

#### Test JSON-RPC Communication
```julia
function test_json_rpc(conn)
    request = Dict(
        "jsonrpc" => "2.0",
        "method" => "initialize", 
        "params" => Dict(),
        "id" => 1
    )
    
    try
        response = MCPClient.send_request(conn, request)
        println("✅ JSON-RPC communication working")
        println("Response: $response")
        return true
    catch e
        println("❌ JSON-RPC communication failed: $e")
        return false
    end
end
```

### Environment Validation

#### System Check Script
```julia
function validate_environment()
    checks = []
    
    # Check Julia version
    push!(checks, ("Julia version", VERSION >= v"1.6"))
    
    # Check server files exist
    server_dir = "/path/to/julia_mcp_server"
    required_files = ["db_admin_example.jl", "file_server_example.jl", "postgres_example.jl"]
    
    for file in required_files
        path = joinpath(server_dir, file)
        push!(checks, ("Server file: $file", isfile(path)))
    end
    
    # Check PostgreSQL connection
    try
        run(`psql -h localhost -U postgres -d postgres -c "SELECT 1" -t`)
        push!(checks, ("PostgreSQL connection", true))
    catch
        push!(checks, ("PostgreSQL connection", false))
    end
    
    # Print results
    for (check, passed) in checks
        status = passed ? "✅" : "❌"
        println("$status $check")
    end
    
    return all(check[2] for check in checks)
end
```

## Error Code Reference

### MCPClient Errors

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "Failed to start MCP server" | Server process spawn failure | Check Julia path and server file |
| "Empty response from server" | Server startup issues or output contamination | Check server dependencies and output |
| "invalid JSON at byte position X" | Non-JSON output from server | Review server output for println statements |
| "Server initialization failed" | MCP handshake failure | Check server MCP protocol implementation |
| "Tool call failed" | Invalid parameters or server error | Validate parameters and check server logs |

### Database Errors

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "Package LibPQ not found" | Missing database dependency | Install LibPQ in server environment |
| "Database connection failed" | PostgreSQL connectivity | Check PostgreSQL status and configuration |
| "Connection pool exhausted" | Too many concurrent connections | Reduce concurrency or increase pool size |
| "Permission denied" | Database access rights | Check user privileges and pg_hba.conf |

## Getting Help

### Diagnostic Information Collection

When reporting issues, include:

1. **Environment Information**
   ```julia
   println("Julia version: ", VERSION)
   println("OS: ", Sys.KERNEL)
   println("Architecture: ", Sys.MACHINE)
   ```

2. **Server Configuration**
   ```julia
   println("Server path: ", server_path)
   println("Working directory: ", working_dir)
   println("Server files exist: ", isfile(server_path))
   ```

3. **Error Details**
   - Full error message and stack trace
   - Steps to reproduce the issue
   - Expected vs. actual behavior

### Testing Minimal Examples

Create minimal reproduction cases:

```julia
# Minimal connection test
function minimal_test()
    conn = MCPConnection(server_path, working_dir)
    
    try
        initialize_server(conn)
        tools = list_tools(conn)
        println("Success: Connected with $(length(tools)) tools")
    catch e
        println("Failed: $e")
    finally
        close_connection(conn)
    end
end
```

### Community Resources

- Check [MCPJuliaServer Issues](https://github.com/SerenaMichaels/MCPJuliaServer/issues)
- Review [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- Consult Julia package documentation for dependencies