import { registerWormholeBridgeService } from './simplified-register-service';
import app from './simplified-bridge-api';

// Register the Wormhole bridge service
const commands = registerWormholeBridgeService();

// Start the bridge API server
const port = process.env.WORMHOLE_BRIDGE_PORT || 3001;
app.listen(port, () => {
  console.log(`Wormhole Bridge API running on http://localhost:${port}`);
});

// Export the commands for testing
export { commands };
