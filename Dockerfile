FROM node:18-slim

# Build arguments for configuring the image
ARG MODE=enhanced
ARG INCLUDE_JULIA=true
ARG INCLUDE_DEV=false

# Labels for better documentation
LABEL maintainer="J3OS Framework Team"
LABEL description="J3OS Framework - Cross-chain/multi-chain AI agent/swarm DeFi project"
LABEL version="1.0"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Julia if requested
RUN if [ "$INCLUDE_JULIA" = "true" ] ; then \
    apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.8/julia-1.8.5-linux-x86_64.tar.gz \
    && tar -xzf julia-1.8.5-linux-x86_64.tar.gz \
    && mv julia-1.8.5 /opt/julia \
    && ln -s /opt/julia/bin/julia /usr/local/bin/julia \
    && rm julia-1.8.5-linux-x86_64.tar.gz ; \
    fi

# Install dev tools if requested
RUN if [ "$INCLUDE_DEV" = "true" ] ; then \
    apt-get update && apt-get install -y --no-install-recommends \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/* ; \
    fi

# Install app dependencies
COPY cli/package*.json ./
RUN npm install

# Install CLI tools globally if using enhanced mode
RUN if [ "$MODE" = "enhanced" ] ; then \
    npm install -g chalk inquirer ora boxen cli-progress gradient-string ; \
    fi

# Bundle app source
COPY cli/ ./

# Create data directories
RUN mkdir -p agents swarms bridges data

# Make the scripts executable
RUN chmod +x ./src/index.js ./src/index.enhanced.js

# Copy Julia setup script if Julia is included
COPY setup.jl ./setup.jl

# Create directories for volume mounting
RUN mkdir -p /workspace/agents /workspace/swarms /workspace/bridges /workspace/data

# Set environment variables
ENV NODE_ENV=production
ENV PATH="/opt/julia/bin:${PATH}"

# Expose port for potential web interface
EXPOSE 3000

# Set up the entrypoint script
RUN echo '#!/bin/bash\n\
if [ "$MODE" = "enhanced" ]; then\n\
  node src/index.enhanced.js "$@"\n\
else\n\
  node src/index.js "$@"\n\
fi' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# Default command (interactive mode for enhanced, help for standard)
CMD ["node", "src/index.enhanced.js", "interactive"]

# If you want to use the entrypoint script instead:
# ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# CMD ["--help"] 