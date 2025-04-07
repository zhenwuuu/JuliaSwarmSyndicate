# JuliaOS CLI Documentation

This guide provides detailed information about using the JuliaOS Command Line Interface (CLI).

## Installation

The JuliaOS CLI can be installed via npm:

```bash
npm install -g juliaos-cli
```

## Prerequisites

To use the JuliaOS CLI, you need:

- [Julia](https://julialang.org/downloads/) 1.8 or later
- [Node.js](https://nodejs.org/) 14 or later

## Usage

### Interactive Mode

Launch the interactive CLI with:

```bash
juliaos
```

This opens an interactive menu-driven interface where you can:
- Manage agents and swarms
- Configure settings
- View system information

### Command Mode

For scripting and automation, you can use command mode:

```bash
juliaos agents list
juliaos swarms create --name "MySwarm" --type "Trading"
```

## Command Reference

### Agent Commands

#### List Agents

```bash
juliaos agents list
```

Lists all agents in the system with their status and basic information.

#### Create Agent

```bash
juliaos agents create --name "MyAgent" --type "Trading" --config '{"parameter": "value"}'
```

Creates a new agent with the specified parameters.

#### Get Agent Details

```bash
juliaos agents get <agent-id>
```

Shows detailed information about a specific agent.

#### Start Agent

```bash
juliaos agents start <agent-id>
```

Starts a specific agent.

#### Stop Agent

```bash
juliaos agents stop <agent-id>
```

Stops a specific agent.

#### Delete Agent

```bash
juliaos agents delete <agent-id>
```

Deletes a specific agent.

### Swarm Commands

#### List Swarms

```bash
juliaos swarms list
```

Lists all swarms in the system with their status and basic information.

#### Create Swarm

```bash
juliaos swarms create --name "MySwarm" --type "Trading" --algorithm "PSO" --config '{"parameter": "value"}'
```

Creates a new swarm with the specified parameters.

#### Get Swarm Details

```bash
juliaos swarms get <swarm-id>
```

Shows detailed information about a specific swarm.

#### Add Agent to Swarm

```bash
juliaos swarms add-agent <swarm-id> <agent-id>
```

Adds an agent to a swarm.

#### Remove Agent from Swarm

```bash
juliaos swarms remove-agent <swarm-id> <agent-id>
```

Removes an agent from a swarm.

#### Start Swarm

```bash
juliaos swarms start <swarm-id>
```

Starts a specific swarm.

#### Stop Swarm

```bash
juliaos swarms stop <swarm-id>
```

Stops a specific swarm.

#### Delete Swarm

```bash
juliaos swarms delete <swarm-id>
```

Deletes a specific swarm.

### System Commands

#### System Status

```bash
juliaos system status
```

Shows the status of the JuliaOS system components.

#### Storage Status

```bash
juliaos system storage
```

Shows the status of local and Web3 storage systems.

#### Web3 Sync

```bash
juliaos system sync
```

Synchronizes data between local and Web3 storage.

## Configuration

The JuliaOS CLI can be configured using a configuration file or environment variables.

### Configuration File

Create a `.juliaosrc` file in your home directory:

```json
{
  "server": {
    "url": "http://localhost:8052",
    "autoStart": true
  },
  "storage": {
    "syncEnabled": true,
    "syncInterval": 3600
  }
}
```

### Environment Variables

You can also use environment variables to configure the CLI:

```bash
export JULIAOS_SERVER_URL=http://localhost:8052
export JULIAOS_AUTO_START_SERVER=true
export JULIAOS_SYNC_ENABLED=true
```

## Troubleshooting

### Server Connection Issues

If you encounter server connection issues:

1. Make sure Julia is installed and in your PATH
2. Check if the server is running with `juliaos system status`
3. Try starting the server manually with `juliaos server start`

### Path Issues

If you encounter path-related errors:

1. Try running the CLI from the root of the JuliaOS repository
2. Check if the `JULIAOS_HOME` environment variable is set correctly
3. Reinstall the CLI with `npm install -g juliaos-cli`

## Further Resources

- [JuliaOS Documentation](https://juliaos.com/docs)
- [Framework API Reference](https://juliaos.com/docs/api)
- [GitHub Repository](https://github.com/juliaos/framework) 