import { WalletAdapter, WalletConfig } from './types';

export class WalletProvider {
  private adapters: Map<string, WalletAdapter> = new Map();
  private config: WalletConfig;

  constructor(config: WalletConfig) {
    this.config = config;
  }

  registerAdapter(name: string, adapter: WalletAdapter) {
    this.adapters.set(name, adapter);
  }

  async connect(walletName: string): Promise<WalletAdapter> {
    const adapter = this.adapters.get(walletName);
    if (!adapter) {
      throw new Error(`Wallet ${walletName} not found`);
    }

    await adapter.connect();
    return adapter;
  }
} 