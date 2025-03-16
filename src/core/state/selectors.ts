/**
 * Selectors Module
 * 
 * This module provides utilities for creating and composing selectors for the state management system.
 * It includes memoization capabilities to improve performance by avoiding unnecessary recalculations.
 */

import { Selector, MemoizedSelector } from './types';

/**
 * Options for creating a memoized selector
 */
interface CreateSelectorOptions {
  /**
   * Maximum cache size
   */
  cacheSize?: number;
  
  /**
   * Custom cache key generation function
   */
  keySelector?: (...args: any[]) => string;
}

/**
 * Create a memoized selector from input selectors and a result function
 */
export function createSelector<S, R>(
  selectors: Selector<S, any>[], 
  resultFunc: (...args: any[]) => R,
  options: CreateSelectorOptions = {}
): MemoizedSelector<S, R> {
  const { cacheSize = 1, keySelector } = options;
  const cache = new Map<string, R>();
  const lastArgs: any[] = [];
  let lastResult: R;
  
  // Create the memoized selector function
  const memoizedSelector = ((state: S) => {
    // Get all the input values
    const args = selectors.map(selector => selector(state));
    
    // Generate cache key
    const cacheKey = keySelector 
      ? keySelector(...args) 
      : JSON.stringify(args);
    
    // Check if we have a cached value
    if (cache.has(cacheKey)) {
      return cache.get(cacheKey) as R;
    }
    
    // If args are the same as last time, return the cached result
    const argsMatch = args.length === lastArgs.length &&
      args.every((arg, i) => arg === lastArgs[i]);
    
    if (argsMatch) {
      return lastResult;
    }
    
    // Calculate new result
    const result = resultFunc(...args);
    
    // Update cache
    if (cache.size >= cacheSize) {
      const firstKey = cache.keys().next().value;
      cache.delete(firstKey);
    }
    cache.set(cacheKey, result);
    
    // Update last args and result
    lastArgs.length = 0;
    args.forEach(arg => lastArgs.push(arg));
    lastResult = result;
    
    return result;
  }) as MemoizedSelector<S, R>;
  
  // Add additional methods
  memoizedSelector.getDependencies = () => selectors;
  memoizedSelector.release = () => {
    cache.clear();
    lastArgs.length = 0;
  };
  memoizedSelector.cacheSize = () => cache.size;
  
  return memoizedSelector;
}

/**
 * Create a selector that creates a new object only if the input has changed
 */
export function createShallowSelector<S, R extends object>(
  inputSelector: Selector<S, R>
): MemoizedSelector<S, R> {
  let lastInput: R;
  let lastResult: R;
  
  const memoizedSelector = ((state: S) => {
    const input = inputSelector(state);
    
    // Return same result if input hasn't changed
    if (input === lastInput) {
      return lastResult;
    }
    
    lastInput = input;
    lastResult = { ...input };
    return lastResult;
  }) as MemoizedSelector<S, R>;
  
  // Add additional methods
  memoizedSelector.getDependencies = () => [inputSelector];
  memoizedSelector.release = () => {
    lastInput = undefined as any;
    lastResult = undefined as any;
  };
  memoizedSelector.cacheSize = () => (lastResult ? 1 : 0);
  
  return memoizedSelector;
}

/**
 * Create a selector that returns a subset of an object
 */
export function createPropertySelector<S, R extends object, K extends keyof R>(
  inputSelector: Selector<S, R>,
  propertyName: K
): Selector<S, R[K]> {
  return (state: S) => {
    const input = inputSelector(state);
    return input[propertyName];
  };
}

/**
 * Combine multiple selectors into one
 */
export function combineSelectors<S, R extends Record<string, any>>(
  selectorMap: { [K in keyof R]: Selector<S, R[K]> }
): Selector<S, R> {
  return (state: S) => {
    const result = {} as R;
    
    for (const key in selectorMap) {
      if (Object.prototype.hasOwnProperty.call(selectorMap, key)) {
        result[key] = selectorMap[key](state);
      }
    }
    
    return result;
  };
}

/**
 * Create a selector with default value if the result is undefined
 */
export function withDefaultValue<S, R>(
  selector: Selector<S, R | undefined>,
  defaultValue: R
): Selector<S, R> {
  return (state: S) => {
    const result = selector(state);
    return result === undefined ? defaultValue : result;
  };
}
