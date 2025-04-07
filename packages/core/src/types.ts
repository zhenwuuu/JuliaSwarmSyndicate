export enum ChainId {
  ETHEREUM = 1,
  POLYGON = 137,
  ARBITRUM = 42161,
  OPTIMISM = 10,
  BASE = 8453,
  BSC = 56,
  AVALANCHE = 43114,
  SOLANA = -1 // Using -1 for Solana since it doesn't use EVM chain IDs
}

export interface Token {
  address: string;
  decimals: number;
  symbol?: string;
  name?: string;
}

export class TokenAmount {
  private value: bigint;
  private decimals: number;

  constructor(value: bigint | string | number, decimals: number) {
    this.value = BigInt(value);
    this.decimals = decimals;
  }

  static fromRaw(value: string | number, decimals: number): TokenAmount {
    return new TokenAmount(value, decimals);
  }

  static zero(): TokenAmount {
    return new TokenAmount(0, 0);
  }

  mul(other: TokenAmount): TokenAmount {
    return new TokenAmount(this.value * other.value, this.decimals + other.decimals);
  }

  div(other: TokenAmount): TokenAmount {
    return new TokenAmount(this.value / other.value, this.decimals - other.decimals);
  }

  add(other: TokenAmount): TokenAmount {
    return new TokenAmount(this.value + other.value, this.decimals);
  }

  gt(other: TokenAmount): boolean {
    return this.value > other.value;
  }

  toString(): string {
    return this.value.toString();
  }

  toNumber(): number {
    return Number(this.value) / Math.pow(10, this.decimals);
  }
} 