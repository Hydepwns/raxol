/**
 * AI Integration Demo
 * 
 * This file demonstrates the usage of the AI integration features in Raxol.
 * 
 * Run with: npx ts-node src/core/ai/demo.ts
 */

import { aiManager } from './index';
import { createCodeCompletion } from './assistant/CodeCompletion';
import { createRefactoringAssistant, RefactoringType } from './assistant/RefactoringAssistant';
import { createPerformanceAdvisor, PerformanceIssueType, IssueSeverity } from './assistant/PerformanceAdvisor';
import { createAccessibilityChecker, AccessibilityIssueType, ComplianceLevel, ImpactLevel } from './assistant/AccessibilityChecker';

// Sample code for demonstrations
const sampleComponentCode = `
import React, { useState, useEffect } from 'react';

function DataTable({ data }) {
  const [sortedData, setSortedData] = useState([]);
  const [sortField, setSortField] = useState(null);
  const [sortDirection, setSortDirection] = useState('asc');

  useEffect(() => {
    // Subscribe to data updates
    const subscription = dataService.subscribe(newData => {
      updateData(newData);
    });
    
    // Missing cleanup function
  }, []);

  const updateData = (newData) => {
    // Sort data on each update
    const d = [...newData].sort((a, b) => {
      if (!sortField) return 0;
      return sortDirection === 'asc' 
        ? a[sortField] > b[sortField] ? 1 : -1
        : a[sortField] < b[sortField] ? 1 : -1;
    });
    setSortedData(d);
  };

  const handleSort = (field) => {
    if (field === sortField) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  const renderRows = () => {
    return sortedData.map(item => (
      <tr key={item.id}>
        <td>{item.name}</td>
        <td>{item.value}</td>
        <td>{item.date}</td>
      </tr>
    ));
  };

  return (
    <div className="data-table-container">
      <table>
        <thead>
          <tr>
            <th onClick={() => handleSort('name')}>Name</th>
            <th onClick={() => handleSort('value')}>Value</th>
            <th onClick={() => handleSort('date')}>Date</th>
          </tr>
        </thead>
        <tbody>
          {renderRows()}
        </tbody>
      </table>
      <div onClick={() => console.log('Export clicked')}>
        Export Data
      </div>
      <img src="/images/info.png" />
    </div>
  );
}

export default DataTable;
`;

/**
 * Main demo function
 */
async function runDemo() {
  console.log('🤖 AI Integration Demo');
  console.log('=====================\n');
  
  // Initialize the AI manager
  console.log('Initializing AI services...');
  await aiManager.updateConfig({
    enabled: true,
    model: {
      name: 'demo-model',
      parameters: {
        temperature: 0.3
      }
    }
  });
  
  await aiManager.initialize();
  
  if (!aiManager.isAvailable()) {
    console.log('❌ AI services are not available. Please check your configuration.');
    return;
  }
  
  console.log('✅ AI services initialized successfully\n');
  
  // Prepare code context
  const codeContext = {
    fileContent: sampleComponentCode,
    filePath: 'components/DataTable.jsx',
    cursorPosition: { line: 20, column: 10 }
  };
  
  // 1. Code Completion Demo
  await demoCodeCompletion(codeContext);
  
  // 2. Refactoring Assistant Demo
  await demoRefactoringAssistant(codeContext);
  
  // 3. Performance Advisor Demo
  await demoPerformanceAdvisor(codeContext);
  
  // 4. Accessibility Checker Demo
  await demoAccessibilityChecker(codeContext);
  
  console.log('\n🎉 Demo completed successfully!');
}

/**
 * Demonstrate code completion features
 */
async function demoCodeCompletion(codeContext) {
  console.log('\n📝 Code Completion Demo');
  console.log('---------------------');
  
  const codeCompletion = createCodeCompletion(aiManager.getConfig());
  await codeCompletion.initialize();
  
  console.log('Getting code suggestions...');
  const suggestions = await codeCompletion.getSuggestions(codeContext);
  
  console.log(`Received ${suggestions.length} suggestions:`);
  suggestions.forEach((suggestion, index) => {
    console.log(`\nSuggestion #${index + 1} (${suggestion.type}) - Confidence: ${suggestion.confidence}:`);
    console.log('```');
    console.log(suggestion.text.length > 100 
      ? suggestion.text.substring(0, 100) + '...' 
      : suggestion.text);
    console.log('```');
  });
}

/**
 * Demonstrate refactoring assistant features
 */
