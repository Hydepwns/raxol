/**
 * default.ts
 * 
 * Default theme configuration for the dashboard.
 */

import { ThemeConfig } from '../ThemeManager';

/**
 * Default theme configuration
 */
export const defaultTheme: ThemeConfig = {
  name: 'Default',
  
  colors: {
    primary: '#1976d2',
    secondary: '#424242',
    background: '#ffffff',
    text: '#212121',
    border: '#e0e0e0',
    success: '#4caf50',
    warning: '#ff9800',
    error: '#f44336',
    info: '#2196f3'
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
    small: '0 2px 4px rgba(0, 0, 0, 0.1)',
    medium: '0 4px 8px rgba(0, 0, 0, 0.1)',
    large: '0 8px 16px rgba(0, 0, 0, 0.1)'
  }
}; 