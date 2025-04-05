/**
 * ThemeManager.ts
 * 
 * Manages dashboard theme customization and styling.
 */

/**
 * Theme configuration
 */
export interface ThemeConfig {
  /**
   * Theme name
   */
  name: string;
  
  /**
   * Theme colors
   */
  colors: {
    /**
     * Primary color
     */
    primary: string;
    
    /**
     * Secondary color
     */
    secondary: string;
    
    /**
     * Background color
     */
    background: string;
    
    /**
     * Text color
     */
    text: string;
    
    /**
     * Border color
     */
    border: string;
    
    /**
     * Success color
     */
    success: string;
    
    /**
     * Warning color
     */
    warning: string;
    
    /**
     * Error color
     */
    error: string;
    
    /**
     * Info color
     */
    info: string;
  };
  
  /**
   * Theme typography
   */
  typography: {
    /**
     * Font family
     */
    fontFamily: string;
    
    /**
     * Font sizes
     */
    fontSize: {
      /**
       * Small font size
       */
      small: string;
      
      /**
       * Medium font size
       */
      medium: string;
      
      /**
       * Large font size
       */
      large: string;
      
      /**
       * Extra large font size
       */
      xlarge: string;
    };
    
    /**
     * Font weights
     */
    fontWeight: {
      /**
       * Light font weight
       */
      light: number;
      
      /**
       * Regular font weight
       */
      regular: number;
      
      /**
       * Medium font weight
       */
      medium: number;
      
      /**
       * Bold font weight
       */
      bold: number;
    };
  };
  
  /**
   * Theme spacing
   */
  spacing: {
    /**
     * Extra small spacing
     */
    xs: string;
    
    /**
     * Small spacing
     */
    sm: string;
    
    /**
     * Medium spacing
     */
    md: string;
    
    /**
     * Large spacing
     */
    lg: string;
    
    /**
     * Extra large spacing
     */
    xl: string;
  };
  
  /**
   * Theme borders
   */
  borders: {
    /**
     * Border radius
     */
    radius: {
      /**
       * Small border radius
       */
      small: string;
      
      /**
       * Medium border radius
       */
      medium: string;
      
      /**
       * Large border radius
       */
      large: string;
    };
    
    /**
     * Border width
     */
    width: {
      /**
       * Thin border width
       */
      thin: string;
      
      /**
       * Regular border width
       */
      regular: string;
      
      /**
       * Thick border width
       */
      thick: string;
    };
  };
  
  /**
   * Theme shadows
   */
  shadows: {
    /**
     * Small shadow
     */
    small: string;
    
    /**
     * Medium shadow
     */
    medium: string;
    
    /**
     * Large shadow
     */
    large: string;
  };
}

/**
 * Theme manager class
 */
export class ThemeManager {
  /**
   * Current theme
   */
  private currentTheme: ThemeConfig;
  
  /**
   * Theme change listeners
   */
  private themeChangeListeners: Array<(theme: ThemeConfig) => void> = [];
  
  /**
   * Constructor
   */
  constructor(initialTheme: ThemeConfig) {
    this.currentTheme = initialTheme;
  }
  
  /**
   * Get current theme
   */
  getTheme(): ThemeConfig {
    return this.currentTheme;
  }
  
  /**
   * Set theme
   */
  setTheme(theme: ThemeConfig): void {
    this.currentTheme = theme;
    this.notifyThemeChange();
  }
  
  /**
   * Add theme change listener
   */
  addThemeChangeListener(listener: (theme: ThemeConfig) => void): void {
    this.themeChangeListeners.push(listener);
  }
  
  /**
   * Remove theme change listener
   */
  removeThemeChangeListener(listener: (theme: ThemeConfig) => void): void {
    const index = this.themeChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.themeChangeListeners.splice(index, 1);
    }
  }
  
  /**
   * Notify theme change
   */
  private notifyThemeChange(): void {
    this.themeChangeListeners.forEach(listener => listener(this.currentTheme));
  }
  
  /**
   * Get widget styles
   */
  getWidgetStyles(): Record<string, any> {
    const { colors, typography, spacing, borders, shadows } = this.currentTheme;
    
    return {
      backgroundColor: colors.background,
      color: colors.text,
      fontFamily: typography.fontFamily,
      fontSize: typography.fontSize.medium,
      padding: spacing.md,
      borderRadius: borders.radius.medium,
      borderWidth: borders.width.regular,
      borderColor: colors.border,
      boxShadow: shadows.small
    };
  }
  
  /**
   * Get widget title styles
   */
  getWidgetTitleStyles(): Record<string, any> {
    const { typography, spacing } = this.currentTheme;
    
    return {
      fontSize: typography.fontSize.large,
      fontWeight: typography.fontWeight.bold,
      marginBottom: spacing.sm
    };
  }
  
  /**
   * Get widget content styles
   */
  getWidgetContentStyles(): Record<string, any> {
    const { spacing } = this.currentTheme;
    
    return {
      padding: spacing.sm
    };
  }
  
  /**
   * Get alert styles
   */
  getAlertStyles(type: 'success' | 'warning' | 'error' | 'info'): Record<string, any> {
    const { colors, spacing, borders } = this.currentTheme;
    
    const backgroundColor = {
      success: colors.success,
      warning: colors.warning,
      error: colors.error,
      info: colors.info
    }[type];
    
    return {
      backgroundColor,
      color: colors.text,
      padding: spacing.sm,
      borderRadius: borders.radius.small,
      marginBottom: spacing.sm
    };
  }
} 