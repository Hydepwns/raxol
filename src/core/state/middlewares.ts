/**
 * Middlewares for State Management
 * 
 * This file contains common middleware implementations for the state management system,
 * including logging, thunk for async actions, and performance monitoring.
 */

import { Middleware, Action, MiddlewareStore } from './types';

/**
 * Options for logger middleware
 */
export interface LoggerOptions {
  /**
   * Log level
   */
  level?: 'debug' | 'info' | 'warn' | 'error';
  
  /**
   * Whether to collapse log groups
   */
  collapsed?: boolean;
  
  /**
   * Custom logger function
   */
  logger?: typeof console;
  
  /**
   * Predicate to filter which actions to log
   */
  predicate?: (state: any, action: Action) => boolean;
  
  /**
   * Transform state before logging
   */
  stateTransformer?: (state: any) => any;
  
  /**
   * Transform action before logging
   */
  actionTransformer?: (action: Action) => any;
  
  /**
   * Custom title formatter
   */
  titleFormatter?: (action: Action) => string;
  
  /**
   * Custom diff formatter
   */
  diffFormatter?: (prevState: any, nextState: any) => string;
}

/**
 * Create a logger middleware
 */
export function createLogger(options: LoggerOptions = {}): Middleware {
  const {
    level = 'info',
    collapsed = false,
    logger = console,
    predicate = () => true,
    stateTransformer = state => state,
    actionTransformer = action => action,
    titleFormatter = action => `Action: ${action.type}`,
    diffFormatter = (prev, next) => `Changed keys: ${Object.keys(next).filter(key => prev[key] !== next[key])}`
  } = options;
  
  return (store: MiddlewareStore) => (next) => (action: Action) => {
    // Check if we should log this action
    if (!predicate(store.getState(), action)) {
      return next(action);
    }
    
    // Get start time
    const startTime = Date.now();
    const prevState = stateTransformer(store.getState());
    
    // Format the action title
    const title = titleFormatter(actionTransformer(action));
    
    // Console group or group collapsed based on option
    const logMethod = collapsed ? 'groupCollapsed' : 'group';
    
    // Log group title with appropriate level
    if (level === 'debug' && typeof logger.debug === 'function') {
      logger.debug(`%c ${title}`, 'color: #9E9E9E; font-weight: bold');
    } else {
      logger[logMethod](`%c ${title}`, 'color: #9E9E9E; font-weight: bold');
    }
    
    // Log previous state
    logger.log('%c Previous State', 'color: #9E9E9E; font-weight: bold', prevState);
    
    // Log action
    logger.log('%c Action', 'color: #03A9F4; font-weight: bold', actionTransformer(action));
    
    // Perform the action
    const result = next(action);
    
    // Calculate execution time
    const execTime = Date.now() - startTime;
    
    // Get next state
    const nextState = stateTransformer(store.getState());
    
    // Log next state
    logger.log('%c Next State', 'color: #4CAF50; font-weight: bold', nextState);
    
    // Log state diff
    logger.log('%c Diff', 'color: #FF9800; font-weight: bold', diffFormatter(prevState, nextState));
    
    // Log execution time
    logger.log('%c Execution time', 'color: #9E9E9E; font-weight: bold', `${execTime}ms`);
    
    logger.groupEnd();
    
    return result;
  };
}

/**
 * Thunk middleware for async actions
 */
export const thunk: Middleware = (store) => (next) => (action) => {
  // If action is a function, invoke it with dispatch and getState
  if (typeof action === 'function') {
    return action(store.dispatch, store.getState);
  }
  
  // Otherwise, continue processing this action
  return next(action);
};

/**
 * Performance monitoring middleware
 */
export function createPerformanceMonitor(threshold = 16): Middleware {
  return (store) => (next) => (action) => {
    const startTime = performance.now();
    const result = next(action);
    const endTime = performance.now();
    const duration = endTime - startTime;
    
    // Log slow actions
    if (duration > threshold) {
      console.warn(`Action '${action.type}' took ${duration.toFixed(2)}ms to process. This may cause UI lag.`);
    }
    
    return result;
  };
}

/**
 * Error handling middleware
 */
export const errorHandler: Middleware = (store) => (next) => (action) => {
  try {
    return next(action);
  } catch (err) {
    console.error('Error processing action:', action);
    console.error(err);
    
    // Dispatch an error action
    store.dispatch({
      type: '@@raxol/ERROR',
      error: true,
      payload: err,
      meta: { originalAction: action }
    });
    
    // Re-throw the error for upstream handling
    throw err;
  }
};

/**
 * Debounce actions middleware
 */
export function createDebounce(wait = 300): Middleware {
  const pending: Record<string, NodeJS.Timeout> = {};
  
  return (store) => (next) => (action) => {
    // Check if this action should be debounced
    if (action.meta?.debounce) {
      const { time = wait, key = action.type } = action.meta.debounce;
      
      // Clear the timeout if it exists
      if (pending[key]) {
        clearTimeout(pending[key]);
      }
      
      // Create a new timeout
      pending[key] = setTimeout(() => {
        delete pending[key];
        next(action);
      }, time);
      
      return;
    }
    
    // Otherwise, continue processing this action
    return next(action);
  };
}

/**
 * Local storage persistence middleware
 */
export function createPersistenceMiddleware(
  key = 'raxol-state',
  paths: string[] = [],
  storage = localStorage
): Middleware {
  return (store) => {
    // Load persisted state on startup
    try {
      const persistedData = storage.getItem(key);
      if (persistedData) {
        const state = JSON.parse(persistedData);
        store.dispatch({ type: '@@raxol/REHYDRATE', payload: state });
      }
    } catch (err) {
      console.error('Failed to load persisted state:', err);
    }
    
    return (next) => (action) => {
      // Process the action
      const result = next(action);
      
      // Only persist after state changes
      if (action.type !== '@@raxol/REHYDRATE') {
        try {
          const state = store.getState();
          
          // Extract only the specified paths if any
          const persistedState = paths.length > 0
            ? paths.reduce((acc, path) => {
                const parts = path.split('.');
                let value = state;
                
                for (const part of parts) {
                  value = value[part];
                  if (value === undefined) break;
                }
                
                if (value !== undefined) {
                  // Set nested path
                  let currentObj = acc;
                  const lastPart = parts.pop() as string;
                  
                  for (const part of parts) {
                    if (!currentObj[part]) currentObj[part] = {};
                    currentObj = currentObj[part];
                  }
                  
                  currentObj[lastPart] = value;
                }
                
                return acc;
              }, {} as Record<string, any>)
            : state;
          
          storage.setItem(key, JSON.stringify(persistedState));
        } catch (err) {
          console.error('Failed to persist state:', err);
        }
      }
      
      return result;
    };
  };
}
