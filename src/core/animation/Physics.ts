/**
 * Physics-based Animation System
 * 
 * Provides natural physics-based animations including:
 * - Spring physics with configurable tension and friction
 * - Gravity and bounce effects
 * - Inertia with damping
 * - Collision detection and resolution
 * - Natural motion curves for common animations
 */

import { Vector2D, Rect } from './types';

/**
 * Spring configuration
 */
export interface SpringConfig {
  /**
   * Spring tension (stiffness)
   * Higher values mean faster movement toward the target
   */
  tension: number;
  
  /**
   * Spring friction (damping)
   * Higher values mean faster energy loss
   */
  friction: number;
  
  /**
   * Spring precision threshold
   * When the spring gets close enough to rest, animation completes
   */
  precision?: number;
  
  /**
   * Whether spring can overshoot the target
   */
  allowOvershoot?: boolean;
  
  /**
   * Spring initial velocity
   */
  initialVelocity?: number;
}

/**
 * Gravity configuration
 */
export interface GravityConfig {
  /**
   * Gravity strength (acceleration in units/s²)
   */
  strength: number;
  
  /**
   * Gravity direction (angle in degrees, 0 = right, 90 = down)
   */
  direction?: number;
  
  /**
   * Air resistance factor
   */
  airResistance?: number;
}

/**
 * Bounce configuration
 */
export interface BounceConfig {
  /**
   * Bounce surface position
   */
  surface: number;
  
  /**
   * Bounce elasticity (0-1)
   * 1 means 100% energy preservation, 0 means no bounce
   */
  elasticity: number;
  
  /**
   * Minimum velocity for bounce to occur
   */
  minVelocity?: number;
  
  /**
   * Maximum number of bounces
   */
  maxBounces?: number;
}

/**
 * Inertia configuration
 */
export interface InertiaConfig {
  /**
   * Initial velocity
   */
  initialVelocity: number;
  
  /**
   * Deceleration rate
   */
  deceleration: number;
  
  /**
   * Minimum velocity threshold to consider motion stopped
   */
  minVelocity?: number;
  
  /**
   * Whether motion can go beyond the 0-1 range
   */
  allowOverflow?: boolean;
}

/**
 * Collision configuration
 */
export interface CollisionConfig {
  /**
   * Objects to check for collisions
   */
  objects: Rect[];
  
  /**
   * Elasticity of collisions (0-1)
   */
  elasticity: number;
}

/**
 * Physics animation state
 */
export interface PhysicsState {
  /**
   * Current position value
   */
  value: number;
  
  /**
   * Current velocity
   */
  velocity: number;
  
  /**
   * Whether animation has completed
   */
  done: boolean;
  
  /**
   * Animation progress (0-1)
   */
  progress: number;
}

/**
 * 2D physics animation state
 */
export interface Physics2DState {
  /**
   * Current position x and y
   */
  position: Vector2D;
  
  /**
   * Current velocity x and y
   */
  velocity: Vector2D;
  
  /**
   * Whether animation has completed
   */
  done: boolean;
  
  /**
   * Animation progress (0-1)
   */
  progress: number;
}

/**
 * Default configurations
 */
export const defaultSpringConfig: SpringConfig = {
  tension: 170,
  friction: 26,
  precision: 0.001,
  allowOvershoot: true,
  initialVelocity: 0
};

export const defaultGravityConfig: GravityConfig = {
  strength: 9.8,
  direction: 90,
  airResistance: 0.01
};

export const defaultBounceConfig: BounceConfig = {
  surface: 1,
  elasticity: 0.7,
  minVelocity: 0.1,
  maxBounces: 5
};

export const defaultInertiaConfig: InertiaConfig = {
  initialVelocity: 0,
  deceleration: 0.95,
  minVelocity: 0.001,
  allowOverflow: false
};

/**
 * Spring animation simulator
 */
export function springSimulator(
  config: SpringConfig = defaultSpringConfig,
  from: number = 0,
  to: number = 1
): (t: number) => PhysicsState {
  const { tension, friction, precision, allowOvershoot, initialVelocity } = {
    ...defaultSpringConfig,
    ...config
  };
  
  // Convert to spring physics model
  const mass = 1;
  const stiffness = tension;
  const damping = friction;
  const restPosition = to;
  const epsilon = precision || 0.001;
  
  let position = from;
  let velocity = initialVelocity || 0;
  let done = Math.abs(position - restPosition) < epsilon && Math.abs(velocity) < epsilon;
  
  // Return a time-based simulator function
  return (deltaTime: number): PhysicsState => {
    if (done) {
      return {
        value: restPosition,
        velocity: 0,
        done: true,
        progress: 1
      };
    }
    
    // Spring force: -k * (x - rest)
    const springForce = -stiffness * (position - restPosition);
    
    // Damping force: -c * v
    const dampingForce = -damping * velocity;
    
    // Total force: F = spring + damping
    const force = springForce + dampingForce;
    
    // Acceleration: F = ma -> a = F/m
    const acceleration = force / mass;
    
    // Update velocity: v = v + a * dt
    velocity += acceleration * deltaTime;
    
    // Update position: x = x + v * dt
    position += velocity * deltaTime;
    
    // Check if we're close enough to rest position
    if (Math.abs(position - restPosition) < epsilon && Math.abs(velocity) < epsilon) {
      position = restPosition;
      velocity = 0;
      done = true;
    }
    
    // If not allowing overshoot, clamp at target
    if (!allowOvershoot) {
      if ((from < to && position > to) || (from > to && position < to)) {
        position = to;
        velocity = 0;
        done = true;
      }
    }
    
    return {
      value: position,
      velocity,
      done,
      progress: normalizeProgress(from, to, position)
    };
  };
}

