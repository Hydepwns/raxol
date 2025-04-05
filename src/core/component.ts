/**
 * component.ts
 * 
 * Core component system for Raxol.
 * Provides base component functionality for UI elements.
 */

import { View, ViewElement } from './renderer/view';

/**
 * Base component class for Raxol UI components
 */
export abstract class RaxolComponent<Props = any, State = any> {
  /**
   * Component props
   */
  protected props: Props;
  
  /**
   * Component state
   */
  protected state: State;
  
  /**
   * Component ID
   */
  protected id: string;
  
  /**
   * Constructor
   */
  constructor(props: Props) {
    this.props = props;
    this.state = {} as State;
    this.id = this.generateId();
  }
  
  /**
   * Generate a unique component ID
   */
  private generateId(): string {
    return `raxol-component-${Math.random().toString(36).substring(2, 9)}`;
  }
  
  /**
   * Set component state
   */
  protected setState(newState: Partial<State>): void {
    this.state = { ...this.state, ...newState };
  }
  
  /**
   * Render the component
   */
  abstract render(): ViewElement;
  
  /**
   * Clean up resources when component is destroyed
   */
  destroy(): void {
    // Default implementation does nothing
  }
} 