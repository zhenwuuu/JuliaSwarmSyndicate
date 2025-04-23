import { LearningExperience, AgentProfile, AgentMetrics } from './types';
import { VectorStore } from '@langchain/core/vectorstores';
import { Document } from '@langchain/core/documents';
import { ChatOpenAI } from '@langchain/openai';
import { PromptTemplate } from '@langchain/core/prompts';
import { BaseMessage } from '@langchain/core/messages';

export class LearningSystem {
  private experiences: VectorStore;
  private model: ChatOpenAI;
  private agentProfiles: Map<string, AgentProfile>;
  private metrics: Map<string, AgentMetrics>;

  constructor(
    vectorStore: VectorStore,
    apiKey: string
  ) {
    this.experiences = vectorStore;
    this.model = new ChatOpenAI({
      openAIApiKey: apiKey,
      modelName: 'gpt-4-turbo-preview',
      temperature: 0.7
    });
    this.agentProfiles = new Map();
    this.metrics = new Map();
  }

  async recordExperience(agentId: string, experience: LearningExperience): Promise<void> {
    const metadata = {
      agentId,
      taskId: experience.taskId,
      feedback: experience.feedback,
      timestamp: experience.timestamp.toISOString()
    };

    const doc = new Document({
      pageContent: JSON.stringify({
        input: experience.input,
        output: experience.output,
        context: experience.context
      }),
      metadata
    });

    await this.experiences.addDocuments([doc]);
    await this.updateMetrics(agentId, experience);
  }

  private async updateMetrics(agentId: string, experience: LearningExperience): Promise<void> {
    const currentMetrics = this.metrics.get(agentId) || {
      successRate: 0,
      averageResponseTime: 0,
      taskCompletion: 0,
      learningProgress: 0,
      collaborationScore: 0
    };

    // Update metrics based on the new experience
    const successWeight = experience.feedback > 0 ? 1 : 0;
    const totalExperiences = await this.getAgentExperienceCount(agentId);

    currentMetrics.successRate = (currentMetrics.successRate * (totalExperiences - 1) + successWeight) / totalExperiences;
    currentMetrics.learningProgress = Math.min(1, totalExperiences / 100); // Arbitrary scale
    
    this.metrics.set(agentId, currentMetrics);
  }

  async retrieveSimilarExperiences(
    input: any,
    context: Record<string, any>,
    limit: number = 5
  ): Promise<LearningExperience[]> {
    const query = JSON.stringify({ input, context });
    const results = await this.experiences.similaritySearch(query, limit);

    return results.map(doc => ({
      taskId: doc.metadata.taskId,
      input: JSON.parse(doc.pageContent).input,
      output: JSON.parse(doc.pageContent).output,
      feedback: doc.metadata.feedback,
      context: JSON.parse(doc.pageContent).context,
      timestamp: new Date(doc.metadata.timestamp)
    }));
  }

  async analyzePerformance(agentId: string): Promise<{
    metrics: AgentMetrics;
    recommendations: string[];
  }> {
    const metrics = this.metrics.get(agentId);
    if (!metrics) {
      throw new Error('No metrics found for agent');
    }

    const template = PromptTemplate.fromTemplate(`
      Agent Performance Metrics:
      {metrics}

      Based on these metrics, provide:
      1. Analysis of the agent's performance
      2. Specific recommendations for improvement
      3. Areas where the agent excels

      Format the response as JSON with keys: analysis, recommendations, strengths
    `);

    const formatted = await template.format({
      metrics: JSON.stringify(metrics, null, 2)
    });

    const response = await this.model.invoke(formatted);
    const content = (response as BaseMessage).content as string;
    const analysis = JSON.parse(content);

    return {
      metrics,
      recommendations: analysis.recommendations
    };
  }

  async adaptAgentBehavior(
    agentId: string,
    context: Record<string, any>
  ): Promise<void> {
    const agent = this.agentProfiles.get(agentId);
    if (!agent) {
      throw new Error('Agent not found');
    }

    const recentExperiences = await this.retrieveSimilarExperiences(
      context,
      context,
      10
    );

    const template = PromptTemplate.fromTemplate(`
      Agent Profile:
      {profile}

      Recent Experiences:
      {experiences}

      Current Context:
      {context}

      Provide behavioral adaptations:
      1. Suggested changes to capabilities
      2. New skills to develop
      3. Adjustments to existing skills

      Format the response as JSON.
    `);

    const formatted = await template.format({
      profile: JSON.stringify(agent, null, 2),
      experiences: JSON.stringify(recentExperiences, null, 2),
      context: JSON.stringify(context, null, 2)
    });

    const response = await this.model.invoke(formatted);
    const content = (response as BaseMessage).content as string;
    const adaptations = JSON.parse(content);

    // Apply adaptations to agent profile
    agent.capabilities = [...agent.capabilities, ...adaptations.newCapabilities];
    agent.skills = [...agent.skills, ...adaptations.newSkills];

    this.agentProfiles.set(agentId, agent);
  }

  private async getAgentExperienceCount(agentId: string): Promise<number> {
    const filter = {
      where: {
        metadata: {
          agentId: agentId
        }
      }
    };

    const results = await this.experiences.similaritySearch('', 1, filter);
    return results.length;
  }

  getAgentMetrics(agentId: string): AgentMetrics {
    const metrics = this.metrics.get(agentId);
    if (!metrics) {
      throw new Error('No metrics found for agent');
    }
    return { ...metrics };
  }
} 