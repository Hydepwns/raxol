/**
 * Responsiveness Metrics Collector
 * 
 * Collects real-time data about application responsiveness.
 */

import { ResponsivenessMetrics } from './metrics';

/**
 * Configuration options for the responsiveness collector
 */
export interface ResponsivenessCollectorConfig {
  /**
   * Whether to automatically start collecting metrics
   * Default: true
   */
  autoStart?: boolean;
  
  /**
   * How often to calculate and report metrics, in milliseconds
   * Default: 5000 (5 seconds)
   */
  reportInterval?: number;
  
  /**
   * Maximum number of interactions to store in history
   * Default: 100
   */
  maxInteractionHistory?: number;
}

/**
 * Tracks an interaction from start to completion
 */
interface InteractionTracker {
  /**
   * Unique ID for this interaction
   */
  id: string;
  
  /**
   * Type of interaction (e.g., click, drag, keypress)
   */
  interactionType: string;
  
  /**
   * Component that was interacted with
   */
  componentId: string;
  
  /**
   * Timestamp when the interaction started
   */
  startTime: number;
  
  /**
   * Timestamp when the first visual response occurred
   * (used to calculate input latency)
   */
  firstResponseTime?: number;
  
  /**
   * Timestamp when the component became fully interactive
   */
  interactiveTime?: number;
  
  /**
   * Timestamp when the interaction completed
   */
  endTime?: number;
  
  /**
   * Frames dropped during this interaction
   */
  droppedFrames: number;
  
  /**
   * Total frames during this interaction
   */
  totalFrames: number;
  
  /**
   * Event processing timestamps
   */
  eventTimestamps: number[];
  
  /**
   * Additional metadata about the interaction
   */
  metadata?: Record<string, any>;
  
  /**
   * Whether this interaction has been completed
   */
  completed: boolean;
}

/**
 * Collects responsiveness metrics for the application
 */
export class ResponsivenessCollector {
  /**
   * Configuration for the collector
   */
  private config: Required<ResponsivenessCollectorConfig>;
  
  /**
   * Currently active interactions being tracked
   */
  private activeInteractions: Map<string, InteractionTracker> = new Map();
  
  /**
   * History of completed interactions
   */
  private interactionHistory: ResponsivenessMetrics[] = [];
  
  /**
   * Timer for regular reporting
   */
  private reportTimer: ReturnType<typeof setInterval> | null = null;
  
  /**
   * Listeners for responsiveness metrics
   */
  private listeners: Array<(metrics: ResponsivenessMetrics) => void> = [];
  
  /**
   * Creates a new ResponsivenessCollector
   */
  constructor(config?: ResponsivenessCollectorConfig) {
    this.config = {
      autoStart: config?.autoStart ?? true,
      reportInterval: config?.reportInterval ?? 5000,
      maxInteractionHistory: config?.maxInteractionHistory ?? 100
    };
    
    if (this.config.autoStart) {
      this.start();
    }
  }
  
  /**
   * Start collecting responsiveness metrics
   */
  public start(): void {
    if (this.reportTimer !== null) {
      return; // Already started
    }
    
    // Set up regular reporting
    this.reportTimer = setInterval(() => {
      this.generateReport();
    }, this.config.reportInterval);
    
    // Clean up any stale interactions (older than 30 seconds)
    setInterval(() => {
      const now = performance.now();
      for (const [id, interaction] of this.activeInteractions.entries()) {
        if (!interaction.completed && now - interaction.startTime > 30000) {
          // Interaction has been active for more than 30 seconds, consider it stale
          this.activeInteractions.delete(id);
        }
      }
    }, 10000); // Check every 10 seconds
  }
  
  /**
   * Stop collecting responsiveness metrics
   */
  public stop(): void {
    if (this.reportTimer !== null) {
      clearInterval(this.reportTimer);
      this.reportTimer = null;
    }
  }
  
  /**
   * Track the start of a user interaction
   */
  public trackInteractionStart(interactionType: string, componentId: string, metadata?: Record<string, any>): string {
    const id = `${interactionType}_${componentId}_${Date.now()}`;
    
    this.activeInteractions.set(id, {
      id,
      interactionType,
      componentId,
      startTime: performance.now(),
      droppedFrames: 0,
      totalFrames: 0,
      eventTimestamps: [],
      metadata,
      completed: false
    });
    
    return id;
  }
  
  /**
   * Track the first visual response to an interaction
   */
  public trackFirstResponse(interactionId: string): void {
    const interaction = this.activeInteractions.get(interactionId);
    if (interaction && !interaction.firstResponseTime) {
      interaction.firstResponseTime = performance.now();
    }
  }
  
  /**
   * Track when a component becomes interactive again
   */
  public trackInteractive(interactionId: string): void {
    const interaction = this.activeInteractions.get(interactionId);
    if (interaction && !interaction.interactiveTime) {
      interaction.interactiveTime = performance.now();
    }
  }
  
  /**
   * Track the completion of an interaction
   */
  public trackInteractionEnd(interactionId: string): ResponsivenessMetrics | null {
    const interaction = this.activeInteractions.get(interactionId);
    if (!interaction) {
      return null;
    }
    
    interaction.endTime = performance.now();
    interaction.completed = true;
    
    // Calculate metrics
    const metrics = this.calculateMetricsForInteraction(interaction);
    
    // Add to history
    this.addToHistory(metrics);
    
    // Remove from active interactions
    this.activeInteractions.delete(interactionId);
    
    // Notify listeners
    this.notifyListeners(metrics);
    
    return metrics;
  }
  
