import Arweave from 'arweave';
import { JWKInterface } from 'arweave/node/lib/wallet';
import { Tag } from 'arweave/node/lib/transaction';
import { TransactionStatusResponse } from 'arweave/node/transactions';
import { box, randomBytes } from 'tweetnacl';
import { decodeUTF8, encodeUTF8, encodeBase64, decodeBase64 } from 'tweetnacl-util';

// Define the DataBundle types since the package doesn't have type definitions
interface DataItem {
  data: string;
  tags: { name: string; value: string }[];
}

interface DataBundle {
  items: DataItem[];
}

// Mock the bundleAndSignData function since we don't have type definitions
declare function bundleAndSignData(bundle: DataBundle, wallet: JWKInterface): Promise<any>;

export interface ArweaveConfig {
  host: string;
  port: number;
  protocol: string;
  timeout: number;
  logging: boolean;
}

export interface StorageMetadata {
  contentType?: string;
  tags?: { name: string; value: string }[];
  encrypted?: boolean;
}

export interface QueryOptions {
  first?: number;
  after?: string;
  minBlockHeight?: number;
  maxBlockHeight?: number;
  sortBy?: 'HEIGHT_ASC' | 'HEIGHT_DESC';
}

export interface QueryResult<T> {
  items: T[];
  pageInfo: {
    hasNextPage: boolean;
    endCursor?: string;
  };
}

export class ArweaveStorage {
  private client: Arweave;
  private wallet: JWKInterface | null = null;
  private encryptionKeys: { publicKey: Uint8Array; secretKey: Uint8Array } | null = null;

  constructor(config: ArweaveConfig) {
    this.client = new Arweave(config);
  }

  async setWallet(wallet: JWKInterface) {
    this.wallet = wallet;
  }

  async generateEncryptionKeys() {
    const keyPair = box.keyPair();
    this.encryptionKeys = {
      publicKey: keyPair.publicKey,
      secretKey: keyPair.secretKey
    };
    return encodeBase64(keyPair.publicKey);
  }

  async setEncryptionKeys(publicKey: string, secretKey?: string) {
    this.encryptionKeys = {
      publicKey: decodeBase64(publicKey),
      secretKey: secretKey ? decodeBase64(secretKey) : new Uint8Array(0)
    };
  }

  private encrypt(data: string, recipientPublicKey: Uint8Array): { encrypted: Uint8Array; nonce: Uint8Array } {
    if (!this.encryptionKeys?.secretKey) {
      throw new Error('Encryption keys not set');
    }

    const nonce = randomBytes(box.nonceLength);
    const messageUint8 = decodeUTF8(data);
    const encrypted = box(messageUint8, nonce, recipientPublicKey, this.encryptionKeys.secretKey);

    return {
      encrypted,
      nonce
    };
  }

  private decrypt(encryptedData: Uint8Array, nonce: Uint8Array, senderPublicKey: Uint8Array): string {
    if (!this.encryptionKeys?.secretKey) {
      throw new Error('Encryption keys not set');
    }

    const decrypted = box.open(encryptedData, nonce, senderPublicKey, this.encryptionKeys.secretKey);
    if (!decrypted) {
      throw new Error('Failed to decrypt data');
    }

    return encodeUTF8(decrypted);
  }

  async getWalletBalance(): Promise<string> {
    if (!this.wallet) {
      throw new Error('Wallet not set');
    }

    const address = await this.client.wallets.jwkToAddress(this.wallet);
    const balance = await this.client.wallets.getBalance(address);
    return this.client.ar.winstonToAr(balance);
  }

