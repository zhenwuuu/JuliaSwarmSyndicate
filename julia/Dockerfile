FROM julia:1.11

WORKDIR /app

# Create directories for JuliaOSBridge
RUN mkdir -p /app/packages/julia-bridge/src

# Copy Julia project files
COPY . /app/

# Copy JuliaOSBridge files if they exist externally
COPY ../packages/julia-bridge/Project.toml /app/packages/julia-bridge/Project.toml || true
COPY ../packages/julia-bridge/src /app/packages/julia-bridge/src || true

# Install required packages
RUN julia -e 'import Pkg; Pkg.add(["HTTP", "WebSockets", "JSON", "LinearAlgebra", "Plots", "Distributions", "DataFrames", "StatsBase", "TimeSeries", "MarketData", "CSV", "MLJ"])'

# Run setup script to properly set up JuliaOSBridge
RUN julia setup.jl

# Precompile packages
RUN julia -e 'import Pkg; Pkg.precompile()'

# Expose the WebSocket port
EXPOSE 8052

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8052/health || exit 1

# Run the Julia server
CMD ["julia", "start_server.jl"] 