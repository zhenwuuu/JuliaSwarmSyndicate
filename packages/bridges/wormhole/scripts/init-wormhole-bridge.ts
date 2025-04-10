import { registerWormholeBridgeService } from '../src/register-service';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Register the Wormhole bridge service
registerWormholeBridgeService();

console.log('Wormhole bridge service initialized');

// Keep the process running
process.stdin.resume();