  async store(data: string | Buffer, metadata: StorageMetadata = {}): Promise<string> {
    if (!this.wallet) {
      throw new Error('Wallet not set');
    }

    let dataToStore: Buffer;
    if (metadata.encrypted && typeof data === 'string') {
      if (!this.encryptionKeys) {
        throw new Error('Encryption keys not set');
      }
      const { encrypted, nonce } = this.encrypt(data, this.encryptionKeys.publicKey);
      dataToStore = Buffer.concat([nonce, encrypted]);
    } else {
      dataToStore = typeof data === 'string' ? Buffer.from(data, 'utf8') : data;
    }

    const transaction = await this.client.createTransaction({
      data: dataToStore
    }, this.wallet);

    if (metadata.contentType) {
      transaction.addTag('Content-Type', metadata.contentType);
    }

    if (metadata.encrypted) {
      transaction.addTag('Encrypted', 'true');
      transaction.addTag('PublicKey', encodeBase64(this.encryptionKeys!.publicKey));
    }

    if (metadata.tags) {
      metadata.tags.forEach(tag => {
        transaction.addTag(tag.name, tag.value);
      });
    }

    await this.client.transactions.sign(transaction, this.wallet);
    const response = await this.client.transactions.post(transaction);

    if (response.status !== 200) {
      throw new Error(`Failed to store data: ${response.statusText}`);
    }

    return transaction.id;
  }

  async storeBundle(items: { data: string | Buffer; metadata?: StorageMetadata }[]): Promise<string> {
    if (!this.wallet) {
      throw new Error('Wallet not set');
    }

    const bundleItems: DataItem[] = await Promise.all(
      items.map(async (item) => {
        let data: string;
        const tags = item.metadata?.tags || [];

        if (item.metadata?.encrypted && typeof item.data === 'string') {
          if (!this.encryptionKeys) {
            throw new Error('Encryption keys not set');
          }
          const { encrypted, nonce } = this.encrypt(item.data, this.encryptionKeys.publicKey);
          data = encodeBase64(Buffer.concat([nonce, encrypted]));
          tags.push(
            { name: 'Encrypted', value: 'true' },
            { name: 'PublicKey', value: encodeBase64(this.encryptionKeys.publicKey) }
          );
        } else {
          data = typeof item.data === 'string' ? item.data : item.data.toString('base64');
        }

        if (item.metadata?.contentType) {
          tags.push({ name: 'Content-Type', value: item.metadata.contentType });
        }

        return {
          data,
          tags
        };
      })
    );

    const bundle: DataBundle = {
      items: bundleItems
    };

    const signedBundle = await bundleAndSignData(bundle, this.wallet);
    const transaction = await this.client.createTransaction({
      data: JSON.stringify(signedBundle)
    }, this.wallet);

    transaction.addTag('Content-Type', 'application/json');
    transaction.addTag('Bundle-Format', 'json');
    transaction.addTag('Bundle-Version', '1.0.0');

    await this.client.transactions.sign(transaction, this.wallet);
    const response = await this.client.transactions.post(transaction);

    if (response.status !== 200) {
      throw new Error(`Failed to store bundle: ${response.statusText}`);
    }

    return transaction.id;
  }

  async retrieve(transactionId: string): Promise<{ data: string; metadata: StorageMetadata }> {
    const transaction = await this.client.transactions.get(transactionId);
    const data = transaction.get('data', { decode: true, string: true });
    const tags = transaction.get('tags', { decode: true, string: true }) as unknown as Array<{
      name: string;
      value: string;
    }>;

    const metadata: StorageMetadata = {
      tags: []
    };

    let isEncrypted = false;
    let publicKey: string | undefined;

    for (const tag of tags) {
      if (tag.name === 'Content-Type') {
        metadata.contentType = tag.value;
      } else if (tag.name === 'Encrypted') {
        isEncrypted = tag.value === 'true';
        metadata.encrypted = true;
      } else if (tag.name === 'PublicKey') {
        publicKey = tag.value;
      } else {
        metadata.tags?.push({ name: tag.name, value: tag.value });
      }
    }

    if (isEncrypted && publicKey) {
      if (!this.encryptionKeys?.secretKey) {
        throw new Error('Encryption keys not set');
      }

      const buffer = Buffer.from(data, 'base64');
      const nonce = buffer.slice(0, box.nonceLength);
      const encryptedData = buffer.slice(box.nonceLength);
      
      return {
        data: this.decrypt(encryptedData, nonce, decodeBase64(publicKey)),
        metadata
      };
    }

    return { data, metadata };
  }