  /**
   * Track a frame being processed during an interaction
   */
  public trackFrame(interactionId: string, dropped: boolean): void {
    const interaction = this.activeInteractions.get(interactionId);
    if (interaction) {
      interaction.totalFrames++;
      if (dropped) {
        interaction.droppedFrames++;
      }
    }
  }
  
  /**
   * Track an event being processed
   */
  public trackEventProcessing(interactionId: string): void {
    const interaction = this.activeInteractions.get(interactionId);
    if (interaction) {
      interaction.eventTimestamps.push(performance.now());
    }
  }
  
  /**
   * Get the current interaction history
   */
  public getInteractionHistory(): ResponsivenessMetrics[] {
    return [...this.interactionHistory];
  }
  
  /**
   * Generate a report of current responsiveness metrics
   */
  public generateReport(): ResponsivenessMetrics | null {
    // If we don't have any completed interactions, return null
    if (this.interactionHistory.length === 0) {
      return null;
    }
    
    // Calculate average metrics from recent history
    const recentHistory = this.interactionHistory.slice(-10);
    
    const avgInputLatency = recentHistory.reduce((sum, m) => sum + m.inputLatency, 0) / recentHistory.length;
    const avgTimeToInteractive = recentHistory.reduce((sum, m) => sum + m.timeToInteractive, 0) / recentHistory.length;
    const avgFrameDropRate = recentHistory.reduce((sum, m) => sum + m.frameDropRate, 0) / recentHistory.length;
    const avgEventProcessingTime = recentHistory.reduce((sum, m) => sum + m.eventProcessingTime, 0) / recentHistory.length;
    
    // Calculate gesture response time if available
    let avgGestureResponseTime: number | undefined;
    const gestureMetrics = recentHistory.filter(m => m.gestureResponseTime !== undefined);
    if (gestureMetrics.length > 0) {
      avgGestureResponseTime = gestureMetrics.reduce((sum, m) => sum + (m.gestureResponseTime || 0), 0) / gestureMetrics.length;
    }
    
    const report: ResponsivenessMetrics = {
      inputLatency: avgInputLatency,
      timeToInteractive: avgTimeToInteractive,
      frameDropRate: avgFrameDropRate,
      eventProcessingTime: avgEventProcessingTime,
      gestureResponseTime: avgGestureResponseTime,
      context: {
        interactionType: 'aggregate',
        componentId: 'all',
        timestamp: Date.now()
      }
    };
    
    return report;
  }
  
  /**
   * Add a listener for responsiveness metrics
   */
  public addListener(callback: (metrics: ResponsivenessMetrics) => void): void {
    this.listeners.push(callback);
  }
  
  /**
   * Remove a listener
   */
  public removeListener(callback: (metrics: ResponsivenessMetrics) => void): void {
    this.listeners = this.listeners.filter(listener => listener !== callback);
  }
  
  /**
   * Calculate metrics for a completed interaction
   */
  private calculateMetricsForInteraction(interaction: InteractionTracker): ResponsivenessMetrics {
    const endTime = interaction.endTime || performance.now();
    
    // Input latency: time from interaction start to first visual response
    const inputLatency = interaction.firstResponseTime 
      ? interaction.firstResponseTime - interaction.startTime 
      : endTime - interaction.startTime;
    
    // Time to interactive: time from interaction start to component becoming fully interactive
    const timeToInteractive = interaction.interactiveTime 
      ? interaction.interactiveTime - interaction.startTime 
      : endTime - interaction.startTime;
    
    // Frame drop rate: percentage of frames dropped during the interaction
    const frameDropRate = interaction.totalFrames > 0 
      ? (interaction.droppedFrames / interaction.totalFrames) * 100 
      : 0;
    
    // Event processing time: average time between event timestamps
    let eventProcessingTime = 0;
    if (interaction.eventTimestamps.length > 1) {
      let totalTime = 0;
      for (let i = 1; i < interaction.eventTimestamps.length; i++) {
        totalTime += interaction.eventTimestamps[i] - interaction.eventTimestamps[i - 1];
      }
      eventProcessingTime = totalTime / (interaction.eventTimestamps.length - 1);
    }
    
    // Gesture response time: total time of the interaction (for gestures like drag)
    const gestureResponseTime = ['drag', 'swipe', 'pinch', 'pan'].includes(interaction.interactionType)
      ? endTime - interaction.startTime
      : undefined;
    
    return {
      inputLatency,
      timeToInteractive,
      frameDropRate,
      eventProcessingTime,
      gestureResponseTime,
      context: {
        interactionType: interaction.interactionType,
        componentId: interaction.componentId,
        timestamp: interaction.startTime,
        metadata: interaction.metadata
      }
    };
  }
  
  /**
   * Add metrics to the history, respecting the max history size
   */
  private addToHistory(metrics: ResponsivenessMetrics): void {
    this.interactionHistory.push(metrics);
    
    // Trim history if needed
    if (this.interactionHistory.length > this.config.maxInteractionHistory) {
      this.interactionHistory = this.interactionHistory.slice(-this.config.maxInteractionHistory);
    }
  }
  
  /**
   * Notify all listeners of new metrics
   */
  private notifyListeners(metrics: ResponsivenessMetrics): void {
    for (const listener of this.listeners) {
      try {
        listener(metrics);
      } catch (error) {
        console.error('Error in responsiveness metrics listener:', error);
      }
    }
  }
} 