export interface JuliaBridgeOptions {
  apiUrl?: string;
  useWebSocket?: boolean;
  useExistingServer?: boolean;
  timeout?: number;
}

export interface CommandResponse {
  status: string;
  result?: any;
  error?: string;
  timestamp: string;
}
