# MCP Julia Client Installation Guide

This guide provides comprehensive installation instructions for the MCP Julia Client across different platforms.

## Quick Install

### Prerequisites
- Julia 1.6+
- [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer) (installed and configured)
- Git

### One-Line Install (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/SerenaMichaels/MCPJuliaClientLib/main/scripts/install.sh | bash
```

### Manual Installation
```bash
# 1. Clone repository
git clone https://github.com/SerenaMichaels/MCPJuliaClientLib.git
cd MCPJuliaClientLib

# 2. Install dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"

# 3. Configure environment
cp .env.example .env
# Edit .env with your settings

# 4. Test installation
julia examples/database_first_workflow.jl
```

## Platform-Specific Installation

### Ubuntu/Debian

#### System Dependencies
```bash
# Update package list
sudo apt update

# Install Julia
curl -fsSL https://install.julialang.org | sh
# OR from package manager
sudo apt install julia

# Install Git
sudo apt install git curl
```

#### Julia Package Dependencies
```bash
# Navigate to client directory
cd MCPJuliaClientLib

# Install Julia dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### CentOS/RHEL/Fedora

#### System Dependencies
```bash
# Fedora
sudo dnf install julia git curl

# CentOS/RHEL
sudo dnf install epel-release
sudo dnf install git curl

# Install Julia manually if not in repos
curl -fsSL https://install.julialang.org | sh
```

### Windows

#### Native Windows Installation
```powershell
# Install Julia from https://julialang.org/downloads/
# Install Git
winget install Git.Git

# Clone repository
git clone https://github.com/SerenaMichaels/MCPJuliaClientLib.git
cd MCPJuliaClientLib

# Install Julia dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

#### Windows Subsystem for Linux (WSL)
```bash
# Install WSL2 with Ubuntu
wsl --install -d Ubuntu-20.04

# Follow Ubuntu installation instructions above
```

### macOS

#### Using Homebrew
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install julia git

# Clone and setup
git clone https://github.com/SerenaMichaels/MCPJuliaClientLib.git
cd MCPJuliaClientLib
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

## Configuration

### Environment Variables

Create `.env` file from template:
```bash
cp .env.example .env
```

#### Essential Configuration
```bash
# Julia executable path
JULIA_PATH=/usr/local/bin/julia

# MCP Server directory (where MCPJuliaServer is installed)
MCP_SERVER_DIR=/opt/mcp-julia-server

