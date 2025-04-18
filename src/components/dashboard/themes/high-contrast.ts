/**
 * high-contrast.ts
 *
 * High-contrast theme configuration for the dashboard.
 * This theme is designed for maximum accessibility and readability.
 */

import { ThemeConfig } from "../ThemeManager";

/**
 * High-contrast theme configuration
 */
export const highContrastTheme: ThemeConfig = {
  name: "High Contrast",

  colors: {
    primary: "#ffffff",
    secondary: "#ffff00",
    background: "#000000",
    text: "#ffffff",
    border: "#ffffff",
    success: "#00ff00",
    warning: "#ffff00",
    error: "#ff0000",
    info: "#00ffff",
  },

  typography: {
    fontFamily:
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    fontSize: {
      small: "14px",
      medium: "16px",
      large: "18px",
      xlarge: "22px",
    },
    fontWeight: {
      light: 400, // Using a higher weight for better readability
      regular: 500,
      medium: 600,
      bold: 800,
    },
  },

  spacing: {
    xs: "6px", // Slightly larger spacing for better separation
    sm: "10px",
    md: "18px",
    lg: "26px",
    xl: "34px",
  },

  borders: {
    radius: {
      small: "2px", // More defined borders with less radius
      medium: "4px",
      large: "8px",
    },
    width: {
      thin: "2px", // Thicker borders for visibility
      regular: "3px",
      thick: "5px",
    },
  },

  shadows: {
    small: "0 0 0 2px #ffffff", // High contrast outlines instead of shadows
    medium: "0 0 0 3px #ffffff",
    large: "0 0 0 4px #ffffff",
  },
};
