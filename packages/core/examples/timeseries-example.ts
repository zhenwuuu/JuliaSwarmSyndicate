/**
 * Example of using TimeSeriesBridge for advanced time series operations
 * 
 * This example demonstrates how to:
 * 1. Initialize the TimeSeriesBridge
 * 2. Decompose a time series
 * 3. Forecast a time series
 * 4. Detect anomalies
 */

import { JuliaBridge } from '../src/bridge/JuliaBridge';
import { TimeSeriesBridge } from '../src/bridge/TimeSeriesBridge';
import * as TimeSeriesTypes from '../src/types/TimeSeriesTypes';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Generate a sample time series with trend and seasonality
function generateSampleTimeSeries(length: number, withAnomaly: boolean = false): TimeSeriesTypes.TimeSeries {
  // Create a time series with trend and seasonal components
  const points: TimeSeriesTypes.TimeSeriesPoint[] = [];
  const startDate = new Date(2023, 0, 1);  // Jan 1, 2023
  
  for (let i = 0; i < length; i++) {
    // Trend component: linear increase
    const trend = 0.05 * i;
    
    // Seasonal component: weekly pattern (7-day cycle)
    const seasonal = 2 * Math.sin(2 * Math.PI * i / 7);
    
    // Random noise
    const noise = Math.random() - 0.5;
    
    // Combine components
    let value = trend + seasonal + noise;
    
    // Add an anomaly if requested
    if (withAnomaly && i === Math.floor(length / 2)) {
      value += 5;  // Spike in the middle of the series
    }
    
    // Create timestamp (daily data)
    const timestamp = new Date(startDate);
    timestamp.setDate(startDate.getDate() + i);
    
    points.push({
      timestamp,
      value
    });
  }
  
  return {
    points,
    name: "Sample Time Series",
    frequency: "daily"
  };
}

async function runExample() {
  console.log('Starting time series example...');

  // Create Julia bridge instance
  const bridge = new JuliaBridge();

  try {
    // Initialize bridge
    console.log('Initializing Julia bridge...');
    await bridge.initialize();
    console.log('Bridge initialized successfully');

    // Create TimeSeriesBridge
    const tsBridge = new TimeSeriesBridge(bridge);
    
    // Initialize time series module
    console.log('Initializing time series module...');
    await tsBridge.initialize();
    console.log('Time series module initialized');

    // Generate sample time series
    console.log('Generating sample time series...');
    const regularTs = generateSampleTimeSeries(90);  // 90 days = ~3 months
    const anomalyTs = generateSampleTimeSeries(90, true);  // With anomaly
    
    // Plot the time series (just print values)
    console.log('Sample time series values:');
    console.log(regularTs.points.slice(0, 10).map(point => 
      `${point.timestamp.toISOString().slice(0, 10)}: ${point.value.toFixed(2)}`
    ));
    console.log('...');

    // Decompose the time series
    console.log('\nDecomposing time series...');
    const decomposition = await tsBridge.decomposeTimeSeries(regularTs, {
      method: 'seasonal',
      period: 7  // Weekly seasonality
    });
    
    // Print decomposition results
    console.log('Decomposition Results:');
    console.log(`Trend (first 5 values): ${decomposition.trend.slice(0, 5).map(v => v.toFixed(2)).join(', ')}`);
    console.log(`Seasonal (first 7 values): ${decomposition.seasonal.slice(0, 7).map(v => v.toFixed(2)).join(', ')}`);
    console.log(`Residual (first 5 values): ${decomposition.residual.slice(0, 5).map(v => v.toFixed(2)).join(', ')}`);

    // Forecast the time series
    console.log('\nForecasting time series...');
    const forecast = await tsBridge.forecastTimeSeries(regularTs, {
      method: 'arima',
      horizon: 14,  // Forecast 14 days ahead
      order: [1, 1, 1]  // ARIMA(1,1,1)
    });
    
    // Print forecast results
    console.log('Forecast Results:');
    console.log(`Forecast (14 days): ${forecast.forecast.map(v => v.toFixed(2)).join(', ')}`);
    if (forecast.lowerBound && forecast.upperBound) {
      console.log(`Lower Bound: ${forecast.lowerBound.map(v => v.toFixed(2)).join(', ')}`);
      console.log(`Upper Bound: ${forecast.upperBound.map(v => v.toFixed(2)).join(', ')}`);
    }

    // Detect anomalies
    console.log('\nDetecting anomalies...');
    const anomalies = await tsBridge.detectAnomalies(anomalyTs, {
      method: 'zscore',
      threshold: 3.0
    });
    
    // Print anomaly detection results
    console.log('Anomaly Detection Results:');
    console.log(`Detected ${anomalies.anomalies.length} anomalies at indices: ${anomalies.anomalies.join(', ')}`);
    
    // For each anomaly, print the date and value
    console.log('Anomaly details:');
    for (const idx of anomalies.anomalies) {
      const point = anomalyTs.points[idx];
      console.log(`Anomaly at ${point.timestamp.toISOString().slice(0, 10)}: value = ${point.value.toFixed(2)}`);
    }

    // Calculate cross-correlation between regular and anomaly time series
    console.log('\nCalculating cross-correlation...');
    const xcorr = await tsBridge.calculateCrossCorrelation(regularTs, anomalyTs, 5);
    
    // Print cross-correlation results
    console.log('Cross-correlation Results:');
    console.log(`Lags: ${xcorr.lags.join(', ')}`);
    console.log(`Correlations: ${xcorr.correlations.map(v => v.toFixed(2)).join(', ')}`);
    
  } catch (error) {
    console.error('Error in time series example:', error);
  } finally {
    // Stop the bridge
    console.log('Stopping Julia bridge...');
    await bridge.stop();
    console.log('Bridge stopped');
  }
}

// Run the example
runExample().catch(console.error); 