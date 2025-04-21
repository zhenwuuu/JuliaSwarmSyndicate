#!/usr/bin/env node

/**
 * Script to apply consistent coding standards across all packages
 * - Updates tsconfig.json files to extend from centralized configuration
 * - Creates or updates .eslintrc.js files to use shared config
 * - Adds necessary scripts to package.json files
 * 
 * Usage: node scripts/apply-coding-standards.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Paths
const rootDir = path.join(__dirname, '..');
const packagesDir = path.join(rootDir, 'packages');

// Template contents
const eslintrcTemplate = `module.exports = {
  extends: ['../../packages/config/eslint-config'],
  parserOptions: {
    project: './tsconfig.json',
  },
};
`;

const tsconfigTemplate = {
  extends: "../../packages/config/typescript-config/base.json",
  compilerOptions: {
    outDir: "./dist",
    rootDir: "./src"
  },
  include: ["src/**/*"]
};

const tsconfigTestTemplate = {
  extends: "../../packages/config/typescript-config/test.json",
  include: ["src/**/*", "test/**/*"]
};

// Scripts to add to package.json
const scriptsToAdd = {
  "lint": "eslint src --ext .ts,.tsx",
  "lint:fix": "eslint src --ext .ts,.tsx --fix",
  "typecheck": "tsc --noEmit",
  "test": "jest",
  "test:watch": "jest --watch",
  "build": "tsup src/index.ts --format cjs,esm --dts --clean",
  "dev": "tsup src/index.ts --format cjs,esm --dts --watch"
};

// Get all packages
function getPackages() {
  if (!fs.existsSync(packagesDir)) {
    console.error(`Packages directory not found: ${packagesDir}`);
    process.exit(1);
  }

  return fs.readdirSync(packagesDir)
    .filter(file => {
      const packageDir = path.join(packagesDir, file);
      const packageJsonPath = path.join(packageDir, 'package.json');
      return fs.statSync(packageDir).isDirectory() && 
             fs.existsSync(packageJsonPath) &&
             file !== 'config'; // Skip the config package itself
    });
}

// Update eslintrc.js
function updateEslintConfig(packageName) {
  const packageDir = path.join(packagesDir, packageName);
  const eslintrcPath = path.join(packageDir, '.eslintrc.js');
  
  fs.writeFileSync(eslintrcPath, eslintrcTemplate);
  console.log(`✅ Updated .eslintrc.js for ${packageName}`);
}

// Update tsconfig.json
function updateTsConfig(packageName) {
  const packageDir = path.join(packagesDir, packageName);
  const tsconfigPath = path.join(packageDir, 'tsconfig.json');
  const tsconfigTestPath = path.join(packageDir, 'tsconfig.test.json');
  
  fs.writeFileSync(tsconfigPath, JSON.stringify(tsconfigTemplate, null, 2));
  console.log(`✅ Updated tsconfig.json for ${packageName}`);
  
  fs.writeFileSync(tsconfigTestPath, JSON.stringify(tsconfigTestTemplate, null, 2));
  console.log(`✅ Updated tsconfig.test.json for ${packageName}`);
}

// Add script to package.json
function updatePackageJson(packageName) {
  const packageDir = path.join(packagesDir, packageName);
  const packageJsonPath = path.join(packageDir, 'package.json');
  
  if (!fs.existsSync(packageJsonPath)) {
    console.error(`package.json not found for ${packageName}`);
    return;
  }
  
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  
  // Ensure scripts object exists
  if (!packageJson.scripts) {
    packageJson.scripts = {};
  }
  
  // Add or update scripts
  let scriptsUpdated = false;
  for (const [scriptName, scriptCommand] of Object.entries(scriptsToAdd)) {
    if (!packageJson.scripts[scriptName]) {
      packageJson.scripts[scriptName] = scriptCommand;
      scriptsUpdated = true;
    }
  }
  
  // Add devDependencies if needed
  if (!packageJson.devDependencies) {
    packageJson.devDependencies = {};
  }
  
  // Ensure required devDependencies are added
  const devDepsToAdd = {
    "@juliaos/eslint-config": "workspace:*",
    "@juliaos/typescript-config": "workspace:*",
    "eslint": "^8.38.0",
    "typescript": "^5.0.4",
    "tsup": "^7.0.0"
  };
  
  let depsUpdated = false;
  for (const [depName, depVersion] of Object.entries(devDepsToAdd)) {
    if (!packageJson.devDependencies[depName]) {
      packageJson.devDependencies[depName] = depVersion;
      depsUpdated = true;
    }
  }
  
  // Add Jest dependencies if the package has tests
  const testDir = path.join(packageDir, 'test');
  if (fs.existsSync(testDir)) {
    const jestDeps = {
      "jest": "^29.5.0",
      "ts-jest": "^29.1.0",
      "@types/jest": "^29.5.0"
    };
    
    for (const [depName, depVersion] of Object.entries(jestDeps)) {
      if (!packageJson.devDependencies[depName]) {
        packageJson.devDependencies[depName] = depVersion;
        depsUpdated = true;
      }
    }
    
    // Add jest.config.js if it doesn't exist
    const jestConfigPath = path.join(packageDir, 'jest.config.js');
    if (!fs.existsSync(jestConfigPath)) {
      const jestConfigContent = `module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  collectCoverage: true,
  coverageDirectory: 'coverage',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};
`;
      fs.writeFileSync(jestConfigPath, jestConfigContent);
      console.log(`✅ Created jest.config.js for ${packageName}`);
    }
  }
  
  // Write package.json if changes were made
  if (scriptsUpdated || depsUpdated) {
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));
    console.log(`✅ Updated package.json for ${packageName}`);
  } else {
    console.log(`ℹ️ No changes needed for package.json in ${packageName}`);
  }
}

