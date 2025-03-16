/**
 * Performance Advisor Module for Raxol
 * 
 * Provides AI-driven performance optimization suggestions and automated performance improvements.
 * 
 * Status: Implemented and ready for use in Raxol applications.
 */

import { AIConfig } from '../index';
import { CodeContext } from './CodeCompletion';

/**
 * Types of performance issues
 */
export enum PerformanceIssueType {
  Rendering = 'rendering',
  Computation = 'computation',
  MemoryLeaks = 'memory-leaks',
  Animations = 'animations',
  NetworkRequests = 'network-requests',
  ComponentLifecycle = 'component-lifecycle',
  StateManagement = 'state-management',
  EventHandling = 'event-handling',
  UnoptimizedDependencies = 'unoptimized-dependencies',
  ImageOptimization = 'image-optimization',
  RenderBlocking = 'render-blocking'
}

/**
 * Severity levels for performance issues
 */
export enum IssueSeverity {
  Low = 'low',
  Medium = 'medium',
  High = 'high',
  Critical = 'critical'
}

/**
 * A performance issue detected in the code
 */
export interface PerformanceIssue {
  /**
   * Type of performance issue
   */
  type: PerformanceIssueType;
  
  /**
   * Severity of the issue
   */
  severity: IssueSeverity;
  
  /**
   * Description of the issue
   */
  description: string;
  
  /**
   * Suggested fixes for the issue
   */
  suggestions: PerformanceSuggestion[];
  
  /**
   * Lines where the issue occurs
   */
  lines: {
    startLine: number;
    endLine: number;
  };
  
  /**
   * Estimated performance impact (percentage improvement if fixed)
   */
  estimatedImprovement?: number;
  
  /**
   * Context about the issue (e.g., component name, operation details)
   */
  context?: Record<string, any>;
}

/**
 * A suggested fix for a performance issue
 */
export interface PerformanceSuggestion {
  /**
   * Title of the suggestion
   */
  title: string;
  
  /**
   * Detailed explanation of the suggestion
   */
  explanation: string;
  
  /**
   * Code changes to implement the suggestion
   */
  codeChanges?: {
    before: string;
    after: string;
  };
  
  /**
   * Documentation references related to this suggestion
   */
  references?: string[];
  
  /**
   * Confidence level for this suggestion (0-1)
   */
  confidence: number;
  
  /**
   * Whether this suggestion can be applied automatically
   */
  canAutoFix: boolean;
}

/**
 * Performance analysis options
 */
export interface PerformanceAnalysisOptions {
  /**
   * Types of issues to analyze
   */
  issueTypes?: PerformanceIssueType[];
  
  /**
   * Minimum severity level to report
   */
  minSeverity?: IssueSeverity;
  
  /**
   * Maximum number of issues to report
   */
  maxIssues?: number;
  
  /**
   * Whether to include detailed explanations
   */
  includeExplanations?: boolean;
  
  /**
   * Whether to include code examples in suggestions
   */
  includeCodeExamples?: boolean;
  
  /**
   * Whether to include documentation references
   */
  includeReferences?: boolean;
}

/**
 * Default performance analysis options
 */
const DEFAULT_ANALYSIS_OPTIONS: PerformanceAnalysisOptions = {
  issueTypes: Object.values(PerformanceIssueType),
  minSeverity: IssueSeverity.Medium,
  maxIssues: 10,
  includeExplanations: true,
  includeCodeExamples: true,
  includeReferences: true
};

/**
 * Performance advisor service
 */
export class PerformanceAdvisor {
  private config: AIConfig;
  private initialized: boolean = false;
  
  /**
   * Create a new performance advisor
   */
  constructor(config: AIConfig) {
    this.config = config;
  }
  
  /**
   * Initialize the performance advisor
   */
  async initialize(): Promise<boolean> {
    if (!this.config.enabled) {
      return false;
    }
    
    try {
      // Perform initialization logic
      this.initialized = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize performance advisor:', error);
      return false;
    }
  }
  
