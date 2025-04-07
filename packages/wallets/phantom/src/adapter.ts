import { WalletAdapter } from '../../common/src/types';
import { Connection, PublicKey, Transaction, LAMPORTS_PER_SOL, SystemProgram, TransactionInstruction } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, createTransferInstruction, getAssociatedTokenAddress, createAssociatedTokenAccountInstruction, getAccount } from '@solana/spl-token';

export class PhantomWalletAdapter implements WalletAdapter {
  private provider: any;
  private connection: Connection;
  private publicKey: PublicKey | null = null;

  constructor(rpcUrl: string) {
    this.connection = new Connection(rpcUrl, 'confirmed');
    if (typeof window !== 'undefined') {
      this.provider = (window as any).solana;
    }
  }

  async connect(): Promise<void> {
    try {
      if (!this.provider) {
        throw new Error('Phantom wallet not found');
      }
      const response = await this.provider.connect();
      this.publicKey = new PublicKey(response.publicKey.toString());
    } catch (error) {
      throw new Error(`Failed to connect to Phantom wallet: ${error}`);
    }
  }

  async disconnect(): Promise<void> {
    try {
      await this.provider.disconnect();
      this.publicKey = null;
    } catch (error) {
      throw new Error(`Failed to disconnect from Phantom wallet: ${error}`);
    }
  }

  async signTransaction(transaction: Transaction): Promise<Transaction> {
    try {
      if (!this.provider || !this.publicKey) {
        throw new Error('Wallet not connected');
      }
      const signedTx = await this.provider.signTransaction(transaction);
      return signedTx;
    } catch (error) {
      throw new Error(`Failed to sign transaction: ${error}`);
    }
  }

  async signMessage(message: string): Promise<string> {
    try {
      if (!this.provider || !this.publicKey) {
        throw new Error('Wallet not connected');
      }
      const encodedMessage = new TextEncoder().encode(message);
      const signedMessage = await this.provider.signMessage(encodedMessage);
      return Buffer.from(signedMessage).toString('base64');
    } catch (error) {
      throw new Error(`Failed to sign message: ${error}`);
    }
  }

  async getAddress(): Promise<string> {
    if (!this.publicKey) {
      throw new Error('Wallet not connected');
    }
    return this.publicKey.toString();
  }

  async getBalance(tokenAddress?: string): Promise<string> {
    if (!this.publicKey) {
      throw new Error('Wallet not connected');
    }
    
    if (tokenAddress) {
      // SPL token balance
      try {
        const tokenPublicKey = new PublicKey(tokenAddress);
        const tokenAccounts = await this.connection.getParsedTokenAccountsByOwner(
          this.publicKey,
          { mint: tokenPublicKey }
        );
        
        if (tokenAccounts.value.length === 0) {
          return '0';
        }
        
        return tokenAccounts.value[0].account.data.parsed.info.tokenAmount.amount;
      } catch (error) {
        throw new Error(`Failed to get token balance: ${error}`);
      }
    } else {
      // SOL balance
      const balance = await this.connection.getBalance(this.publicKey);
      return balance.toString();
    }
  }

  async sendTransaction(transaction: Transaction): Promise<string> {
    try {
      if (!this.provider || !this.publicKey) {
        throw new Error('Wallet not connected');
      }
      
      // Get the latest blockhash
      const { blockhash } = await this.connection.getLatestBlockhash();
      transaction.recentBlockhash = blockhash;
      transaction.feePayer = this.publicKey;
      
      // Sign the transaction
      const signedTx = await this.provider.signTransaction(transaction);
      
      // Send the transaction
      const signature = await this.connection.sendRawTransaction(signedTx.serialize());
      
      // Confirm the transaction
      await this.connection.confirmTransaction(signature);
      
      return signature;
    } catch (error) {
      throw new Error(`Failed to send transaction: ${error}`);
    }
  }

  async sendSol(toAddress: string, amount: number): Promise<string> {
    try {
      if (!this.publicKey) {
        throw new Error('Wallet not connected');
      }
      
      const toPublicKey = new PublicKey(toAddress);
      const transaction = new Transaction().add(
        SystemProgram.transfer({
          fromPubkey: this.publicKey,
          toPubkey: toPublicKey,
          lamports: amount * LAMPORTS_PER_SOL
        })
      );
      
      return this.sendTransaction(transaction);
    } catch (error) {
      throw new Error(`Failed to send SOL: ${error}`);
    }
  }

  async sendToken(tokenAddress: string, toAddress: string, amount: number): Promise<string> {
    try {
      if (!this.publicKey) {
        throw new Error('Wallet not connected');
      }
      
      // Convert addresses to PublicKey objects
      const tokenMint = new PublicKey(tokenAddress);
      const recipient = new PublicKey(toAddress);
      
      // Get the sender's token account address
      const senderTokenAccount = await getAssociatedTokenAddress(
        tokenMint,
        this.publicKey
      );
      
      // Get the recipient's token account address
      const recipientTokenAccount = await getAssociatedTokenAddress(
        tokenMint,
        recipient
      );
      
      // Check if recipient token account exists, otherwise create it
      let transaction = new Transaction();
      
      try {
        // This will throw if the account doesn't exist
        await getAccount(this.connection, recipientTokenAccount);
      } catch (error) {
        // If account doesn't exist, add instruction to create it
        transaction.add(
          createAssociatedTokenAccountInstruction(
            this.publicKey, // payer
            recipientTokenAccount,
            recipient,
            tokenMint
          )
        );
      }
      
      // Get token decimals
      const tokenInfo = await this.connection.getParsedAccountInfo(tokenMint);
      const tokenDecimals = (tokenInfo.value?.data as any)?.parsed?.info?.decimals || 9;
      
      // Calculate the amount in token units
      const tokenAmount = amount * Math.pow(10, tokenDecimals);
      
      // Add the transfer instruction
      transaction.add(
        createTransferInstruction(
          senderTokenAccount,
          recipientTokenAccount,
          this.publicKey,
          Math.floor(tokenAmount),
          [],
          TOKEN_PROGRAM_ID
        )
      );
      
      // Send the transaction
      return this.sendTransaction(transaction);
    } catch (error) {
      throw new Error(`Failed to send token: ${error}`);
    }
  }
} 