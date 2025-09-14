/**
 * Renderer System Utilities
 * 
 * This module provides utilities for UI rendering, update batching, and view management
 * for high-performance rendering in Raxol applications.
 */

// Types for renderer system
export interface UIUpdate {
  id: string;
  component: string;
  type: 'render' | 'update' | 'layout' | 'style';
  payload: any;
  timestamp: number;
  priority: 'low' | 'normal' | 'high';
  completed: boolean;
}

export interface RenderFrame {
  frameId: string;
  updates: UIUpdate[];
  startTime: number;
  endTime?: number;
  duration?: number;
}

export interface ViewConfig {
  id: string;
  element?: HTMLElement;
  template?: string;
  data?: any;
  events?: Record<string, (event: Event) => void>;
}

// Global renderer state
let updateIdCounter = 0;
const pendingUpdates: UIUpdate[] = [];
const renderFrames: RenderFrame[] = [];
let isRendering = false;
let currentFrameId = '';

/**
 * Generate a unique update ID
 */
function generateUpdateId(): string {
  return `update_${++updateIdCounter}_${Date.now()}`;
}

/**
 * Queue a UI update for batched processing
 */
export function queueUIUpdate(
  component: string, 
  type: UIUpdate['type'], 
  payload: any, 
  priority: UIUpdate['priority'] = 'normal'
): string {
  const update: UIUpdate = {
    id: generateUpdateId(),
    component,
    type,
    payload,
    timestamp: Date.now(),
    priority,
    completed: false
  };

  pendingUpdates.push(update);

  // Schedule rendering if not already scheduled
  if (!isRendering) {
    scheduleRender();
  }

  return update.id;
}

/**
 * Get the count of pending UI updates
 */
export function getPendingUpdateCount(): number {
  return pendingUpdates.length;
}

/**
 * Schedule rendering using requestAnimationFrame
 */
function scheduleRender(): void {
  if (isRendering) return;

  isRendering = true;

  // Use requestAnimationFrame if available, otherwise setTimeout
  const scheduler = typeof requestAnimationFrame !== 'undefined' 
    ? requestAnimationFrame 
    : (callback: () => void) => setTimeout(callback, 16);

  scheduler(() => {
    processRenderFrame();
    isRendering = false;
  });
}

/**
 * Process all pending updates in a single render frame
 */
function processRenderFrame(): void {
  if (pendingUpdates.length === 0) return;

  const frameId = `frame_${Date.now()}`;
  currentFrameId = frameId;

  const renderFrame: RenderFrame = {
    frameId,
    updates: [],
    startTime: performance.now()
  };

  // Sort updates by priority (high -> normal -> low)
  const sortedUpdates = [...pendingUpdates].sort((a, b) => {
    const priorityOrder = { high: 3, normal: 2, low: 1 };
    return priorityOrder[b.priority] - priorityOrder[a.priority];
  });

  // Process all updates in this frame
  while (pendingUpdates.length > 0) {
    const update = pendingUpdates.shift()!;
    renderFrame.updates.push(update);
    processUIUpdate(update);
  }

  renderFrame.endTime = performance.now();
  renderFrame.duration = renderFrame.endTime - renderFrame.startTime;
  renderFrames.push(renderFrame);

  // Keep only the last 100 frames to prevent memory leaks
  while (renderFrames.length > 100) {
    renderFrames.shift();
  }

  console.log(`Render frame ${frameId} completed: ${renderFrame.updates.length} updates in ${renderFrame.duration?.toFixed(2)}ms`);
}

/**
 * Process a single UI update
 */
function processUIUpdate(update: UIUpdate): void {
  try {
    switch (update.type) {
      case 'render':
        processRenderUpdate(update);
        break;
      case 'update':
        processComponentUpdate(update);
        break;
      case 'layout':
        processLayoutUpdate(update);
        break;
      case 'style':
        processStyleUpdate(update);
        break;
      default:
        console.warn(`Unknown update type: ${update.type}`);
    }

    update.completed = true;
  } catch (error) {
    console.error(`Error processing UI update ${update.id}:`, error);
  }
}

/**
 * Process a render update
 */
function processRenderUpdate(update: UIUpdate): void {
  console.log(`Rendering component: ${update.component}`, update.payload);
  
  // In a real implementation, this would trigger component re-render
  if (typeof window !== 'undefined') {
    const customEvent = new CustomEvent('raxol:render', {
      detail: {
        component: update.component,
        payload: update.payload
      }
    });
    window.dispatchEvent(customEvent);
  }
}

