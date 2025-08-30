module MCPClient

using JSON3
using UUIDs
using Dates

export MCPConnection, call_tool, initialize_server, list_tools, close_connection

mutable struct MCPConnection
    process::Union{Base.Process, Nothing}
    server_path::String
    working_dir::String
    initialized::Bool
    request_id::Int
    
    MCPConnection(server_path::String, working_dir::String = ".") = new(nothing, server_path, working_dir, false, 0)
end

function start_server(conn::MCPConnection)
    if conn.process !== nothing && process_running(conn.process)
        return true
    end
    
    try
        # Start the Julia MCP server process
        julia_cmd = "/home/seren/test-project/julia-1.11.2/bin/julia"
        cmd = `$julia_cmd --project=$(conn.working_dir) $(conn.server_path)`
        conn.process = open(cmd, "r+")
        
        # Give the server a moment to start
        sleep(0.5)
        
        return process_running(conn.process)
    catch e
        @error "Failed to start MCP server" error=e
        return false
    end
end

function initialize_server(conn::MCPConnection)
    if !start_server(conn)
        throw(ArgumentError("Failed to start MCP server"))
    end
    
    conn.request_id += 1
    request = Dict(
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "params" => Dict{String,Any}(),
        "id" => conn.request_id
    )
    
    response = send_request(conn, request)
    
    if haskey(response, "result")
        conn.initialized = true
        return response["result"]
    else
        throw(ArgumentError("Server initialization failed: $(get(response, "error", "Unknown error"))"))
    end
end

function list_tools(conn::MCPConnection)
    if !conn.initialized
        initialize_server(conn)
    end
    
    conn.request_id += 1
    request = Dict(
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "params" => Dict{String,Any}(),
        "id" => conn.request_id
    )
    
    response = send_request(conn, request)
    
    if haskey(response, "result")
        return response["result"]["tools"]
    else
        throw(ArgumentError("Failed to list tools: $(get(response, "error", "Unknown error"))"))
    end
end

function call_tool(conn::MCPConnection, tool_name::String, arguments::Dict{String,Any} = Dict{String,Any}())
    if !conn.initialized
        initialize_server(conn)
    end
    
    conn.request_id += 1
    request = Dict(
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "params" => Dict(
            "name" => tool_name,
            "arguments" => arguments
        ),
        "id" => conn.request_id
    )
    
    response = send_request(conn, request)
    
    if haskey(response, "result")
        return response["result"]["content"][1]["text"]
    elseif haskey(response, "error")
        throw(ArgumentError("Tool call failed: $(response["error"]["message"])"))
    else
        throw(ArgumentError("Unexpected response format"))
    end
end

function send_request(conn::MCPConnection, request::Dict)
    if conn.process === nothing || !process_running(conn.process)
        throw(ArgumentError("MCP server is not running"))
    end
    
    try
        # Send request
        request_json = JSON3.write(request)
        println(conn.process.in, request_json)
        flush(conn.process.in)
        
        # Read response
        response_line = readline(conn.process.out)
        
        if isempty(response_line)
            throw(ArgumentError("Empty response from server"))
        end
        
        return JSON3.read(response_line)
    catch e
        @error "Communication error with MCP server" error=e
        rethrow(e)
    end
end

function close_connection(conn::MCPConnection)
    if conn.process !== nothing
        try
            close(conn.process.in)
            close(conn.process.out)
            kill(conn.process)
        catch e
            @warn "Error closing MCP connection" error=e
        finally
            conn.process = nothing
            conn.initialized = false
        end
    end
end

end # module