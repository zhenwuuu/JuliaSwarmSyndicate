export interface WalletAdapter {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  signTransaction(transaction: any): Promise<any>;
  signMessage(message: string): Promise<string>;
  getAddress(): Promise<string>;
}

export interface ChainConfig {
  chainId: string;
  rpcUrl: string;
  blockExplorer: string;
}

export interface WalletConfig {
  chains: ChainConfig[];
  defaultChain?: string;
} 