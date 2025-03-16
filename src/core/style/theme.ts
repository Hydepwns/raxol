/**
 * Theme definition for the Raxol style system
 */

/**
 * Color palette definition
 */
export interface ColorPalette {
  primary: string;
  secondary: string;
  accent: string;
  background: string;
  text: string;
  border: string;
  success: string;
  warning: string;
  error: string;
  info: string;
  [key: string]: string;
}

/**
 * Typography configuration
 */
export interface TypographyConfig {
  fontFamily: string;
  baseFontSize: string;
  fontWeights: {
    light: number;
    regular: number;
    medium: number;
    bold: number;
    [key: string]: number;
  };
  lineHeights: {
    tight: number;
    normal: number;
    loose: number;
    [key: string]: number;
  };
  [key: string]: any;
}

/**
 * Spacing configuration
 */
export interface SpacingConfig {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
  xxl: number;
  [key: string]: number;
}

/**
 * Border radius configuration
 */
export interface BorderRadiusConfig {
  sm: number;
  md: number;
  lg: number;
  pill: number;
  [key: string]: number;
}

/**
 * Theme definition
 */
export interface Theme {
  /**
   * Color palette
   */
  colors: ColorPalette;
  
  /**
   * Typography configuration
   */
  typography: TypographyConfig;
  
  /**
   * Spacing configuration
   */
  spacing: SpacingConfig;
  
  /**
   * Border radius configuration
   */
  borderRadius: BorderRadiusConfig;
  
  /**
   * Additional theme properties
   */
  [key: string]: any;
}

/**
 * Theme variant (light, dark, high-contrast, etc.)
 */
export type ThemeVariant = 'light' | 'dark' | 'high-contrast' | string;

/**
 * Predefined themes
 */
export const defaultTheme: Theme = {
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
};

export const darkTheme: Theme = {
  colors: {
    primary: '#3498db',
    secondary: '#2ecc71',
    accent: '#9b59b6',
    background: '#222222',
    text: '#eeeeee',
    border: '#444444',
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
};

export const highContrastTheme: Theme = {
  colors: {
    primary: '#0066CC',
    secondary: '#008000',
    accent: '#9900CC',
    background: '#FFFFFF',
    text: '#000000',
    border: '#000000',
    success: '#008000',
    warning: '#CC6600',
    error: '#CC0000',
    info: '#0066CC'
  },
  typography: {
    fontFamily: 'system-ui, -apple-system, sans-serif',
    baseFontSize: '18px',
    fontWeights: {
      light: 400,
      regular: 500,
      medium: 600,
      bold: 700
    },
    lineHeights: {
      tight: 1.3,
      normal: 1.6,
      loose: 1.9
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
}; 