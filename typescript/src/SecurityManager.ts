import { Chain, Bridge, Transaction } from './types';

/**
 * Security configuration interface
 */
export interface SecurityConfig {
  emergencyContacts: string[];
  anomalyDetectionThreshold: number;
  maxTransactionValue: number;
  pausedChains: string[];
  riskParams: Record<string, any>;
  monitoringInterval: number;  // seconds
  hooksEnabled: boolean;
}

/**
 * Security monitoring status interface
 */
export interface SecurityStatus {
  status: 'healthy' | 'warning' | 'critical' | 'paused';
  lastUpdated: Date;
  activeIncidents: SecurityIncident[];
  chainStatus: Record<string, string>;
  bridgeStatus: Record<string, string>;
}

/**
 * Security incident interface
 */
export interface SecurityIncident {
  id: string;
  type: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  timestamp: Date;
  details: Record<string, any>;
  status: 'new' | 'acknowledged' | 'investigating' | 'resolved';
  affectedChains: string[];
}

/**
 * Transaction risk assessment result
 */
export interface TransactionRiskAssessment {
  overallRisk: number;
  riskCategory: string;
  mevRisk: Record<string, any>;
  contractRisk: number;
  contractAssessment: Record<string, any>;
  recommendation: 'Proceed' | 'Caution' | 'Abort';
}

/**
 * Main interface for the SecurityManager
 */
export class SecurityManager {
  private config: SecurityConfig;
  private status: SecurityStatus;
  private bridgeMonitors: Map<string, Record<string, any>>;
  private contractMonitors: Map<string, Record<string, any>>;
  private wsConnection: WebSocket | null = null;

  /**
   * Constructor for SecurityManager
   */
  constructor(config: SecurityConfig) {
    this.config = config;
    this.status = {
      status: 'healthy',
      lastUpdated: new Date(),
      activeIncidents: [],
      chainStatus: {},
      bridgeStatus: {}
    };
    this.bridgeMonitors = new Map();
    this.contractMonitors = new Map();
  }

  /**
   * Initialize the security monitoring system
   */
  async initialize(): Promise<boolean> {
    console.log('Initializing security monitoring system...');
    try {
      // Connect to WebSocket for real-time monitoring
      await this.connectToSecurityWebSocket();
      
      // Initialize monitoring for all supported chains
      await this.initializeChainMonitoring();
      
      // Register security hooks
      this.registerDefaultSecurityHooks();
      
      this.status.lastUpdated = new Date();
      return true;
    } catch (error) {
      console.error('Failed to initialize security monitoring:', error);
      return false;
    }
  }

