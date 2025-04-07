export type ChainId = number;

export interface ChainConfig {
  chainId: ChainId;
  name: string;
  rpcUrl: string;
  explorerUrl: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  contracts?: {
    [key: string]: string;
  };
}

export interface NetworkConfig {
  chains: {
    [chainId: number]: ChainConfig;
  };
  defaultChainId: ChainId;
} 