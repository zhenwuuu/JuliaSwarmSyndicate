import { Pipeline, pipeline } from '@xenova/transformers';
import { ChatOpenAI } from '@langchain/openai';
import { PromptTemplate } from '@langchain/core/prompts';
import { NLPCapabilities } from './types';

export class EnhancedNLP {
  private sentimentAnalyzer: Pipeline;
  private entityRecognizer: Pipeline;
  private intentClassifier: Pipeline;
  private languageModel: ChatOpenAI;
  private capabilities: NLPCapabilities;

  constructor(apiKey: string) {
    this.languageModel = new ChatOpenAI({
      openAIApiKey: apiKey,
      modelName: 'gpt-4-turbo-preview',
      temperature: 0.7
    });

    this.capabilities = {
      intentRecognition: true,
      entityExtraction: true,
      sentimentAnalysis: true,
      contextualUnderstanding: true,
      multilingualSupport: true
    };
  }

  async initialize(): Promise<void> {
    // Initialize the transformer models
    this.sentimentAnalyzer = await pipeline('sentiment-analysis');
    this.entityRecognizer = await pipeline('ner');
    this.intentClassifier = await pipeline('text-classification');
  }

  async analyzeSentiment(text: string): Promise<{ label: string; score: number }> {
    const result = await this.sentimentAnalyzer(text);
    return {
      label: result[0].label,
      score: result[0].score
    };
  }

  async extractEntities(text: string): Promise<Array<{
    entity: string;
    type: string;
    score: number;
    word: string;
  }>> {
    const entities = await this.entityRecognizer(text);
    return entities.map((e: any) => ({
      entity: e.word,
      type: e.entity,
      score: e.score,
      word: e.word
    }));
  }

  async classifyIntent(text: string): Promise<{
    intent: string;
    confidence: number;
  }> {
    const result = await this.intentClassifier(text);
    return {
      intent: result[0].label,
      confidence: result[0].score
    };
  }

  async understandContext(
    text: string,
    context: Record<string, any>
  ): Promise<{
    understanding: string;
    relevantContext: Record<string, any>;
    confidence: number;
  }> {
    const template = PromptTemplate.fromTemplate(`
      Context Information:
      {context}

      User Input:
      {text}

      Please analyze the input considering the context and provide:
      1. A comprehensive understanding of the meaning
      2. Relevant context elements
      3. Confidence level in the understanding (0-1)

      Format the response as JSON with keys: understanding, relevantContext, confidence
    `);

    const formatted = await template.format({
      context: JSON.stringify(context),
      text
    });

    const response = await this.languageModel.invoke(formatted);
    return JSON.parse(response.content);
  }

  async translateAndAnalyze(
    text: string,
    sourceLanguage: string,
    targetLanguage: string
  ): Promise<{
    translation: string;
    analysis: {
      sentiment: { label: string; score: number };
      entities: Array<{ entity: string; type: string; score: number }>;
      intent: { intent: string; confidence: number };
    };
  }> {
    const template = PromptTemplate.fromTemplate(`
      Translate and analyze the following text:
      Original ({sourceLanguage}): {text}
      Target language: {targetLanguage}

      Provide:
      1. Translation
      2. Sentiment analysis
      3. Entity recognition
      4. Intent classification

      Format the response as JSON.
    `);

    const formatted = await template.format({
      sourceLanguage,
      text,
      targetLanguage
    });

    const response = await this.languageModel.invoke(formatted);
    return JSON.parse(response.content);
  }

  getCapabilities(): NLPCapabilities {
    return { ...this.capabilities };
  }

  async enhanceText(text: string): Promise<{
    enhanced: string;
    improvements: string[];
  }> {
    const template = PromptTemplate.fromTemplate(`
      Enhance the following text while maintaining its core meaning:
      {text}

      Provide:
      1. Enhanced version
      2. List of improvements made

      Format the response as JSON with keys: enhanced, improvements
    `);

    const formatted = await template.format({ text });
    const response = await this.languageModel.invoke(formatted);
    return JSON.parse(response.content);
  }
} 