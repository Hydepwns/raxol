const fs = require('fs');
const path = require('path');
const matter = require('gray-matter');

// Configuration
const DOCS_DIR = path.join(__dirname, '../../docs');
const SEARCH_INDEX_FILE = path.join(DOCS_DIR, 'search-index.json');

// Generate search index
function generateSearchIndex() {
  const files = fs.readdirSync(DOCS_DIR)
    .filter(file => file.endsWith('.md'));

  const searchIndex = files.map(file => {
    const content = fs.readFileSync(path.join(DOCS_DIR, file), 'utf8');
    const { data, content: markdownContent } = matter(content);
    
    // Extract headings
    const headings = markdownContent
      .split('\n')
      .filter(line => line.startsWith('#'))
      .map(line => ({
        level: line.match(/^#+/)[0].length,
        text: line.replace(/^#+\s*/, '').trim()
      }));

    // Extract code blocks
    const codeBlocks = markdownContent
      .split('```')
      .filter((_, index) => index % 2 === 1)
      .map(code => code.trim());

    return {
      file,
      title: data.title || file,
      description: data.description || '',
      date: data.date || '',
      author: data.author || '',
      section: data.section || 'uncategorized',
      headings,
      codeBlocks,
      tags: data.tags || [],
      searchText: markdownContent
        .replace(/```[\s\S]*?```/g, '') // Remove code blocks
        .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1') // Remove link URLs
        .replace(/[#*_`]/g, '') // Remove markdown syntax
        .toLowerCase()
    };
  });

  return searchIndex;
}

// Generate search suggestions
function generateSearchSuggestions(searchIndex) {
  const suggestions = new Set();
  
  searchIndex.forEach(doc => {
    // Add titles
    suggestions.add(doc.title.toLowerCase());
    
    // Add headings
    doc.headings.forEach(heading => {
      suggestions.add(heading.text.toLowerCase());
    });
    
    // Add tags
    doc.tags.forEach(tag => {
      suggestions.add(tag.toLowerCase());
    });
  });

  return Array.from(suggestions).sort();
}

// Main execution
function main() {
  console.log('Generating documentation search index...');
  
  const searchIndex = generateSearchIndex();
  const suggestions = generateSearchSuggestions(searchIndex);
  
  const searchData = {
    index: searchIndex,
    suggestions,
    lastUpdated: new Date().toISOString()
  };
  
  fs.writeFileSync(SEARCH_INDEX_FILE, JSON.stringify(searchData, null, 2));
  console.log(`Search index generated with ${searchIndex.length} documents and ${suggestions.length} suggestions`);
}

main(); 