import { EventEmitter } from 'events';
import { WalletProvider, WalletState, WalletEvent, WalletError, ChainConfig, CrossChainTransaction } from '../types';
import { SUPPORTED_CHAINS } from '../types';

export abstract class BaseWalletProvider extends EventEmitter implements WalletProvider {
  protected state: WalletState = {
    address: null,
    chainId: null,
    isConnected: false,
    isConnecting: false,
    error: null,
    supportedChains: Object.values(SUPPORTED_CHAINS)
  };

  constructor() {
    super();
    this.setupEventListeners();
  }

  protected abstract setupEventListeners(): void;
  protected abstract checkAvailability(): boolean;

  public abstract connect(): Promise<void>;
  public abstract disconnect(): Promise<void>;
  public abstract signMessage(message: string): Promise<string>;
  public abstract getAddress(): Promise<string>;
  public abstract getBalance(): Promise<string>;
  public abstract switchNetwork(chainId: number): Promise<void>;
  public abstract getChainId(): Promise<number>;
  public abstract sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string>;

  public isAvailable(): boolean {
    return this.checkAvailability();
  }

  public getSupportedChains(): ChainConfig[] {
    return this.state.supportedChains;
  }

  protected setState(newState: Partial<WalletState>): void {
    this.state = { ...this.state, ...newState };
    this.emit('stateChanged', this.state);
  }

  protected handleError(error: Error): void {
    const walletError: WalletError = {
      ...error,
      code: (error as any).code || -1
    };
    this.setState({ error: walletError });
    this.emit('error', walletError);
  }

  protected emitEvent(event: WalletEvent, data?: any): void {
    this.emit(event, data);
  }

  public getState(): WalletState {
    return { ...this.state };
  }

  protected async validateChainSupport(chainId: number): Promise<boolean> {
    return this.state.supportedChains.some(chain => chain.chainId === chainId);
  }

  protected async validateCrossChainTransaction(tx: CrossChainTransaction): Promise<void> {
    const fromChainSupported = await this.validateChainSupport(tx.fromChain);
    const toChainSupported = await this.validateChainSupport(tx.toChain);

    if (!fromChainSupported || !toChainSupported) {
      throw new Error('One or both chains are not supported');
    }

    if (tx.fromChain === tx.toChain) {
      throw new Error('Source and destination chains must be different');
    }
  }
} 