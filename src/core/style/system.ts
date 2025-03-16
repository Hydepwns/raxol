/**
 * Enhanced Style System for Raxol
 * 
 * A comprehensive styling system that provides:
 * - Theme management with dynamic switching
 * - Responsive styles with breakpoints
 * - CSS variable integration
 * - Style composition and inheritance
 * - Performance-optimized style application
 */

import { Theme, ThemeVariant, ColorPalette } from './theme';
import { ResponsiveBreakpoints, DeviceType } from './responsive';

/**
 * Style property interfaces
 */
export interface StyleProperties {
  // Layout
  display?: 'flex' | 'grid' | 'block' | 'inline' | 'inline-block' | 'none';
  position?: 'static' | 'relative' | 'absolute' | 'fixed' | 'sticky';
  width?: string | number;
  height?: string | number;
  minWidth?: string | number;
  minHeight?: string | number;
  maxWidth?: string | number;
  maxHeight?: string | number;
  padding?: string | number | [number, number] | [number, number, number, number];
  margin?: string | number | [number, number] | [number, number, number, number];
  
  // Flexbox
  flexDirection?: 'row' | 'column' | 'row-reverse' | 'column-reverse';
  flexWrap?: 'nowrap' | 'wrap' | 'wrap-reverse';
  justifyContent?: 'flex-start' | 'flex-end' | 'center' | 'space-between' | 'space-around' | 'space-evenly';
  alignItems?: 'flex-start' | 'flex-end' | 'center' | 'baseline' | 'stretch';
  alignContent?: 'flex-start' | 'flex-end' | 'center' | 'space-between' | 'space-around' | 'stretch';
  flex?: string | number;
  flexGrow?: number;
  flexShrink?: number;
  flexBasis?: string | number;
  alignSelf?: 'auto' | 'flex-start' | 'flex-end' | 'center' | 'baseline' | 'stretch';
  
  // Grid
  gridTemplateColumns?: string;
  gridTemplateRows?: string;
  gridTemplateAreas?: string;
  gridColumn?: string;
  gridRow?: string;
  gridArea?: string;
  gridAutoFlow?: string;
  gridAutoRows?: string;
  gridAutoColumns?: string;
  gridColumnGap?: string | number;
  gridRowGap?: string | number;
  gridGap?: string | number | [number, number];
  
  // Appearance
  color?: string;
  backgroundColor?: string;
  borderRadius?: string | number | [number, number, number, number];
  border?: string;
  borderColor?: string;
  borderWidth?: string | number | [number, number, number, number];
  borderStyle?: 'none' | 'solid' | 'dashed' | 'dotted' | 'double';
  boxShadow?: string;
  opacity?: number;
  visibility?: 'visible' | 'hidden' | 'collapse';
  
  // Typography
  fontFamily?: string;
  fontSize?: string | number;
  fontWeight?: string | number;
  lineHeight?: string | number;
  textAlign?: 'left' | 'right' | 'center' | 'justify';
  textDecoration?: 'none' | 'underline' | 'line-through' | 'overline';
  letterSpacing?: string | number;
  
  // Transitions and Animations
  transition?: string;
  transform?: string;
  animation?: string;
  
  // Other
  cursor?: 'default' | 'pointer' | 'text' | 'not-allowed' | 'wait' | 'move';
  overflow?: 'visible' | 'hidden' | 'scroll' | 'auto';
  zIndex?: number;
  
  // Additional custom properties
  [key: string]: any;
}

/**
 * Responsive style definition
 */
export interface ResponsiveStyles {
  base: StyleProperties;
  small?: StyleProperties;
  medium?: StyleProperties;
  large?: StyleProperties;
  extraLarge?: StyleProperties;
  [key: string]: StyleProperties | undefined;
}

/**
 * Variant style definition
 */
export interface StyleVariants {
  [variant: string]: StyleProperties | ResponsiveStyles;
}

/**
 * Component style definition
 */
export interface ComponentStyles {
  root: StyleProperties | ResponsiveStyles;
  variants?: StyleVariants;
  states?: {
    hover?: StyleProperties;
    active?: StyleProperties;
    focus?: StyleProperties;
    disabled?: StyleProperties;
    [key: string]: StyleProperties | undefined;
  };
  children?: {
    [selector: string]: StyleProperties | ResponsiveStyles;
  };
}

/**
 * Style Manager Configuration
 */
export interface StyleManagerConfig {
  defaultTheme?: string;
  themes?: Record<string, Theme>;
  breakpoints?: ResponsiveBreakpoints;
  rootSelector?: string;
  useCssVariables?: boolean;
  styleCache?: boolean;
}

/**
 * Style Manager
 */
export class StyleManager {
  private config: StyleManagerConfig;
  private currentTheme: string;
  private themes: Record<string, Theme>;
  private breakpoints: ResponsiveBreakpoints;
  private styleCache: Map<string, any> = new Map();
  