  /**
   * Connect to the security WebSocket for real-time updates
   */
  private async connectToSecurityWebSocket(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // In a real implementation, this would connect to your backend
        this.wsConnection = new WebSocket('wss://your-backend/security');
        
        this.wsConnection.onopen = () => {
          console.log('Security WebSocket connected');
          resolve();
        };
        
        this.wsConnection.onmessage = (event) => {
          this.handleSecurityEvent(JSON.parse(event.data));
        };
        
        this.wsConnection.onerror = (error) => {
          console.error('Security WebSocket error:', error);
          reject(error);
        };
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * Initialize monitoring for all supported chains
   */
  private async initializeChainMonitoring(): Promise<void> {
    const supportedChains = ['ethereum', 'arbitrum', 'optimism', 'polygon'];
    
    for (const chain of supportedChains) {
      // Initialize chain status
      this.status.chainStatus[chain] = 'healthy';
      
      // Initialize bridge status for this chain
      for (const destination of supportedChains) {
        if (chain !== destination) {
          const bridgeKey = `${chain}_${destination}`;
          this.status.bridgeStatus[bridgeKey] = 'operational';
        }
      }
    }
  }

  /**
   * Register default security hooks
   */
  private registerDefaultSecurityHooks(): void {
    // These would be registered with the backend in a real implementation
    console.log('Registering default security hooks');
  }

  /**
   * Handle a security event from the WebSocket
   */
  private handleSecurityEvent(event: Record<string, any>): void {
    console.log('Received security event:', event);
    
    switch (event.type) {
      case 'anomaly_detected':
        this.handleAnomalyDetection(event);
        break;
      case 'contract_warning':
        this.handleContractWarning(event);
        break;
      case 'bridge_status_change':
        this.handleBridgeStatusChange(event);
        break;
      case 'emergency_pause':
        this.handleEmergencyPause(event);
        break;
      default:
        console.log('Unknown security event type:', event.type);
    }
    
    // Update last updated timestamp
    this.status.lastUpdated = new Date();
  }

  /**
   * Handle anomaly detection event
   */
  private handleAnomalyDetection(event: Record<string, any>): void {
    // Create a new incident if anomaly score is high enough
    if (event.anomalyScore > this.config.anomalyDetectionThreshold) {
      const incident: SecurityIncident = {
        id: `ANOM-${Date.now()}`,
        type: 'anomaly_detection',
        severity: event.anomalyScore > 0.8 ? 'critical' : 
                 event.anomalyScore > 0.6 ? 'high' : 'medium',
        timestamp: new Date(),
        details: event,
        status: 'new',
        affectedChains: [event.chain]
      };
      
      this.status.activeIncidents.push(incident);
      
      // Update chain status
      if (event.anomalyScore > 0.8) {
        this.status.chainStatus[event.chain] = 'critical';
      } else if (event.anomalyScore > 0.6) {
        this.status.chainStatus[event.chain] = 'warning';
      }
    }
  }

  /**
   * Handle contract warning event
   */
  private handleContractWarning(event: Record<string, any>): void {
    // Create a new incident for contract warnings
    const incident: SecurityIncident = {
      id: `CONT-${Date.now()}`,
      type: 'contract_warning',
      severity: event.riskScore > 0.8 ? 'high' : 'medium',
      timestamp: new Date(),
      details: event,
      status: 'new',
      affectedChains: [event.chain]
    };
    
    this.status.activeIncidents.push(incident);
  }

  /**
   * Handle bridge status change event
   */
  private handleBridgeStatusChange(event: Record<string, any>): void {
    const bridgeKey = `${event.sourceChain}_${event.destinationChain}`;
    this.status.bridgeStatus[bridgeKey] = event.status;
    
    // Create an incident if status is degraded or down
    if (event.status === 'degraded' || event.status === 'down') {
      const incident: SecurityIncident = {
        id: `BRDG-${Date.now()}`,
        type: 'bridge_degradation',
        severity: event.status === 'down' ? 'critical' : 'high',
        timestamp: new Date(),
        details: event,
        status: 'new',
        affectedChains: [event.sourceChain, event.destinationChain]
      };
      
      this.status.activeIncidents.push(incident);
    }
  }

  /**
   * Handle emergency pause event
   */
  private handleEmergencyPause(event: Record<string, any>): void {
    // Update chain status
    this.status.chainStatus[event.chain] = 'paused';
    
    // Create a critical incident
    const incident: SecurityIncident = {
      id: `EMER-${Date.now()}`,
      type: 'emergency_pause',
      severity: 'critical',
      timestamp: new Date(),
      details: event,
      status: 'new',
      affectedChains: [event.chain]
    };
    
    this.status.activeIncidents.push(incident);
    
    // Update overall status
    this.status.status = 'critical';
  }

  /**
   * Get current security status
   */
  getSecurityStatus(): SecurityStatus {
    return this.status;
  }

  /**
   * Assess the risk of a transaction before sending
   */
  async assessTransactionRisk(transaction: Transaction): Promise<TransactionRiskAssessment> {
    // In a real implementation, this would call to your backend
    try {
      const response = await fetch('/api/security/assess-transaction', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(transaction)
      });
      
      return await response.json();
    } catch (error) {
      console.error('Failed to assess transaction risk:', error);
      
      // Return a cautious assessment on failure
      return {
        overallRisk: 0.5,
        riskCategory: 'Medium',
        mevRisk: {
          mevRate: 0.01,
          mevValue: transaction.value * 0.01
        },
        contractRisk: 0.5,
        contractAssessment: {},
        recommendation: 'Caution'
      };
    }
  }

  /**
   * Check if a specific chain is currently under emergency pause
   */
  isChainPaused(chain: string): boolean {
    return this.status.chainStatus[chain] === 'paused' || 
           this.config.pausedChains.includes(chain);
  }

  /**
   * Check if a bridge between two chains is operational
   */
  isBridgeOperational(sourceChain: string, destinationChain: string): boolean {
    const bridgeKey = `${sourceChain}_${destinationChain}`;
    return this.status.bridgeStatus[bridgeKey] === 'operational';
  }

  /**
   * Report a security incident from the client side
   */
  async reportIncident(
    incidentType: string, 
    severity: 'critical' | 'high' | 'medium' | 'low',
    details: Record<string, any>
  ): Promise<SecurityIncident> {
    // Create the incident
    const incident: SecurityIncident = {
      id: `USER-${Date.now()}`,
      type: incidentType,
      severity: severity,
      timestamp: new Date(),
      details: details,
      status: 'new',
      affectedChains: details.affectedChains || []
    };
    
    // In a real implementation, report to the backend
    try {
      const response = await fetch('/api/security/report-incident', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(incident)
      });
      
      const result = await response.json();
      
      // Add to local incidents
      this.status.activeIncidents.push(incident);
      
      return incident;
    } catch (error) {
      console.error('Failed to report incident:', error);
      return incident;
    }
  }

  /**
   * Generate a security report for the current system state
   */
  async generateSecurityReport(): Promise<Record<string, any>> {
    // In a real implementation, this would call to your backend
    try {
      const response = await fetch('/api/security/generate-report');
      return await response.json();
    } catch (error) {
      console.error('Failed to generate security report:', error);
      
      // Return a basic report on failure
      return {
        reportId: `REP-${Date.now()}`,
        generatedAt: new Date(),
        summary: {
          totalIncidents: this.status.activeIncidents.length,
          critical: this.status.activeIncidents.filter(i => i.severity === 'critical').length,
          high: this.status.activeIncidents.filter(i => i.severity === 'high').length,
          medium: this.status.activeIncidents.filter(i => i.severity === 'medium').length,
          low: this.status.activeIncidents.filter(i => i.severity === 'low').length
        },
        chainStatus: this.status.chainStatus,
        bridgeStatus: this.status.bridgeStatus
      };
    }
  }
} 