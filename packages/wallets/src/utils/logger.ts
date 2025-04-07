import { ethers } from 'ethers';

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR'
}

export interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  data?: any;
  error?: Error;
  transactionHash?: string;
  chainId?: number;
  address?: string;
}

export class WalletLogger {
  private static instance: WalletLogger;
  private logs: LogEntry[] = [];
  private readonly MAX_LOGS = 1000;
  private readonly LOG_LEVEL = process.env.NODE_ENV === 'production' ? LogLevel.INFO : LogLevel.DEBUG;

  private constructor() {}

  static getInstance(): WalletLogger {
    if (!WalletLogger.instance) {
      WalletLogger.instance = new WalletLogger();
    }
    return WalletLogger.instance;
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = Object.values(LogLevel);
    return levels.indexOf(level) >= levels.indexOf(this.LOG_LEVEL);
  }

  private formatLog(entry: LogEntry): string {
    const { timestamp, level, message, data, error, transactionHash, chainId, address } = entry;
    let logMessage = `[${timestamp}] ${level}: ${message}`;
    
    if (transactionHash) logMessage += ` | txHash: ${transactionHash}`;
    if (chainId) logMessage += ` | chainId: ${chainId}`;
    if (address) logMessage += ` | address: ${address}`;
    if (data) logMessage += ` | data: ${JSON.stringify(data)}`;
    if (error) logMessage += ` | error: ${error.message}`;
    
    return logMessage;
  }

  private addLog(entry: LogEntry): void {
    this.logs.push(entry);
    if (this.logs.length > this.MAX_LOGS) {
      this.logs.shift();
    }
  }

  debug(message: string, data?: any): void {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.DEBUG,
      message,
      data
    };
    
    this.addLog(entry);
    console.debug(this.formatLog(entry));
  }

  info(message: string, data?: any): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.INFO,
      message,
      data
    };
    
    this.addLog(entry);
    console.info(this.formatLog(entry));
  }

  warn(message: string, data?: any, error?: Error): void {
    if (!this.shouldLog(LogLevel.WARN)) return;
    
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.WARN,
      message,
      data,
      error
    };
    
    this.addLog(entry);
    console.warn(this.formatLog(entry));
  }

  error(message: string, error?: Error, data?: any): void {
    if (!this.shouldLog(LogLevel.ERROR)) return;
    
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.ERROR,
      message,
      error,
      data
    };
    
    this.addLog(entry);
    console.error(this.formatLog(entry));
  }

  logTransaction(
    message: string,
    transactionHash: string,
    chainId: number,
    address: string,
    data?: any
  ): void {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel.INFO,
      message,
      transactionHash,
      chainId,
      address,
      data
    };
    
    this.addLog(entry);
    console.info(this.formatLog(entry));
  }

  getLogs(level?: LogLevel): LogEntry[] {
    if (level) {
      return this.logs.filter(log => log.level === level);
    }
    return [...this.logs];
  }

  clearLogs(): void {
    this.logs = [];
  }

  // Performance monitoring
  private metrics: Map<string, number[]> = new Map();

  recordMetric(name: string, value: number): void {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, []);
    }
    this.metrics.get(name)!.push(value);
  }

  getMetricStats(name: string): { avg: number; min: number; max: number; count: number } | null {
    const values = this.metrics.get(name);
    if (!values || values.length === 0) return null;

    const sum = values.reduce((a, b) => a + b, 0);
    const min = Math.min(...values);
    const max = Math.max(...values);

    return {
      avg: sum / values.length,
      min,
      max,
      count: values.length
    };
  }

  clearMetrics(): void {
    this.metrics.clear();
  }
} 