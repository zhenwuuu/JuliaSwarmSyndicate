import { BaseAgent, AgentConfig } from '../agent/BaseAgent';
import { Skill } from '../skills/Skill';
import { EventEmitter } from 'events';
import { LLMConfig, LLMResponse } from '../llm/LLMProvider';

export interface SwarmAgentConfig extends AgentConfig {
  swarmConfig: {
    size: number;
    communicationProtocol: 'gossip' | 'broadcast' | 'direct';
    consensusThreshold: number;
    updateInterval: number;
    useLLMForConsensus?: boolean;
  };
}

export class SwarmAgent extends BaseAgent {
  private swarmConfig: SwarmAgentConfig['swarmConfig'];
  private peers: Map<string, SwarmAgent> = new Map();
  private consensus: Map<string, any> = new Map();
  private updateInterval?: NodeJS.Timeout;

  constructor(config: SwarmAgentConfig) {
    super(config);
    this.swarmConfig = config.swarmConfig;
  }

  async initialize(): Promise<void> {
    try {
      // Initialize LLM if configured
      if (this.parameters.llmConfig) {
        await this.initializeLLM(this.parameters.llmConfig);
      }
      
      // Initialize swarm-specific components
      this.setupSwarmCommunication();
      this.setupConsensusMechanism();

      this.emit('initialized');
      console.log(`SwarmAgent ${this.name} initialized`);
    } catch (error) {
      this.emit('error', error);
      console.error(`Failed to initialize SwarmAgent ${this.name}:`, error);
      throw error;
    }
  }

