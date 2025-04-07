// Wallet Manager Implementation
import { ethers } from 'ethers';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import crypto from 'crypto';
import argon2 from 'argon2';

/**
 * Security-enhanced wallet manager with MFA and rate limiting
 */
export class WalletManager {
    constructor() {
        this.state = {
            isConnected: false,
            address: null,
            chain: null,
            balance: null,
            provider: null
        };
        
        // Private storage for secure wallets - never exposed outside this class
        this._secureWallets = new Map();
        
        // Security enhancements
        this._failedAttempts = new Map(); // Map of address/operation to failed attempts
        this._lastReset = Date.now(); // Time of last reset of failed attempts
        this._mfaVerified = new Map(); // Map of transaction hashes to MFA verification status
        this._verificationCodes = new Map(); // Store of verification code hashes and their expiry
        this._highValueThresholds = {
            'ethereum': 0.5, // 0.5 ETH
            'polygon': 100, // 100 MATIC
            'solana': 5, // 5 SOL
            'arbitrum': 0.5, // 0.5 ETH
            'optimism': 0.5, // 0.5 ETH
            'base': 0.5, // 0.5 ETH
            'bsc': 1, // 1 BNB
        };
        
        // Rate limiting configuration
        this._maxFailedAttempts = 5; // Max failed attempts before lockout
        this._lockoutPeriod = 15 * 60 * 1000; // 15 minutes in milliseconds
        this._failedAttemptsResetPeriod = 60 * 60 * 1000; // Reset failed attempts after 1 hour
        
        this.providers = {
            metamask: {
                name: 'MetaMask',
                chains: ['ethereum', 'polygon', 'bsc', 'arbitrum', 'optimism', 'base'],
                connect: async () => {
                    if (typeof window.ethereum === 'undefined') {
                        throw new Error('MetaMask is not installed');
                    }
                    try {
                        const provider = new ethers.providers.Web3Provider(window.ethereum);
                        const accounts = await provider.send('eth_requestAccounts', []);
                        const network = await provider.getNetwork();
                        return {
                            address: accounts[0],
                            chain: this.getChainFromId(network.chainId),
                            provider
                        };
                    } catch (error) {
                        throw new Error(`Failed to connect to MetaMask: ${error.message}`);
                    }
                },
                getBalance: async (address, provider) => {
                    const balance = await provider.getBalance(address);
                    return ethers.utils.formatEther(balance);
                },
                signTransaction: async (tx, provider) => {
                    const signer = provider.getSigner();
                    return await signer.sendTransaction(tx);
                }
            },
            phantom: {
                name: 'Phantom',
                chains: ['solana'],
                connect: async () => {
                    if (typeof window.solana === 'undefined') {
                        throw new Error('Phantom is not installed');
                    }
                    try {
                        const resp = await window.solana.connect();
                        const connection = new Connection('https://api.mainnet-beta.solana.com');
                        return {
                            address: resp.publicKey.toString(),
                            chain: 'solana',
                            provider: connection
                        };
                    } catch (error) {
                        throw new Error(`Failed to connect to Phantom: ${error.message}`);
                    }
                },
                getBalance: async (address, provider) => {
                    const balance = await provider.getBalance(new PublicKey(address));
                    return (balance / 1e9).toFixed(4); // SOL has 9 decimals
                },
                signTransaction: async (tx, provider) => {
                    return await window.solana.signTransaction(tx);
                }
            },
            rabby: {
                name: 'Rabby',
                chains: ['ethereum', 'polygon', 'bsc', 'arbitrum', 'optimism', 'base'],
                connect: async () => {
                    if (typeof window.rabby === 'undefined') {
                        throw new Error('Rabby is not installed');
                    }
                    try {
                        const provider = new ethers.providers.Web3Provider(window.rabby);
                        const accounts = await provider.send('eth_requestAccounts', []);
                        const network = await provider.getNetwork();
                        return {
                            address: accounts[0],
                            chain: this.getChainFromId(network.chainId),
                            provider
                        };
                    } catch (error) {
                        throw new Error(`Failed to connect to Rabby: ${error.message}`);
                    }
                },
                getBalance: async (address, provider) => {
                    const balance = await provider.getBalance(address);
                    return ethers.utils.formatEther(balance);
                },
                signTransaction: async (tx, provider) => {
                    const signer = provider.getSigner();
                    return await signer.sendTransaction(tx);
                }
            }
        };
    }

