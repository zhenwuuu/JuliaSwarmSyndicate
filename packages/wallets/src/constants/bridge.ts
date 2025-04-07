import { SUPPORTED_CHAINS } from '../types';

// Base Bridge Contract ABIs
export const BASE_BRIDGE_ABI = [
  'function deposit(address to, uint256 amount) external payable',
  'function withdraw(address to, uint256 amount) external',
  'function getDepositStatus(bytes32 depositId) external view returns (bool)',
  'function getWithdrawalStatus(bytes32 withdrawalId) external view returns (bool)',
  'event DepositInitiated(address indexed from, address indexed to, uint256 amount, bytes32 depositId)',
  'event WithdrawalInitiated(address indexed from, address indexed to, uint256 amount, bytes32 withdrawalId)'
];

// Bridge Contract Addresses
export const BRIDGE_CONTRACTS = {
  [SUPPORTED_CHAINS.base.chainId]: {
    address: '0x3154Cf16ccdb4C6d922629664174b904d80F2C35', // Base Mainnet Bridge
    abi: BASE_BRIDGE_ABI
  },
  [SUPPORTED_CHAINS.ethereum.chainId]: {
    address: '0x49048044D57e1C92A77f79988d21Fa8fAF74E97e', // Ethereum Mainnet Bridge
    abi: BASE_BRIDGE_ABI
  }
};

// Bridge Configuration
export const BRIDGE_CONFIG = {
  [SUPPORTED_CHAINS.base.chainId]: {
    minDepositAmount: '0.0001', // Minimum deposit amount in ETH
    maxDepositAmount: '100', // Maximum deposit amount in ETH
    withdrawalDelay: 7 * 24 * 60 * 60, // 7 days in seconds
    fee: '0.0001' // Bridge fee in ETH
  },
  [SUPPORTED_CHAINS.ethereum.chainId]: {
    minDepositAmount: '0.0001',
    maxDepositAmount: '100',
    withdrawalDelay: 7 * 24 * 60 * 60,
    fee: '0.0001'
  }
};

// Bridge Events
export const BRIDGE_EVENTS = {
  DEPOSIT_INITIATED: 'DepositInitiated',
  WITHDRAWAL_INITIATED: 'WithdrawalInitiated'
};

// Bridge Status
export enum BridgeStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  FAILED = 'FAILED'
}

// Bridge Transaction Types
export interface BridgeTransaction {
  fromChain: number;
  toChain: number;
  fromAddress: string;
  toAddress: string;
  amount: string;
  status: BridgeStatus;
  depositId?: string;
  withdrawalId?: string;
  timestamp: number;
} 