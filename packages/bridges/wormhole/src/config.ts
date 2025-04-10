import { BridgeConfig } from './types';
import dotenv from 'dotenv';

dotenv.config();

export function loadConfig(): BridgeConfig {
  return {
    networks: {
      ethereum: {
        rpcUrl: process.env.ETHEREUM_RPC_URL || 'https://dry-capable-wildflower.quiknode.pro/2c509d168dcf3f71d49a4341f650c4b427be5b30',
        bridgeAddress: process.env.ETHEREUM_WORMHOLE_BRIDGE_ADDRESS || '0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B',
        tokenBridgeAddress: process.env.ETHEREUM_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0x3ee18B2214AFF97000D974cf647E7C347E8fa585',
        wormholeChainId: 2,
        nativeTokenDecimals: 18
      },
      solana: {
        rpcUrl: process.env.SOLANA_RPC_URL || 'https://cosmopolitan-restless-sunset.solana-mainnet.quiknode.pro/ca360edea8156bd1629813a9aaabbfceb5cc9d05',
        bridgeAddress: process.env.SOLANA_WORMHOLE_BRIDGE_ADDRESS || 'worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth',
        tokenBridgeAddress: process.env.SOLANA_WORMHOLE_TOKEN_BRIDGE_ADDRESS || 'wormDTUJ6AWPNvk59vGQbDvGJmqbDTdgWgAqcLBCgUb',
        wormholeChainId: 1,
        nativeTokenDecimals: 9
      },
      bsc: {
        rpcUrl: process.env.BSC_RPC_URL || 'https://still-magical-orb.bsc.quiknode.pro/e14cb1f002c159ce0eb678a480698dc2abd7846c',
        bridgeAddress: process.env.BSC_WORMHOLE_BRIDGE_ADDRESS || '0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B',
        tokenBridgeAddress: process.env.BSC_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0xB6F6D86a8f9879A9c87f643768d9efc38c1Da6E7',
        wormholeChainId: 4,
        nativeTokenDecimals: 18
      },
      avalanche: {
        rpcUrl: process.env.AVALANCHE_RPC_URL || 'https://green-cosmological-glade.avalanche-mainnet.quiknode.pro/aa5db7aa86b1576f08e44c51054d709f6698d485/ext/bc/C/rpc/',
        bridgeAddress: process.env.AVALANCHE_WORMHOLE_BRIDGE_ADDRESS || '0x54a8e5f9c4CbA08F9943965859F6c34eAF03E26c',
        tokenBridgeAddress: process.env.AVALANCHE_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0x0e082F06FF657D94310cB8cE8B0D9a04541d8052',
        wormholeChainId: 6,
        nativeTokenDecimals: 18
      },
      fantom: {
        rpcUrl: process.env.FANTOM_RPC_URL || 'https://distinguished-icy-meme.fantom.quiknode.pro/69343151a0265c018d02ecfbca4b62a6c011fe1b',
        bridgeAddress: process.env.FANTOM_WORMHOLE_BRIDGE_ADDRESS || '0x126783A6Cb203a3E35344528B26ca3a0489a1485',
        tokenBridgeAddress: process.env.FANTOM_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0x7C9Fc5741288cDFdD83CeB07f3ea7e22618D79D2',
        wormholeChainId: 10,
        nativeTokenDecimals: 18
      },
      arbitrum: {
        rpcUrl: process.env.ARBITRUM_RPC_URL || 'https://wiser-thrilling-pool.arbitrum-mainnet.quiknode.pro/f7b7ccfade9f3ac53e01aaaff329dd5565239945',
        bridgeAddress: process.env.ARBITRUM_WORMHOLE_BRIDGE_ADDRESS || '0xa5f208e072434bC67592E4C49C1B991BA79BCA46',
        tokenBridgeAddress: process.env.ARBITRUM_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0x0b2402144Bb366A632D14B83F244D2e0e21bD39c',
        wormholeChainId: 23,
        nativeTokenDecimals: 18
      },
      base: {
        rpcUrl: process.env.BASE_RPC_URL || 'https://withered-boldest-waterfall.base-mainnet.quiknode.pro/38ed3b981b066d4bd33984e96f6809e54d6c71b8',
        bridgeAddress: process.env.BASE_WORMHOLE_BRIDGE_ADDRESS || '0xbebdb6C8ddC678FfA9f8748f85C815C556Dd8ac6',
        tokenBridgeAddress: process.env.BASE_WORMHOLE_TOKEN_BRIDGE_ADDRESS || '0x8d2de8d2f73F1F4cAB472AC9A881C9b029C457Eb',
        wormholeChainId: 30,
        nativeTokenDecimals: 18
      }
    },
    privateKeys: {
      ethereum: process.env.ETHEREUM_PRIVATE_KEY || '',
      solana: process.env.SOLANA_PRIVATE_KEY || '',
      bsc: process.env.BSC_PRIVATE_KEY || '',
      avalanche: process.env.AVALANCHE_PRIVATE_KEY || '',
      fantom: process.env.FANTOM_PRIVATE_KEY || '',
      arbitrum: process.env.ARBITRUM_PRIVATE_KEY || '',
      base: process.env.BASE_PRIVATE_KEY || ''
    }
  };
}
