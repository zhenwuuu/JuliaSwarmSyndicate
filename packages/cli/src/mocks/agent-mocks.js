/**
 * Mock implementations for agent-related commands
 */

// Helper to generate a random ID
const generateId = () => `agent-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 7)}`;

// Helper to get current timestamp
const now = () => new Date().toISOString();

// Agent type mapping
const AGENT_TYPES = {
  'trading': 1,
  'monitor': 2,
  'arbitrage': 3,
  'data_collection': 4,
  'notification': 5,
  'custom': 99
};

// Agent status enum
const AGENT_STATUS = ['CREATED', 'RUNNING', 'STOPPED', 'PAUSED', 'ERROR'];

/**
 * Mock agent data store
 */
const mockAgents = [
  {
    id: 'agent1',
    name: 'Trading Agent',
    type: AGENT_TYPES.trading,
    status: 'RUNNING',
    created: new Date(Date.now() - 86400000).toISOString(),
    updated: new Date(Date.now() - 3600000).toISOString(),
    config: {
      abilities: ['ping', 'llm_chat', 'trade'],
      chains: ['ethereum', 'polygon'],
      parameters: {
        max_skills: 10,
        update_interval: 60,
        capabilities: ['basic', 'trading']
      },
      llm_config: {
        provider: 'openai',
        model: 'gpt-4o-mini',
        temperature: 0.7,
        max_tokens: 1024
      },
      memory_config: {
        max_size: 1024,
        retention_policy: 'lru'
      },
      max_task_history: 100
    },
    memory: {
      'last_trade': { symbol: 'BTC-USD', price: 50000, timestamp: now() },
      'portfolio_value': 125000,
      'risk_tolerance': 'medium'
    },
    task_history: [
      {
        timestamp: new Date(Date.now() - 3600000).toISOString(),
        input: { ability: 'ping' },
        output: { msg: 'pong' }
      },
      {
        timestamp: new Date(Date.now() - 1800000).toISOString(),
        input: { ability: 'llm_chat', prompt: 'Hello' },
        output: { answer: 'Hello! How can I assist you today?' }
      }
    ]
  },
  {
    id: 'agent2',
    name: 'Research Agent',
    type: AGENT_TYPES.custom,
    status: 'STOPPED',
    created: new Date(Date.now() - 172800000).toISOString(),
    updated: new Date(Date.now() - 43200000).toISOString(),
    config: {
      abilities: ['ping', 'llm_chat', 'research'],
      chains: [],
      parameters: {
        max_skills: 15,
        update_interval: 120,
        capabilities: ['basic', 'research']
      },
      llm_config: {
        provider: 'anthropic',
        model: 'claude-3-opus',
        temperature: 0.5,
        max_tokens: 2048
      },
      memory_config: {
        max_size: 2048,
        retention_policy: 'lru'
      },
      max_task_history: 200
    },
    memory: {
      'research_topics': ['DeFi', 'NFTs', 'Layer 2 Solutions'],
      'last_report': { topic: 'DeFi Trends', timestamp: new Date(Date.now() - 86400000).toISOString() }
    },
    task_history: [
      {
        timestamp: new Date(Date.now() - 86400000).toISOString(),
        input: { ability: 'research', topic: 'DeFi Trends' },
        output: { status: 'completed', report_id: 'report-123' }
      }
    ]
  },
  {
    id: 'agent3',
    name: 'Portfolio Agent',
    type: AGENT_TYPES.trading,
    status: 'CREATED',
    created: new Date(Date.now() - 43200000).toISOString(),
    updated: new Date(Date.now() - 43200000).toISOString(),
    config: {
      abilities: ['ping', 'portfolio_management'],
      chains: ['ethereum', 'polygon', 'avalanche'],
      parameters: {
        max_skills: 8,
        update_interval: 300,
        capabilities: ['basic', 'portfolio']
      },
      llm_config: {
        provider: 'openai',
        model: 'gpt-4o',
        temperature: 0.3,
        max_tokens: 1024
      },
      memory_config: {
        max_size: 1024,
        retention_policy: 'lru'
      },
      max_task_history: 50
    },
    memory: {
      'portfolio_allocation': {
        'BTC': 0.4,
        'ETH': 0.3,
        'SOL': 0.2,
        'AVAX': 0.1
      },
      'risk_profile': 'moderate'
    },
    task_history: []
  }
];