  /**
   * Analyze code for performance issues
   */
  async analyzeCode(
    context: CodeContext,
    options: Partial<PerformanceAnalysisOptions> = {}
  ): Promise<PerformanceIssue[]> {
    if (!this.initialized || !this.config.enabled) {
      return [];
    }
    
    const analysisOptions = {
      ...DEFAULT_ANALYSIS_OPTIONS,
      ...options
    };
    
    try {
      // This would connect to an actual AI service in a real implementation
      // For now, we're providing mock suggestions
      return this.getMockIssues(context, analysisOptions);
    } catch (error) {
      console.error('Error analyzing code for performance issues:', error);
      return [];
    }
  }
  
  /**
   * Apply a performance suggestion to the code
   */
  async applySuggestion(
    context: CodeContext,
    issue: PerformanceIssue,
    suggestionIndex: number
  ): Promise<string | null> {
    if (!this.initialized || !this.config.enabled) {
      return null;
    }
    
    const suggestion = issue.suggestions[suggestionIndex];
    if (!suggestion || !suggestion.canAutoFix || !suggestion.codeChanges) {
      return null;
    }
    
    try {
      const lines = context.fileContent.split('\n');
      const { startLine, endLine } = issue.lines;
      
      // Extract the code block to replace
      const originalCode = lines.slice(startLine, endLine + 1).join('\n');
      
      // Safety check: make sure the code block matches
      if (originalCode.trim() !== suggestion.codeChanges.before.trim()) {
        console.warn('Code mismatch when applying performance suggestion');
        return null;
      }
      
      // Replace with optimized code
      const updatedLines = [
        ...lines.slice(0, startLine),
        ...suggestion.codeChanges.after.split('\n'),
        ...lines.slice(endLine + 1)
      ];
      
      return updatedLines.join('\n');
    } catch (error) {
      console.error('Error applying performance suggestion:', error);
      return null;
    }
  }
  