// Create or update README.md with standard template
function updateReadme(packageName) {
  const packageDir = path.join(packagesDir, packageName);
  const readmePath = path.join(packageDir, 'README.md');
  
  // Skip if README already exists and is not empty
  if (fs.existsSync(readmePath) && fs.statSync(readmePath).size > 100) {
    console.log(`ℹ️ README.md for ${packageName} already exists and appears to have content`);
    return;
  }
  
  // Read package.json to get description
  const packageJsonPath = path.join(packageDir, 'package.json');
  const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
  const description = packageJson.description || `JuliaOS ${packageName} package`;
  
  // Convert kebab-case to PascalCase
  const pascalCase = packageName
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
  
  const readmeContent = `# @juliaos/${packageName}

${description}

## Installation

\`\`\`bash
npm install @juliaos/${packageName}
\`\`\`

## Usage

\`\`\`typescript
import { ${pascalCase} } from '@juliaos/${packageName}';

// Example usage code
\`\`\`

## API Documentation

### Classes

#### \`${pascalCase}\`

Main class for ${packageName} functionality.

### Functions

(Document key functions here)

### Interfaces

(Document key interfaces here)

## License

MIT
`;

  fs.writeFileSync(readmePath, readmeContent);
  console.log(`✅ Updated README.md for ${packageName}`);
}

// Ensure src and test directories exist
function ensureDirectories(packageName) {
  const packageDir = path.join(packagesDir, packageName);
  const srcDir = path.join(packageDir, 'src');
  const testDir = path.join(packageDir, 'test');
  
  if (!fs.existsSync(srcDir)) {
    fs.mkdirSync(srcDir);
    console.log(`✅ Created src directory for ${packageName}`);
    
    // Create a placeholder index.ts if it doesn't exist
    const indexPath = path.join(srcDir, 'index.ts');
    if (!fs.existsSync(indexPath)) {
      const indexContent = `/**
 * ${packageName} module
 * @packageDocumentation
 */

/**
 * Main export class for ${packageName}
 */
export class ${packageName
  .split('-')
  .map(word => word.charAt(0).toUpperCase() + word.slice(1))
  .join('')} {
  /**
   * Constructor
   */
  constructor() {
    console.log('${packageName} initialized');
  }
}
`;
      fs.writeFileSync(indexPath, indexContent);
      console.log(`✅ Created placeholder index.ts for ${packageName}`);
    }
  }
  
  if (!fs.existsSync(testDir)) {
    fs.mkdirSync(testDir);
    console.log(`✅ Created test directory for ${packageName}`);
    
    // Create a placeholder test file
    const testFilePath = path.join(testDir, `${packageName}.test.ts`);
    if (!fs.existsSync(testFilePath)) {
      const className = packageName
        .split('-')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join('');
      
      const testContent = `import { ${className} } from '../src';

describe('${className}', () => {
  it('should be instantiable', () => {
    const instance = new ${className}();
    expect(instance).toBeDefined();
  });
});
`;
      fs.writeFileSync(testFilePath, testContent);
      console.log(`✅ Created placeholder test file for ${packageName}`);
    }
  }
}

// Install dependencies and run linting
function installAndLint() {
  console.log('\n📦 Installing dependencies...');
  try {
    execSync('npm install', { stdio: 'inherit', cwd: rootDir });
    console.log('✅ Dependencies installed successfully');
  } catch (error) {
    console.error('❌ Failed to install dependencies');
    console.error(error);
  }
  
  console.log('\n🧹 Running linting...');
  try {
    execSync('npm run lint', { stdio: 'inherit', cwd: rootDir });
    console.log('✅ Linting completed successfully');
  } catch (error) {
    console.error('❌ Linting failed, please fix the errors');
    console.error(error);
  }
}

// Main function
function main() {
  console.log('🔍 Finding packages...');
  const packages = getPackages();
  console.log(`Found ${packages.length} packages to update\n`);
  
  for (const packageName of packages) {
    console.log(`\n📦 Processing package: ${packageName}`);
    ensureDirectories(packageName);
    updateEslintConfig(packageName);
    updateTsConfig(packageName);
    updatePackageJson(packageName);
    updateReadme(packageName);
    console.log(`✅ Finished processing ${packageName}`);
  }
  
  console.log('\n🎉 All packages have been updated with consistent coding standards!');
  
  // Ask if user wants to install dependencies and run linting
  console.log('\nWould you like to install dependencies and run linting now? (y/n)');
  const { stdin, stdout } = process;
  stdin.resume();
  stdin.setEncoding('utf8');
  stdin.on('data', (data) => {
    const input = data.toString().trim().toLowerCase();
    if (input === 'y' || input === 'yes') {
      installAndLint();
    }
    process.exit(0);
  });
}

// Run main function
main();