/**
 * Gravity animation simulator
 */
export function gravitySimulator(
  config: GravityConfig = defaultGravityConfig,
  bounceConfig: BounceConfig = defaultBounceConfig,
  from: number = 0,
  to: number = 1
): (t: number) => PhysicsState {
  const { strength, direction, airResistance } = {
    ...defaultGravityConfig,
    ...config
  };
  
  const { surface, elasticity, minVelocity, maxBounces } = {
    ...defaultBounceConfig,
    ...bounceConfig
  };
  
  // Calculate gravity direction vector
  const angleInRadians = (direction || 90) * (Math.PI / 180);
  const gravityX = strength * Math.cos(angleInRadians);
  const gravityY = strength * Math.sin(angleInRadians);
  
  // Map from/to to our gravity simulation
  const totalDistance = Math.abs(to - from);
  let position = 0; // Will be mapped back to from->to
  let velocity = 0;
  let bounceCount = 0;
  let done = false;
  
  // Return a time-based simulator function
  return (deltaTime: number): PhysicsState => {
    if (done) {
      return {
        value: to,
        velocity: 0,
        done: true,
        progress: 1
      };
    }
    
    // Apply gravity
    velocity += gravityY * deltaTime;
    
    // Apply air resistance
    if (airResistance) {
      velocity *= (1 - airResistance * deltaTime);
    }
    
    // Update position
    position += velocity * deltaTime;
    
    // Check for bounce at surface
    if (position >= surface && velocity > 0) {
      bounceCount++;
      
      // Check if we should stop bouncing
      if (Math.abs(velocity) < (minVelocity || 0.1) || 
          (maxBounces !== undefined && bounceCount >= maxBounces)) {
        position = surface;
        velocity = 0;
        done = true;
      } else {
        // Bounce with energy loss
        position = surface;
        velocity = -velocity * elasticity;
      }
    }
    
    // Map position from 0->surface to from->to
    const mappedPosition = from + (position / surface) * totalDistance;
    
    return {
      value: Math.min(to, mappedPosition),
      velocity,
      done,
      progress: normalizeProgress(from, to, mappedPosition)
    };
  };
}

/**
 * Inertia animation simulator
 */
export function inertiaSimulator(
  config: InertiaConfig,
  from: number = 0,
  to: number = 1
): (t: number) => PhysicsState {
  const { initialVelocity, deceleration, minVelocity, allowOverflow } = {
    ...defaultInertiaConfig,
    ...config
  };
  
  let position = from;
  let velocity = initialVelocity;
  let done = Math.abs(velocity) < (minVelocity || 0.001);
  
  // Return a time-based simulator function
  return (deltaTime: number): PhysicsState => {
    if (done) {
      return {
        value: position,
        velocity: 0,
        done: true,
        progress: normalizeProgress(from, to, position)
      };
    }
    
    // Apply deceleration
    velocity *= Math.pow(deceleration, deltaTime * 60);
    
    // Update position
    position += velocity * deltaTime;
    
    // Check if velocity is small enough to stop
    if (Math.abs(velocity) < (minVelocity || 0.001)) {
      velocity = 0;
      done = true;
    }
    
    // Clamp position if not allowing overflow
    if (!allowOverflow) {
      if (position < from) {
        position = from;
        velocity = 0;
        done = true;
      } else if (position > to) {
        position = to;
        velocity = 0;
        done = true;
      }
    }
    
    return {
      value: position,
      velocity,
      done,
      progress: normalizeProgress(from, to, position)
    };
  };
}

/**
 * 2D spring animation simulator
 */
export function spring2DSimulator(
  config: SpringConfig = defaultSpringConfig,
  fromX: number = 0,
  fromY: number = 0,
  toX: number = 1,
  toY: number = 1
): (t: number) => Physics2DState {
  // Create separate simulators for X and Y
  const simulatorX = springSimulator(config, fromX, toX);
  const simulatorY = springSimulator(config, fromY, toY);
  
  // Return a time-based simulator function
  return (deltaTime: number): Physics2DState => {
    const stateX = simulatorX(deltaTime);
    const stateY = simulatorY(deltaTime);
    
    return {
      position: { x: stateX.value, y: stateY.value },
      velocity: { x: stateX.velocity, y: stateY.velocity },
      done: stateX.done && stateY.done,
      progress: (stateX.progress + stateY.progress) / 2
    };
  };
}