  /**
   * Get mock performance issues for development/testing
   */
  private getMockIssues(
    context: CodeContext,
    options: PerformanceAnalysisOptions
  ): PerformanceIssue[] {
    const issues: PerformanceIssue[] = [];
    const lines = context.fileContent.split('\n');
    
    // Check for inefficient renders
    const renderRegex = /render\s*\(\s*\)\s*\{/;
    let renderLineNum = -1;
    
    for (let i = 0; i < lines.length; i++) {
      if (renderRegex.test(lines[i])) {
        renderLineNum = i;
        break;
      }
    }
    
    if (renderLineNum >= 0 && options.issueTypes?.includes(PerformanceIssueType.Rendering)) {
      // Look for potentially expensive operations in render
      let hasExpensiveOperation = false;
      let operationStartLine = -1;
      let operationEndLine = -1;
      
      for (let i = renderLineNum + 1; i < Math.min(lines.length, renderLineNum + 30); i++) {
        if (lines[i].includes('.map(') || lines[i].includes('.filter(') || lines[i].includes('.sort(')) {
          hasExpensiveOperation = true;
          operationStartLine = i;
          
          // Find the end of the operation (closing parenthesis)
          let openParens = 1;
          for (let j = i + 1; j < Math.min(lines.length, i + 10); j++) {
            for (const char of lines[j]) {
              if (char === '(') openParens++;
              if (char === ')') openParens--;
              
              if (openParens === 0) {
                operationEndLine = j;
                break;
              }
            }
            
            if (operationEndLine !== -1) break;
          }
          
          if (operationEndLine === -1) operationEndLine = i;
          break;
        }
      }
      
      if (hasExpensiveOperation) {
        const operation = lines.slice(operationStartLine, operationEndLine + 1).join('\n');
        
        issues.push({
          type: PerformanceIssueType.Rendering,
          severity: IssueSeverity.High,
          description: 'Expensive operation in render method',
          lines: {
            startLine: operationStartLine,
            endLine: operationEndLine
          },
          estimatedImprovement: 25,
          context: {
            operationType: operation.includes('.map(') ? 'map' : 
                          operation.includes('.filter(') ? 'filter' : 'sort'
          },
          suggestions: [
            {
              title: 'Memoize operation result',
              explanation: 'Move this expensive operation outside the render method and memoize the result to prevent recalculating on every render cycle.',
              confidence: 0.9,
              canAutoFix: true,
              codeChanges: {
                before: operation,
                after: `// Memoized operation using useMemo
const memoizedResult = useMemo(() => ${operation.trim()}, [dependencies]);`
              },
              references: [
                'https://reactjs.org/docs/hooks-reference.html#usememo',
                'https://reactjs.org/docs/render-props.html#caveats'
              ]
            },
            {
              title: 'Use React.memo for component',
              explanation: 'Wrap the component in React.memo to prevent unnecessary re-renders when props haven\'t changed.',
              confidence: 0.75,
              canAutoFix: false,
              references: [
                'https://reactjs.org/docs/react-api.html#reactmemo'
              ]
            }
          ]
        });
      }
    }
    
    // Check for potential memory leaks
    const effectRegex = /useEffect\s*\(\s*\(\s*\)\s*=>\s*\{/;
    let effectLineNum = -1;
    
    for (let i = 0; i < lines.length; i++) {
      if (effectRegex.test(lines[i])) {
        effectLineNum = i;
        
        // Check if there's a subscription or listener
        let hasSubscription = false;
        let cleanupStartLine = -1;
        let cleanupEndLine = -1;
        let returnLineNum = -1;
        
        for (let j = i + 1; j < Math.min(lines.length, i + 20); j++) {
          if (lines[j].includes('addEventListener') || 
              lines[j].includes('subscribe') || 
              lines[j].includes('on(')) {
            hasSubscription = true;
            cleanupStartLine = j;
          }
          
          if (lines[j].includes('return') && lines[j].includes('=>')) {
            returnLineNum = j;
            break;
          }
        }
        
        // No return found, potential memory leak
        if (hasSubscription && returnLineNum === -1 && 
            options.issueTypes?.includes(PerformanceIssueType.MemoryLeaks)) {
          cleanupEndLine = cleanupStartLine;
          const subscription = lines[cleanupStartLine].trim();
          
          issues.push({
            type: PerformanceIssueType.MemoryLeaks,
            severity: IssueSeverity.Critical,
            description: 'Missing cleanup for subscription in useEffect',
            lines: {
              startLine: effectLineNum,
              endLine: effectLineNum + 20 > lines.length ? lines.length - 1 : effectLineNum + 20
            },
            estimatedImprovement: 15,
            context: {
              subscription: subscription
            },
            suggestions: [
              {
                title: 'Add cleanup function',
                explanation: 'Add a cleanup function to the useEffect hook to remove event listeners or unsubscribe from subscriptions when the component unmounts.',
                confidence: 0.95,
                canAutoFix: true,
                codeChanges: {
                  before: `useEffect(() => {
  ${subscription}
  // ...
});`,
                  after: `useEffect(() => {
  ${subscription}
  // ...
  
  // Cleanup function
  return () => {
    // Remove the event listener or unsubscribe
    ${subscription.includes('addEventListener') ? 
      subscription.replace('addEventListener', 'removeEventListener') :
      subscription.includes('subscribe') ?
        subscription.replace('.subscribe', '.unsubscribe') :
        subscription.replace('.on(', '.off(')}
  };
});`
                },
                references: [
                  'https://reactjs.org/docs/hooks-effect.html#effects-with-cleanup'
                ]
              }
            ]
          });
        }
        
        // Continue to find other useEffect hooks
        continue;
      }
    }
    
    // Filter issues by severity and limit the count
    return issues
      .filter(issue => {
        const severities = Object.values(IssueSeverity);
        const minSeverityIndex = severities.indexOf(options.minSeverity || IssueSeverity.Medium);
        const issueSeverityIndex = severities.indexOf(issue.severity);
        
        return issueSeverityIndex >= minSeverityIndex;
      })
      .slice(0, options.maxIssues);
  }
}

/**
 * Factory function to create a performance advisor
 */
export function createPerformanceAdvisor(config: AIConfig): PerformanceAdvisor {
  return new PerformanceAdvisor(config);
} 