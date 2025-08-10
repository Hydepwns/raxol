#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Create VSIX package manually since vsce has compatibility issues
console.log('Creating VSIX package manually...');

try {
    // Remove any existing .vsix files
    execSync('rm -f *.vsix', { stdio: 'inherit' });

    // Create temporary directory structure
    console.log('Creating package structure...');
    
    // Read package.json to get extension info
    const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    const extensionName = `${packageJson.name}-${packageJson.version}.vsix`;
    
    console.log(`Packaging as: ${extensionName}`);
    
    // Create the zip file with correct structure
    const filesToInclude = [
        'package.json',
        'README.md',
        'CHANGELOG.md', 
        'LICENSE',
        'language-configuration.json',
        'out/',
        'snippets/',
        'syntaxes/'
    ];
    
    // Build the zip command
    let zipCommand = 'zip -r ' + extensionName;
    
    for (const file of filesToInclude) {
        if (fs.existsSync(file)) {
            zipCommand += ` "${file}"`;
        } else {
            console.log(`Warning: ${file} does not exist, skipping...`);
        }
    }
    
    // Exclude files based on .vscodeignore
    zipCommand += ' -x "*.map" "src/*" "node_modules/*" ".git/*" "*.log" "*.vsix"';
    
    console.log('Running zip command...');
    execSync(zipCommand, { stdio: 'inherit' });
    
    console.log(`✅ Successfully created ${extensionName}`);
    console.log(`Package size: ${(fs.statSync(extensionName).size / 1024).toFixed(1)} KB`);
    
} catch (error) {
    console.error('❌ Error creating VSIX package:', error.message);
    process.exit(1);
}