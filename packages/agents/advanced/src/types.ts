import { BaseLanguageModel } from '@langchain/core/language_models/base';
import { VectorStore } from '@langchain/core/vectorstores';

export interface AgentMemory {
  shortTerm: VectorStore;
  longTerm: VectorStore;
  episodic: VectorStore;
}

export interface AgentSkill {
  name: string;
  description: string;
  execute: (input: any) => Promise<any>;
  requiredCapabilities: string[];
}

export interface AgentProfile {
  id: string;
  name: string;
  description: string;
  capabilities: string[];
  skills: AgentSkill[];
  model: BaseLanguageModel;
  memory: AgentMemory;
}

export interface CollaborationRequest {
  taskId: string;
  fromAgentId: string;
  toAgentId: string;
  taskDescription: string;
  requiredCapabilities: string[];
  priority: number;
  deadline?: Date;
}

export interface CollaborationResponse {
  requestId: string;
  accepted: boolean;
  reason?: string;
  estimatedCompletionTime?: Date;
}

export interface LearningExperience {
  taskId: string;
  input: any;
  output: any;
  feedback: number; // -1 to 1 scale
  context: Record<string, any>;
  timestamp: Date;
}

export interface AgentMetrics {
  successRate: number;
  averageResponseTime: number;
  taskCompletion: number;
  learningProgress: number;
  collaborationScore: number;
}

export interface NLPCapabilities {
  intentRecognition: boolean;
  entityExtraction: boolean;
  sentimentAnalysis: boolean;
  contextualUnderstanding: boolean;
  multilingualSupport: boolean;
}

export type FeedbackType = 'positive' | 'negative' | 'neutral';

export interface AgentFeedback {
  taskId: string;
  fromAgentId: string;
  toAgentId: string;
  type: FeedbackType;
  score: number;
  comment?: string;
  timestamp: Date;
} 