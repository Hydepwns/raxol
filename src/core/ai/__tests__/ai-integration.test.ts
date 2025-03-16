/**
 * AI Integration Module Tests
 * 
 * Unit tests for the AI integration module in Raxol.
 */

// @ts-ignore - Jest globals
import { jest, describe, test, expect, beforeEach } from '@jest/globals';
import { 
  aiManager, 
  createCodeCompletion, 
  createRefactoringAssistant, 
  createPerformanceAdvisor,
  createAccessibilityChecker,
  RefactoringType,
  PerformanceIssueType,
  AccessibilityIssueType,
  ComplianceLevel
} from '../index';

// Mock implementations for testing
jest.mock('../assistant/CodeCompletion', () => ({
  createCodeCompletion: jest.fn().mockImplementation(() => ({
    initialize: jest.fn().mockResolvedValue(true),
    getSuggestions: jest.fn().mockResolvedValue([])
  }))
}));

jest.mock('../assistant/RefactoringAssistant', () => ({
  RefactoringType: {
    ExtractFunction: 'extract-function'
  },
  createRefactoringAssistant: jest.fn().mockImplementation(() => ({
    initialize: jest.fn().mockResolvedValue(true),
    getSuggestions: jest.fn().mockResolvedValue([])
  }))
}));

jest.mock('../assistant/PerformanceAdvisor', () => ({
  PerformanceIssueType: {
    Rendering: 'rendering'
  },
  createPerformanceAdvisor: jest.fn().mockImplementation(() => ({
    initialize: jest.fn().mockResolvedValue(true),
    analyzeCode: jest.fn().mockResolvedValue([])
  }))
}));

jest.mock('../assistant/AccessibilityChecker', () => ({
  ComplianceLevel: {
    A: 'A',
    AA: 'AA',
    AAA: 'AAA'
  },
  AccessibilityIssueType: {
    MissingAltText: 'missing-alt-text'
  },
  createAccessibilityChecker: jest.fn().mockImplementation(() => ({
    initialize: jest.fn().mockResolvedValue(true),
    checkAccessibility: jest.fn().mockResolvedValue([])
  }))
}));

describe('AI Integration Module', () => {
  beforeEach(() => {
    // Reset AI manager before each test
    aiManager.updateConfig({
      enabled: true,
      model: {
        name: 'test-model',
        parameters: {
          temperature: 0.3
        }
      }
    });
  });

  describe('AIManager', () => {
    test('should initialize successfully', async () => {
      const result = await aiManager.initialize();
      expect(result).toBe(true);
      expect(aiManager.isAvailable()).toBe(true);
    });

    test('should update configuration', () => {
      aiManager.updateConfig({
        enabled: false,
        model: {
          name: 'updated-model'
        }
      });
      
      const config = aiManager.getConfig();
      expect(config.enabled).toBe(false);
      expect(config.model?.name).toBe('updated-model');
    });
  });

  describe('Code Completion', () => {
    test('should create code completion service', async () => {
      const codeCompletion = createCodeCompletion(aiManager.getConfig());
      await codeCompletion.initialize();
      
      const suggestions = await codeCompletion.getSuggestions({
        fileContent: 'function test() {\n  // TODO: implement\n}',
        filePath: 'test.ts',
        cursorPosition: { line: 1, column: 18 }
      });
      
      expect(Array.isArray(suggestions)).toBe(true);
    });
  });

  describe('Refactoring Assistant', () => {
    test('should create refactoring assistant', async () => {
      const refactoring = createRefactoringAssistant(aiManager.getConfig());
      await refactoring.initialize();
      
      const suggestions = await refactoring.getSuggestions({
        fileContent: 'function longFunction() {\n  const a = 1;\n  const b = 2;\n  return a + b;\n}',
        filePath: 'test.ts',
        cursorPosition: { line: 1, column: 0 }
      });
      
      expect(Array.isArray(suggestions)).toBe(true);
    });
  });

  describe('Performance Advisor', () => {
    test('should create performance advisor', async () => {
      const performanceAdvisor = createPerformanceAdvisor(aiManager.getConfig());
      await performanceAdvisor.initialize();
      
      const issues = await performanceAdvisor.analyzeCode({
        fileContent: 'function render() {\n  const items = [];\n  for (let i = 0; i < 1000; i++) {\n    items.push(<div key={i}>{i}</div>);\n  }\n  return items;\n}',
        filePath: 'Component.jsx',
        cursorPosition: { line: 0, column: 0 }
      });
      
      expect(Array.isArray(issues)).toBe(true);
    });
  });

  describe('Accessibility Checker', () => {
    test('should create accessibility checker', async () => {
      const accessibilityChecker = createAccessibilityChecker(aiManager.getConfig());
      await accessibilityChecker.initialize();
      
      const issues = await accessibilityChecker.checkAccessibility({
        fileContent: '<div onClick={() => alert("clicked")}>Click me</div>\n<img src="image.png" />',
        filePath: 'Component.jsx',
        cursorPosition: { line: 0, column: 0 }
      });
      
      expect(Array.isArray(issues)).toBe(true);
    });
  });
}); 