/**
 * Process a component update
 */
function processComponentUpdate(update: UIUpdate): void {
  console.log(`Updating component: ${update.component}`, update.payload);
  
  // In a real implementation, this would update component state/props
  if (typeof window !== 'undefined') {
    const customEvent = new CustomEvent('raxol:update', {
      detail: {
        component: update.component,
        payload: update.payload
      }
    });
    window.dispatchEvent(customEvent);
  }
}

/**
 * Process a layout update
 */
function processLayoutUpdate(update: UIUpdate): void {
  console.log(`Layout update for: ${update.component}`, update.payload);
  
  // In a real implementation, this would trigger layout calculations
  if (typeof window !== 'undefined') {
    const customEvent = new CustomEvent('raxol:layout', {
      detail: {
        component: update.component,
        payload: update.payload
      }
    });
    window.dispatchEvent(customEvent);
  }
}

/**
 * Process a style update
 */
function processStyleUpdate(update: UIUpdate): void {
  console.log(`Style update for: ${update.component}`, update.payload);
  
  // In a real implementation, this would apply CSS changes
  if (typeof window !== 'undefined') {
    const customEvent = new CustomEvent('raxol:style', {
      detail: {
        component: update.component,
        payload: update.payload
      }
    });
    window.dispatchEvent(customEvent);
  }
}

/**
 * View class for managing UI components
 */
export class View {
  private config: ViewConfig;
  private element?: HTMLElement;

  constructor(config: ViewConfig) {
    this.config = config;
    this.initialize();
  }

  private initialize(): void {
    if (this.config.element) {
      this.element = this.config.element;
    } else if (typeof document !== 'undefined') {
      this.element = document.createElement('div');
      this.element.id = this.config.id;
    }

    if (this.element && this.config.template) {
      this.element.innerHTML = this.config.template;
    }

    this.bindEvents();
  }

  private bindEvents(): void {
    if (!this.element || !this.config.events) return;

    Object.entries(this.config.events).forEach(([eventType, handler]) => {
      this.element!.addEventListener(eventType, handler);
    });
  }

  public render(data?: any): void {
    const renderData = data || this.config.data;
    
    queueUIUpdate(this.config.id, 'render', renderData, 'normal');
  }

  public update(data: any): void {
    this.config.data = { ...this.config.data, ...data };
    queueUIUpdate(this.config.id, 'update', data, 'normal');
  }

  public setStyle(styles: Record<string, string>): void {
    queueUIUpdate(this.config.id, 'style', styles, 'normal');
    
    // Apply styles immediately to the element if available
    if (this.element) {
      Object.assign(this.element.style, styles);
    }
  }

  public getElement(): HTMLElement | undefined {
    return this.element;
  }

  public destroy(): void {
    if (this.element) {
      // Remove event listeners
      if (this.config.events) {
        Object.entries(this.config.events).forEach(([eventType, handler]) => {
          this.element!.removeEventListener(eventType, handler);
        });
      }

      // Remove from DOM if it has a parent
      if (this.element.parentNode) {
        this.element.parentNode.removeChild(this.element);
      }
    }
  }
}

/**
 * Clear all pending updates
 */
export function clearPendingUpdates(): void {
  pendingUpdates.length = 0;
}

/**
 * Get render performance statistics
 */
export function getRenderStats(): {
  pendingUpdates: number;
  totalFrames: number;
  averageFrameTime: number;
  lastFrameTime: number;
} {
  const frameTimes = renderFrames
    .filter(frame => frame.duration !== undefined)
    .map(frame => frame.duration!);

  const averageFrameTime = frameTimes.length > 0 
    ? frameTimes.reduce((sum, time) => sum + time, 0) / frameTimes.length 
    : 0;

  const lastFrameTime = frameTimes.length > 0 ? frameTimes[frameTimes.length - 1] : 0;

  return {
    pendingUpdates: pendingUpdates.length,
    totalFrames: renderFrames.length,
    averageFrameTime,
    lastFrameTime
  };
}

/**
 * Force immediate processing of all pending updates
 */
export function flushPendingUpdates(): void {
  if (pendingUpdates.length > 0) {
    processRenderFrame();
  }
}

/**
 * Create a new View instance
 */
export function createView(config: ViewConfig): View {
  return new View(config);
}