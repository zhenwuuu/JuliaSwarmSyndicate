import Arweave from 'arweave';
import { JWKInterface } from 'arweave/node/lib/wallet';
import { bundleAndSignData, DataBundle } from 'arweave-bundles';

export interface ArweaveConfig {
  host: string;
  port: number;
  protocol: string;
  wallet: JWKInterface;
}

export class ArweaveStorage {
  private arweave: Arweave;
  private wallet: JWKInterface;

  constructor(config: ArweaveConfig) {
    this.arweave = new Arweave({
      host: config.host,
      port: config.port,
      protocol: config.protocol
    });
    this.wallet = config.wallet;
  }

  async storeData(data: any, tags: { name: string; value: string }[] = []): Promise<string> {
    const transaction = await this.arweave.createTransaction({
      data: JSON.stringify(data)
    }, this.wallet);

    // Add tags for better data organization and querying
    tags.forEach(tag => {
      transaction.addTag(tag.name, tag.value);
    });

    await this.arweave.transactions.sign(transaction, this.wallet);
    await this.arweave.transactions.post(transaction);

    return transaction.id;
  }

  async storeBundle(items: { data: any; tags?: { name: string; value: string }[] }[]): Promise<string> {
    const bundle: DataBundle = {
      items: items.map(item => ({
        data: JSON.stringify(item.data),
        tags: item.tags || []
      }))
    };

    const signedBundle = await bundleAndSignData(bundle, this.wallet);
    const transaction = await this.arweave.createTransaction({
      data: JSON.stringify(signedBundle)
    }, this.wallet);

    transaction.addTag('Content-Type', 'application/json');
    transaction.addTag('Bundle-Format', 'json');
    transaction.addTag('Bundle-Version', '1.0.0');

    await this.arweave.transactions.sign(transaction, this.wallet);
    await this.arweave.transactions.post(transaction);

    return transaction.id;
  }

  async getData(transactionId: string): Promise<any> {
    const transaction = await this.arweave.transactions.get(transactionId);
    const data = transaction.get('data', { decode: true, string: true });
    return JSON.parse(data as string);
  }

  async getDataByTag(tagName: string, tagValue: string): Promise<any[]> {
    const query = `{
      transactions(
        tags: [
          { name: "${tagName}", values: ["${tagValue}"] }
        ]
      ) {
        edges {
          node {
            id
            data {
              size
            }
          }
        }
      }
    }`;

    const results = await this.arweave.api.post('graphql', { query });
    const transactions = results.data.data.transactions.edges;

    return Promise.all(
      transactions.map(async (tx: any) => {
        return this.getData(tx.node.id);
      })
    );
  }
} 