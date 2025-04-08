# Use a stable Julia base image (e.g., 1.10)
FROM julia:1.10

# Set the working directory
WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy only the project definition files first for better caching
COPY Project.toml Manifest.toml /app/

# Instantiate the environment - installs packages based on Manifest
# This ensures reproducible builds
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'

# Copy the rest of the application code from the julia directory
COPY . /app/

# Copy the JuliaOSBridge package (required for Pkg.develop in setup.jl)
# Assumes the Docker build context is the project root (JuliaOS/)
COPY packages/julia-bridge /app/packages/julia-bridge

# Ensure the entrypoint script is executable
RUN chmod +x /app/entrypoint.sh

# Run the setup script which should handle Pkg.develop for the bridge
# and potentially other setup tasks
RUN julia /app/setup.jl

# Precompile packages for faster startup
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.precompile()'

# Expose the server port
EXPOSE 8052

# Health check (optional but recommended)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8052/health || exit 1

# Set the entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]

# Command to run the server (passed to entrypoint.sh)
CMD ["julia", "/app/julia_server.jl"] 