export interface BridgeEvent {
  from: string;
  token: string;
  amount: bigint;
  recipient: Uint8Array;
  sourceChainId: number;
  targetChainId: number;
} 