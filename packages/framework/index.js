/**
 * JuliaOS Framework
 * 
 * This is the main entry point for the JuliaOS Framework.
 * It exports all the modules that make up the framework.
 */

// Import modules
const JuliaBridge = require('@juliaos/julia-bridge');
const Swarms = require('./swarms/src');

// Export modules
module.exports = {
  JuliaBridge,
  Swarms
};
