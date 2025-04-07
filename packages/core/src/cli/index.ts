import { SetupCLI } from './setup';

async function main() {
  const setup = new SetupCLI();
  await setup.start();
}

if (require.main === module) {
  main().catch((error) => {
    console.error('Failed to run setup:', error);
    process.exit(1);
  });
} 