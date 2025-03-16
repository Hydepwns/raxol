/**
 * Animation type definitions
 */

/**
 * 2D vector representation
 */
export interface Vector2D {
  /**
   * X coordinate
   */
  x: number;
  
  /**
   * Y coordinate
   */
  y: number;
}

/**
 * 3D vector representation
 */
export interface Vector3D extends Vector2D {
  /**
   * Z coordinate
   */
  z: number;
}

/**
 * Rectangle representation
 */
export interface Rect {
  /**
   * X coordinate (top-left)
   */
  x: number;
  
  /**
   * Y coordinate (top-left)
   */
  y: number;
  
  /**
   * Width of rectangle
   */
  width: number;
  
  /**
   * Height of rectangle
   */
  height: number;
}

/**
 * Animation types
 */
export enum AnimationType {
  /**
   * Linear animation (constant speed)
   */
  LINEAR = 'linear',
  
  /**
   * Easing animation (acceleration/deceleration)
   */
  EASING = 'easing',
  
  /**
   * Spring physics animation
   */
  SPRING = 'spring',
  
  /**
   * Gravity physics animation
   */
  GRAVITY = 'gravity',
  
  /**
   * Inertia animation
   */
  INERTIA = 'inertia',
  
  /**
   * Keyframe animation
   */
  KEYFRAME = 'keyframe',
  
  /**
   * Gesture-driven animation
   */
  GESTURE = 'gesture'
}

/**
 * Easing function type
 */
export type EasingFunction = (t: number) => number;

/**
 * Animation direction
 */
export enum AnimationDirection {
  /**
   * Forward animation (from -> to)
   */
  FORWARD = 'forward',
  
  /**
   * Reverse animation (to -> from)
   */
  REVERSE = 'reverse',
  
  /**
   * Alternate between forward and reverse
   */
  ALTERNATE = 'alternate'
}

/**
 * Animation playback state
 */
export enum AnimationPlaybackState {
  /**
   * Animation is idle (not started)
   */
  IDLE = 'idle',
  
  /**
   * Animation is running
   */
  RUNNING = 'running',
  
  /**
   * Animation is paused
   */
  PAUSED = 'paused',
  
  /**
   * Animation is completed
   */
  COMPLETED = 'completed'
}

/**
 * Keyframe definition
 */
export interface Keyframe<T> {
  /**
   * Keyframe position (0-1)
   */
  position: number;
  
  /**
   * Keyframe value
   */
  value: T;
  
  /**
   * Optional easing function for transition to next keyframe
   */
  easing?: EasingFunction;
}

/**
 * Animation event types
 */
export enum AnimationEventType {
  /**
   * Animation has started
   */
  START = 'start',
  
  /**
   * Animation has updated
   */
  UPDATE = 'update',
  
  /**
   * Animation has completed
   */
  COMPLETE = 'complete',
  
  /**
   * Animation has been cancelled
   */
  CANCEL = 'cancel',
  
  /**
   * Animation has been paused
   */
  PAUSE = 'pause',
  
  /**
   * Animation has been resumed
   */
  RESUME = 'resume'
}

/**
 * Animation event
 */
export interface AnimationEvent<T = any> {
  /**
   * Event type
   */
  type: AnimationEventType;
  
  /**
   * Animation data
   */
  data: {
    /**
     * Current value
     */
    value: T;
    
    /**
     * Animation progress (0-1)
     */
    progress: number;
    
    /**
     * Current timestamp
     */
    timestamp: number;
    
    /**
     * Additional event data
     */
    [key: string]: any;
  };
}

/**
 * Animation options common to all animation types
 */
export interface AnimationOptions {
  /**
   * Animation duration in milliseconds
   */
  duration?: number;
  
  /**
   * Delay before animation starts in milliseconds
   */
  delay?: number;
  
  /**
   * Number of times to repeat the animation
   * -1 means infinite
   */
  repeat?: number;
  
  /**
   * Whether to alternate direction on repeat
   */
  alternateDirection?: boolean;
  
  /**
   * Animation direction
   */
  direction?: AnimationDirection;
  
  /**
   * Whether to play animation backwards
   */
  reverse?: boolean;
  
  /**
   * Animation event callbacks
   */
  onStart?: (event: AnimationEvent) => void;
  onUpdate?: (event: AnimationEvent) => void;
  onComplete?: (event: AnimationEvent) => void;
  onCancel?: (event: AnimationEvent) => void;
  onPause?: (event: AnimationEvent) => void;
  onResume?: (event: AnimationEvent) => void;
} 