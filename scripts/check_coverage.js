#!/usr/bin/env node

/**
 * This script checks test coverage and ensures it meets the required threshold.
 * It parses the Jest coverage report and checks if the coverage meets the threshold.
 */

const fs = require('fs');
const path = require('path');

// Configuration
const COVERAGE_THRESHOLD = 80; // 80% coverage threshold
const COVERAGE_REPORT_PATH = path.resolve(__dirname, '../coverage/coverage-final.json');

/**
 * Parse the Jest coverage report
 */
function parseCoverageReport() {
  try {
    const coverageData = JSON.parse(fs.readFileSync(COVERAGE_REPORT_PATH, 'utf8'));
    return coverageData;
  } catch (error) {
    console.error('Error parsing coverage report:', error.message);
    console.error('Make sure you have run the tests with coverage enabled: npm run test:coverage');
    process.exit(1);
  }
}

/**
 * Calculate coverage percentage for a file
 */
function calculateFileCoverage(fileData) {
  const statements = Object.values(fileData.s);
  const coveredStatements = statements.filter(value => value > 0).length;
  const totalStatements = statements.length;
  
  return {
    statements: (coveredStatements / totalStatements) * 100,
    totalStatements,
    coveredStatements
  };
}

/**
 * Calculate overall coverage
 */
function calculateOverallCoverage(coverageData) {
  let totalStatements = 0;
  let coveredStatements = 0;
  
  Object.values(coverageData).forEach(fileData => {
    const fileCoverage = calculateFileCoverage(fileData);
    totalStatements += fileCoverage.totalStatements;
    coveredStatements += fileCoverage.coveredStatements;
  });
  
  return {
    statements: (coveredStatements / totalStatements) * 100,
    totalStatements,
    coveredStatements
  };
}

/**
 * Check if coverage meets the threshold
 */
function checkCoverageThreshold(coverage) {
  return coverage.statements >= COVERAGE_THRESHOLD;
}

/**
 * Find files with low coverage
 */
function findLowCoverageFiles(coverageData) {
  const lowCoverageFiles = [];
  
  Object.entries(coverageData).forEach(([filePath, fileData]) => {
    const fileCoverage = calculateFileCoverage(fileData);
    
    if (fileCoverage.statements < COVERAGE_THRESHOLD) {
      lowCoverageFiles.push({
        filePath,
        coverage: fileCoverage.statements,
        threshold: COVERAGE_THRESHOLD
      });
    }
  });
  
  return lowCoverageFiles;
}

/**
 * Main function
 */
function main() {
  console.log(`Checking test coverage (threshold: ${COVERAGE_THRESHOLD}%)...`);
  
  const coverageData = parseCoverageReport();
  const overallCoverage = calculateOverallCoverage(coverageData);
  const meetsThreshold = checkCoverageThreshold(overallCoverage);
  
  console.log(`Overall coverage: ${overallCoverage.statements.toFixed(2)}%`);
  console.log(`Covered statements: ${overallCoverage.coveredStatements} / ${overallCoverage.totalStatements}`);
  
  if (!meetsThreshold) {
    console.error(`Coverage is below the required threshold of ${COVERAGE_THRESHOLD}%`);
    
    const lowCoverageFiles = findLowCoverageFiles(coverageData);
    console.error(`Found ${lowCoverageFiles.length} files with coverage below the threshold:`);
    
    lowCoverageFiles.forEach(file => {
      console.error(`  - ${file.filePath}: ${file.coverage.toFixed(2)}% (threshold: ${file.threshold}%)`);
    });
    
    process.exit(1);
  } else {
    console.log(`Coverage meets the required threshold of ${COVERAGE_THRESHOLD}%`);
    process.exit(0);
  }
}

main(); 