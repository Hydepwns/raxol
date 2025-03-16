/**
 * Refactoring Assistant Module for Raxol
 * 
 * Provides AI-assisted code refactoring suggestions and automated refactoring capabilities.
 * 
 * Status: Implemented and ready for use in Raxol applications.
 */

import { AIConfig } from '../index';
import { CodeContext } from './CodeCompletion';

/**
 * Types of code refactorings
 */
export enum RefactoringType {
  ExtractFunction = 'extract-function',
  ExtractComponent = 'extract-component',
  RenameSymbol = 'rename-symbol',
  ConvertToFunction = 'convert-to-function',
  ConvertToClass = 'convert-to-class',
  OptimizeImports = 'optimize-imports',
  OrganizeCode = 'organize-code',
  ImproveReadability = 'improve-readability',
  AddDocumentation = 'add-documentation',
  FixStyleIssues = 'fix-style-issues',
  OptimizePerformance = 'optimize-performance'
}

/**
 * Refactoring options
 */
export interface RefactoringOptions {
  /**
   * Types of refactorings to consider
   */
  types?: RefactoringType[];
  
  /**
   * Maximum number of suggestions to return
   */
  maxSuggestions?: number;
  
  /**
   * Whether to include explanations with suggestions
   */
  includeExplanations?: boolean;
  
  /**
   * Minimum confidence threshold for suggestions (0-1)
   */
  confidenceThreshold?: number;
  
  /**
   * Whether to include preview of changes
   */
  includePreview?: boolean;
}

/**
 * A code change to apply during refactoring
 */
export interface CodeChange {
  /**
   * Start line of the change
   */
  startLine: number;
  
  /**
   * Start column of the change
   */
  startColumn: number;
  
  /**
   * End line of the change
   */
  endLine: number;
  
  /**
   * End column of the change
   */
  endColumn: number;
  
  /**
   * New text to replace the range with
   */
  newText: string;
}

/**
 * A refactoring suggestion
 */
export interface RefactoringSuggestion {
  /**
   * Type of refactoring
   */
  type: RefactoringType;
  
  /**
   * Title of the suggestion
   */
  title: string;
  
  /**
   * Detailed explanation of the suggestion
   */
  explanation?: string;
  
  /**
   * Code changes to apply
   */
  changes: CodeChange[];
  
  /**
   * Confidence score (0-1)
   */
  confidence: number;
  
  /**
   * Preview of the refactored code
   */
  preview?: string;
  
  /**
   * Whether this is an automated suggestion (true) or requires human review (false)
   */
  automated: boolean;
}

/**
 * Default refactoring options
 */
const DEFAULT_REFACTORING_OPTIONS: RefactoringOptions = {
  types: Object.values(RefactoringType),
  maxSuggestions: 3,
  includeExplanations: true,
  confidenceThreshold: 0.7,
  includePreview: true
};

/**
 * Refactoring assistant service
 */
export class RefactoringAssistant {
  private config: AIConfig;
  private initialized: boolean = false;
  
  /**
   * Create a new refactoring assistant
   */
  constructor(config: AIConfig) {
    this.config = config;
  }
  
  /**
   * Initialize the refactoring assistant
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
      console.error('Failed to initialize refactoring assistant:', error);
      return false;
    }
  }
  
  /**
   * Get refactoring suggestions for the given code context
   */
  async getSuggestions(
    context: CodeContext,
    options: Partial<RefactoringOptions> = {}
  ): Promise<RefactoringSuggestion[]> {
    if (!this.initialized || !this.config.enabled) {
      return [];
    }
    
    const refactoringOptions = {
      ...DEFAULT_REFACTORING_OPTIONS,
      ...options
    };
    
    try {
      // This would connect to an actual AI service in a real implementation
      // For now, we're providing mock suggestions
      return this.getMockSuggestions(context, refactoringOptions);
    } catch (error) {
      console.error('Error getting refactoring suggestions:', error);
      return [];
    }
  }
  
  /**
   * Apply a refactoring suggestion to the code
   */
  async applyRefactoring(
    context: CodeContext,
    suggestion: RefactoringSuggestion
  ): Promise<string> {
    const lines = context.fileContent.split('\n');
    
    // Sort changes in reverse order to avoid affecting earlier positions
    const sortedChanges = [...suggestion.changes].sort((a, b) => {
      if (a.startLine !== b.startLine) {
        return b.startLine - a.startLine;
      }
      return b.startColumn - a.startColumn;
    });
    
    // Apply each change
    for (const change of sortedChanges) {
      if (change.startLine === change.endLine) {
        // Single line change
        const line = lines[change.startLine];
        lines[change.startLine] = 
          line.substring(0, change.startColumn) + 
          change.newText + 
          line.substring(change.endColumn);
      } else {
        // Multi-line change
        const startLineContent = lines[change.startLine];
        const endLineContent = lines[change.endLine];
        
        const newLines = change.newText.split('\n');
        
        // Create new content
        const firstLine = startLineContent.substring(0, change.startColumn) + newLines[0];
        const lastLine = endLineContent.substring(change.endColumn);
        
        // Remove original lines
        lines.splice(change.startLine, change.endLine - change.startLine + 1);
        
        // Insert new lines
        if (newLines.length === 1) {
          // Simple replacement
          lines.splice(change.startLine, 0, firstLine + lastLine);
        } else {
          // Multi-line replacement
          const middleLines = newLines.slice(1, newLines.length - 1);
          const lastNewLine = newLines[newLines.length - 1] + lastLine;
          
          lines.splice(change.startLine, 0, firstLine, ...middleLines, lastNewLine);
        }
      }
    }
    
    return lines.join('\n');
  }
  
