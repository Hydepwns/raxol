/**
 * Store Module
 * 
 * This module provides the core store implementation for the state management system.
 * It includes support for reducers, middleware, and state subscription.
 */

import {
  Store,
  Reducer,
  Action,
  Listener,
  Unsubscribe,
  Middleware,
  StoreEnhancer,
  StoreCreator,
  Selector,
  StateSlice
} from './types';

/**
 * Create a store that holds the state tree.
 */
export function createStore<S = any>(
  reducer: Reducer<S>,
  initialState?: S,
  enhancer?: StoreEnhancer<S>
): Store<S> {
  // Handle enhancer if provided
  if (typeof enhancer === 'function') {
    return enhancer(createStore)(reducer, initialState);
  }
  
  // Store state
  let currentState = initialState as S;
  let currentReducer = reducer;
  let listeners: Listener[] = [];
  let isDispatching = false;
  
  /**
   * Get the current state
   */
  function getState(): S {
    if (isDispatching) {
      throw new Error('Cannot call getState() while dispatching');
    }
    
    return currentState;
  }
  
  /**
   * Add a listener for state changes
   */
  function subscribe(listener: Listener): Unsubscribe {
    if (isDispatching) {
      throw new Error('Cannot subscribe while dispatching');
    }
    
    // Add the listener
    listeners.push(listener);
    let isSubscribed = true;
    
    // Return unsubscribe function
    return function unsubscribe() {
      if (!isSubscribed) {
        return;
      }
      
      if (isDispatching) {
        throw new Error('Cannot unsubscribe while dispatching');
      }
      
      isSubscribed = false;
      listeners = listeners.filter(l => l !== listener);
    };
  }
  
  /**
   * Dispatch an action to update state
   */
  function dispatch(action: Action): Action {
    if (isDispatching) {
      throw new Error('Cannot dispatch while dispatching');
    }
    
    try {
      isDispatching = true;
      
      // Apply the reducer to get the new state
      currentState = currentReducer(currentState, action);
    } finally {
      isDispatching = false;
    }
    
    // Notify all listeners
    listeners.forEach(listener => listener());
    
    return action;
  }
  
  /**
   * Replace the current reducer
   */
  function replaceReducer(nextReducer: Reducer<S>): void {
    if (typeof nextReducer !== 'function') {
      throw new Error('Expected the next reducer to be a function');
    }
    
    currentReducer = nextReducer;
    dispatch({ type: '@@raxol/REPLACE' });
  }
  
  /**
   * Select a portion of state using a selector
   */
  function select<R>(selector: Selector<S, R>): R {
    return selector(getState());
  }
  
  // Dispatch a dummy action to initialize the store with the initial state
  dispatch({ type: '@@raxol/INIT' });
  
  return {
    getState,
    dispatch,
    subscribe,
    replaceReducer,
    select
  };
}

/**
 * Apply middleware to the store
 */
export function applyMiddleware<S = any>(...middlewares: Middleware[]): StoreEnhancer<S> {
  return (createStore: StoreCreator<S>) => (
    reducer: Reducer<S>,
    initialState?: S
  ): Store<S> => {
    // Create the store
    const store = createStore(reducer, initialState);
    
    // Store a reference to the original dispatch function
    let dispatch = store.dispatch;
    
    // Create a middleware API that only exposes getState and dispatch
    const middlewareAPI = {
      getState: store.getState,
      dispatch: (action: Action) => dispatch(action)
    };
    
    // Apply each middleware to the API
    const chain = middlewares.map(middleware => middleware(middlewareAPI));
    
    // Compose all the middleware-enhanced dispatch functions
    dispatch = compose(...chain)(store.dispatch);
    
    // Return the store with the enhanced dispatch
    return {
      ...store,
      dispatch
    };
  };
}

/**
 * Compose functions from right to left.
 */
export function compose(...funcs: Function[]): Function {
  if (funcs.length === 0) {
    return (arg: any) => arg;
  }
  
  if (funcs.length === 1) {
    return funcs[0];
  }
  
  // Compose all functions into a single one
  return funcs.reduce((a, b) => (...args: any[]) => a(b(...args)));
}

/**
 * Combine multiple reducers into a single reducer.
 */
export function combineReducers<S>(
  reducers: { [K in keyof S]: Reducer<S[K]> }
): Reducer<S> {
  // Get the keys of the reducers object
  const reducerKeys = Object.keys(reducers) as (keyof S)[];
  
  // Return a combined reducer function
  return function combinedReducer(state: S = {} as S, action: Action): S {
    // Check if any reducer changes the state
    let hasChanged = false;
    const nextState = {} as S;
    
    // Apply each reducer to its corresponding state slice
    for (const key of reducerKeys) {
      const reducer = reducers[key];
      const previousStateForKey = state[key];
      const nextStateForKey = reducer(previousStateForKey, action);
      
      // Store the new state
      nextState[key] = nextStateForKey;
      
      // Check if state has changed
      hasChanged = hasChanged || nextStateForKey !== previousStateForKey;
    }
    
    // Return the new state if changed, otherwise return the original state
    return hasChanged ? nextState : state;
  };
}

/**
 * Create a slice of state with its own reducer and actions.
 */
export function createSlice<S = any>(slice: StateSlice<S>): {
  name: string;
  reducer: Reducer<S>;
  actions: Record<string, Function>;
  initialState: S;
} {
  const { name, initialState, reducer, actions } = slice;
  
  // Create the action creators with the slice name
  const actionCreators: Record<string, Function> = {};
  
  for (const key in actions) {
    if (Object.prototype.hasOwnProperty.call(actions, key)) {
      const actionCreator = actions[key];
      
      // Convert action creators to include the slice name in the type
      actionCreators[key] = (...args: any[]) => {
        const action = actionCreator(...args);
        
        // If this is an async action creator, wrap it
        if (typeof action === 'function') {
          return action;
        }
        
        // Otherwise, make sure the action type includes the slice name
        if (!action.type.includes(`${name}/`)) {
          return {
            ...action,
            type: `${name}/${action.type}`
          };
        }
        
        return action;
      };
    }
  }
  
  return {
    name,
    reducer,
    actions: actionCreators,
    initialState
  };
}
