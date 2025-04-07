import { EventEmitter } from 'events';
import { PublicKey } from '@solana/web3.js';
import { Signer } from 'ethers';

export type ChainId = number;
export type Address = string;

export interface ChainConfig {
  chainId: ChainId;
  name: string;
  rpcUrl: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  blockExplorerUrl?: string;
}

export const SUPPORTED_CHAINS: Record<string, ChainConfig> = {
  ethereum: {
    chainId: 1,
    name: 'Ethereum Mainnet',
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/your-api-key',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18
    },
    blockExplorerUrl: 'https://etherscan.io'
  },
  base: {
    chainId: 8453,
    name: 'Base Mainnet',
    rpcUrl: 'https://mainnet.base.org',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18
    },
    blockExplorerUrl: 'https://basescan.org'
  },
  baseGoerli: {
    chainId: 84531,
    name: 'Base Goerli',
    rpcUrl: 'https://goerli.base.org',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18
    },
    blockExplorerUrl: 'https://goerli.basescan.org'
  }
};

export interface WalletState {
  address: Address | null;
  chainId: ChainId | null;
  isConnected: boolean;
  isConnecting: boolean;
  error: Error | null;
  supportedChains: ChainConfig[];
}

export interface CrossChainTransaction {
  fromChain: ChainId;
  toChain: ChainId;
  fromAddress: Address;
  toAddress: Address;
  amount: string;
  token?: string;
}

export interface WalletProvider extends EventEmitter {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  signMessage(message: string): Promise<string>;
  getAddress(): Promise<Address>;
  getBalance(): Promise<string>;
  switchNetwork(chainId: ChainId): Promise<void>;
  getChainId(): Promise<ChainId>;
  isAvailable(): boolean;
  getState(): WalletState;
  getSupportedChains(): ChainConfig[];
  sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string>;
}

export interface SolanaWalletProvider extends WalletProvider {
  getPublicKey(): Promise<PublicKey>;
  signTransaction(transaction: any): Promise<any>;
  signAllTransactions(transactions: any[]): Promise<any[]>;
}

export interface EthereumWalletProvider extends WalletProvider {
  getSigner(): Promise<Signer>;
  sendTransaction(transaction: any): Promise<any>;
}

export interface IWalletManager {
  connect(providerName: string): Promise<void>;
  disconnect(): Promise<void>;
  getProvider(providerName: string): WalletProvider | null;
  getCurrentProvider(): WalletProvider | null;
  getState(): WalletState;
  isAvailable(providerName: string): boolean;
}

export type WalletEvent = 
  | 'connect'
  | 'disconnect'
  | 'accountsChanged'
  | 'chainChanged'
  | 'error'
  | 'bridgeTransactionInitiated'
  | 'bridgeTransactionStatusUpdate';

export interface WalletError extends Error {
  code: number;
  data?: any;
} 