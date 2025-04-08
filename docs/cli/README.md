# JuliaOS CLI Documentation

This guide provides detailed information about using the JuliaOS Command Line Interface (CLI) to interact with the Julia backend server.

## Prerequisites

To run JuliaOS and the interactive CLI, you need:

- [Julia](https://julialang.org/downloads/) **1.8 or later** (ensure the `julia` command is in your system's PATH)
- [Node.js](https://nodejs.org/) **18 or later** (ensure `node` and `npm` are in your system's PATH)
- A **bash-compatible shell** (standard on Linux and macOS)
- Standard command-line utilities like `git`, `pkill`, `curl` (optional but helpful).
- **Internet access** is required during the first run to download Julia dependencies.
- *(Potentially)* System build tools (`gcc`, `make`, etc.) depending on your OS and installed Julia packages.

## Setup

1.  **Clone the Repository:**
    ```bash
    git clone <repository-url>
    cd JuliaOS 
    ```
2.  **Install Node.js Dependencies:**
    ```bash
    npm install
    ```
    This installs `inquirer`, `chalk`, `ora`, and other required packages for the interactive CLI script.
3.  **Julia Dependencies:** The necessary Julia packages are automatically installed the *first* time you run the Julia server using the `start.sh` script (see Usage below).

## Usage

Running JuliaOS involves two main steps in separate terminals:

**1. Start the Julia Backend Server:**

   - Navigate to the Julia directory:
     ```bash
     cd julia
     ```
   - Make the start script executable (only needed once):
     ```bash
     chmod +x start.sh
     ```
   - Run the start script:
     ```bash
     ./start.sh
     ```
   - **Important:** The first time you run this, it will install all necessary Julia packages and might take several minutes. Subsequent starts will be much faster.
   - Leave this terminal running. It displays the server logs. Use `Ctrl+C` to stop the server.

**2. Run the Interactive CLI:**

   - Open a **new terminal window**.
   - Navigate to the project root directory (`JuliaOS`).
   - Run the interactive script using Node.js:
     ```bash
     node scripts/interactive.cjs
     ```
   - This will launch the menu-driven interface where you can interact with the running Julia backend to manage agents, swarms, wallets, etc.

## Command Reference

**Note:** The following commands describe the *backend functionality* available through the Julia server API. Currently, these are primarily accessed via the menu options in the `scripts/interactive.cjs` script, not as direct command-line arguments to that script.

### Agent Commands

#### List Agents

- **Menu Option:** `Agent Management` -> `List Agents`
- **Backend Command:** `list_agents`
- Lists all agents registered with the Julia backend.

#### Create Agent

- **Menu Option:** `Agent Management` -> `Create Agent`
- **Backend Command:** `create_agent`
- Creates a new agent instance in the Julia backend.

#### Get Agent Details (Not currently in menu)

- **Backend Command:** `get_agent_state` (example)
- Shows detailed information about a specific agent.

#### Start Agent

- **Menu Option:** `Agent Management` -> `Start Agent`
- **Backend Command:** `update_agent` (with status update)
- Starts a specific agent process in the backend.

#### Stop Agent

- **Menu Option:** `Agent Management` -> `Stop Agent`
- **Backend Command:** `update_agent` (with status update)
- Stops a specific agent process in the backend.

#### Delete Agent

- **Menu Option:** `Agent Management` -> `Delete Agent`
- **Backend Command:** `delete_agent`
- Deletes a specific agent from the backend.

### Swarm Commands

*(Similar structure - map menu options to backend commands)*

#### List Swarms

- **Menu Option:** `Swarm Management` -> `List Swarms`
- **Backend Command:** `list_swarms`

#### Create Swarm

- **Menu Option:** `Swarm Management` -> `Create Swarm` (Supports Julia Native & OpenAI)
- **Backend Command:** `SwarmManager.create_swarm` (Julia Native), `OpenAISwarmAdapter.create_openai_swarm` (OpenAI)

#### Get Swarm Details (Not currently in menu)

- **Backend Command:** `get_swarm_state` (example)

#### Add Agent to Swarm (Not currently in menu)

- **Backend Command:** *(Requires implementation)*

#### Remove Agent from Swarm (Not currently in menu)

- **Backend Command:** *(Requires implementation)*

#### Start Swarm

- **Menu Option:** `Swarm Management` -> `Start Swarm`
- **Backend Command:** `update_swarm` (with status update)

#### Stop Swarm

- **Menu Option:** `Swarm Management` -> `Stop Swarm`
- **Backend Command:** `update_swarm` (with status update)

#### Delete Swarm

- **Menu Option:** `Swarm Management` -> `Delete Swarm`
- **Backend Command:** `delete_swarm`

### OpenAI Swarm Interaction (New)

- **Menu Options (To be added):**
    - `Swarm Management` -> `Run OpenAI Task`
    - `Swarm Management` -> `Get OpenAI Response`
- **Backend Commands:**
    - `OpenAISwarmAdapter.run_openai_task`
    - `OpenAISwarmAdapter.get_openai_response`

### System Commands (Accessed via Main Menu / Diagnostics)

#### System Status / Diagnostics

- **Menu Option:** `Run System Checks`, `Component Diagnostics`
- Shows the status of the JuliaOS system components by sending various health/list commands to the backend.

#### Storage Status (Not currently directly exposed)

- Backend functionality exists within `Storage.jl`.

#### Web3 Sync (Not currently implemented)

- Placeholder for future Web3 storage features.

## Configuration

- **Julia Backend:** Configured primarily via the `.env` file located in the `julia/` directory. This file contains API keys, database paths, etc.
- **Interactive CLI:** Currently uses hardcoded defaults (e.g., server URL `http://localhost:8052`). Configuration options might be added in the future.

## Troubleshooting

### Julia Server Issues (`./start.sh`)

- **Errors during first run:** Check internet connection, ensure Julia has permissions to write to its package directories (e.g., `~/.julia`), verify necessary build tools are installed if package building fails. Check the terminal output for specific Julia `Pkg` errors.
- **Server fails to start:** Check the logs in the `julia/logs` directory and the terminal output from `start.sh`. Ensure port `8052` is not already in use. Verify the `.env` file has correct settings if used.
- **`pkill` command not found:** Install `procps` or equivalent package for your OS.

### Interactive CLI Issues (`node scripts/interactive.cjs`)

- **Cannot connect / Connection Refused:** Ensure the Julia server is running (check the *other* terminal running `./start.sh`). Verify the server started successfully and is listening on port 8052. Check network settings or firewalls.
- **Errors after selecting a menu option:** Check the terminal output in *both* the CLI window and the Julia server window for specific error messages. The error might originate from the Julia backend.
- **`Component Diagnostics` show errors:** If components show disconnected after fixing previous issues, ensure the Julia server is fully running and hasn't crashed. Check server logs.
- **Node.js errors (`require` not found, etc.):** Ensure you ran `npm install` in the project root directory. Check your Node.js version (`node -v`).

## Further Resources

- [JuliaOS Documentation](https://juliaos.com/docs)
- [Framework API Reference](https://juliaos.com/docs/api)
- [GitHub Repository](https://github.com/juliaos/framework) 