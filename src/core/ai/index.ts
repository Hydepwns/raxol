/**
 * AI Integration Module for Raxol
 * 
 * Provides intelligent features for Raxol applications including development
 * assistance, content generation, and runtime optimization capabilities.
 * 
 * Status: Core functionality and development assistance features implemented.
 * Content generation and runtime features planned for future releases.
 */

// Assistant APIs
export * from './assistant/CodeCompletion';
export * from './assistant/RefactoringAssistant';
export * from './assistant/PerformanceAdvisor';
export * from './assistant/AccessibilityChecker';

// Note: The following modules are planned but not yet implemented
// Content & UI Generation APIs and Runtime AI Features will be implemented in future updates

/**
 * Main AI configuration interface
 */
export interface AIConfig {
  /**
   * API key for AI service integration
   */
  apiKey?: string;
  
  /**
   * Base URL for AI service endpoints
   */
  baseUrl?: string;
  
  /**
   * Enable/disable AI features globally
   */
  enabled?: boolean;
  
  /**
   * Maximum token limit for requests
   */
  maxTokens?: number;
  
  /**
   * Model configuration
   */
  model?: {
    /**
     * Model identifier to use
     */
    name: string;
    
    /**
     * Model-specific parameters
     */
    parameters?: Record<string, any>;
  };
  
  /**
   * Privacy settings for AI integration
   */
  privacy?: {
    /**
     * Whether to allow sending code to external services
     */
    allowCodeSharing?: boolean;
    
    /**
     * Data retention policy
     */
    dataRetention?: 'none' | 'session' | 'persistent';
    
    /**
     * Types of data allowed to be processed
     */
    allowedDataTypes?: Array<'code' | 'userInput' | 'usage' | 'performance'>;
  };
}

/**
 * Default AI configuration
 */
export const DEFAULT_AI_CONFIG: AIConfig = {
  enabled: false,
  maxTokens: 1024,
  model: {
    name: 'gpt-3.5-turbo',
    parameters: {
      temperature: 0.7,
      topP: 1
    }
  },
  privacy: {
    allowCodeSharing: false,
    dataRetention: 'session',
    allowedDataTypes: ['code', 'performance']
  }
};

/**
 * AI service manager for Raxol
 */
export class AIManager {
  private config: AIConfig;
  private initialized: boolean = false;
  
  /**
   * Create a new AI manager instance
   */
  constructor(config: Partial<AIConfig> = {}) {
    this.config = {
      ...DEFAULT_AI_CONFIG,
      ...config
    };
  }
  
  /**
   * Initialize the AI system
   */
  async initialize(): Promise<boolean> {
    if (!this.config.enabled) {
      console.info('AI integration disabled by configuration');
      return false;
    }
    
    if (!this.config.apiKey && !this.isUsingLocalModel()) {
      console.warn('No API key provided for AI services');
      return false;
    }
    
    try {
      // Perform initialization logic
      this.initialized = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize AI services:', error);
      return false;
    }
  }
  
  /**
   * Check if AI services are available
   */
  isAvailable(): boolean {
    return this.initialized && Boolean(this.config.enabled);
  }
  
  /**
   * Get current AI configuration
   */
  getConfig(): AIConfig {
    return { ...this.config };
  }
  
  /**
   * Update AI configuration
   */
  updateConfig(newConfig: Partial<AIConfig>): void {
    this.config = {
      ...this.config,
      ...newConfig
    };
  }
  
  /**
   * Check if using local model instead of remote API
   */
  private isUsingLocalModel(): boolean {
    return Boolean(this.config.model?.name?.includes('local'));
  }
}

/**
 * Global AI manager instance
 */
export const aiManager = new AIManager(); 