/**
 * Collision detection and resolution simulator
 */
export function collisionSimulator(
  config: CollisionConfig,
  position: Vector2D,
  velocity: Vector2D
): (t: number) => Physics2DState {
  let currentPosition = { ...position };
  let currentVelocity = { ...velocity };
  let done = false;
  
  // Return a time-based simulator function
  return (deltaTime: number): Physics2DState => {
    if (done) {
      return {
        position: currentPosition,
        velocity: { x: 0, y: 0 },
        done: true,
        progress: 1
      };
    }
    
    // Update position
    const nextPosition = {
      x: currentPosition.x + currentVelocity.x * deltaTime,
      y: currentPosition.y + currentVelocity.y * deltaTime
    };
    
    // Check for collisions with all objects
    let collision = false;
    
    for (const object of config.objects) {
      if (checkCollision(nextPosition, object)) {
        // Simple collision resolution - bounce back
        currentVelocity.x = -currentVelocity.x * config.elasticity;
        currentVelocity.y = -currentVelocity.y * config.elasticity;
        collision = true;
        break;
      }
    }
    
    if (!collision) {
      currentPosition = nextPosition;
    }
    
    // Check if velocity is small enough to stop
    if (Math.abs(currentVelocity.x) < 0.001 && Math.abs(currentVelocity.y) < 0.001) {
      currentVelocity = { x: 0, y: 0 };
      done = true;
    }
    
    return {
      position: currentPosition,
      velocity: currentVelocity,
      done,
      progress: done ? 1 : 0
    };
  };
}

/**
 * Create a gesture-based animation
 */
export function gestureAnimator(
  onUpdate: (position: Vector2D, velocity: Vector2D) => void,
  decelerationRate: number = 0.95
): {
  start: (position: Vector2D) => void;
  move: (position: Vector2D) => void;
  end: (velocity: Vector2D) => void;
  cancel: () => void;
} {
  let tracking = false;
  let lastPosition: Vector2D | null = null;
  let velocity: Vector2D = { x: 0, y: 0 };
  let animationFrame: number | null = null;
  
  // Animation loop for inertia
  const animate = () => {
    if (!tracking && (Math.abs(velocity.x) > 0.01 || Math.abs(velocity.y) > 0.01)) {
      // Apply deceleration
      velocity.x *= decelerationRate;
      velocity.y *= decelerationRate;
      
      // Calculate new position based on velocity
      if (lastPosition) {
        const newPosition = {
          x: lastPosition.x + velocity.x,
          y: lastPosition.y + velocity.y
        };
        
        // Update last position
        lastPosition = newPosition;
        
        // Call update callback
        onUpdate(newPosition, velocity);
      }
      
      // Continue animation
      animationFrame = requestAnimationFrame(animate);
    } else if (!tracking) {
      // Animation complete
      velocity = { x: 0, y: 0 };
      animationFrame = null;
    }
  };
  
  return {
    start: (position: Vector2D) => {
      // Cancel any existing animation
      if (animationFrame !== null) {
        cancelAnimationFrame(animationFrame);
        animationFrame = null;
      }
      
      tracking = true;
      lastPosition = position;
      velocity = { x: 0, y: 0 };
    },
    
    move: (position: Vector2D) => {
      if (tracking && lastPosition) {
        // Calculate velocity based on position change
        velocity = {
          x: position.x - lastPosition.x,
          y: position.y - lastPosition.y
        };
        
        // Update last position
        lastPosition = position;
        
        // Call update callback
        onUpdate(position, velocity);
      }
    },
    
    end: (finalVelocity: Vector2D = velocity) => {
      tracking = false;
      velocity = finalVelocity;
      
      // Start deceleration animation
      if (animationFrame === null && (Math.abs(velocity.x) > 0.01 || Math.abs(velocity.y) > 0.01)) {
        animationFrame = requestAnimationFrame(animate);
      }
    },
    
    cancel: () => {
      tracking = false;
      velocity = { x: 0, y: 0 };
      
      if (animationFrame !== null) {
        cancelAnimationFrame(animationFrame);
        animationFrame = null;
      }
    }
  };
}

// Helper Functions

/**
 * Check collision between a point and a rectangle
 */
function checkCollision(point: Vector2D, rect: Rect): boolean {
  return (
    point.x >= rect.x &&
    point.x <= rect.x + rect.width &&
    point.y >= rect.y &&
    point.y <= rect.y + rect.height
  );
}

/**
 * Normalize progress into a 0-1 range
 */
function normalizeProgress(from: number, to: number, current: number): number {
  if (from === to) return 1;
  const range = to - from;
  const progress = (current - from) / range;
  return Math.max(0, Math.min(1, progress));
} 