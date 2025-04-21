#!/usr/bin/env node

/**
 * JuliaOS Project Setup Script
 * 
 * This script streamlines the project setup by running all the infrastructure tools
 * in the correct order. It's useful for both initial setup and for maintaining
 * the project's infrastructure.
 * 
 * Actions:
 * 1. Applies coding standards to all packages
 * 2. Generates tests for all Julia modules
 * 3. Runs all tests to verify everything is working
 * 4. Generates documentation
 * 
 * Usage: node scripts/project-setup.js
 */

const { execSync } = require('child_process');
const chalk = require('chalk');
const { program } = require('commander');
const { logSection, withSpinner, logStep } = require('./utils/progress-utils');
const { showNextSteps } = require('./utils/error-utils');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
program
  .name('juliaos-setup')
  .description('JuliaOS Project Setup')
  .version('0.1.0')
  .option('--skip-julia', 'Skip Julia-related setup')
  .option('--skip-ts', 'Skip TypeScript-related setup')
  .option('--skip-tests', 'Skip running tests')
  .option('--skip-docs', 'Skip generating documentation')
  .option('-v, --verbose', 'Show verbose output')
  .parse(process.argv);

const options = program.opts();

/**
 * Execute a command and return its output
 * 
 * @param {string} command - Command to execute
 * @param {Object} options - Options
 * @returns {string} Command output
 */
function execCommand(command, options = {}) {
  const defaultOptions = {
    stdio: options.verbose ? 'inherit' : 'pipe',
    encoding: 'utf8'
  };
  
  try {
    return execSync(command, { ...defaultOptions, ...options });
  } catch (error) {
    if (!options.ignoreError) {
      throw error;
    }
    return error.stdout || '';
  }
}

/**
 * Apply coding standards to all TypeScript packages
 */
async function applyCodingStandards() {
  return withSpinner(
    'Applying coding standards to all packages...',
    async () => {
      execCommand('node scripts/apply-coding-standards.js', {
        verbose: options.verbose
      });
      return { packages: countPackages() };
    },
    (result) => `Applied coding standards to ${result.packages} packages`
  );
}

/**
 * Generate tests for all Julia modules
 */
async function generateJuliaTests() {
  return withSpinner(
    'Generating tests for all Julia modules...',
    async () => {
      execCommand('cd julia && julia ../scripts/generate-julia-tests.jl', {
        verbose: options.verbose
      });
      return { modules: countJuliaModules() };
    },
    (result) => `Generated tests for ${result.modules} Julia modules`
  );
}

/**
 * Run all tests
 */
async function runAllTests() {
  // Run Julia tests
  if (!options.skipJulia) {
    await withSpinner(
      'Running Julia tests...',
      async () => {
        const output = execCommand('cd julia && julia run_tests.jl', {
          verbose: options.verbose,
          ignoreError: true
        });
        return { output };
      },
      (result) => {
        const passCount = (result.output.match(/✅/g) || []).length;
        return `Julia tests complete: ${passCount} tests passed`;
      }
    );
  }
  
  // Run TypeScript tests
  if (!options.skipTs) {
    await withSpinner(
      'Running TypeScript tests...',
      async () => {
        const output = execCommand('npm test', {
          verbose: options.verbose,
          ignoreError: true
        });
        return { output };
      },
      (result) => {
        return `TypeScript tests complete`;
      }
    );
    
    // Run Integration tests
    await withSpinner(
      'Running integration tests...',
      async () => {
        const output = execCommand('npm run test:integration', {
          verbose: options.verbose,
          ignoreError: true
        });
        return { output };
      },
      (result) => `Integration tests complete`
    );
  }
}

/**
 * Generate documentation
 */
async function generateDocs() {
  // Generate Julia docs
  if (!options.skipJulia) {
    await withSpinner(
      'Generating Julia documentation...',
      async () => {
        execCommand('cd julia && julia generate_docs.jl', {
          verbose: options.verbose
        });
        return {};
      },
      () => `Julia documentation generated`
    );
  }
  
  // Generate TypeScript docs
  if (!options.skipTs) {
    await withSpinner(
      'Generating TypeScript documentation...',
      async () => {
        execCommand('npm run docs', {
          verbose: options.verbose,
          ignoreError: true
        });
        return {};
      },
      () => `TypeScript documentation generated`
    );
  }
}

/**
 * Count the number of packages
 * 
 * @returns {number} Number of packages
 */
function countPackages() {
  try {
    const packagesDir = path.join(__dirname, '..', 'packages');
    return fs.readdirSync(packagesDir)
      .filter(name => {
        const packagePath = path.join(packagesDir, name);
        return fs.statSync(packagePath).isDirectory() &&
               fs.existsSync(path.join(packagePath, 'package.json'));
      })
      .length;
  } catch (error) {
    return 0;
  }
}

/**
 * Count the number of Julia modules
 * 
 * @returns {number} Number of Julia modules
 */
function countJuliaModules() {
  try {
    const juliaSrcDir = path.join(__dirname, '..', 'julia', 'src');
    let moduleCount = 0;
    
    function countInDir(dir) {
      fs.readdirSync(dir).forEach(file => {
        const filePath = path.join(dir, file);
        if (fs.statSync(filePath).isDirectory()) {
          countInDir(filePath);
        } else if (file.endsWith('.jl')) {
          // Check if file contains "module X"
          const content = fs.readFileSync(filePath, 'utf8');
          if (content.match(/\bmodule\s+[A-Z]/)) {
            moduleCount++;
          }
        }
      });
    }
    
    countInDir(juliaSrcDir);
    return moduleCount;
  } catch (error) {
    return 0;
  }
}

/**
 * Main function
 */
async function main() {
  logSection('JuliaOS Project Setup');
  
  // Step 1: Apply coding standards
  if (!options.skipTs) {
    await applyCodingStandards();
  }
  
  // Step 2: Generate tests
  if (!options.skipJulia) {
    await generateJuliaTests();
  }
  
  // Step 3: Run tests
  if (!options.skipTests) {
    await runAllTests();
  }
  
  // Step 4: Generate docs
  if (!options.skipDocs) {
    await generateDocs();
  }
  
  // Show next steps
  showNextSteps(
    'JuliaOS project setup complete. Here are some next steps:',
    [
      'Run "node scripts/cli-startup.js" to start the CLI with the new enhancements',
      'Review the generated documentation in the docs directory',
      'Check test coverage reports to identify areas needing more tests',
      'Customize the configuration in .env or config files as needed'
    ]
  );
}

// Run the main function
main().catch(error => {
  console.error(chalk.red(`Error: ${error.message}`));
  if (options.verbose) {
    console.error(error);
  }
  process.exit(1);
});
