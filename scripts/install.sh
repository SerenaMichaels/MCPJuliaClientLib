#!/bin/bash
# MCP Julia Client Installation Script
# Supports: Ubuntu, Debian, CentOS, Fedora, macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
JULIA_VERSION="1.11.2"
INSTALL_DIR="/opt/mcp-julia-client"
CLIENT_USER="mcpclient"
REPO_URL="https://github.com/SerenaMichaels/MCPJuliaClientLib.git"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            OS="debian"
            PKG_MANAGER="apt-get"
        elif command -v dnf >/dev/null 2>&1; then
            OS="fedora"
            PKG_MANAGER="dnf"
        elif command -v yum >/dev/null 2>&1; then
            OS="centos"
            PKG_MANAGER="yum"
        else
            error "Unsupported Linux distribution"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PKG_MANAGER="brew"
    else
        error "Unsupported operating system: $OSTYPE"
    fi
    log "Detected OS: $OS"
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons"
    fi
    
    # Check for required commands
    local required_commands=("git" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command '$cmd' not found"
        fi
    done
}

install_system_deps() {
    log "Installing system dependencies..."
    
    case $OS in
        "debian")
            sudo apt-get update
            sudo apt-get install -y \
                curl \
                git \
                ca-certificates
            ;;
        "fedora")
            sudo dnf update -y
            sudo dnf install -y \
                curl \
                git \
                ca-certificates
            ;;
        "centos")
            sudo yum update -y
            sudo yum install -y \
                curl \
                git \
                ca-certificates
            ;;
        "macos")
            if ! command -v brew >/dev/null 2>&1; then
                log "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install git curl
            ;;
    esac
}

install_julia() {
    log "Installing Julia..."
    
    if command -v julia >/dev/null 2>&1; then
        local julia_version=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        log "Julia $julia_version already installed"
        return
    fi
    
    # Use same Julia installation logic as server installer
    local julia_url
    case $(uname -m) in
        "x86_64")
            julia_url="https://julialang-s3.julialang.org/bin/linux/x64/$(echo $JULIA_VERSION | cut -d. -f1-2)/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
            ;;
        "aarch64"|"arm64")
            julia_url="https://julialang-s3.julialang.org/bin/linux/aarch64/$(echo $JULIA_VERSION | cut -d. -f1-2)/julia-${JULIA_VERSION}-linux-aarch64.tar.gz"
            ;;
        *)
            error "Unsupported architecture: $(uname -m)"
            ;;
    esac
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log "Downloading Julia $JULIA_VERSION..."
    curl -fsSL "$julia_url" -o julia.tar.gz
    
    log "Extracting Julia..."
    tar -xzf julia.tar.gz
    
    log "Installing Julia to /usr/local..."
    sudo mv julia-*/ /usr/local/julia
    sudo ln -sf /usr/local/julia/bin/julia /usr/local/bin/julia
    
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    # Verify installation
    if julia --version >/dev/null 2>&1; then
        log "Julia installed successfully: $(julia --version)"
    else
        error "Julia installation failed"
    fi
}

check_server_installation() {
    log "Checking for MCP Julia Server installation..."
    
    # Check common installation locations
    local server_locations=(
        "/opt/mcp-julia-server"
        "$HOME/MCPJuliaServer"
        "$HOME/.local/opt/mcp-julia-server"
        "/usr/local/opt/mcp-julia-server"
    )
    
    local server_found=false
    local server_dir=""
    
    for dir in "${server_locations[@]}"; do
        if [[ -f "$dir/postgres_example.jl" ]]; then
            server_found=true
            server_dir="$dir"
            break
        fi
    done
    
    if [[ "$server_found" == "false" ]]; then
        warn "MCP Julia Server not found in common locations"
        echo "Please install MCPJuliaServer first:"
        echo "  curl -fsSL https://raw.githubusercontent.com/SerenaMichaels/MCPJuliaServer/main/scripts/install.sh | bash"
        echo ""
        echo "Or specify custom server location when configuring the client."
        read -p "Continue installation anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "Found MCP Julia Server at: $server_dir"
        echo "export MCP_SERVER_DIR=\"$server_dir\"" >> ~/.bashrc
    fi
}

create_client_user() {
    log "Creating client user..."
    
    if ! id "$CLIENT_USER" >/dev/null 2>&1; then
        case $OS in
            "debian"|"fedora"|"centos")
                sudo useradd -r -s /bin/bash -d /home/$CLIENT_USER -m $CLIENT_USER
                sudo usermod -aG sudo $CLIENT_USER 2>/dev/null || sudo usermod -aG wheel $CLIENT_USER 2>/dev/null || true
                ;;
            "macos")
                warn "User creation on macOS requires manual setup"
                ;;
        esac
    fi
}

install_mcp_client() {
    log "Installing MCP Julia Client..."
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"
    
    # Clone repository
    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        sudo git clone "$REPO_URL" "$INSTALL_DIR"
    else
        sudo git -C "$INSTALL_DIR" pull origin main
    fi
    
    # Set ownership
    sudo chown -R $CLIENT_USER:$CLIENT_USER "$INSTALL_DIR"
    
    # Install Julia dependencies
    cd "$INSTALL_DIR"
    sudo -u $CLIENT_USER julia --project=. -e "using Pkg; Pkg.instantiate()"
    
    # Create configuration
    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        sudo -u $CLIENT_USER cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
        log "Created .env configuration file - please edit $INSTALL_DIR/.env with your settings"
    fi
    
    # Create logs directory
    sudo -u $CLIENT_USER mkdir -p "$INSTALL_DIR/logs"
}

