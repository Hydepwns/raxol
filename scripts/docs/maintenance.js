const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

// Configuration
const ROOT_DIR = path.join(__dirname, '../..');
const DOCS_DIR = path.join(ROOT_DIR, 'docs');
const REQUIRED_SECTIONS = ['title', 'description', 'date', 'author'];
const REQUIRED_FILES = ['README.md', 'CONTRIBUTING.md', 'CHANGELOG.md'];

// Get all markdown files recursively
function getMarkdownFiles(dir) {
  let results = [];
  const items = fs.readdirSync(dir);

  items.forEach(item => {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);

    if (stat.isDirectory() && !item.startsWith('.') && !item.startsWith('_') && item !== 'node_modules') {
      results = results.concat(getMarkdownFiles(fullPath));
    } else if (item.endsWith('.md')) {
      results.push(fullPath);
    }
  });

  return results;
}

// Validate markdown files
function validateMarkdownFiles() {
  const files = getMarkdownFiles(ROOT_DIR);

  files.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    const { data } = matter(content);
    const relativePath = path.relative(ROOT_DIR, file);

    // Check required frontmatter for files in docs directory
    if (file.startsWith(DOCS_DIR)) {
      REQUIRED_SECTIONS.forEach(section => {
        if (!data[section]) {
          console.error(`Missing required section '${section}' in ${relativePath}`);
        }
      });
    }

    // Check for broken links
    const links = content.match(/\[([^\]]+)\]\(([^)]+)\)/g) || [];
    links.forEach(link => {
      const url = link.match(/\(([^)]+)\)/)[1];
      if (!url.startsWith('http') && !url.startsWith('#') && !url.startsWith('/')) {
        const linkPath = path.join(path.dirname(file), url);
        if (!fs.existsSync(linkPath)) {
          console.error(`Broken link in ${relativePath}: ${url}`);
        }
      }
    });
  });
}

// Ensure required documentation files exist
function ensureRequiredFiles() {
  REQUIRED_FILES.forEach(file => {
    const filePath = path.join(DOCS_DIR, file);
    if (!fs.existsSync(filePath)) {
      console.error(`Missing required file: ${file}`);
    }
  });
}

// Generate documentation metrics
function generateMetrics() {
  const files = getMarkdownFiles(DOCS_DIR);
  
  const metrics = {
    totalFiles: files.length,
    totalWords: 0,
    totalCodeBlocks: 0,
    filesBySection: {}
  };

  files.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    const { data } = matter(content);
    
    // Count words
    const words = content.split(/\s+/).length;
    metrics.totalWords += words;
    
    // Count code blocks
    const codeBlocks = (content.match(/```/g) || []).length / 2;
    metrics.totalCodeBlocks += codeBlocks;
    
    // Group by section
    const section = data.section || 'uncategorized';
    metrics.filesBySection[section] = (metrics.filesBySection[section] || 0) + 1;
  });

  return metrics;
}

// Main execution
function main() {
  console.log('Running documentation maintenance...');
  
  console.log('\nValidating markdown files...');
  validateMarkdownFiles();
  
  console.log('\nChecking required files...');
  ensureRequiredFiles();
  
  console.log('\nGenerating metrics...');
  const metrics = generateMetrics();
  console.log('Documentation Metrics:');
  console.log(JSON.stringify(metrics, null, 2));
}

main(); 