  async getTransactionStatus(transactionId: string): Promise<TransactionStatusResponse> {
    return this.client.transactions.getStatus(transactionId);
  }

  async verifyTransaction(transactionId: string): Promise<boolean> {
    const transaction = await this.client.transactions.get(transactionId);
    return this.client.transactions.verify(transaction);
  }

  async query(
    tags: { name: string; value: string }[],
    options: QueryOptions = {}
  ): Promise<QueryResult<string>> {
    const query = `
      query {
        transactions(
          tags: [${tags.map(tag => `{ name: "${tag.name}", values: ["${tag.value}"] }`).join(', ')}]
          ${options.first ? `first: ${options.first}` : ''}
          ${options.after ? `after: "${options.after}"` : ''}
          ${options.minBlockHeight ? `block: { min: ${options.minBlockHeight} }` : ''}
          ${options.maxBlockHeight ? `block: { max: ${options.maxBlockHeight} }` : ''}
          ${options.sortBy ? `sort: ${options.sortBy}` : ''}
        ) {
          edges {
            node {
              id
            }
            cursor
          }
          pageInfo {
            hasNextPage
          }
        }
      }
    `;

    const response = await this.client.api.post('graphql', { query });

    if (response.status !== 200) {
      throw new Error('Failed to query transactions');
    }

    const edges = response.data.data.transactions.edges;
    return {
      items: edges.map((edge: any) => edge.node.id),
      pageInfo: {
        hasNextPage: response.data.data.transactions.pageInfo.hasNextPage,
        endCursor: edges.length > 0 ? edges[edges.length - 1].cursor : undefined
      }
    };
  }

  async storeAgentConfig(agentId: string, config: any): Promise<string> {
    return this.store(JSON.stringify(config), {
      contentType: 'application/json',
      tags: [
        { name: 'Type', value: 'AgentConfig' },
        { name: 'AgentId', value: agentId }
      ]
    });
  }

  async getAgentConfigs(agentId: string, options?: QueryOptions): Promise<QueryResult<string>> {
    return this.query([
      { name: 'Type', value: 'AgentConfig' },
      { name: 'AgentId', value: agentId }
    ], options);
  }

  async storeTrainingData(modelId: string, data: any): Promise<string> {
    return this.store(JSON.stringify(data), {
      contentType: 'application/json',
      tags: [
        { name: 'Type', value: 'TrainingData' },
        { name: 'ModelId', value: modelId }
      ]
    });
  }

  async getTrainingData(modelId: string, options?: QueryOptions): Promise<QueryResult<string>> {
    return this.query([
      { name: 'Type', value: 'TrainingData' },
      { name: 'ModelId', value: modelId }
    ], options);
  }

  async storeMarketplaceMetadata(moduleId: string, metadata: any): Promise<string> {
    return this.store(JSON.stringify(metadata), {
      contentType: 'application/json',
      tags: [
        { name: 'Type', value: 'MarketplaceMetadata' },
        { name: 'ModuleId', value: moduleId }
      ]
    });
  }

  async getMarketplaceMetadata(moduleId: string, options?: QueryOptions): Promise<QueryResult<string>> {
    return this.query([
      { name: 'Type', value: 'MarketplaceMetadata' },
      { name: 'ModuleId', value: moduleId }
    ], options);
  }

  async storeUserInteraction(userId: string, data: any): Promise<string> {
    return this.store(JSON.stringify(data), {
      contentType: 'application/json',
      tags: [
        { name: 'Type', value: 'UserInteraction' },
        { name: 'UserId', value: userId }
      ]
    });
  }

  async getUserInteractions(userId: string, options?: QueryOptions): Promise<QueryResult<string>> {
    return this.query([
      { name: 'Type', value: 'UserInteraction' },
      { name: 'UserId', value: userId }
    ], options);
  }
} 