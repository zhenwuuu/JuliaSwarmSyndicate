import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';
import { z } from 'zod';

const writeFile = promisify(fs.writeFile);
const readFile = promisify(fs.readFile);

interface SetupConfig {
  juliaPath: string;
  projectPath: string;
  dependencies: {
    typescript: boolean;
    julia: boolean;
  };
  features: {
    trading: boolean;
    optimization: boolean;
    visualization: boolean;
  };
}

const SetupConfigSchema = z.object({
  juliaPath: z.string(),
  projectPath: z.string(),
  dependencies: z.object({
    typescript: z.boolean(),
    julia: z.boolean()
  }),
  features: z.object({
    trading: z.boolean(),
    optimization: z.boolean(),
    visualization: z.boolean()
  })
});

export class SetupCLI {
  private config: SetupConfig;

  constructor() {
    this.config = {
      juliaPath: '',
      projectPath: '',
      dependencies: {
        typescript: true,
        julia: true
      },
      features: {
        trading: true,
        optimization: true,
        visualization: true
      }
    };
  }

  async start(): Promise<void> {
    console.log('Welcome to JuliaOS Setup');
    console.log('=======================');

    try {
      // Check Julia installation
      await this.checkJuliaInstallation();

      // Get project path
      await this.getProjectPath();

      // Configure dependencies
      await this.configureDependencies();

      // Configure features
      await this.configureFeatures();

      // Create project structure
      await this.createProjectStructure();

      // Install dependencies
      await this.installDependencies();

      // Create configuration files
      await this.createConfigFiles();

      console.log('\nSetup completed successfully!');
      console.log('You can now start developing with JuliaOS.');
    } catch (error) {
      console.error('Setup failed:', error);
      process.exit(1);
    }
  }

  private async checkJuliaInstallation(): Promise<void> {
    try {
      const juliaVersion = execSync('julia --version').toString().trim();
      console.log(`Found Julia: ${juliaVersion}`);
      
      // Check if Julia is in PATH
      const juliaPath = execSync('which julia').toString().trim();
      this.config.juliaPath = juliaPath;
      console.log(`Julia path: ${juliaPath}`);
    } catch (error) {
      console.error('Julia is not installed or not in PATH');
      console.error('Please install Julia from https://julialang.org/downloads/');
      throw error;
    }
  }

  private async getProjectPath(): Promise<void> {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      readline.question('Enter project path (default: ./juliaos-project): ', (path: string) => {
        this.config.projectPath = path || './juliaos-project';
        readline.close();
        resolve();
      });
    });
  }

  private async configureDependencies(): Promise<void> {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      readline.question('Install TypeScript dependencies? (y/n): ', (answer: string) => {
        this.config.dependencies.typescript = answer.toLowerCase() === 'y';
        readline.question('Install Julia dependencies? (y/n): ', (answer: string) => {
          this.config.dependencies.julia = answer.toLowerCase() === 'y';
          readline.close();
          resolve();
        });
      });
    });
  }

  private async configureFeatures(): Promise<void> {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      readline.question('Enable trading features? (y/n): ', (answer: string) => {
        this.config.features.trading = answer.toLowerCase() === 'y';
        readline.question('Enable optimization features? (y/n): ', (answer: string) => {
          this.config.features.optimization = answer.toLowerCase() === 'y';
          readline.question('Enable visualization features? (y/n): ', (answer: string) => {
            this.config.features.visualization = answer.toLowerCase() === 'y';
            readline.close();
            resolve();
          });
        });
      });
    });
  }

  private async createProjectStructure(): Promise<void> {
    const dirs = [
      '',
      'src',
      'src/agents',
      'src/skills',
      'src/bridge',
      'src/utils',
      'julia',
      'julia/src',
      'julia/test',
      'config',
      'docs'
    ];

    for (const dir of dirs) {
      const fullPath = path.join(this.config.projectPath, dir);
      if (!fs.existsSync(fullPath)) {
        fs.mkdirSync(fullPath, { recursive: true });
      }
    }
  }

  private async installDependencies(): Promise<void> {
    if (this.config.dependencies.typescript) {
      console.log('Installing TypeScript dependencies...');
      execSync('npm init -y', { cwd: this.config.projectPath });
      execSync('npm install typescript @types/node ts-node --save-dev', { cwd: this.config.projectPath });
    }

    if (this.config.dependencies.julia) {
      console.log('Installing Julia dependencies...');
      const juliaDeps = [
        'HTTP',
        'WebSockets',
        'JSON',
        'DataFrames',
        'Distributions',
        'Plots'
      ];

      for (const dep of juliaDeps) {
        execSync(`julia -e 'using Pkg; Pkg.add("${dep}")'`, { cwd: this.config.projectPath });
      }
    }
  }

  private async createConfigFiles(): Promise<void> {
    // Create TypeScript configuration
    const tsConfig = {
      compilerOptions: {
        target: 'es2020',
        module: 'commonjs',
        strict: true,
        esModuleInterop: true,
        skipLibCheck: true,
        forceConsistentCasingInFileNames: true,
        outDir: './dist',
        rootDir: './src'
      },
      include: ['src/**/*'],
      exclude: ['node_modules', 'dist']
    };

    await writeFile(
      path.join(this.config.projectPath, 'tsconfig.json'),
      JSON.stringify(tsConfig, null, 2)
    );

    // Create Julia project file
    const juliaProject = {
      name: 'JuliaOS',
      uuid: '12345678-1234-5678-1234-567812345678',
      authors: ['Your Name <your.email@example.com>'],
      version: '0.1.0',
      dependencies: {
        'HTTP': '0.9.17',
        'WebSockets': '1.5.0',
        'JSON': '0.21.3',
        'DataFrames': '1.5.0',
        'Distributions': '0.25.70',
        'Plots': '1.38.0'
      }
    };

    await writeFile(
      path.join(this.config.projectPath, 'julia/Project.toml'),
      JSON.stringify(juliaProject, null, 2)
    );

    // Create README
    const readme = `# JuliaOS Project

This project was created using JuliaOS framework.

## Setup

1. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

2. Start the development server:
   \`\`\`bash
   npm run dev
   \`\`\`

## Features

- Trading: ${this.config.features.trading}
- Optimization: ${this.config.features.optimization}
- Visualization: ${this.config.features.visualization}

## Documentation

See the \`docs\` directory for detailed documentation.
`;

    await writeFile(
      path.join(this.config.projectPath, 'README.md'),
      readme
    );
  }
} 