/**
 * dark.ts
 * 
 * Dark theme configuration for the dashboard.
 */

import { ThemeConfig } from '../ThemeManager';

/**
 * Dark theme configuration
 */
export const darkTheme: ThemeConfig = {
  name: 'Dark',
  
  colors: {
    primary: '#90caf9',
    secondary: '#b0bec5',
    background: '#121212',
    text: '#ffffff',
    border: '#424242',
    success: '#81c784',
    warning: '#ffb74d',
    error: '#e57373',
    info: '#64b5f6'
  },
  
  typography: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    fontSize: {
      small: '12px',
      medium: '14px',
      large: '16px',
      xlarge: '20px'
    },
    fontWeight: {
      light: 300,
      regular: 400,
      medium: 500,
      bold: 700
    }
  },
  
  spacing: {
    xs: '4px',
    sm: '8px',
    md: '16px',
    lg: '24px',
    xl: '32px'
  },
  
  borders: {
    radius: {
      small: '4px',
      medium: '8px',
      large: '12px'
    },
    width: {
      thin: '1px',
      regular: '2px',
      thick: '4px'
    }
  },
  
  shadows: {
    small: '0 2px 4px rgba(0, 0, 0, 0.3)',
    medium: '0 4px 8px rgba(0, 0, 0, 0.3)',
    large: '0 8px 16px rgba(0, 0, 0, 0.3)'
  }
}; 