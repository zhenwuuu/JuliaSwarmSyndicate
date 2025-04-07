#!/usr/bin/env node

/**
 * This script helps update import paths after the directory reorganization.
 * It scans files and can replace old import paths with new ones.
 * 
 * Usage: node scripts/update-imports.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Path mappings (old -> new)
const pathMappings = [
  { from: '../typechain-types', to: '@tests/contracts/typechain-types' },
  { from: '../../packages', to: '@juliaos' },
  { from: '../wallets/common/src/types', to: '@juliaos/wallets-common/types' },
  { from: '../../wallets/common/src/types', to: '@juliaos/wallets-common/types' },
  { from: '../packages/core', to: '@juliaos/core' },
];

// Extensions to process
const extensions = ['.ts', '.tsx', '.js', '.jsx'];

// Get a list of all TypeScript/JavaScript files recursively
function getAllFiles(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      // Skip node_modules and dist directories
      if (file !== 'node_modules' && file !== 'dist' && file !== '.git') {
        getAllFiles(filePath, fileList);
      }
    } else if (extensions.includes(path.extname(file))) {
      fileList.push(filePath);
    }
  });
  
  return fileList;
}

// Process a file to update import paths
function processFile(filePath) {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let updated = false;
    
    // Look for import statements
    const importRegex = /import\s+(?:(?:{[^}]*}|\*\s+as\s+[^;]+)\s+from\s+)?['"]([^'"]+)['"]/g;
    
    // Replace old paths with new paths
    content = content.replace(importRegex, (match, importPath) => {
      for (const mapping of pathMappings) {
        if (importPath.includes(mapping.from)) {
          updated = true;
          const newPath = importPath.replace(mapping.from, mapping.to);
          return match.replace(importPath, newPath);
        }
      }
      return match;
    });
    
    // Write updated content back to file if changes were made
    if (updated) {
      fs.writeFileSync(filePath, content, 'utf8');
      console.log(`Updated imports in: ${filePath}`);
    }
  } catch (error) {
    console.error(`Error processing file ${filePath}:`, error);
  }
}

// Main function
function main() {
  console.log('Updating import paths after directory reorganization...');
  
  // Get all TypeScript/JavaScript files
  const files = getAllFiles('.');
  
  // Process each file
  let filesUpdated = 0;
  for (const file of files) {
    processFile(file);
    filesUpdated++;
    
    // Show progress for large codebases
    if (filesUpdated % 100 === 0) {
      console.log(`Processed ${filesUpdated} files...`);
    }
  }
  
  console.log(`Import path update complete. Processed ${filesUpdated} files.`);
  console.log('You may need to manually check and fix any remaining import issues.');
}

// Run the main function
main(); 