# PostgreSQL connection (if using database examples)
POSTGRES_HOST=localhost
POSTGRES_PASSWORD=your_secure_password
```

#### Platform-Specific Paths

**Linux (System Install):**
```bash
JULIA_PATH=/usr/local/bin/julia
MCP_SERVER_DIR=/opt/mcp-julia-server
```

**Linux (User Install):**
```bash
JULIA_PATH=$HOME/.local/bin/julia
MCP_SERVER_DIR=$HOME/MCPJuliaServer
```

**Windows:**
```bash
JULIA_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Julia\Julia-1.11.2\bin\julia.exe
MCP_SERVER_DIR=C:\mcp-julia-server
```

**macOS (Homebrew):**
```bash
JULIA_PATH=/usr/local/bin/julia
MCP_SERVER_DIR=/usr/local/opt/mcp-julia-server
```

**WSL:**
```bash
JULIA_PATH=/usr/local/bin/julia
MCP_SERVER_DIR=/opt/mcp-julia-server
# Or access Windows installation:
# MCP_SERVER_DIR=/mnt/c/mcp-julia-server
```

### Server Configuration

The client requires a properly configured MCPJuliaServer installation. See the [MCPJuliaServer Installation Guide](https://github.com/SerenaMichaels/MCPJuliaServer/blob/main/INSTALL.md) for setup instructions.

#### Verify Server Installation
```bash
# Test server availability
ls -la $MCP_SERVER_DIR/*.jl

# Check required servers exist
ls -la $MCP_SERVER_DIR/file_server_example.jl
ls -la $MCP_SERVER_DIR/db_admin_example.jl
ls -la $MCP_SERVER_DIR/postgres_example.jl
```

## Usage Examples

### Basic Client Usage
```bash
# Navigate to client directory
cd MCPJuliaClientLib

# Load environment variables
source .env

# Run basic example
julia -e "
include(\"src/MCPClient.jl\")
using .MCPClient

conn = MCPConnection(\"\$MCP_SERVER_DIR/file_server_example.jl\", \"\$MCP_SERVER_DIR\")
try
    initialize_server(conn)
    tools = list_tools(conn)
    println(\"Connected successfully with \$(length(tools)) tools\")
finally
    close_connection(conn)
end
"
```

### Workflow Examples
```bash
# Database-first workflow
julia examples/database_first_workflow.jl

# ETL pipeline
julia examples/file_to_database_pipeline.jl

# Database migration
julia examples/cross_database_migration.jl

# Multi-server orchestration
julia examples/multi_server_orchestration.jl
```

## Docker Installation

### Using Docker Compose
```yaml
version: '3.8'
services:
  mcp-client:
    build: .
    volumes:
      - ./examples:/app/examples
      - ./data:/app/data
    environment:
      - MCP_SERVER_DIR=/app/servers
      - POSTGRES_HOST=postgres
      - POSTGRES_PASSWORD=secure_password
    depends_on:
      - mcp-servers
```

### Standalone Docker
```bash
# Build image
docker build -t mcp-julia-client .

# Run with server access
docker run -it \
  -e MCP_SERVER_DIR=/app/servers \
  -e POSTGRES_HOST=host.docker.internal \
  -e POSTGRES_PASSWORD=your_password \
  -v $(pwd)/examples:/app/examples \
  mcp-julia-client julia examples/database_first_workflow.jl
```

## Development Setup

### IDE Configuration

#### VS Code
Install recommended extensions:
- Julia Language Support
- Julia Formatter
- GitLens

Create `.vscode/settings.json`:
```json
{
    "julia.executablePath": "/usr/local/bin/julia",
    "julia.environmentPath": ".",
    "julia.lint.run": true,
    "julia.format.indent": 4
}
```

#### Jupyter/IJulia Setup
```bash
# Install IJulia in the project environment
julia --project=. -e "using Pkg; Pkg.add(\"IJulia\")"

# Start Jupyter
julia --project=. -e "using IJulia; notebook()"
```

### Development Dependencies
```bash
# Add development packages
julia --project=. -e "
using Pkg
Pkg.add(\"BenchmarkTools\")  # Performance testing
Pkg.add(\"Test\")            # Unit testing
Pkg.add(\"Logging\")         # Enhanced logging
"
```

## Testing

### Automated Tests
```bash
# Run all tests
julia --project=. scripts/test_all_examples.jl

# Run specific test
julia --project=. -e "include(\"examples/database_first_workflow.jl\")"
```

### Manual Verification
```bash
# Check dependencies
julia --project=. -e "using Pkg; Pkg.status()"

# Test server connectivity
julia --project=. -e "
include(\"src/MCPClient.jl\")
using .MCPClient
# Test connection...
"
```

## Troubleshooting

### Common Issues

#### "Julia not found"
```bash
# Find Julia installation
which julia

# Add to PATH
export PATH=\"\$PATH:/usr/local/julia/bin\"
echo 'export PATH=\"\$PATH:/usr/local/julia/bin\"' >> ~/.bashrc
```

#### "Server not found"
```bash
# Verify server path
ls -la \$MCP_SERVER_DIR/

# Check environment variable
echo \$MCP_SERVER_DIR

# Update .env file
nano .env
```

#### "Connection failed"
```bash
# Check server logs
tail -f \$MCP_SERVER_DIR/logs/server.log

# Test server manually
julia --project=\$MCP_SERVER_DIR \$MCP_SERVER_DIR/file_server_example.jl
```

### Debug Mode
Enable debug mode for detailed logs:
```bash
export MCP_DEBUG_COMMUNICATION=true
julia examples/database_first_workflow.jl
```

### Log Analysis
```bash
# View client logs
tail -f ~/.julia/logs/mcp-client.log

# Check system logs
journalctl -u mcp-julia-client -f  # if using systemd service
```

## Deployment

### Production Deployment

#### Systemd Service (Linux)
```bash
# Create service file
sudo tee /etc/systemd/system/mcp-julia-client.service <<EOF
[Unit]
Description=MCP Julia Client Service
After=mcp-julia-server.service

[Service]
Type=oneshot
User=mcpclient
WorkingDirectory=/opt/mcp-julia-client
EnvironmentFile=/opt/mcp-julia-client/.env
ExecStart=/usr/local/bin/julia --project=. examples/multi_server_orchestration.jl

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mcp-julia-client
```

#### Cron Jobs
```bash
# Add to crontab for scheduled workflows
crontab -e

# Run ETL pipeline daily at 2 AM
0 2 * * * cd /opt/mcp-julia-client && /usr/local/bin/julia --project=. examples/file_to_database_pipeline.jl
```

### Container Orchestration

#### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-julia-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mcp-julia-client
  template:
    metadata:
      labels:
        app: mcp-julia-client
    spec:
      containers:
      - name: client
        image: mcp-julia-client:latest
        env:
        - name: MCP_SERVER_DIR
          value: "/app/servers"
        - name: POSTGRES_HOST
          value: "postgres-service"
        volumeMounts:
        - name: config
          mountPath: /app/.env
          subPath: .env
      volumes:
      - name: config
        configMap:
          name: mcp-client-config
```

## Performance Optimization

### Julia Precompilation
```bash
# Precompile packages for faster startup
julia --project=. -e "using Pkg; Pkg.precompile()"
```

### Connection Pooling
Enable connection reuse in production:
```julia
# In your application code
const CONNECTION_POOL = Dict{String, MCPConnection}()

function get_pooled_connection(server_type::String)
    if haskey(CONNECTION_POOL, server_type)
        return CONNECTION_POOL[server_type]
    end
    # Create new connection...
end
```

### Memory Management
```bash
# Monitor memory usage
julia --project=. -e "
using .MCPClient
# Monitor memory with @time and @allocated macros
"
```

## Support

### Getting Help
- Check logs: `tail -f ~/.julia/logs/mcp-client.log`
- Documentation: [GitHub Repository](https://github.com/SerenaMichaels/MCPJuliaClientLib)
- Issues: [GitHub Issues](https://github.com/SerenaMichaels/MCPJuliaClientLib/issues)
- Server Documentation: [MCPJuliaServer](https://github.com/SerenaMichaels/MCPJuliaServer)

### Community Resources
- Julia Discourse: [discourse.julialang.org](https://discourse.julialang.org)
- MCP Specification: [modelcontextprotocol.io](https://modelcontextprotocol.io)

### Commercial Support
For enterprise deployments and commercial support, contact the maintainers through GitHub issues or discussions.