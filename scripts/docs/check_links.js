#!/usr/bin/env node

/**
 * This script checks for broken links in the documentation.
 * It parses all markdown files in the docs directory and checks that all links are valid.
 */

const fs = require('fs');
const path = require('path');
const glob = require('glob');
const matter = require('gray-matter');

// Configuration
const DOCS_DIR = path.resolve(__dirname, '../../docs');
const EXCLUDED_DIRS = ['node_modules', '_build', 'deps'];
const EXCLUDED_FILES = ['package.json', 'package-lock.json'];

// Regular expressions for finding links
const LINK_REGEX = /\[([^\]]+)\]\(([^)]+)\)/g;
const ANCHOR_REGEX = /#([^#\s]+)/;

/**
 * Get all markdown files in the docs directory
 */
function getMarkdownFiles() {
  return glob.sync('**/*.md', {
    cwd: DOCS_DIR,
    ignore: EXCLUDED_DIRS.map(dir => `**/${dir}/**`).concat(EXCLUDED_FILES)
  });
}

/**
 * Parse a markdown file and extract all links
 */
function extractLinks(filePath) {
  const content = fs.readFileSync(path.join(DOCS_DIR, filePath), 'utf8');
  const { data, content: markdownContent } = matter(content);
  
  const links = [];
  let match;
  
  while ((match = LINK_REGEX.exec(markdownContent)) !== null) {
    const [, text, url] = match;
    links.push({ text, url, file: filePath });
  }
  
  return links;
}

/**
 * Check if a link is valid
 */
function isValidLink(link, allFiles) {
  const { url, file } = link;
  
  // Skip external links
  if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('//')) {
    return true;
  }
  
  // Handle anchor links
  const [filePath, anchor] = url.split('#');
  
  // If the URL is just an anchor, it's referring to the current file
  const targetFile = filePath ? path.join(path.dirname(file), filePath) : file;
  
  // Check if the file exists
  if (!allFiles.includes(targetFile)) {
    console.error(`Broken link in ${file}: ${url} (file not found)`);
    return false;
  }
  
  // If there's an anchor, check if it exists in the target file
  if (anchor) {
    const targetContent = fs.readFileSync(path.join(DOCS_DIR, targetFile), 'utf8');
    const { content } = matter(targetContent);
    
    // Look for headers that match the anchor
    const headerRegex = new RegExp(`^#{1,6}\\s+${anchor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'm');
    if (!headerRegex.test(content)) {
      console.error(`Broken link in ${file}: ${url} (anchor not found)`);
      return false;
    }
  }
  
  return true;
}

/**
 * Main function
 */
function main() {
  console.log('Checking for broken links in documentation...');
  
  const allFiles = getMarkdownFiles();
  const allLinks = allFiles.flatMap(extractLinks);
  
  let validLinks = 0;
  let brokenLinks = 0;
  
  allLinks.forEach(link => {
    if (isValidLink(link, allFiles)) {
      validLinks++;
    } else {
      brokenLinks++;
    }
  });
  
  console.log(`Found ${allLinks.length} links in documentation.`);
  console.log(`${validLinks} valid links, ${brokenLinks} broken links.`);
  
  if (brokenLinks > 0) {
    console.error('Documentation contains broken links. Please fix them before committing.');
    process.exit(1);
  } else {
    console.log('All documentation links are valid.');
    process.exit(0);
  }
}

main(); 