import { Connection, PublicKey, Transaction, VersionedTransaction } from '@solana/web3.js';
import { BaseWalletProvider } from './BaseWalletProvider';
import { SolanaWalletProvider, CrossChainTransaction } from '../types';

declare global {
  interface Window {
    solana?: {
      isPhantom?: boolean;
      connect(): Promise<{ publicKey: PublicKey }>;
      disconnect(): Promise<void>;
      signMessage(message: Uint8Array): Promise<{ signature: Uint8Array }>;
      signTransaction(transaction: Transaction | VersionedTransaction): Promise<Transaction | VersionedTransaction>;
      signAllTransactions(transactions: (Transaction | VersionedTransaction)[]): Promise<(Transaction | VersionedTransaction)[]>;
      on(event: string, callback: (args: any) => void): void;
      removeListener(event: string, callback: (args: any) => void): void;
    };
  }
}

export class PhantomProvider extends BaseWalletProvider implements SolanaWalletProvider {
  private connection: Connection | null = null;
  private publicKey: PublicKey | null = null;

  protected checkAvailability(): boolean {
    return typeof window !== 'undefined' && !!window.solana?.isPhantom;
  }

  protected setupEventListeners(): void {
    if (!window.solana) return;

    window.solana.on('connect', (publicKey: PublicKey) => {
      this.publicKey = publicKey;
      this.setState({
        address: publicKey.toString(),
        isConnected: true,
        isConnecting: false
      });
      this.emitEvent('connect', { publicKey });
    });

    window.solana.on('disconnect', () => {
      this.disconnect();
    });

    window.solana.on('accountChanged', (publicKey: PublicKey | null) => {
      if (publicKey) {
        this.publicKey = publicKey;
        this.setState({ address: publicKey.toString() });
        this.emitEvent('accountsChanged', publicKey.toString());
      } else {
        this.disconnect();
      }
    });
  }

  public async connect(): Promise<void> {
    if (!this.checkAvailability()) {
      throw new Error('Phantom wallet is not available');
    }

    try {
      this.setState({ isConnecting: true });
      
      const { publicKey } = await window.solana!.connect();
      this.publicKey = publicKey;
      
      // Initialize connection to Solana network
      this.connection = new Connection('https://api.mainnet-beta.solana.com');
      
      const balance = await this.connection.getBalance(publicKey);

      this.setState({
        address: publicKey.toString(),
        isConnected: true,
        isConnecting: false
      });

      this.emitEvent('connect', { publicKey, balance });
    } catch (error) {
      this.handleError(error as Error);
      throw error;
    }
  }

  public async disconnect(): Promise<void> {
    if (window.solana) {
      await window.solana.disconnect();
    }
    
    this.publicKey = null;
    this.connection = null;
    
    this.setState({
      address: null,
      chainId: null,
      isConnected: false,
      isConnecting: false
    });
    
    this.emitEvent('disconnect');
  }

  public async signMessage(message: string): Promise<string> {
    if (!window.solana || !this.publicKey) {
      throw new Error('Wallet not connected');
    }

    const encodedMessage = new TextEncoder().encode(message);
    const { signature } = await window.solana.signMessage(encodedMessage);
    return Buffer.from(signature).toString('hex');
  }

  public async getAddress(): Promise<string> {
    if (!this.publicKey) {
      throw new Error('Wallet not connected');
    }
    return this.publicKey.toString();
  }

  public async getBalance(): Promise<string> {
    if (!this.connection || !this.publicKey) {
      throw new Error('Wallet not connected');
    }
    const balance = await this.connection.getBalance(this.publicKey);
    return (balance / 1e9).toString(); // Convert lamports to SOL
  }

  public async switchNetwork(chainId: number): Promise<void> {
    // Solana doesn't support network switching in the same way as Ethereum
    throw new Error('Network switching not supported for Solana');
  }

  public async getChainId(): Promise<number> {
    // Solana doesn't use chain IDs
    return 0;
  }

  public async getPublicKey(): Promise<PublicKey> {
    if (!this.publicKey) {
      throw new Error('Wallet not connected');
    }
    return this.publicKey;
  }

  public async signTransaction(transaction: Transaction | VersionedTransaction): Promise<Transaction | VersionedTransaction> {
    if (!window.solana || !this.publicKey) {
      throw new Error('Wallet not connected');
    }
    return window.solana.signTransaction(transaction);
  }

  public async signAllTransactions(transactions: (Transaction | VersionedTransaction)[]): Promise<(Transaction | VersionedTransaction)[]> {
    if (!window.solana || !this.publicKey) {
      throw new Error('Wallet not connected');
    }
    return window.solana.signAllTransactions(transactions);
  }

  // Implement the abstract method from BaseWalletProvider
  public async sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string> {
    // Validate the cross-chain transaction
    await this.validateCrossChainTransaction(tx);
    
    // Ensure wallet is connected
    if (!window.solana || !this.publicKey || !this.connection) {
      throw new Error('Wallet not connected');
    }
    
    // Solana can't switch networks like Ethereum
    // In a real implementation, this would use a Wormhole or other bridge
    // For now, we'll just simulate a transaction
    try {
      // In a real implementation, this would create a cross-chain transfer
      // through a bridge like Wormhole, Portal, or Allbridge
      
      // Create a simple transfer transaction for simulation
      const transaction = new Transaction().add(
        // This is a placeholder - a real implementation would include
        // proper instructions for the cross-chain transfer
        {
          keys: [{ pubkey: this.publicKey, isSigner: true, isWritable: true }],
          programId: new PublicKey('11111111111111111111111111111111'),
          data: Buffer.from('simulated-cross-chain-tx')
        }
      );
      
      // Sign the transaction
      const signedTransaction = await this.signTransaction(transaction);
      
      // In a real implementation, you would serialize and send it
      // For now, just return a mock transaction hash
      return Buffer.from(
        `solana-cross-chain-tx-${Date.now()}-${tx.fromChain}-${tx.toChain}`
      ).toString('base64');
    } catch (error) {
      this.handleError(error as Error);
      throw error;
    }
  }
} 