    getChainFromId(chainId) {
        const chainMap = {
            '0x1': 'ethereum',
            '0x89': 'polygon',
            '0x38': 'bsc',
            '0xa4b1': 'arbitrum',
            '0xa': 'optimism',
            '0x2105': 'base'
        };
        return chainMap[chainId] || 'unknown';
    }

    async connect(provider = 'metamask') {
        if (!this.providers[provider]) {
            throw new Error(`Provider ${provider} not supported`);
        }

        try {
            const { address, chain, provider: providerInstance } = await this.providers[provider].connect();
            const balance = await this.providers[provider].getBalance(address, providerInstance);

            this.state = {
                isConnected: true,
                address,
                chain,
                balance,
                provider: providerInstance
            };

            return this.state;
        } catch (error) {
            throw new Error(`Failed to connect to ${provider}: ${error.message}`);
        }
    }

    /**
     * Generates a one-time verification code for MFA
     * @private
     * @param {string} txId Transaction ID to associate with the code
     * @returns {Promise<string>} Six-digit verification code
     */
    async _generateVerificationCode(txId) {
        // Generate a random 6-digit code
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        
        try {
            // Use Argon2 to hash the code - significantly more secure than simple hashing
            // Argon2id is a good balance of resistance to side-channel and GPU attacks
            const hash = await argon2.hash(code, {
                type: argon2.argon2id,
                memoryCost: 1024,  // 1 MB
                timeCost: 2,       // 2 iterations
                parallelism: 1     // 1 thread
            });
            
            // Store the hash and expiry time
            this._verificationCodes.set(txId, {
                hash,
                expiry: Date.now() + (5 * 60 * 1000) // 5 minute expiry
            });
            
            return code;
        } catch (error) {
            console.error('Error generating verification code:', error);
            throw new Error('Failed to generate secure verification code');
        }
    }
    
    /**
     * Verifies an MFA code using Argon2
     * @private
     * @param {string} code User-provided verification code
     * @param {string} txId Transaction ID associated with the code
     * @returns {Promise<boolean>} Whether the code is valid
     */
    async _verifyCode(code, txId) {
        // Get stored hash information
        const storedInfo = this._verificationCodes.get(txId);
        
        // Check if we have a stored hash and it's not expired
        if (!storedInfo || Date.now() > storedInfo.expiry) {
            return false;
        }
        
        try {
            // Verify the code using Argon2
            const isValid = await argon2.verify(storedInfo.hash, code);
            
            if (isValid) {
                // Mark this transaction as verified
                this._mfaVerified.set(txId, true);
                
                // Clean up the stored hash
                this._verificationCodes.delete(txId);
            }
            
            return isValid;
        } catch (error) {
            console.error('Error verifying code:', error);
            return false;
        }
    }
    
    /**
     * Checks if the number of failed attempts exceeds the limit
     * @private
     * @param {string} key Identifier for the operation (e.g. 'auth', txId)
     * @returns {boolean} true if account is locked out
     */
    _isLockedOut(key) {
        this._resetFailedAttemptsIfNeeded();
        
        const attempts = this._failedAttempts.get(key) || 0;
        return attempts >= this._maxFailedAttempts;
    }
    
    /**
     * Records a failed attempt
     * @private
     * @param {string} key Identifier for the operation
     */
    _recordFailedAttempt(key) {
        const attempts = this._failedAttempts.get(key) || 0;
        this._failedAttempts.set(key, attempts + 1);
    }
    
