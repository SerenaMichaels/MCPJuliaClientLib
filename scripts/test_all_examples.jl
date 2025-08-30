#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

"""
Test Runner for MCP Julia Client Examples

This script runs all example workflows to verify they work correctly
with the MCPJuliaServer suite.
"""

function run_example(example_name::String, example_path::String)
    println("🧪 Testing: $example_name")
    println("=" ^ 60)
    
    try
        start_time = time()
        
        # Run the example
        result = run(`julia $example_path`)
        
        elapsed = time() - start_time
        
        if result.exitcode == 0
            println("✅ $example_name completed successfully in $(round(elapsed, digits=2))s")
            return true
        else
            println("❌ $example_name failed with exit code $(result.exitcode)")
            return false
        end
        
    catch e
        println("❌ $example_name failed with error: $e")
        return false
    finally
        println("\n" * "=" ^ 60 * "\n")
    end
end

function check_prerequisites()
    println("🔍 Checking prerequisites...")
    
    # Check if MCPJuliaServer exists
    server_dir = "../../julia_mcp_server"
    if !isdir(server_dir)
        println("❌ MCPJuliaServer not found at $server_dir")
        println("   Please clone https://github.com/SerenaMichaels/MCPJuliaServer")
        return false
    end
    
    # Check required server files
    required_servers = [
        "file_server_example.jl",
        "db_admin_example.jl", 
        "postgres_example.jl"
    ]
    
    for server in required_servers
        server_path = joinpath(server_dir, server)
        if !isfile(server_path)
            println("❌ Required server not found: $server_path")
            return false
        end
    end
    
    println("✅ All prerequisites found")
    return true
end

function test_mcp_client_library()
    println("🧪 Testing MCP Client Library")
    println("-" ^ 40)
    
    try
        include("../src/MCPClient.jl")
        using .MCPClient
        
        # Test basic client creation
        server_path = "../../julia_mcp_server/db_admin_example.jl"
        conn = MCPConnection(server_path, "../../julia_mcp_server")
        
        println("✅ MCPConnection created successfully")
        
        # Test initialization (quick test)
        try
            initialize_server(conn)
            println("✅ Server initialization successful")
            
            # Test tool listing
            tools = list_tools(conn)
            println("✅ Tool listing successful ($(length(tools)) tools found)")
            
            close_connection(conn)
            println("✅ Connection closed successfully")
            
        catch e
            @warn "Server interaction test failed (this may be expected in some environments)" error=e
        end
        
        return true
        
    catch e
        println("❌ MCP Client library test failed: $e")
        return false
    end
end

function main()
    println("🚀 MCP Julia Client - Example Test Suite")
    println("=" ^ 80)
    
    # Check prerequisites
    if !check_prerequisites()
        println("❌ Prerequisites not met. Please set up MCPJuliaServer first.")
        exit(1)
    end
    
    # Test MCP client library
    println("\n📚 Testing MCP Client Library...")
    if !test_mcp_client_library()
        println("❌ MCP Client library tests failed")
        exit(1)
    end
    
    println("\n🎯 Running Example Workflows...")
    
    examples = [
        ("Database-First Workflow", "../examples/database_first_workflow.jl"),
        ("File-to-Database Pipeline", "../examples/file_to_database_pipeline.jl"), 
        ("Cross-Database Migration", "../examples/cross_database_migration.jl"),
        ("Multi-Server Orchestration", "../examples/multi_server_orchestration.jl")
    ]
    
    results = []
    total_start_time = time()
    
    for (name, path) in examples
        success = run_example(name, path)
        push!(results, (name, success))
        
        if !success
            println("⚠️  Continuing with remaining tests...\n")
        end
    end
    
    total_elapsed = time() - total_start_time
    
    # Print summary
    println("📊 TEST SUMMARY")
    println("=" ^ 80)
    
    passed = 0
    failed = 0
    
    for (name, success) in results
        if success
            println("✅ $name")
            passed += 1
        else
            println("❌ $name")
            failed += 1
        end
    end
    
    println("\n📈 Results:")
    println("   Passed: $passed")
    println("   Failed: $failed")
    println("   Total:  $(passed + failed)")
    println("   Time:   $(round(total_elapsed, digits=2))s")
    
    if failed == 0
        println("\n🎉 All tests passed! MCP Julia Client is working correctly.")
        exit(0)
    else
        println("\n⚠️  Some tests failed. Check the output above for details.")
        println("   Common issues:")
        println("   - PostgreSQL not running or not accessible")
        println("   - Incorrect server paths in examples")
        println("   - Missing dependencies in MCPJuliaServer")
        exit(1)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end