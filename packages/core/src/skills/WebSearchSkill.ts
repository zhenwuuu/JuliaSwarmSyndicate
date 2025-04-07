import { Skill, SkillConfig } from './Skill';

/**
 * Configuration for the WebSearchSkill
 * 
 * @interface WebSearchSkillConfig
 * @extends {SkillConfig}
 */
export interface WebSearchSkillConfig extends SkillConfig {
  /** API key for the search service */
  apiKey?: string;
  
  /** Search engine to use */
  searchEngine?: 'google' | 'bing' | 'duckduckgo';
  
  /** Number of results to return */
  maxResults?: number;
  
  /** Safe search setting */
  safeSearch?: boolean;
}

/**
 * WebSearchSkill provides web search capabilities to agents
 * 
 * This skill uses a search API to perform web searches and return results.
 * It's a simple example to demonstrate how to create a skill that interacts
 * with external services.
 * 
 * @class WebSearchSkill
 * @extends {Skill}
 */
export class WebSearchSkill extends Skill {
  private apiKey: string;
  private searchEngine: 'google' | 'bing' | 'duckduckgo';
  private maxResults: number;
  private safeSearch: boolean;
  private query: string = '';
  private results: Array<SearchResult> = [];
  
  /**
   * Creates an instance of WebSearchSkill.
   * 
   * @param {WebSearchSkillConfig} config - Configuration options
   */
  constructor(config: WebSearchSkillConfig) {
    super(config.parameters || {}, config.name || 'web-search', config.type || 'search');
    
    this.apiKey = config.apiKey || this.parameters.apiKey || '';
    this.searchEngine = config.searchEngine || this.parameters.searchEngine || 'google';
    this.maxResults = config.maxResults || this.parameters.maxResults || 10;
    this.safeSearch = config.safeSearch ?? this.parameters.safeSearch ?? true;
  }
  
  /**
   * Initialize the web search skill
   * 
   * @returns {Promise<void>}
   */
  async initialize(): Promise<void> {
    try {
      // Validate the API key
      if (!this.apiKey) {
        console.warn('WebSearchSkill initialized without API key. Searches will be simulated.');
      }
      
      this.setInitialized(true);
    } catch (error) {
      this.handleError(error as Error);
      throw error;
    }
  }
  
  /**
   * Set the search query
   * 
   * @param {string} query - The search query
   */
  setQuery(query: string): void {
    this.query = query;
  }
  
  /**
   * Get the search results
   * 
   * @returns {Array<SearchResult>} The search results
   */
  getResults(): Array<SearchResult> {
    return [...this.results];
  }
  
  /**
   * Execute the web search
   * 
   * @returns {Promise<void>}
   */
  async execute(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('WebSearchSkill is not initialized');
    }
    
    if (!this.query) {
      throw new Error('No search query provided. Call setQuery() before execute()');
    }
    
    try {
      this.setRunning(true);
      this.updateExecutionTime();
      
      // Perform the search
      this.results = await this.performSearch(this.query);
      
      // Emit the results
      this.emit('searchComplete', {
        query: this.query,
        results: this.results,
        timestamp: Date.now()
      });
      
      this.setRunning(false);
    } catch (error) {
      this.handleError(error as Error);
      this.setRunning(false);
      throw error;
    }
  }
  
  /**
   * Stop the web search skill
   * 
   * @returns {Promise<void>}
   */
  async stop(): Promise<void> {
    this.setRunning(false);
  }
  
  /**
   * Perform a web search
   * 
   * @private
   * @param {string} query - The search query
   * @returns {Promise<Array<SearchResult>>} The search results
   */
  private async performSearch(query: string): Promise<Array<SearchResult>> {
    // This is a simulated search since we're not actually connecting to a search API
    // In a real implementation, you would call the search API here
    
    // Simulate network delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Generate mock results based on the query
    const results: Array<SearchResult> = [];
    
    for (let i = 0; i < this.maxResults; i++) {
      results.push({
        title: `Result ${i + 1} for "${query}"`,
        url: `https://example.com/search?q=${encodeURIComponent(query)}&result=${i + 1}`,
        snippet: `This is a snippet for result ${i + 1} related to "${query}". It contains some information about the search query.`,
        position: i + 1
      });
    }
    
    return results;
  }
}

/**
 * Interface for search results
 * 
 * @interface SearchResult
 */
export interface SearchResult {
  /** Title of the search result */
  title: string;
  
  /** URL of the search result */
  url: string;
  
  /** Text snippet from the search result */
  snippet: string;
  
  /** Position in the search results (1-based) */
  position: number;
} 