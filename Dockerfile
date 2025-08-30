# MCP Julia Client Dockerfile
# Multi-stage build for efficient image size

# Build stage
FROM julia:1.11.2-slim as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY Project.toml Manifest.toml ./

# Install Julia dependencies
RUN julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

# Production stage
FROM julia:1.11.2-slim

# Create non-root user for security
RUN groupadd -r mcpclient && \
    useradd -r -g mcpclient -d /home/mcpclient -m mcpclient

# Install runtime system dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Julia environment from builder
COPY --from=builder /usr/local/julia /usr/local/julia
COPY --from=builder /app/.julia /home/mcpclient/.julia

# Copy application files
COPY --chown=mcpclient:mcpclient . /app/

# Set ownership
RUN chown -R mcpclient:mcpclient /app

# Create data and logs directories
RUN mkdir -p /app/data /app/logs && \
    chown -R mcpclient:mcpclient /app/data /app/logs

# Switch to non-root user
USER mcpclient

# Set environment variables
ENV JULIA_PATH=/usr/local/julia/bin/julia
ENV MCP_CLIENT_HOME=/app
ENV PATH=$PATH:/usr/local/julia/bin

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD julia --project=. -e "println(\"MCP Client Health OK\")"

# Default command runs the multi-server orchestration example
CMD ["julia", "--project=.", "examples/multi_server_orchestration.jl"]