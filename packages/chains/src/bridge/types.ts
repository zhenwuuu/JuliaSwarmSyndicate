import { BigNumberish } from 'ethers';
import { ChainId } from '../types';

export interface BridgeConfig {
  sourceChainId: ChainId;
  targetChainId: ChainId;
  sourceTokenAddress: string;
  targetTokenAddress: string;
  bridgeContractAddress: string;
  minAmount: BigNumberish;
  maxAmount: BigNumberish;
  fees: {
    percentage: number;
    fixed: BigNumberish;
  };
}

export interface BridgeTransaction {
  id: string;
  sourceChainId: ChainId;
  targetChainId: ChainId;
  sourceAddress: string;
  targetAddress: string;
  amount: BigNumberish;
  status: BridgeTransactionStatus;
  timestamp: number;
  sourceTransactionHash?: string;
  targetTransactionHash?: string;
  error?: string;
}

export enum BridgeTransactionStatus {
  PENDING = 'PENDING',
  SOURCE_CONFIRMED = 'SOURCE_CONFIRMED',
  TARGET_INITIATED = 'TARGET_INITIATED',
  TARGET_CONFIRMED = 'TARGET_CONFIRMED',
  FAILED = 'FAILED'
}

export interface IBridgeProvider {
  initiate(
    sourceChainId: ChainId,
    targetChainId: ChainId,
    amount: BigNumberish,
    targetAddress: string
  ): Promise<BridgeTransaction>;
  
  confirm(
    transactionId: string
  ): Promise<BridgeTransaction>;
  
  getStatus(
    transactionId: string
  ): Promise<BridgeTransactionStatus>;
  
  getSupportedChains(): Promise<ChainId[]>;
  
  getConfig(
    sourceChainId: ChainId,
    targetChainId: ChainId
  ): Promise<BridgeConfig>;
} 