    /**
     * Reset failed attempts if enough time has passed
     * @private
     */
    _resetFailedAttemptsIfNeeded() {
        const now = Date.now();
        if (now - this._lastReset > this._failedAttemptsResetPeriod) {
            this._failedAttempts.clear();
            this._lastReset = now;
        }
    }
    
    /**
     * Checks if a transaction requires MFA based on value
     * @private
     * @param {object} tx Transaction object
     * @returns {boolean} Whether MFA is required
     */
    _requiresMFA(tx) {
        if (!this.state.chain) {
            return false;
        }
        
        const threshold = this._highValueThresholds[this.state.chain] || 0;
        let value;
        
        if (this.state.chain === 'solana') {
            value = tx.amount;
        } else {
            value = tx.value;
        }
        
        return value >= threshold;
    }
    
    /**
     * Performs multi-factor authentication for high-value transactions
     * @param {object} tx Transaction object
     * @param {string} txId Unique transaction identifier
     * @returns {Promise<boolean>} Whether authentication was successful
     */
    async performMFA(tx, txId) {
        try {
            // Generate a verification code (in real implementation, this would be sent to the user)
            const code = await this._generateVerificationCode(txId);
            
            // Simulate sending the code to the user
            console.log(`[DEMO] MFA code sent to user: ${code}`);
            
            // In a real implementation, the code would be entered by the user
            // For demo purposes, we'll simulate user input with a prompt
            return await new Promise((resolve) => {
                setTimeout(async () => {
                    // Simulate user inputting the correct code 
                    // In production, this would come from user input
                    console.log('[DEMO] User entering correct code');
                    const isValid = await this._verifyCode(code, txId);
                    resolve(isValid);
                }, 1500);
            });
        } catch (error) {
            console.error('MFA error:', error);
            return false;
        }
    }

    /**
     * Securely connect to a wallet using a private key without exposing the key in state
     * Now with rate limiting for failed attempts
     * @param {string} chain - The blockchain to connect to
     * @param {string} privateKey - The private key to use (never stored directly)
     * @returns {Promise<{address: string, balance: string}>} Wallet information
     */
    async secureConnect(chain, privateKey) {
        // Check for rate limiting on connect attempts
        const connectKey = `connect-${chain}`;
        if (this._isLockedOut(connectKey)) {
            throw new Error('Too many failed connection attempts. Please try again later.');
        }
        
        try {
            let wallet;
            let address;
            let balance = '0.0000';
            
            // Create appropriate wallet based on chain
            if (chain === 'solana') {
                // For Solana, handle with solana/web3.js
                try {
                    const seed = Buffer.from(privateKey, 'hex'); // In production, validate key format
                    const keypair = Keypair.fromSeed(seed.slice(0, 32)); // Ensure 32 bytes
                    address = keypair.publicKey.toString();
                    
                    // Store securely for signing - never directly accessible
                    this._secureWallets.set(chain, keypair);
                    
                    // Mock balance in demo mode
                    balance = '1.2345';
                } catch (error) {
                    // Record failed attempt due to invalid key
                    this._recordFailedAttempt(connectKey);
                    throw new Error(`Invalid Solana key format: ${error.message}`);
                }
            } else {
                // For EVM chains, use ethers.js
                // This would connect to the actual blockchain in production
                try {
                    // Create wallet without exposing the private key
                    wallet = new ethers.Wallet(privateKey);
                    address = wallet.address;
                    
                    // Store securely for signing - never directly accessible
                    this._secureWallets.set(chain, wallet);
                    
                    // Mock balance in demo mode
                    balance = '1.2345';
                } catch (error) {
                    // Record failed attempt due to invalid key
                    this._recordFailedAttempt(connectKey);
                    throw new Error(`Invalid private key format: ${error.message}`);
                }
            }
            
            // Return only the public information, NEVER the private key
            return {
                address,
                balance
            };
        } catch (error) {
            // Record failed attempt
            this._recordFailedAttempt(connectKey);
            throw new Error(`Failed to securely connect wallet: ${error.message}`);
        }
    }

