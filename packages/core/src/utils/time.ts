/**
 * Sleep for a specified duration
 * @param ms Milliseconds to sleep
 * @returns Promise that resolves after the specified time
 */
export const sleep = (ms: number): Promise<void> => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

/**
 * Format a timestamp as ISO 8601 string
 * @param timestamp Timestamp to format (optional, defaults to now)
 * @returns ISO 8601 formatted date string
 */
export const formatTimestamp = (timestamp?: number | Date): string => {
  const date = timestamp ? new Date(timestamp) : new Date();
  return date.toISOString();
};

/**
 * Format a timestamp as a human-readable string
 * @param timestamp Timestamp to format (optional, defaults to now)
 * @returns Human-readable date string
 */
export const formatHumanReadable = (timestamp?: number | Date): string => {
  const date = timestamp ? new Date(timestamp) : new Date();
  return date.toLocaleString();
};

/**
 * Get current unix timestamp in seconds
 * @returns Current unix timestamp in seconds
 */
export const getUnixTimestamp = (): number => {
  return Math.floor(Date.now() / 1000);
};

/**
 * Get current unix timestamp in milliseconds
 * @returns Current unix timestamp in milliseconds
 */
export const getUnixTimestampMs = (): number => {
  return Date.now();
};

/**
 * Calculate time difference in milliseconds
 * @param start Start timestamp
 * @param end End timestamp (optional, defaults to now)
 * @returns Time difference in milliseconds
 */
export const calculateTimeDiff = (start: number, end: number = Date.now()): number => {
  return end - start;
};

/**
 * Format a duration in milliseconds to a human-readable string
 * @param ms Duration in milliseconds
 * @returns Human-readable duration string
 */
export const formatDuration = (ms: number): string => {
  if (ms < 1000) {
    return `${ms}ms`;
  }
  
  const seconds = Math.floor(ms / 1000);
  
  if (seconds < 60) {
    return `${seconds}s`;
  }
  
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  
  if (minutes < 60) {
    return `${minutes}m ${remainingSeconds}s`;
  }
  
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  
  if (hours < 24) {
    return `${hours}h ${remainingMinutes}m ${remainingSeconds}s`;
  }
  
  const days = Math.floor(hours / 24);
  const remainingHours = hours % 24;
  
  return `${days}d ${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s`;
};

/**
 * Check if a timestamp is expired
 * @param timestamp Timestamp to check
 * @param expiryMs Expiry time in milliseconds
 * @returns Whether the timestamp is expired
 */
export const isExpired = (timestamp: number, expiryMs: number): boolean => {
  return Date.now() - timestamp > expiryMs;
};

/**
 * Create a timeout with a promise interface
 * @param ms Milliseconds before timeout
 * @returns Promise that resolves after the specified time
 */
export const timeout = <T>(promise: Promise<T>, ms: number): Promise<T> => {
  let timeoutId: NodeJS.Timeout;
  
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`Operation timed out after ${ms}ms`));
    }, ms);
  });
  
  return Promise.race([
    promise.then(result => {
      clearTimeout(timeoutId);
      return result;
    }),
    timeoutPromise,
  ]);
};

/**
 * Execute a function with retry logic
 * @param fn Function to execute
 * @param retries Number of retries
 * @param delay Delay between retries in milliseconds
 * @param backoff Backoff multiplier for each retry
 * @returns Promise with the function result
 */
export const withRetry = async <T>(
  fn: () => Promise<T>,
  retries: number = 3,
  delay: number = 1000,
  backoff: number = 2
): Promise<T> => {
  try {
    return await fn();
  } catch (error) {
    if (retries <= 0) {
      throw error;
    }
    
    await sleep(delay);
    
    return withRetry(fn, retries - 1, delay * backoff, backoff);
  }
}; 