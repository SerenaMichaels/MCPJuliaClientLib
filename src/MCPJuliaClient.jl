module MCPJuliaClient

include("MCPClient.jl")

using .MCPClient

export MCPConnection, call_tool, initialize_server, list_tools, close_connection

end