    async disconnect() {
        if (this.state.provider) {
            if (this.state.chain === 'solana') {
                await window.solana.disconnect();
            }
        }
        
        // Clear any secure wallet data
        this._secureWallets.clear();
        
        this.state = {
            isConnected: false,
            address: null,
            chain: null,
            balance: null,
            provider: null
        };
    }

    async getBalance() {
        if (!this.state.isConnected) {
            throw new Error('Wallet not connected');
        }

        try {
            // If we have a secure wallet, we could get a real balance here
            // in production implementation
            if (this._secureWallets.has(this.state.chain)) {
                // Mock implementation for demo
                return this.state.balance;
            }
            
            // For regular browser wallet connections
            const balance = await this.providers[this.state.chain === 'solana' ? 'phantom' : 'metamask']
                .getBalance(this.state.address, this.state.provider);
            this.state.balance = balance;
            return balance;
        } catch (error) {
            throw new Error(`Failed to get balance: ${error.message}`);
        }
    }

    /**
     * Sign a transaction securely without exposing private keys
     * Now with multi-factor authentication for high-value transactions
     * @param {object} tx - Transaction to sign
     * @returns {Promise<object>} Signed transaction
     */
    async signTransaction(tx) {
        if (!this.state.isConnected) {
            throw new Error('Wallet not connected');
        }
        
        // Generate a unique identifier for this transaction
        const txId = `tx-${Date.now()}-${Math.random().toString(36).substring(2, 10)}`;
        
        // Check for rate limiting
        if (this._isLockedOut(this.state.address)) {
            throw new Error('Account temporarily locked due to too many failed attempts. Please try again later.');
        }

        try {
            // Determine if this requires MFA (high-value transaction)
            const requiresMFA = this._requiresMFA(tx);
            
            // If MFA is required and not already verified
            if (requiresMFA && !this._mfaVerified.get(txId)) {
                console.log(`High-value transaction detected (${tx.value || tx.amount} ${this.state.chain}). Requiring MFA verification.`);
                
                // Perform MFA
                const mfaSuccess = await this.performMFA(tx, txId);
                
                if (!mfaSuccess) {
                    this._recordFailedAttempt(this.state.address);
                    throw new Error('Multi-factor authentication failed. Transaction cancelled.');
                }
                
                // MFA successful, proceed with signing
                console.log('MFA verification successful. Proceeding with transaction.');
            }
            
            // First check if we have a secure wallet
            if (this._secureWallets.has(this.state.chain)) {
                const wallet = this._secureWallets.get(this.state.chain);
                
                // Sign with the secure wallet based on chain
                if (this.state.chain === 'solana') {
                    // Solana signing (mock for this demo)
                    console.log(`Signing Solana transaction to ${tx.to}`);
                    
                    // Clean up MFA verification after successful signing
                    this._mfaVerified.delete(txId);
                    
                    return { 
                        signature: '5KN6PJ...1RwuW3', 
                        transaction: tx 
                    };
                } else {
                    // EVM chain signing (mock for this demo)
                    console.log(`Signing ${this.state.chain} transaction to ${tx.to}`);
                    
                    // Clean up MFA verification after successful signing
                    this._mfaVerified.delete(txId);
                    
                    return {
                        signature: '0x7b12...8f91',
                        transaction: tx
                    };
                }
            }
            
            // Otherwise use browser wallet providers
            const result = await this.providers[this.state.chain === 'solana' ? 'phantom' : 'metamask']
                .signTransaction(tx, this.state.provider);
                
            // Clean up MFA verification after successful signing
            this._mfaVerified.delete(txId);
            
            return result;
        } catch (error) {
            // Record failed attempt if it's an authentication error
            if (error.message.includes('MFA') || error.message.includes('authentication')) {
                this._recordFailedAttempt(this.state.address);
            }
            
            throw new Error(`Failed to sign transaction: ${error.message}`);
        }
    }

    getState() {
        return this.state;
    }
} 