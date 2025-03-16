/**
 * Responsive design utilities for the Raxol style system
 */

/**
 * Device types for responsive design
 */
export type DeviceType = 'mobile' | 'tablet' | 'laptop' | 'desktop';

/**
 * Responsive breakpoint configuration
 */
export interface ResponsiveBreakpoints {
  /**
   * Small screens (e.g. mobile phones)
   */
  small: number;
  
  /**
   * Medium screens (e.g. tablets)
   */
  medium: number;
  
  /**
   * Large screens (e.g. laptops)
   */
  large: number;
  
  /**
   * Extra large screens (e.g. desktop monitors)
   */
  extraLarge: number;
  
  /**
   * Custom breakpoints
   */
  [key: string]: number;
}

/**
 * Default responsive breakpoints
 */
export const defaultBreakpoints: ResponsiveBreakpoints = {
  small: 576,
  medium: 768,
  large: 992,
  extraLarge: 1200
};

/**
 * Media query string builder for responsive styles
 */
export function createMediaQuery(breakpoint: keyof ResponsiveBreakpoints | number): string {
  const breakpointValue = typeof breakpoint === 'string'
    ? defaultBreakpoints[breakpoint]
    : breakpoint;
    
  return `@media (min-width: ${breakpointValue}px)`;
}

/**
 * Get current device type based on window width
 */
export function getDeviceType(breakpoints: ResponsiveBreakpoints = defaultBreakpoints): DeviceType {
  if (typeof window === 'undefined') return 'desktop';
  
  const width = window.innerWidth;
  
  if (width < breakpoints.small) return 'mobile';
  if (width < breakpoints.medium) return 'tablet';
  if (width < breakpoints.large) return 'laptop';
  return 'desktop';
}

/**
 * Create responsive value based on device type
 */
export function createResponsiveValue<T>(
  values: Partial<Record<DeviceType, T>>,
  defaultValue: T
): T {
  const deviceType = getDeviceType();
  return values[deviceType] ?? defaultValue;
}

/**
 * Create responsive styles for different breakpoints
 */
export function createResponsiveStyles<T>(
  stylesByBreakpoint: Partial<Record<keyof ResponsiveBreakpoints, T>>,
  baseStyles: T
): Record<string, T> {
  const result: Record<string, T> = {
    base: baseStyles
  };
  
  for (const breakpoint in stylesByBreakpoint) {
    if (Object.prototype.hasOwnProperty.call(stylesByBreakpoint, breakpoint)) {
      const breakpointStyles = stylesByBreakpoint[breakpoint as keyof ResponsiveBreakpoints];
      if (breakpointStyles) {
        result[breakpoint] = breakpointStyles;
      }
    }
  }
  
  return result;
}

/**
 * Add window resize listener for responsive design
 */
export function onDeviceTypeChange(callback: (deviceType: DeviceType) => void): () => void {
  if (typeof window === 'undefined') return () => {};
  
  let currentDeviceType = getDeviceType();
  
  const handleResize = () => {
    const newDeviceType = getDeviceType();
    if (newDeviceType !== currentDeviceType) {
      currentDeviceType = newDeviceType;
      callback(currentDeviceType);
    }
  };
  
  window.addEventListener('resize', handleResize);
  
  // Return cleanup function
  return () => {
    window.removeEventListener('resize', handleResize);
  };
} 