configure_environment() {
    log "Configuring environment..."
    
    # Auto-detect server installation if found
    local server_locations=(
        "/opt/mcp-julia-server"
        "$HOME/MCPJuliaServer"
    )
    
    for dir in "${server_locations[@]}"; do
        if [[ -f "$dir/postgres_example.jl" ]]; then
            sudo -u $CLIENT_USER sed -i "s|MCP_SERVER_DIR=.*|MCP_SERVER_DIR=$dir|" "$INSTALL_DIR/.env"
            log "Configured MCP_SERVER_DIR to: $dir"
            break
        fi
    done
    
    # Set Julia path
    local julia_path=$(which julia)
    sudo -u $CLIENT_USER sed -i "s|JULIA_PATH=.*|JULIA_PATH=$julia_path|" "$INSTALL_DIR/.env"
    log "Configured JULIA_PATH to: $julia_path"
}

create_scripts() {
    log "Creating utility scripts..."
    
    # Run examples script
    sudo tee "$INSTALL_DIR/run-examples.sh" >/dev/null <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source .env 2>/dev/null || true

echo "=== MCP Julia Client Examples ==="
echo "1. Database-First Workflow"
echo "2. File-to-Database Pipeline"
echo "3. Cross-Database Migration"
echo "4. Multi-Server Orchestration"
echo "5. Run All Examples"
echo ""

read -p "Select example (1-5): " choice

case $choice in
    1) julia examples/database_first_workflow.jl ;;
    2) julia examples/file_to_database_pipeline.jl ;;
    3) julia examples/cross_database_migration.jl ;;
    4) julia examples/multi_server_orchestration.jl ;;
    5) julia scripts/test_all_examples.jl ;;
    *) echo "Invalid selection" ;;
esac
EOF
    
    # Status script
    sudo tee "$INSTALL_DIR/status.sh" >/dev/null <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source .env 2>/dev/null || true

echo "=== MCP Julia Client Status ==="
echo "Installation: $(pwd)"
echo "Julia: $(which julia) ($(julia --version))"
echo "Server Dir: $MCP_SERVER_DIR"
echo ""

echo "=== Server Availability ==="
if [[ -f "$MCP_SERVER_DIR/postgres_example.jl" ]]; then
    echo "✅ PostgreSQL Server: Available"
else
    echo "❌ PostgreSQL Server: Not found"
fi

if [[ -f "$MCP_SERVER_DIR/file_server_example.jl" ]]; then
    echo "✅ File Server: Available"
else
    echo "❌ File Server: Not found"
fi

if [[ -f "$MCP_SERVER_DIR/db_admin_example.jl" ]]; then
    echo "✅ Database Admin Server: Available"
else
    echo "❌ Database Admin Server: Not found"
fi

echo ""
echo "=== Julia Package Status ==="
julia --project=. -e "using Pkg; Pkg.status()" 2>/dev/null || echo "❌ Package check failed"
EOF
    
    sudo chmod +x "$INSTALL_DIR"/*.sh
    sudo chown $CLIENT_USER:$CLIENT_USER "$INSTALL_DIR"/*.sh
}

run_tests() {
    log "Running installation tests..."
    
    cd "$INSTALL_DIR"
    
    # Test Julia packages
    sudo -u $CLIENT_USER julia --project=. -e "
    using Pkg
    Pkg.status()
    println(\"✅ Julia packages OK\")
    " 2>/dev/null || warn "Julia package test failed"
    
    # Test basic client functionality
    sudo -u $CLIENT_USER julia --project=. -e "
    include(\"src/MCPClient.jl\")
    using .MCPClient
    println(\"✅ MCP Client library loaded successfully\")
    " 2>/dev/null || warn "MCP Client library test failed"
    
    log "Installation tests completed"
}

print_next_steps() {
    log "Installation completed successfully!"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Configure your client settings:"
    echo "   sudo -u $CLIENT_USER nano $INSTALL_DIR/.env"
    echo ""
    echo "2. Ensure MCP Julia Server is installed and running:"
    echo "   curl -fsSL https://raw.githubusercontent.com/SerenaMichaels/MCPJuliaServer/main/scripts/install.sh | bash"
    echo ""
    echo "3. Run example workflows:"
    echo "   sudo -u $CLIENT_USER $INSTALL_DIR/run-examples.sh"
    echo ""
    echo "4. Check status:"
    echo "   sudo -u $CLIENT_USER $INSTALL_DIR/status.sh"
    echo ""
    echo -e "${BLUE}Files and Directories:${NC}"
    echo "  Installation: $INSTALL_DIR"
    echo "  Configuration: $INSTALL_DIR/.env"
    echo "  Examples: $INSTALL_DIR/examples/"
    echo "  Logs: $INSTALL_DIR/logs/"
    echo ""
    echo -e "${BLUE}Environment Setup:${NC}"
    echo "  Add to your shell profile (~/.bashrc or ~/.zshrc):"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo "  export MCP_CLIENT_HOME=\"$INSTALL_DIR\""
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  Installation Guide: $INSTALL_DIR/INSTALL.md"
    echo "  API Reference: $INSTALL_DIR/docs/API_Reference.md"
    echo "  Examples: $INSTALL_DIR/EXAMPLES.md"
    echo "  Repository: https://github.com/SerenaMichaels/MCPJuliaClientLib"
}

# Main installation process
main() {
    log "Starting MCP Julia Client installation..."
    
    detect_os
    check_requirements
    install_system_deps
    install_julia
    check_server_installation
    create_client_user
    install_mcp_client
    configure_environment
    create_scripts
    run_tests
    print_next_steps
}

# Run main function
main "$@"