  /**
   * Create a new style manager
   */
  constructor(config: StyleManagerConfig = {}) {
    this.config = {
      defaultTheme: 'default',
      rootSelector: ':root',
      useCssVariables: true,
      styleCache: true,
      ...config
    };
    
    this.currentTheme = this.config.defaultTheme || 'default';
    this.themes = this.config.themes || {
      default: {
        colors: {
          primary: '#3498db',
          secondary: '#2ecc71',
          accent: '#9b59b6',
          background: '#ffffff',
          text: '#333333',
          border: '#dddddd',
          success: '#2ecc71',
          warning: '#f39c12',
          error: '#e74c3c',
          info: '#3498db'
        },
        typography: {
          fontFamily: 'system-ui, -apple-system, sans-serif',
          baseFontSize: '16px',
          fontWeights: {
            light: 300,
            regular: 400,
            medium: 500,
            bold: 700
          },
          lineHeights: {
            tight: 1.2,
            normal: 1.5,
            loose: 1.8
          }
        },
        spacing: {
          xs: 4,
          sm: 8,
          md: 16,
          lg: 24,
          xl: 32,
          xxl: 48
        },
        borderRadius: {
          sm: 2,
          md: 4,
          lg: 8,
          pill: 9999
        }
      }
    };
    
    this.breakpoints = this.config.breakpoints || {
      small: 576,
      medium: 768,
      large: 992,
      extraLarge: 1200
    };
    
    // Initialize CSS variables if enabled
    if (this.config.useCssVariables) {
      this.initializeCssVariables();
    }
  }
  
  /**
   * Initialize CSS variables from the current theme
   */
  private initializeCssVariables(): void {
    if (typeof document === 'undefined') return;
    
    const theme = this.themes[this.currentTheme];
    if (!theme) return;
    
    const rootElement = document.querySelector(this.config.rootSelector || ':root');
    if (!rootElement) return;
    
    // Set color variables
    Object.entries(theme.colors).forEach(([name, value]) => {
      (rootElement as HTMLElement).style.setProperty(`--color-${name}`, value);
    });
    
    // Set typography variables
    Object.entries(theme.typography.fontWeights).forEach(([name, value]) => {
      (rootElement as HTMLElement).style.setProperty(`--font-weight-${name}`, value.toString());
    });
    
    Object.entries(theme.typography.lineHeights).forEach(([name, value]) => {
      (rootElement as HTMLElement).style.setProperty(`--line-height-${name}`, value.toString());
    });
    
    // Set spacing variables
    Object.entries(theme.spacing).forEach(([name, value]) => {
      (rootElement as HTMLElement).style.setProperty(`--spacing-${name}`, `${value}px`);
    });
    
    // Set border radius variables
    Object.entries(theme.borderRadius).forEach(([name, value]) => {
      (rootElement as HTMLElement).style.setProperty(`--radius-${name}`, `${value}px`);
    });
  }
  
  /**
   * Get the current theme
   */
  getCurrentTheme(): Theme {
    return this.themes[this.currentTheme];
  }
  
  /**
   * Set the current theme
   */
  setTheme(themeName: string): void {
    if (this.themes[themeName]) {
      this.currentTheme = themeName;
      
      if (this.config.useCssVariables) {
        this.initializeCssVariables();
      }
    } else {
      console.warn(`Theme "${themeName}" not found, using current theme`);
    }
  }
  
  /**
   * Add a new theme
   */
  addTheme(name: string, theme: Theme): void {
    this.themes[name] = theme;
  }
  
  /**
   * Get current device type based on viewport width
   */
  getDeviceType(): DeviceType {
    if (typeof window === 'undefined') return 'desktop';
    
    const width = window.innerWidth;
    
    if (width < this.breakpoints.small) return 'mobile';
    if (width < this.breakpoints.medium) return 'tablet';
    if (width < this.breakpoints.large) return 'laptop';
    return 'desktop';
  }
  
  /**
   * Create component styles with responsive breakpoints
   */
  createStyles<T extends string>(
    componentName: string,
    styleConfig: Record<T, ComponentStyles>
  ): Record<T, any> {
    const theme = this.getCurrentTheme();
    const result: Record<string, any> = {};
    
    for (const key in styleConfig) {
      const componentStyle = styleConfig[key];
      
      // Create the styles for this component part
      result[key] = this.processComponentStyle(componentStyle, theme);
    }
    
    return result as Record<T, any>;
  }
  