/**
 * Mock implementations for agent commands
 */
const agentMocks = {
  // List agents
  'list_agents': (params, dynamic) => {
    return mockAgents.map(agent => ({
      id: agent.id,
      name: agent.name,
      type: agent.type,
      status: agent.status
    }));
  },

  // Get agent details
  'get_agent': (params, dynamic) => {
    const agentId = params.id || 'agent1';
    const agent = mockAgents.find(a => a.id === agentId);
    
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    return agent;
  },

  // Create agent
  'create_agent': (params, dynamic) => {
    // Extract parameters
    const name = params.name || 'New Agent';
    let type = params.type;
    
    // Convert string type to numeric if needed
    if (typeof type === 'string') {
      type = AGENT_TYPES[type.toLowerCase()] || AGENT_TYPES.custom;
    } else if (typeof type !== 'number') {
      type = AGENT_TYPES.custom;
    }
    
    // Create new agent
    const newAgent = {
      id: params.id || generateId(),
      name: name,
      type: type,
      status: 'CREATED',
      created: now(),
      updated: now(),
      config: {
        abilities: params.abilities || [],
        chains: params.chains || [],
        parameters: {
          max_skills: params.max_skills || 10,
          update_interval: params.update_interval || 60,
          capabilities: params.capabilities || ['basic'],
          recovery_attempts: params.recovery_attempts || 0
        },
        llm_config: params.llm_config || {
          provider: "openai",
          model: "gpt-4o-mini",
          temperature: 0.7,
          max_tokens: 1024
        },
        memory_config: params.memory_config || {
          max_size: 1000,
          retention_policy: "lru"
        },
        max_task_history: params.max_task_history || 100
      },
      memory: {},
      task_history: []
    };
    
    // In a real implementation, we would add this to the mockAgents array
    // For now, just return the new agent
    return newAgent;
  },

  // Update agent
  'update_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    // Update agent properties
    if (params.name) agent.name = params.name;
    if (params.status) agent.status = params.status;
    if (params.config) {
      agent.config = {
        ...agent.config,
        ...params.config
      };
    }
    
    agent.updated = now();
    
    return {
      success: true,
      agent: agent
    };
  },

  // Delete agent
  'delete_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    // In a real implementation, we would remove from the mockAgents array
    return {
      success: true,
      message: `Agent ${agentId} deleted successfully`
    };
  },

  // Start agent
  'start_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    if (agent.status === 'RUNNING') {
      return {
        success: false,
        error: `Agent ${agentId} is already running`
      };
    }
    
    agent.status = 'RUNNING';
    agent.updated = now();
    
    return {
      success: true,
      message: `Agent ${agentId} started successfully`,
      agent: {
        id: agent.id,
        name: agent.name,
        status: agent.status
      }
    };
  },

  // Stop agent
  'stop_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    if (agent.status === 'STOPPED') {
      return {
        success: false,
        error: `Agent ${agentId} is already stopped`
      };
    }
    
    agent.status = 'STOPPED';
    agent.updated = now();
    
    return {
      success: true,
      message: `Agent ${agentId} stopped successfully`,
      agent: {
        id: agent.id,
        name: agent.name,
        status: agent.status
      }
    };
  },

  // Pause agent
  'pause_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    if (agent.status === 'PAUSED') {
      return {
        success: false,
        error: `Agent ${agentId} is already paused`
      };
    }
    
    agent.status = 'PAUSED';
    agent.updated = now();
    
    return {
      success: true,
      message: `Agent ${agentId} paused successfully`,
      agent: {
        id: agent.id,
        name: agent.name,
        status: agent.status
      }
    };
  },

  // Resume agent
  'resume_agent': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    if (agent.status !== 'PAUSED') {
      return {
        success: false,
        error: `Agent ${agentId} is not paused`
      };
    }
    
    agent.status = 'RUNNING';
    agent.updated = now();
    
    return {
      success: true,
      message: `Agent ${agentId} resumed successfully`,
      agent: {
        id: agent.id,
        name: agent.name,
        status: agent.status
      }
    };
  },

  // Get agent status
  'get_agent_status': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    return {
      id: agent.id,
      name: agent.name,
      status: agent.status,
      updated: agent.updated
    };
  },

  // Get agent metrics
  'get_agent_metrics': (params, dynamic) => {
    const agentId = params.id || 'agent1';
    
    return {
      [agentId]: {
        'tasks_executed': {
          'current': 42,
          'type': 'COUNTER',
          'history': [[now(), 42]],
          'last_updated': now()
        },
        'memory_usage': {
          'current': 256,
          'type': 'GAUGE',
          'history': [[now(), 256]],
          'last_updated': now()
        },
        'execution_time': {
          'type': 'HISTOGRAM',
          'count': 10,
          'min': 0.1,
          'max': 2.5,
          'mean': 0.8,
          'median': 0.7,
          'last_updated': now()
        }
      }
    };
  },

  // Get agent health
  'get_agent_health': (params, dynamic) => {
    return {
      'agent1': {
        'agent_id': 'agent1',
        'status': 'HEALTHY',
        'message': 'Agent is healthy',
        'timestamp': now(),
        'details': {}
      },
      'agent2': {
        'agent_id': 'agent2',
        'status': 'STOPPED',
        'message': 'Agent is stopped',
        'timestamp': now(),
        'details': {}
      },
      'agent3': {
        'agent_id': 'agent3',
        'status': 'WARNING',
        'message': 'Agent may be stalled',
        'timestamp': now(),
        'details': {
          'time_since_update': '300 seconds'
        }
      }
    };
  },

  // Execute agent task
  'execute_agent_task': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    if (agent.status !== 'RUNNING') {
      return {
        success: false,
        error: `Agent ${agentId} is not running`
      };
    }
    
    const taskId = `task-${Date.now().toString(36)}`;
    
    return {
      success: true,
      task_id: taskId,
      status: 'submitted',
      agent_id: agentId,
      timestamp: now(),
      estimated_completion: new Date(Date.now() + 5000).toISOString()
    };
  },

  // Get agent memory
  'get_agent_memory': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    const key = params.key;
    if (key) {
      return {
        success: true,
        key: key,
        value: agent.memory[key] || null
      };
    }
    
    return {
      success: true,
      memory: agent.memory
    };
  },

  // Set agent memory
  'set_agent_memory': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    const key = params.key;
    const value = params.value;
    
    if (!key) {
      return {
        success: false,
        error: 'Memory key is required'
      };
    }
    
    // In a real implementation, we would update the agent's memory
    
    return {
      success: true,
      message: `Memory key ${key} set successfully for agent ${agentId}`
    };
  },

  // Clear agent memory
  'clear_agent_memory': (params, dynamic) => {
    const agentId = params.id;
    if (!agentId) {
      return {
        success: false,
        error: 'Agent ID is required'
      };
    }
    
    const agent = mockAgents.find(a => a.id === agentId);
    if (!agent) {
      return {
        success: false,
        error: `Agent with ID ${agentId} not found`
      };
    }
    
    const key = params.key;
    
    if (key) {
      // Clear specific key
      // In a real implementation, we would delete the key from agent.memory
      return {
        success: true,
        message: `Memory key ${key} cleared successfully for agent ${agentId}`
      };
    }
    
    // Clear all memory
    // In a real implementation, we would set agent.memory = {}
    return {
      success: true,
      message: `All memory cleared successfully for agent ${agentId}`
    };
  }
};

// Add aliases for commands
const aliases = {
  'agents.list_agents': agentMocks.list_agents,
  'agents.get_agent': agentMocks.get_agent,
  'agents.create_agent': agentMocks.create_agent,
  'agents.update_agent': agentMocks.update_agent,
  'agents.delete_agent': agentMocks.delete_agent,
  'agents.start_agent': agentMocks.start_agent,
  'agents.stop_agent': agentMocks.stop_agent,
  'agents.pause_agent': agentMocks.pause_agent,
  'agents.resume_agent': agentMocks.resume_agent,
  'agents.get_status': agentMocks.get_agent_status,
  'agents.execute_task': agentMocks.execute_agent_task,
  'agents.get_metrics': agentMocks.get_agent_metrics,
  'agents.get_health_status': agentMocks.get_agent_health,
  'agents.get_memory': agentMocks.get_agent_memory,
  'agents.set_memory': agentMocks.set_agent_memory,
  'agents.clear_memory': agentMocks.clear_agent_memory
};

// Add all aliases to the exports
Object.assign(agentMocks, aliases);

module.exports = agentMocks;
