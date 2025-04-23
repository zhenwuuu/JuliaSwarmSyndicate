/**
 * Mock implementations for system-related commands
 */

// Helper to get current timestamp
const now = () => new Date().toISOString();

/**
 * Mock implementations for system commands
 */
const systemMocks = {
  // Check system health
  'check_system_health': (params, dynamic) => {
    return {
      status: 'healthy',
      timestamp: now(),
      components: {
        server: {
          status: 'healthy',
          uptime: 86400, // 24 hours in seconds
          version: '1.0.0'
        },
        storage: {
          status: 'healthy',
          type: 'sqlite',
          free_space: '10GB'
        },
        framework: {
          status: 'healthy',
          version: '1.0.0'
        }
      }
    };
  },

  // Get system overview
  'get_system_overview': (params, dynamic) => {
    return {
      cpu_usage: { percent: 25.5, cores: 8, threads: 16 },
      memory_usage: { total: 16384, used: 4096, percent: 25.0 },
      storage: { total: 512000, used: 128000, percent: 25.0 },
      uptime: { seconds: 3600, formatted: '1 hour' },
      active_agents: 2,
      active_swarms: 1,
      pending_tasks: 0,
      timestamp: now(),
      modules: {
        agents: true,
        swarms: true,
        storage: true,
        bridge: true,
        dex: true,
        neural_networks: true,
        portfolio: true
      }
    };
  },

  // Get realtime metrics
  'get_realtime_metrics': (params, dynamic) => {
    return {
      timestamp: now(),
      metrics: {
        cpu: [
          { timestamp: new Date(Date.now() - 60000).toISOString(), value: 22.5 },
          { timestamp: new Date(Date.now() - 50000).toISOString(), value: 23.1 },
          { timestamp: new Date(Date.now() - 40000).toISOString(), value: 24.7 },
          { timestamp: new Date(Date.now() - 30000).toISOString(), value: 26.2 },
          { timestamp: new Date(Date.now() - 20000).toISOString(), value: 25.8 },
          { timestamp: new Date(Date.now() - 10000).toISOString(), value: 25.5 }
        ],
        memory: [
          { timestamp: new Date(Date.now() - 60000).toISOString(), value: 23.0 },
          { timestamp: new Date(Date.now() - 50000).toISOString(), value: 23.5 },
          { timestamp: new Date(Date.now() - 40000).toISOString(), value: 24.0 },
          { timestamp: new Date(Date.now() - 30000).toISOString(), value: 24.5 },
          { timestamp: new Date(Date.now() - 20000).toISOString(), value: 25.0 },
          { timestamp: new Date(Date.now() - 10000).toISOString(), value: 25.0 }
        ],
        active_agents: [
          { timestamp: new Date(Date.now() - 60000).toISOString(), value: 2 },
          { timestamp: new Date(Date.now() - 50000).toISOString(), value: 2 },
          { timestamp: new Date(Date.now() - 40000).toISOString(), value: 2 },
          { timestamp: new Date(Date.now() - 30000).toISOString(), value: 2 },
          { timestamp: new Date(Date.now() - 20000).toISOString(), value: 2 },
          { timestamp: new Date(Date.now() - 10000).toISOString(), value: 2 }
        ],
        active_swarms: [
          { timestamp: new Date(Date.now() - 60000).toISOString(), value: 1 },
          { timestamp: new Date(Date.now() - 50000).toISOString(), value: 1 },
          { timestamp: new Date(Date.now() - 40000).toISOString(), value: 1 },
          { timestamp: new Date(Date.now() - 30000).toISOString(), value: 1 },
          { timestamp: new Date(Date.now() - 20000).toISOString(), value: 1 },
          { timestamp: new Date(Date.now() - 10000).toISOString(), value: 1 }
        ]
      }
    };
  },

  // Get resource usage
  'get_resource_usage': (params, dynamic) => {
    return {
      timestamp: now(),
      cpu: {
        total: 25.5,
        cores: [
          { core: 0, usage: 30.2 },
          { core: 1, usage: 28.7 },
          { core: 2, usage: 22.1 },
          { core: 3, usage: 24.5 },
          { core: 4, usage: 26.8 },
          { core: 5, usage: 23.4 },
          { core: 6, usage: 25.1 },
          { core: 7, usage: 22.9 }
        ]
      },
      memory: {
        total: 16384, // MB
        used: 4096,   // MB
        free: 12288,  // MB
        percent: 25.0,
        swap: {
          total: 8192,  // MB
          used: 512,    // MB
          free: 7680,   // MB
          percent: 6.25
        }
      },
      disk: {
        total: 512000,  // MB
        used: 128000,   // MB
        free: 384000,   // MB
        percent: 25.0,
        io: {
          read_count: 12345,
          write_count: 6789,
          read_bytes: 1024000,
          write_bytes: 512000
        }
      },
      network: {
        interfaces: [
          {
            name: 'eth0',
            bytes_sent: 1024000,
            bytes_recv: 2048000,
            packets_sent: 8765,
            packets_recv: 9876,
            errors_in: 0,
            errors_out: 0
          }
        ]
      },
      processes: {
        total: 120,
        running: 2,
        sleeping: 118,
        top: [
          { pid: 1234, name: 'julia', cpu: 15.2, memory: 512 },
          { pid: 5678, name: 'node', cpu: 8.7, memory: 256 }
        ]
      }
    };
  },

  // Run performance test
  'run_performance_test': (params, dynamic) => {
    const testType = params.test_type || 'basic';
    
    return {
      timestamp: now(),
      test_type: testType,
      duration: 5.2, // seconds
      results: {
        cpu_benchmark: {
          score: 8750,
          single_thread: 1250,
          multi_thread: 8750
        },
        memory_benchmark: {
          read_speed: 12500, // MB/s
          write_speed: 9800  // MB/s
        },
        disk_benchmark: {
          read_speed: 550,  // MB/s
          write_speed: 520, // MB/s
          random_read_iops: 12000,
          random_write_iops: 10000
        },
        agent_benchmark: {
          creation_time: 0.12,  // seconds
          task_execution_time: 0.25 // seconds
        },
        swarm_benchmark: {
          creation_time: 0.35,  // seconds
          optimization_time: 1.2 // seconds
        }
      }
    };
  },

  // Get system config
  'get_system_config': (params, dynamic) => {
    return {
      timestamp: now(),
      config: {
        server: {
          host: 'localhost',
          port: 8052,
          workers: 4,
          max_connections: 100,
          timeout: 30000
        },
        storage: {
          type: 'sqlite',
          path: '~/.juliaos/juliaos.sqlite',
          backup_enabled: true,
          backup_interval: 86400 // 24 hours in seconds
        },
        agents: {
          max_agents: 100,
          default_timeout: 60000,
          memory_limit: 1024,
          default_model: 'gpt-4o-mini'
        },
        swarms: {
          max_swarms: 20,
          max_agents_per_swarm: 50,
          default_algorithm: 'SwarmPSO'
        },
        logging: {
          level: 'info',
          file: '~/.juliaos/logs/juliaos.log',
          max_size: 10, // MB
          max_files: 5
        },
        security: {
          api_key_required: false,
          rate_limit: 100, // requests per minute
          max_payload_size: 10 // MB
        }
      }
    };
  },

  // Update system config
  'update_system_config': (params, dynamic) => {
    return {
      success: true,
      message: 'System configuration updated successfully',
      timestamp: now(),
      updated_keys: Object.keys(params)
    };
  }
};

// Add aliases for commands
const aliases = {
  'system.health': systemMocks.check_system_health,
  'metrics.get_system_overview': systemMocks.get_system_overview,
  'metrics.get_realtime_metrics': systemMocks.get_realtime_metrics,
  'metrics.get_resource_usage': systemMocks.get_resource_usage,
  'metrics.run_performance_test': systemMocks.run_performance_test,
  'system.get_config': systemMocks.get_system_config,
  'system.update_config': systemMocks.update_system_config
};

// Add all aliases to the exports
Object.assign(systemMocks, aliases);

module.exports = systemMocks;