async function demoRefactoringAssistant(codeContext) {
  console.log('\n🔄 Refactoring Assistant Demo');
  console.log('----------------------------');
  
  const refactoring = createRefactoringAssistant(aiManager.getConfig());
  await refactoring.initialize();
  
  console.log('Analyzing code for refactoring opportunities...');
  const suggestions = await refactoring.getSuggestions(codeContext, {
    types: [
      RefactoringType.ExtractFunction,
      RefactoringType.ImproveReadability,
      RefactoringType.OptimizeImports
    ]
  });
  
  console.log(`Found ${suggestions.length} refactoring suggestions:`);
  suggestions.forEach((suggestion, index) => {
    console.log(`\n${index + 1}. ${suggestion.title} (${suggestion.type})`);
    console.log(`   Confidence: ${suggestion.confidence}, Can auto-fix: ${suggestion.automated}`);
    console.log(`   ${suggestion.explanation}`);
    
    if (suggestion.preview) {
      console.log('\n   Preview (excerpt):');
      const previewLines = suggestion.preview.split('\n');
      const shortPreview = previewLines.length > 5 
        ? previewLines.slice(0, 5).join('\n') + '\n   ...' 
        : suggestion.preview;
      console.log(`   ${shortPreview}`);
    }
  });
  
  // Apply a refactoring if available
  if (suggestions.length > 0) {
    console.log('\nApplying the first refactoring suggestion...');
    const refactoredCode = await refactoring.applyRefactoring(codeContext, suggestions[0]);
    
    if (refactoredCode) {
      console.log('✅ Successfully applied refactoring');
      console.log('\nRefactored code (excerpt):');
      console.log('```');
      console.log(refactoredCode.split('\n').slice(0, 10).join('\n') + '\n...');
      console.log('```');
    } else {
      console.log('❌ Failed to apply refactoring');
    }
  }
}

/**
 * Demonstrate performance advisor features
 */
async function demoPerformanceAdvisor(codeContext) {
  console.log('\n⚡ Performance Advisor Demo');
  console.log('--------------------------');
  
  const performanceAdvisor = createPerformanceAdvisor(aiManager.getConfig());
  await performanceAdvisor.initialize();
  
  console.log('Analyzing code for performance issues...');
  const issues = await performanceAdvisor.analyzeCode(codeContext, {
    issueTypes: [PerformanceIssueType.Rendering, PerformanceIssueType.MemoryLeaks],
    minSeverity: IssueSeverity.Medium
  });
  
  console.log(`Found ${issues.length} performance issues:`);
  issues.forEach((issue, index) => {
    console.log(`\n${index + 1}. ${issue.description} (${issue.type})`);
    console.log(`   Severity: ${issue.severity}, Lines: ${issue.lines.startLine}-${issue.lines.endLine}`);
    console.log(`   Estimated improvement: ${issue.estimatedImprovement ?? 'Unknown'}%`);
    
    if (issue.suggestions.length > 0) {
      console.log('\n   Suggestions:');
      issue.suggestions.forEach((suggestion, i) => {
        console.log(`   ${i + 1}. ${suggestion.title} (Confidence: ${suggestion.confidence})`);
        console.log(`      ${suggestion.explanation}`);
      });
    }
  });
  
  // Apply a performance suggestion if available
  if (issues.length > 0 && issues[0].suggestions.length > 0) {
    console.log('\nApplying the first performance suggestion...');
    const optimizedCode = await performanceAdvisor.applySuggestion(
      codeContext,
      issues[0],
      0
    );
    
    if (optimizedCode) {
      console.log('✅ Successfully applied performance optimization');
      console.log('\nOptimized code (excerpt):');
      console.log('```');
      console.log(optimizedCode.split('\n').slice(0, 10).join('\n') + '\n...');
      console.log('```');
    } else {
      console.log('❌ Failed to apply performance optimization');
    }
  }
}

/**
 * Demonstrate accessibility checker features
 */
async function demoAccessibilityChecker(codeContext) {
  console.log('\n♿ Accessibility Checker Demo');
  console.log('----------------------------');
  
  const accessibilityChecker = createAccessibilityChecker(aiManager.getConfig());
  await accessibilityChecker.initialize();
  
  console.log('Checking code for accessibility issues...');
  const issues = await accessibilityChecker.checkAccessibility(codeContext, {
    issueTypes: [
      AccessibilityIssueType.MissingAltText,
      AccessibilityIssueType.KeyboardNavigation,
      AccessibilityIssueType.FormLabels
    ],
    minComplianceLevel: ComplianceLevel.AA,
    minImpactLevel: ImpactLevel.Moderate
  });
  
  console.log(`Found ${issues.length} accessibility issues:`);
  issues.forEach((issue, index) => {
    console.log(`\n${index + 1}. ${issue.description} (${issue.type})`);
    console.log(`   Impact: ${issue.impact}, Compliance Level: ${issue.complianceLevel}`);
    console.log(`   WCAG Criteria: ${issue.wcagCriteria.join(', ')}`);
    
    if (issue.suggestions.length > 0) {
      console.log('\n   Suggestions:');
      issue.suggestions.forEach((suggestion, i) => {
        console.log(`   ${i + 1}. ${suggestion.title}`);
        console.log(`      ${suggestion.explanation}`);
      });
    }
  });
  
  // Apply an accessibility fix if available
  if (issues.length > 0 && issues[0].suggestions.length > 0) {
    console.log('\nApplying the first accessibility fix...');
    const fixedCode = await accessibilityChecker.applyFix(
      codeContext,
      issues[0],
      0
    );
    
    if (fixedCode) {
      console.log('✅ Successfully applied accessibility fix');
      console.log('\nFixed code (excerpt):');
      console.log('```');
      console.log(fixedCode.split('\n').slice(0, 10).join('\n') + '\n...');
      console.log('```');
    } else {
      console.log('❌ Failed to apply accessibility fix');
    }
  }
}

// Run the demo
runDemo().catch(error => {
  console.error('Error running AI integration demo:', error);
}); 