  async start(): Promise<void> {
    try {
      if (this.isRunning) {
        throw new Error('Agent is already running');
      }

      // Start swarm operations
      this.startSwarmOperations();
      this.isRunning = true;
      this.emit('started');

      // Start all platforms
      for (const platform of this.platforms) {
        await platform.start();
      }

      // Execute all skills
      for (const skill of this.skills) {
        await skill.execute();
      }

      console.log(`SwarmAgent ${this.name} started`);
    } catch (error) {
      this.emit('error', error);
      console.error(`Failed to start SwarmAgent ${this.name}:`, error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    try {
      if (!this.isRunning) {
        throw new Error('Agent is not running');
      }

      // Stop swarm operations
      if (this.updateInterval) {
        clearInterval(this.updateInterval);
      }
      
      this.stopSwarmOperations();
      this.isRunning = false;
      this.emit('stopped');

      // Stop all platforms
      for (const platform of this.platforms) {
        await platform.stop();
      }

      // Stop all skills
      for (const skill of this.skills) {
        await skill.stop();
      }

      console.log(`SwarmAgent ${this.name} stopped`);
    } catch (error) {
      this.emit('error', error);
      console.error(`Failed to stop SwarmAgent ${this.name}:`, error);
      throw error;
    }
  }

  // Swarm-specific methods
  async addPeer(peer: SwarmAgent): Promise<void> {
    if (this.peers.size >= this.swarmConfig.size) {
      throw new Error('Swarm size limit reached');
    }

    this.peers.set(peer.getName(), peer);
    this.emit('peerAdded', peer);
  }

  async removePeer(peerName: string): Promise<void> {
    this.peers.delete(peerName);
    this.emit('peerRemoved', peerName);
  }

  async broadcast(message: any): Promise<void> {
    switch (this.swarmConfig.communicationProtocol) {
      case 'gossip':
        await this.gossip(message);
        break;
      case 'broadcast':
        await this.directBroadcast(message);
        break;
      case 'direct':
        await this.directMessage(message);
        break;
    }
  }

  async reachConsensus(topic: string, value: any): Promise<boolean> {
    const votes = new Map<string, any>();
    votes.set(this.getName(), value);

    // Collect votes from peers
    for (const peer of this.peers.values()) {
      const peerVote = await this.requestVote(peer, topic);
      votes.set(peer.getName(), peerVote);
    }

    // Use LLM to analyze votes if configured
    if (this.swarmConfig.useLLMForConsensus && this.llmProvider) {
      return await this.llmBasedConsensus(topic, votes);
    } else {
      // Use traditional consensus mechanism
      const consensusValue = this.calculateConsensus(votes);
      const consensusReached = this.checkConsensusThreshold(votes, consensusValue);

      if (consensusReached) {
        this.consensus.set(topic, consensusValue);
        this.emit('consensusReached', { topic, value: consensusValue });
      }

      return consensusReached;
    }
  }

  // Private helper methods
  private setupSwarmCommunication(): void {
    // Set up event listeners for swarm communication
    this.on('message', this.handleMessage.bind(this));
    this.on('consensusUpdate', this.handleConsensusUpdate.bind(this));
  }

  private setupConsensusMechanism(): void {
    // Initialize consensus tracking
    this.consensus = new Map();
  }

  private startSwarmOperations(): void {
    // Start periodic swarm operations
    this.updateInterval = setInterval(() => {
      this.updateSwarmState();
    }, this.swarmConfig.updateInterval);
  }

  private stopSwarmOperations(): void {
    // Clean up swarm operations
    this.peers.clear();
    this.consensus.clear();
  }

  private async gossip(message: any): Promise<void> {
    // Implement gossip protocol
    const randomPeers = this.getRandomPeers(Math.ceil(this.peers.size / 2));
    for (const peer of randomPeers) {
      await this.sendToPeer(peer, message);
    }
  }

  private async directBroadcast(message: any): Promise<void> {
    // Implement direct broadcast to all peers
    for (const peer of this.peers.values()) {
      await this.sendToPeer(peer, message);
    }
  }

  private async directMessage(message: any): Promise<void> {
    // Implement direct message to specific peer
    if (!message.targetPeer) {
      throw new Error('Direct message requires peer target');
    }
    
    const peer = this.peers.get(message.targetPeer);
    if (!peer) {
      throw new Error(`Peer not found: ${message.targetPeer}`);
    }
    
    await this.sendToPeer(peer, message.content);
  }

  private async sendToPeer(peer: SwarmAgent, message: any): Promise<void> {
    // Implement peer-to-peer message sending
    peer.emit('message', {
      from: this.getName(),
      content: message
    });
  }

  private getRandomPeers(count: number): SwarmAgent[] {
    const peers = Array.from(this.peers.values());
    const shuffled = peers.sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
  }

  private handleMessage(message: any): void {
    // Store message in memory for future reference
    this.setMemory(`message:${Date.now()}`, message);
    
    // Handle incoming messages
    console.log(`SwarmAgent ${this.name} received message:`, message);
  }

  private handleConsensusUpdate(update: any): void {
    // Handle consensus updates
    console.log(`SwarmAgent ${this.name} received consensus update:`, update);
  }

  private updateSwarmState(): void {
    // Update swarm state and trigger necessary events
    this.emit('stateUpdate', {
      peerCount: this.peers.size,
      consensusTopics: Array.from(this.consensus.keys())
    });
  }

  private async requestVote(peer: SwarmAgent, topic: string): Promise<any> {
    // Request vote from peer for consensus
    return new Promise((resolve) => {
      peer.emit('voteRequest', { topic }, resolve);
    });
  }

  private calculateConsensus(votes: Map<string, any>): any {
    // Implement consensus calculation logic
    // This should be customized based on your specific needs
    const values = Array.from(votes.values());
    return values.reduce((a, b) => a + b, 0) / values.length;
  }

  private checkConsensusThreshold(votes: Map<string, any>, consensusValue: any): boolean {
    // Check if consensus threshold is reached
    const agreeingVotes = Array.from(votes.values()).filter(
      value => Math.abs(value - consensusValue) < 0.01
    );
    return agreeingVotes.length / votes.size >= this.swarmConfig.consensusThreshold;
  }

  private async llmBasedConsensus(topic: string, votes: Map<string, any>): Promise<boolean> {
    try {
      // Generate a prompt for the LLM to analyze the votes
      const prompt = `
        As a swarm intelligence coordinator, analyze these votes on topic "${topic}":
        ${Array.from(votes.entries()).map(([agent, vote]) => `${agent}: ${vote}`).join('\n')}
        
        Based on these votes:
        1. What is the optimal consensus value?
        2. Is there sufficient agreement to reach consensus (threshold: ${this.swarmConfig.consensusThreshold})?
        3. If consensus is not reached, what recommendations would you make?
        
        Format your response as JSON with the following structure:
        {
          "consensusValue": (number),
          "consensusReached": (boolean),
          "confidence": (number between 0-1),
          "recommendations": (string)
        }
      `;

      // Process with LLM
      const response = await this.processWithLLM(prompt);
      
      // Parse LLM response (assuming it returns valid JSON)
      const analysisResult = JSON.parse(response.text);
      
      if (analysisResult.consensusReached) {
        this.consensus.set(topic, analysisResult.consensusValue);
        this.emit('consensusReached', { 
          topic, 
          value: analysisResult.consensusValue,
          confidence: analysisResult.confidence,
          recommendations: analysisResult.recommendations
        });
      }

      return analysisResult.consensusReached;
    } catch (error) {
      await this.handleError(error as Error);
      
      // Fall back to traditional consensus mechanism
      console.warn('LLM consensus failed, falling back to traditional method');
      const consensusValue = this.calculateConsensus(votes);
      const consensusReached = this.checkConsensusThreshold(votes, consensusValue);
      
      if (consensusReached) {
        this.consensus.set(topic, consensusValue);
        this.emit('consensusReached', { topic, value: consensusValue });
      }
      
      return consensusReached;
    }
  }
} 