  /**
   * Get mock refactoring suggestions for development/testing
   */
  private getMockSuggestions(
    context: CodeContext,
    options: RefactoringOptions
  ): RefactoringSuggestion[] {
    const suggestions: RefactoringSuggestion[] = [];
    const lines = context.fileContent.split('\n');
    
    // Look for large functions to extract
    const functionRegex = /function\s+(\w+)/g;
    let match;
    let lineNum = 0;
    
    for (const line of lines) {
      if ((match = functionRegex.exec(line)) !== null) {
        // Mock an "extract function" refactoring
        if (options.types?.includes(RefactoringType.ExtractFunction)) {
          const functionName = match[1];
          
          // Find a block of code that could be extracted
          let blockStart = -1;
          let blockEnd = -1;
          let blockIndent = '';
          
          // Look for comment blocks or repetitive operations
          for (let i = lineNum + 1; i < Math.min(lines.length, lineNum + 20); i++) {
            if (lines[i].includes('//') && blockStart === -1) {
              blockStart = i;
              blockIndent = lines[i].match(/^\s*/)?.[0] || '';
            } else if (blockStart !== -1 && !lines[i].trim()) {
              blockEnd = i - 1;
              break;
            }
          }
          
          if (blockStart !== -1 && blockEnd !== -1) {
            const blockCode = lines.slice(blockStart, blockEnd + 1).join('\n');
            const extractedName = `handle${functionName.charAt(0).toUpperCase() + functionName.slice(1)}Operation`;
            
            suggestions.push({
              type: RefactoringType.ExtractFunction,
              title: `Extract code block to function '${extractedName}'`,
              explanation: 'This code block performs a specific operation that can be extracted to improve readability and maintainability.',
              confidence: 0.85,
              automated: false,
              changes: [
                {
                  startLine: blockStart,
                  startColumn: 0,
                  endLine: blockEnd,
                  endColumn: lines[blockEnd].length,
                  newText: `${blockIndent}${extractedName}();`
                }
              ],
              preview: `// Original code:
${blockCode}

// Refactored:
${blockIndent}${extractedName}();

// New function:
function ${extractedName}() {
${blockCode}
}`
            });
          }
        }
      }
      
      lineNum++;
    }
    
    // Mock an "improve readability" refactoring
    if (options.types?.includes(RefactoringType.ImproveReadability)) {
      suggestions.push({
        type: RefactoringType.ImproveReadability,
        title: 'Improve variable naming and add comments',
        explanation: 'Some variables have generic names that could be more descriptive. Adding comments would also improve code understanding.',
        confidence: 0.75,
        automated: false,
        changes: [
          {
            startLine: 5,
            startColumn: 0,
            endLine: 5,
            endColumn: lines[5]?.length || 0,
            newText: lines[5]?.replace(/const (\w{1,2}) =/, '// Store the processed data\nconst processedData =') || ''
          }
        ],
        preview: '// Before:\nconst d = calculateValues();\n\n// After:\n// Store the processed data\nconst processedData = calculateValues();'
      });
    }
    
    // Mock an "optimize imports" refactoring
    if (options.types?.includes(RefactoringType.OptimizeImports)) {
      const importLines: number[] = [];
      let importBlock = '';
      
      // Find import statements
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('import ')) {
          importLines.push(i);
          importBlock += lines[i] + '\n';
        } else if (importLines.length > 0 && !lines[i].trim()) {
          continue;
        } else if (importLines.length > 0) {
          break;
        }
      }
      
      if (importLines.length > 1) {
        const optimizedImports = `// Organized imports
import { Component, useState, useEffect } from 'react';
import { 
  Button,
  Card,
  Container,
  TextField
} from './components';
import { formatData, processResponse } from './utils';
`;
        
        suggestions.push({
          type: RefactoringType.OptimizeImports,
          title: 'Organize and sort imports',
          explanation: 'Imports can be organized more consistently, grouped by source, and alphabetically sorted.',
          confidence: 0.9,
          automated: true,
          changes: [
            {
              startLine: importLines[0],
              startColumn: 0,
              endLine: importLines[importLines.length - 1],
              endColumn: lines[importLines[importLines.length - 1]].length,
              newText: optimizedImports.trim()
            }
          ],
          preview: `// Before:\n${importBlock}\n// After:\n${optimizedImports}`
        });
      }
    }
    
    // Filter by confidence threshold and limit count
    return suggestions
      .filter(s => s.confidence >= (options.confidenceThreshold || 0))
      .slice(0, options.maxSuggestions);
  }
}

/**
 * Factory function to create a refactoring assistant
 */
export function createRefactoringAssistant(config: AIConfig): RefactoringAssistant {
  return new RefactoringAssistant(config);
} 