const chalk = require('chalk');
const ora = require('ora');
const inquirer = require('inquirer');
const { displayHeader } = require('./utils');

/**
 * Swarm Visualization Menu
 * Provides visualization tools for swarm coordination
 */
async function swarmVisualizationMenu(juliaBridge, breadcrumbs = ['Main', 'Swarm Visualization']) {
    let exit = false;

    while (!exit) {
        displayHeader(breadcrumbs.join(' > '));
        
        console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  📊 Swarm Visualization Tools                   │
│                                                 │
│  Visualize swarm coordination and activities.   │
│                                                 │
└─────────────────────────────────────────────────┘
`));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Select a visualization:',
                pageSize: 10,
                choices: [
                    { name: 'Swarm Network Diagram', value: 'network' },
                    { name: 'Consensus Voting Visualization', value: 'consensus' },
                    { name: 'Leader Election Visualization', value: 'leader' },
                    { name: 'Swarm Activity Timeline', value: 'timeline' },
                    { name: 'Agent Communication Graph', value: 'communication' },
                    new inquirer.Separator(),
                    { name: 'Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'network':
                await visualizeSwarmNetwork(juliaBridge, [...breadcrumbs, 'Network Diagram']);
                break;
            case 'consensus':
                await visualizeConsensusVoting(juliaBridge, [...breadcrumbs, 'Consensus Voting']);
                break;
            case 'leader':
                await visualizeLeaderElection(juliaBridge, [...breadcrumbs, 'Leader Election']);
                break;
            case 'timeline':
                await visualizeSwarmTimeline(juliaBridge, [...breadcrumbs, 'Activity Timeline']);
                break;
            case 'communication':
                await visualizeCommunicationGraph(juliaBridge, [...breadcrumbs, 'Communication Graph']);
                break;
            case 'back':
                exit = true;
                break;
        }
    }
}

/**
 * Visualize the swarm network structure
 */
async function visualizeSwarmNetwork(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));
    
    // First, get the list of swarms
    const spinner = ora({
        text: 'Fetching swarms...',
        spinner: 'dots',
        color: 'blue'
    }).start();
    
    try {
        const swarmsResult = await juliaBridge.runJuliaCommand('swarms.list_swarms', {});
        
        if (!swarmsResult || !swarmsResult.success || !Array.isArray(swarmsResult.swarms) || swarmsResult.swarms.length === 0) {
            spinner.fail('No swarms available.');
            console.log(chalk.yellow('\nNo swarms found. Create a swarm first.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }
        
        // Let user select a swarm
        spinner.stop();
        
        const swarmChoices = swarmsResult.swarms.map(swarm => ({
            name: `${swarm.name} (${swarm.algorithm}) - ${swarm.status}`,
            value: swarm.id
        }));
        
        const { swarmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'swarmId',
                message: 'Select a swarm to visualize:',
                choices: swarmChoices,
                pageSize: 10
            }
        ]);
        
        // Get swarm details
        spinner.text = 'Fetching swarm details...';
        spinner.start();
        
        const swarmResult = await juliaBridge.runJuliaCommand('swarms.get_swarm', { id: swarmId });
        
        spinner.stop();
        
        if (!swarmResult || !swarmResult.success) {
            console.log(chalk.red(`\n❌ Failed to fetch swarm details: ${swarmResult?.error || 'Unknown error'}`));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }
        
        const swarm = swarmResult;
        const agents = swarm.agents || [];
        
        // Draw the network diagram
        console.log(chalk.cyan(`\n┌─ Swarm Network: ${swarm.name} ─${'─'.repeat(Math.max(0, 50 - swarm.name.length))}┐`));
        console.log(chalk.cyan(`│                                                                      │`));
        
        // Draw the swarm node at the center
        console.log(chalk.cyan(`│                          ┌───────────────┐                           │`));
        console.log(chalk.cyan(`│                          │               │                           │`));
        console.log(chalk.cyan(`│                          │  ${chalk.bold.green('SWARM NODE')}  │                           │`));
        console.log(chalk.cyan(`│                          │  ${chalk.green(swarm.algorithm.padEnd(11))}  │                           │`));
        console.log(chalk.cyan(`│                          │               │                           │`));
        console.log(chalk.cyan(`│                          └───────────────┘                           │`));
        console.log(chalk.cyan(`│                                 │                                    │`));
        
        // Draw connections to agents
        if (agents.length === 0) {
            console.log(chalk.cyan(`│                                                                      │`));
            console.log(chalk.cyan(`│                      ${chalk.yellow('No agents in this swarm')}                       │`));
        } else {
            // Draw connection lines
            console.log(chalk.cyan(`│                ┌──────────┴───────────┬──────────┐                │`));
            
            // Draw agent nodes
            const agentRows = Math.ceil(agents.length / 4);
            for (let row = 0; row < agentRows; row++) {
                const startIdx = row * 4;
                const endIdx = Math.min(startIdx + 4, agents.length);
                const rowAgents = agents.slice(startIdx, endIdx);
                
                // Draw agent boxes
                console.log(chalk.cyan(`│     ${rowAgents.map(a => `┌───────────┐`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                console.log(chalk.cyan(`│     ${rowAgents.map(a => `│           │`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                console.log(chalk.cyan(`│     ${rowAgents.map(a => `│  ${chalk.bold.blue('AGENT')}    │`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                console.log(chalk.cyan(`│     ${rowAgents.map((a, i) => `│  ${chalk.blue(`A${startIdx + i + 1}`.padEnd(7))}  │`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                console.log(chalk.cyan(`│     ${rowAgents.map(a => `│           │`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                console.log(chalk.cyan(`│     ${rowAgents.map(a => `└───────────┘`).join('     ')}${' '.repeat(Math.max(0, 70 - rowAgents.length * 17))}│`));
                
                if (row < agentRows - 1) {
                    console.log(chalk.cyan(`│                                                                      │`));
                }
            }
        }
        
        console.log(chalk.cyan(`│                                                                      │`));
        console.log(chalk.cyan(`│  ${chalk.bold('Swarm Details:')}                                                       │`));
        console.log(chalk.cyan(`│  • Algorithm: ${chalk.white(swarm.algorithm)}${' '.repeat(Math.max(0, 55 - swarm.algorithm.length))}│`));
        console.log(chalk.cyan(`│  • Status: ${chalk.white(swarm.status)}${' '.repeat(Math.max(0, 57 - swarm.status.length))}│`));
        console.log(chalk.cyan(`│  • Agents: ${chalk.white(agents.length)}${' '.repeat(Math.max(0, 57 - String(agents.length).length))}│`));
        
        if (swarm.algorithm === 'consensus') {
            console.log(chalk.cyan(`│  • Protocol: ${chalk.white('Consensus-based voting')}${' '.repeat(35)}│`));
        } else if (swarm.algorithm === 'leader') {
            const leaderId = swarm.memory?.leader?.id || 'None';
            console.log(chalk.cyan(`│  • Protocol: ${chalk.white('Leader-based')}${' '.repeat(45)}│`));
            console.log(chalk.cyan(`│  • Current Leader: ${chalk.white(leaderId)}${' '.repeat(Math.max(0, 50 - leaderId.length))}│`));
        }
        
        console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────────────┘`));
        
        // Show agent details
        if (agents.length > 0) {
            console.log(chalk.cyan(`\n┌─ Agent Details ─${'─'.repeat(60)}┐`));
            
            agents.forEach((agent, index) => {
                console.log(chalk.cyan(`│                                                                      │`));
                console.log(chalk.cyan(`│  ${chalk.bold(`A${index + 1}: ${agent.name}`)}${' '.repeat(Math.max(0, 65 - `A${index + 1}: ${agent.name}`.length))}│`));
                console.log(chalk.cyan(`│  • ID: ${chalk.gray(agent.id)}${' '.repeat(Math.max(0, 60 - agent.id.length))}│`));
                console.log(chalk.cyan(`│  • Type: ${agent.type}${' '.repeat(Math.max(0, 58 - agent.type.length))}│`));
                console.log(chalk.cyan(`│  • Status: ${agent.status}${' '.repeat(Math.max(0, 56 - agent.status.length))}│`));
                
                const capabilities = agent.capabilities || [];
                if (capabilities.length > 0) {
                    const capStr = capabilities.join(', ');
                    console.log(chalk.cyan(`│  • Capabilities: ${capStr.substring(0, 50)}${capStr.length > 50 ? '...' : ''}${' '.repeat(Math.max(0, 50 - Math.min(capStr.length, 53)))}│`));
                }
                
                if (index < agents.length - 1) {
                    console.log(chalk.cyan(`│  ${'-'.repeat(70)}  │`));
                }
            });
            
            console.log(chalk.cyan(`│                                                                      │`));
            console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────────────┘`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }
    
    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Visualize consensus voting process
 */
async function visualizeConsensusVoting(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));
    
    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🗳️  Consensus Voting Visualization             │
│                                                 │
│  Visualize the consensus voting process in      │
│  a swarm.                                       │
│                                                 │
└─────────────────────────────────────────────────┘
`));
    
    // First, get the list of swarms
    const spinner = ora({
        text: 'Fetching swarms...',
        spinner: 'dots',
        color: 'blue'
    }).start();
    
    try {
        const swarmsResult = await juliaBridge.runJuliaCommand('swarms.list_swarms', {});
        
        if (!swarmsResult || !swarmsResult.success || !Array.isArray(swarmsResult.swarms) || swarmsResult.swarms.length === 0) {
            spinner.fail('No swarms available.');
            console.log(chalk.yellow('\nNo swarms found. Create a swarm first.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }
        
        // Filter for consensus swarms
        const consensusSwarms = swarmsResult.swarms.filter(swarm => 
            swarm.algorithm === 'consensus' || 
            swarm.algorithm === 'hybrid' || 
            swarm.algorithm === 'DE' || 
            swarm.algorithm === 'PSO'
        );
        
        if (consensusSwarms.length === 0) {
            spinner.fail('No consensus-based swarms available.');
            console.log(chalk.yellow('\nNo consensus-based swarms found. Create a consensus swarm first.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }
        
        // Let user select a swarm
        spinner.stop();
        
        const swarmChoices = consensusSwarms.map(swarm => ({
            name: `${swarm.name} (${swarm.algorithm}) - ${swarm.status}`,
            value: swarm.id
        }));
        
        const { swarmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'swarmId',
                message: 'Select a swarm to visualize:',
                choices: swarmChoices,
                pageSize: 10
            }
        ]);
        
        // Get swarm details
        spinner.text = 'Fetching swarm details...';
        spinner.start();
        
        const swarmResult = await juliaBridge.runJuliaCommand('swarms.get_swarm', { id: swarmId });
        
        spinner.stop();
        
        if (!swarmResult || !swarmResult.success) {
            console.log(chalk.red(`\n❌ Failed to fetch swarm details: ${swarmResult?.error || 'Unknown error'}`));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }
        
        const swarm = swarmResult;
        const agents = swarm.agents || [];
        const votes = swarm.memory?.votes || {};
        
        // Draw the consensus voting visualization
        console.log(chalk.cyan(`\n┌─ Consensus Voting: ${swarm.name} ─${'─'.repeat(Math.max(0, 46 - swarm.name.length))}┐`));
        console.log(chalk.cyan(`│                                                                      │`));
        
        if (Object.keys(votes).length === 0) {
            console.log(chalk.cyan(`│                                                                      │`));
            console.log(chalk.cyan(`│                  ${chalk.yellow('No active voting sessions found')}                   │`));
            console.log(chalk.cyan(`│                                                                      │`));
        } else {
            // Show voting sessions
            let index = 0;
            for (const [proposalId, session] of Object.entries(votes)) {
                const proposal = session.proposal || {};
                const voteResults = session.votes || {};
                const status = session.status || 'voting';
                const result = session.result;
                
                console.log(chalk.cyan(`│  ${chalk.bold(`Voting Session ${index + 1}:`)}${' '.repeat(Math.max(0, 50 - `Voting Session ${index + 1}:`.length))}│`));
                console.log(chalk.cyan(`│  • Proposal ID: ${chalk.gray(proposalId.substring(0, 20))}...${' '.repeat(Math.max(0, 35 - 23))}│`));
                
                // Show proposal details
                const actionType = proposal.action || 'unknown';
                console.log(chalk.cyan(`│  • Action: ${actionType}${' '.repeat(Math.max(0, 57 - actionType.length))}│`));
                
                if (actionType === 'update_parameter') {
                    const param = proposal.parameter || '';
                    const value = String(proposal.value || '');
                    console.log(chalk.cyan(`│    - Parameter: ${param}${' '.repeat(Math.max(0, 52 - param.length))}│`));
                    console.log(chalk.cyan(`│    - Value: ${value}${' '.repeat(Math.max(0, 56 - value.length))}│`));
                } else if (actionType === 'execute_task') {
                    const taskName = proposal.task?.name || '';
                    console.log(chalk.cyan(`│    - Task: ${taskName}${' '.repeat(Math.max(0, 57 - taskName.length))}│`));
                }
                
                // Show voting status
                const totalVotes = Object.keys(voteResults).length;
                const yesVotes = Object.values(voteResults).filter(v => v === true).length;
                const noVotes = totalVotes - yesVotes;
                const threshold = swarm.parameters?.consensus_threshold || 0.66;
                const thresholdPercent = Math.round(threshold * 100);
                
                console.log(chalk.cyan(`│                                                                      │`));
                console.log(chalk.cyan(`│  • Status: ${status === 'voting' ? chalk.yellow(status) : status === 'approved' ? chalk.green(status) : chalk.red(status)}${' '.repeat(Math.max(0, 56 - status.length))}│`));
                console.log(chalk.cyan(`│  • Votes: ${totalVotes} / ${agents.length}${' '.repeat(Math.max(0, 56 - String(totalVotes).length - String(agents.length).length - 3))}│`));
                console.log(chalk.cyan(`│  • Threshold: ${thresholdPercent}%${' '.repeat(Math.max(0, 53 - String(thresholdPercent).length - 1))}│`));
                console.log(chalk.cyan(`│                                                                      │`));
                
                // Draw vote visualization
                console.log(chalk.cyan(`│  ${chalk.bold('Vote Distribution:')}${' '.repeat(48)}│`));
                
                // Calculate percentages
                const yesPercent = totalVotes > 0 ? Math.round((yesVotes / totalVotes) * 100) : 0;
                const noPercent = totalVotes > 0 ? Math.round((noVotes / totalVotes) * 100) : 0;
                
                // Draw progress bars
                const barWidth = 50;
                const yesBarWidth = Math.round((yesPercent / 100) * barWidth);
                const noBarWidth = Math.round((noPercent / 100) * barWidth);
                
                console.log(chalk.cyan(`│  Yes: ${chalk.green('█'.repeat(yesBarWidth))}${' '.repeat(barWidth - yesBarWidth)} ${yesPercent}%  │`));
                console.log(chalk.cyan(`│  No:  ${chalk.red('█'.repeat(noBarWidth))}${' '.repeat(barWidth - noBarWidth)} ${noPercent}%  │`));
                
                // Draw threshold line
                const thresholdPosition = Math.round(threshold * barWidth);
                const thresholdLine = ' '.repeat(thresholdPosition) + '|' + ' '.repeat(barWidth - thresholdPosition - 1);
                console.log(chalk.cyan(`│      ${thresholdLine} ${thresholdPercent}%  │`));
                
                // Show result if voting is complete
                if (status !== 'voting') {
                    console.log(chalk.cyan(`│                                                                      │`));
                    console.log(chalk.cyan(`│  • Result: ${result ? chalk.green('Approved') : chalk.red('Rejected')}${' '.repeat(Math.max(0, 56 - (result ? 8 : 8)))}│`));
                }
                
                if (index < Object.keys(votes).length - 1) {
                    console.log(chalk.cyan(`│  ${'-'.repeat(70)}  │`));
                }
                
                index++;
            }
        }
        
        console.log(chalk.cyan(`│                                                                      │`));
        console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────────────┘`));
        
        // Show consensus configuration
        console.log(chalk.cyan(`\n┌─ Consensus Configuration ─${'─'.repeat(46)}┐`));
        console.log(chalk.cyan(`│                                                                      │`));
        
        const threshold = swarm.parameters?.consensus_threshold || 0.66;
        const timeout = swarm.parameters?.voting_timeout || 60;
        
        console.log(chalk.cyan(`│  • Consensus Threshold: ${Math.round(threshold * 100)}%${' '.repeat(Math.max(0, 45 - String(Math.round(threshold * 100)).length - 1))}│`));
        console.log(chalk.cyan(`│  • Voting Timeout: ${timeout} seconds${' '.repeat(Math.max(0, 47 - String(timeout).length - 8))}│`));
        
        console.log(chalk.cyan(`│                                                                      │`));
        console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────────────┘`));
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }
    
    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Visualize leader election process
 */
async function visualizeLeaderElection(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));
    
    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  👑 Leader Election Visualization               │
│                                                 │
│  Visualize the leader election process in       │
│  a swarm.                                       │
│                                                 │
└─────────────────────────────────────────────────┘
`));
    
    // Implementation similar to consensus visualization but for leader-based swarms
    console.log(chalk.yellow('\nThis feature is under development.'));
    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Visualize swarm activity timeline
 */
async function visualizeSwarmTimeline(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));
    
    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  ⏱️  Swarm Activity Timeline                    │
│                                                 │
│  Visualize the activity timeline of a swarm.    │
│                                                 │
└─────────────────────────────────────────────────┘
`));
    
    // Implementation for timeline visualization
    console.log(chalk.yellow('\nThis feature is under development.'));
    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Visualize agent communication graph
 */
async function visualizeCommunicationGraph(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));
    
    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🔄 Agent Communication Graph                   │
│                                                 │
│  Visualize communication between agents in      │
│  a swarm.                                       │
│                                                 │
└─────────────────────────────────────────────────┘
`));
    
    // Implementation for communication graph visualization
    console.log(chalk.yellow('\nThis feature is under development.'));
    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

// Export the menu function
module.exports = {
    swarmVisualizationMenu,
    visualizeSwarmNetwork,
    visualizeConsensusVoting,
    visualizeLeaderElection,
    visualizeSwarmTimeline,
    visualizeCommunicationGraph
};
