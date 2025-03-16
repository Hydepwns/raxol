/**
 * State Management System Types
 * 
 * This file defines the types used in the Raxol advanced state management system.
 */

/**
 * Action type for state changes
 */
export interface Action<T = any> {
  /**
   * Unique identifier for the action type
   */
  type: string;
  
  /**
   * Optional payload data
   */
  payload?: T;
  
  /**
   * Optional metadata
   */
  meta?: Record<string, any>;
  
  /**
   * Optional error flag
   */
  error?: boolean;
}

/**
 * Reducer function type
 */
export type Reducer<S = any, A extends Action = Action> = (
  state: S,
  action: A
) => S;

/**
 * Middleware interface
 */
export type Middleware<S = any> = (
  store: MiddlewareStore<S>
) => (next: (action: Action) => any) => (action: Action) => any;

/**
 * Store API exposed to middleware
 */
export interface MiddlewareStore<S = any> {
  getState(): S;
  dispatch(action: Action): any;
}

/**
 * Subscription callback
 */
export type Listener = () => void;

/**
 * Unsubscribe function
 */
export type Unsubscribe = () => void;

/**
 * Selector function
 */
export type Selector<S = any, R = any> = (state: S) => R;

/**
 * Store interface
 */
export interface Store<S = any> {
  /**
   * Get the current state
   */
  getState(): S;
  
  /**
   * Dispatch an action to update state
   */
  dispatch(action: Action): Action;
  
  /**
   * Subscribe to store changes
   */
  subscribe(listener: Listener): Unsubscribe;
  
  /**
   * Replace the current reducer
   */
  replaceReducer(nextReducer: Reducer<S>): void;
  
  /**
   * Select a portion of state using a selector
   */
  select<R>(selector: Selector<S, R>): R;
}

/**
 * Store enhancer function
 */
export type StoreEnhancer<S = any> = (
  createStore: StoreCreator<S>
) => StoreCreator<S>;

/**
 * Store creator function
 */
export type StoreCreator<S = any> = (
  reducer: Reducer<S>,
  initialState?: S
) => Store<S>;

/**
 * Action creator function
 */
export type ActionCreator<P = any> = (payload?: P) => Action<P>;

/**
 * Async action creator function
 */
export type AsyncActionCreator<P = any, R = any> = (
  payload?: P
) => (dispatch: Store['dispatch'], getState: Store['getState']) => Promise<R>;

/**
 * Memoized selector with dependencies
 */
export interface MemoizedSelector<S = any, R = any> extends Selector<S, R> {
  /**
   * Get dependencies of this selector
   */
  getDependencies(): Selector<S, any>[];
  
  /**
   * Reset memoization cache
   */
  release(): void;
  
  /**
   * Get memoization cache size
   */
  cacheSize(): number;
}

/**
 * Component connection options
 */
export interface ConnectOptions {
  /**
   * Whether to shallow compare state changes
   */
  shallowCompare?: boolean;
  
  /**
   * Whether to forward refs
   */
  forwardRef?: boolean;
  
  /**
   * Pure component optimization
   */
  pure?: boolean;
}

/**
 * State slice definition
 */
export interface StateSlice<S = any> {
  /**
   * Slice name
   */
  name: string;
  
  /**
   * Initial state
   */
  initialState: S;
  
  /**
   * Reducer function
   */
  reducer: Reducer<S>;
  
  /**
   * Action creators
   */
  actions: Record<string, ActionCreator | AsyncActionCreator>;
  
  /**
   * Selectors for this slice
   */
  selectors?: Record<string, Selector<any, any>>;
}
