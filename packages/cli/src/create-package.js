#!/usr/bin/env node

/**
 * Script to create a new package in the JuliaOS monorepo
 * Usage: node scripts/create-package.js my-package "My Package Description"
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Get the package name and description from command line arguments
const packageName = process.argv[2];
const packageDescription = process.argv[3] || packageName;

if (!packageName) {
  console.error('Please provide a package name as an argument');
  console.error('Usage: node scripts/create-package.js my-package "My Package Description"');
  process.exit(1);
}

// Convert kebab-case to PascalCase for the folder name
const pascalCase = (str) => {
  return str
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
};

// Main package directory
const packageDir = path.join(__dirname, '..', 'packages', packageName);

// Create the package directory if it doesn't exist
if (!fs.existsSync(packageDir)) {
  fs.mkdirSync(packageDir, { recursive: true });
  console.log(`Created directory: ${packageDir}`);
} else {
  console.error(`Directory already exists: ${packageDir}`);
  process.exit(1);
}

// Create source directory
const srcDir = path.join(packageDir, 'src');
fs.mkdirSync(srcDir);
console.log(`Created directory: ${srcDir}`);

// Create test directory
const testDir = path.join(packageDir, 'test');
fs.mkdirSync(testDir);
console.log(`Created directory: ${testDir}`);

// Read package.json template
const templatePath = path.join(__dirname, '..', 'packages', 'config', 'package-template', 'package.json.template');
const packageTemplate = fs.readFileSync(templatePath, 'utf8');

// Replace placeholders in the template
const packageJson = packageTemplate
  .replace(/\[PACKAGE_NAME\]/g, packageName)
  .replace(/\[PACKAGE_DESCRIPTION\]/g, packageDescription);

// Write package.json
fs.writeFileSync(path.join(packageDir, 'package.json'), packageJson);
console.log(`Created file: ${path.join(packageDir, 'package.json')}`);

// Create tsconfig.json
const tsconfigContent = {
  "extends": "../../packages/config/typescript-config/base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"]
};

fs.writeFileSync(
  path.join(packageDir, 'tsconfig.json'),
  JSON.stringify(tsconfigContent, null, 2)
);
console.log(`Created file: ${path.join(packageDir, 'tsconfig.json')}`);

// Create tsconfig.test.json
const tsconfigTestContent = {
  "extends": "../../packages/config/typescript-config/test.json",
  "include": ["src/**/*", "test/**/*"]
};

fs.writeFileSync(
  path.join(packageDir, 'tsconfig.test.json'),
  JSON.stringify(tsconfigTestContent, null, 2)
);
console.log(`Created file: ${path.join(packageDir, 'tsconfig.test.json')}`);

// Create jest.config.js
const jestConfigContent = `module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  collectCoverage: true,
  coverageDirectory: 'coverage',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};
`;

fs.writeFileSync(path.join(packageDir, 'jest.config.js'), jestConfigContent);
console.log(`Created file: ${path.join(packageDir, 'jest.config.js')}`);

// Create .eslintrc.js
const eslintRcContent = `module.exports = {
  extends: ['../../packages/config/eslint-config'],
  parserOptions: {
    project: './tsconfig.json',
  },
};
`;

fs.writeFileSync(path.join(packageDir, '.eslintrc.js'), eslintRcContent);
console.log(`Created file: ${path.join(packageDir, '.eslintrc.js')}`);

// Create index.ts
const indexTsContent = `/**
 * @packageDocumentation
 * @module @juliaos/${packageName}
 */

/**
 * Primary export for the ${packageName} package
 */
export class ${pascalCase(packageName)} {
  /**
   * Creates a new instance
   */
  constructor() {
    console.log('${pascalCase(packageName)} initialized');
  }

  /**
   * Example method
   * @returns A greeting message
   */
  public greet(): string {
    return 'Hello from ${pascalCase(packageName)}!';
  }
}

// Export additional types and functions
export * from './types';
`;

fs.writeFileSync(path.join(srcDir, 'index.ts'), indexTsContent);
console.log(`Created file: ${path.join(srcDir, 'index.ts')}`);

// Create types.ts
const typesTsContent = `/**
 * Types for the ${packageName} package
 * @packageDocumentation
 * @module @juliaos/${packageName}
 */

/**
 * Configuration options for ${pascalCase(packageName)}
 */
export interface ${pascalCase(packageName)}Options {
  /** Optional configuration property */
  someProperty?: string;
}
`;

fs.writeFileSync(path.join(srcDir, 'types.ts'), typesTsContent);
console.log(`Created file: ${path.join(srcDir, 'types.ts')}`);

// Create a basic test file
const testFileContent = `/**
 * Tests for the ${packageName} package
 */
import { ${pascalCase(packageName)} } from '../src';

describe('${pascalCase(packageName)}', () => {
  it('should be instantiable', () => {
    const instance = new ${pascalCase(packageName)}();
    expect(instance).toBeInstanceOf(${pascalCase(packageName)});
  });

  it('should have a greet method that returns a string', () => {
    const instance = new ${pascalCase(packageName)}();
    expect(typeof instance.greet()).toBe('string');
    expect(instance.greet()).toContain('Hello from ${pascalCase(packageName)}');
  });
});
`;

fs.writeFileSync(path.join(testDir, `${packageName}.test.ts`), testFileContent);
console.log(`Created file: ${path.join(testDir, `${packageName}.test.ts`)}`);

// Create README.md
const readmeContent = `# @juliaos/${packageName}

${packageDescription}

## Installation

\`\`\`bash
npm install @juliaos/${packageName}
\`\`\`

## Usage

\`\`\`typescript
import { ${pascalCase(packageName)} } from '@juliaos/${packageName}';

const instance = new ${pascalCase(packageName)}();
console.log(instance.greet());
\`\`\`

## API Documentation

### \`${pascalCase(packageName)}\`

The main class exposed by this package.

#### Constructor

\`\`\`typescript
constructor();
\`\`\`

Creates a new instance of the ${pascalCase(packageName)} class.

#### Methods

##### \`greet()\`

\`\`\`typescript
greet(): string
\`\`\`

Returns a greeting message.

## License

MIT
`;

fs.writeFileSync(path.join(packageDir, 'README.md'), readmeContent);
console.log(`Created file: ${path.join(packageDir, 'README.md')}`);

// Update the root package.json to include the new package in workspaces
try {
  console.log('Adding package to workspaces in root package.json...');
  // We could use JSON parsing here, but let's use a more direct approach 
  // to preserve formatting and comments in the package.json
  execSync(`npm exec -- better-npm-workspaces add ${packageName}`, { stdio: 'inherit' });
} catch (error) {
  console.log('Could not automatically update workspaces in root package.json');
  console.log('Please add the new package to the workspaces field in the root package.json manually');
}

console.log(`\nPackage @juliaos/${packageName} has been created successfully!`);
console.log(`You can now cd into packages/${packageName} and start development.`);
console.log(`Run 'npm install' from the repository root to update dependencies.`);
