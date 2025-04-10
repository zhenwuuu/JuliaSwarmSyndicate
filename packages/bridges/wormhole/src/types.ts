import { BigNumberish } from 'ethers';

export interface ChainConfig {
  rpcUrl: string;
  bridgeAddress: string;
  tokenBridgeAddress: string;
  wormholeChainId: number;
  nativeTokenDecimals: number;
}

export interface NetworkConfig {
  [chainName: string]: ChainConfig;
}

export interface BridgeConfig {
  networks: NetworkConfig;
  privateKeys: {
    [chainName: string]: string;
  };
}

export interface TokenBridgeParams {
  sourceChain: string;
  targetChain: string;
  token: string;
  amount: BigNumberish;
  recipient: string;
  relayerFee?: BigNumberish;
}

export interface TransferResult {
  transactionHash: string;
  amount: string;
  fee: string;
  sourceChain: string;
  targetChain: string;
  token: string;
  recipient: string;
  status: 'pending' | 'completed' | 'failed';
  message?: string;
  sequence?: string;
  emitterAddress?: string;
  vaa?: string;
}

export interface RedeemResult {
  transactionHash: string;
  status: 'completed' | 'failed';
  message?: string;
}

export interface WormholeMessage {
  vaa: string;
  emitterChain: number;
  emitterAddress: string;
  sequence: string;
  payload: string;
  timestamp: number;
}

export interface TokenInfo {
  address: string;
  chainId: number;
  decimals: number;
  symbol: string;
  name: string;
  isNative: boolean;
}
