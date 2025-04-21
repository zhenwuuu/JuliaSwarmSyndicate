const fs = require('fs-extra');
const os = require('os');
const path = require('path');
const inquirer = require('inquirer');
const ora = require('ora');

const PREFERENCES_PATH = path.join(os.homedir(), '.juliaos', 'dex_preferences.json');

// Helper: Load preferences from file
async function loadPreferences() {
    try {
        if (await fs.pathExists(PREFERENCES_PATH)) {
            return await fs.readJson(PREFERENCES_PATH);
        }
    } catch (e) {}
    return {};
}

// Helper: Save preferences to file
async function savePreferences(prefs) {
    await fs.ensureDir(path.dirname(PREFERENCES_PATH));
    await fs.writeJson(PREFERENCES_PATH, prefs, { spaces: 2 });
}

// Helper: Get supported DEXes for a chain (try backend, fallback to static)
async function getSupportedDexes(juliaBridge, chainName) {
    try {
        const spinner = ora('Fetching supported DEXes from backend...').start();
        // Use the enhanced bridge to execute the command with better error handling
        const result = await juliaBridge.executeCommand('list_supported_dexes', { chain: chainName }, {
            showSpinner: false, // We're already showing our own spinner
            fallbackToMock: true // Allow fallback to mock data if backend is unavailable
        });
        spinner.stop();
        if (result && Array.isArray(result)) {
            return result;
        }
    } catch (e) {}
    // Fallback static mapping
    const staticDexes = {
        ethereum: ['uniswap_v3', 'sushiswap', 'curve', 'balancer', '1inch'],
        polygon: ['quickswap', 'uniswap_v3', 'sushiswap', 'curve', '1inch'],
        solana: ['raydium', 'orca', 'saber', 'jupiter'],
        arbitrum: ['uniswap_v3', 'sushiswap', 'curve', 'camelot', '1inch'],
        optimism: ['uniswap_v3', 'velodrome', 'curve', '1inch'],
        base: ['baseswap', 'aerodrome', 'balancer', '1inch'],
        avalanche: ['trader_joe', 'pangolin', 'curve', '1inch'],
        bsc: ['pancakeswap', 'biswap', 'apeswap', '1inch'],
        fantom: ['spookyswap', 'spiritswap', 'curve', '1inch']
    };
    return staticDexes[chainName] || [];
}

// Menu to select DEX preference for a chain
async function selectDexPreference(juliaBridge, currentChainName) {
    if (!currentChainName) {
        console.log('No chain selected or connected.');
        return;
    }
    const prefs = await loadPreferences();
    const dexes = await getSupportedDexes(juliaBridge, currentChainName);
    if (!dexes.length) {
        console.log(`No DEXes found for chain: ${currentChainName}`);
        return;
    }
    const { dex } = await inquirer.prompt([
        {
            type: 'list',
            name: 'dex',
            message: `Select your preferred DEX for ${currentChainName}:`,
            choices: dexes,
            default: prefs[currentChainName] || dexes[0]
        }
    ]);
    prefs[currentChainName] = dex;
    await savePreferences(prefs);
    console.log(`Preferred DEX for ${currentChainName} set to: ${dex}`);
}

// Get current DEX preference for a chain
async function getCurrentDexPreference(chainName) {
    const prefs = await loadPreferences();
    return prefs[chainName] || null;
}

module.exports = {
    selectDexPreference,
    getCurrentDexPreference
};