  /**
   * Process a component style
   */
  private processComponentStyle(componentStyle: ComponentStyles, theme: Theme): any {
    const { root, variants, states, children } = componentStyle;
    
    const result: any = {
      root: this.processStyleProps(root, theme)
    };
    
    // Process variants
    if (variants) {
      result.variants = {};
      for (const variant in variants) {
        result.variants[variant] = this.processStyleProps(variants[variant], theme);
      }
    }
    
    // Process states
    if (states) {
      result.states = {};
      for (const state in states) {
        if (states[state]) {
          result.states[state] = this.processStyleProps(states[state]!, theme);
        }
      }
    }
    
    // Process children
    if (children) {
      result.children = {};
      for (const selector in children) {
        result.children[selector] = this.processStyleProps(children[selector], theme);
      }
    }
    
    return result;
  }
  
  /**
   * Process style properties or responsive styles
   */
  private processStyleProps(
    style: StyleProperties | ResponsiveStyles,
    theme: Theme
  ): any {
    // Check if it's responsive styles
    if ('base' in style) {
      const responsiveStyles: any = {
        base: this.resolveThemeValues(style.base, theme)
      };
      
      // Process each breakpoint
      for (const breakpoint in style) {
        if (breakpoint !== 'base' && style[breakpoint]) {
          responsiveStyles[breakpoint] = this.resolveThemeValues(style[breakpoint]!, theme);
        }
      }
      
      return responsiveStyles;
    }
    
    // Regular style properties
    return this.resolveThemeValues(style, theme);
  }
  
  /**
   * Resolve theme values in style properties
   */
  private resolveThemeValues(style: StyleProperties, theme: Theme): StyleProperties {
    const result: StyleProperties = {};
    
    for (const key in style) {
      const value = style[key];
      
      if (typeof value === 'string' && value.startsWith('$')) {
        // It's a theme reference like $colors.primary
        const themePathParts = value.substring(1).split('.');
        let themeValue: any = theme;
        
        for (const part of themePathParts) {
          if (themeValue === undefined) break;
          themeValue = themeValue[part];
        }
        
        result[key] = themeValue !== undefined ? themeValue : value;
      } else {
        result[key] = value;
      }
    }
    
    return result;
  }
  
  /**
   * Get style for a component with current theme, variant, and state
   */
  getComponentStyle(
    componentStyles: any,
    options: {
      variant?: string;
      state?: string;
      deviceType?: DeviceType;
    } = {}
  ): StyleProperties {
    const { variant, state, deviceType = this.getDeviceType() } = options;
    
    // Start with root style
    let style = this.getResponsiveStyle(componentStyles.root, deviceType);
    
    // Apply variant style if applicable
    if (variant && componentStyles.variants && componentStyles.variants[variant]) {
      const variantStyle = this.getResponsiveStyle(componentStyles.variants[variant], deviceType);
      style = { ...style, ...variantStyle };
    }
    
    // Apply state style if applicable
    if (state && componentStyles.states && componentStyles.states[state]) {
      style = { ...style, ...componentStyles.states[state] };
    }
    
    return style;
  }
  
  /**
   * Get responsive style for current device
   */
  private getResponsiveStyle(style: any, deviceType: DeviceType): StyleProperties {
    if (!style) return {};
    
    // If it's not responsive, return as is
    if (!style.base) return style;
    
    // Start with base styles
    let result = { ...style.base };
    
    // Apply breakpoint styles based on device type
    const deviceBreakpoints: Record<DeviceType, string[]> = {
      mobile: ['small'],
      tablet: ['small', 'medium'],
      laptop: ['small', 'medium', 'large'],
      desktop: ['small', 'medium', 'large', 'extraLarge']
    };
    
    const breakpointsToApply = deviceBreakpoints[deviceType] || [];
    
    for (const breakpoint of breakpointsToApply) {
      if (style[breakpoint]) {
        result = { ...result, ...style[breakpoint] };
      }
    }
    
    return result;
  }
  
  /**
   * Convert object styles to CSS string
   */
  toCss(styles: StyleProperties): string {
    let css = '';
    
    for (const key in styles) {
      const cssKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
      let value = styles[key];
      
      // Handle arrays for shorthand properties
      if (Array.isArray(value)) {
        value = value.join(' ');
      }
      
      // Add pixel units to numbers that need them
      if (typeof value === 'number' && 
          !['zIndex', 'opacity', 'fontWeight', 'flexGrow', 'flexShrink'].includes(key)) {
        value = `${value}px`;
      }
      
      css += `${cssKey}: ${value}; `;
    }
    
    return css;
  }
}

// Export a default style manager instance
export const styleManager = new StyleManager();

// Helper functions
export function createTheme(theme: Theme): Theme {
  return theme;
}

export function extendTheme(base: Theme, overrides: Partial<Theme>): Theme {
  return {
    colors: { ...base.colors, ...overrides.colors },
    typography: { ...base.typography, ...overrides.typography },
    spacing: { ...base.spacing, ...overrides.spacing },
    borderRadius: { ...base.borderRadius, ...overrides.borderRadius }
  };
} 