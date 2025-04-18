/**
 * ThemeManager.ts
 *
 * Manages dashboard theme customization and styling.
 */

import { defaultTheme } from "./themes/default";
import { darkTheme } from "./themes/dark";
import { highContrastTheme } from "./themes/high-contrast";
import * as fs from "fs";
import * as path from "path";

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
   * Available themes
   */
  private themes: Map<string, ThemeConfig> = new Map();

  /**
   * Theme change listeners
   */
  private themeChangeListeners: Array<(theme: ThemeConfig) => void> = [];

  /**
   * Constructor
   */
  constructor(initialTheme: ThemeConfig = defaultTheme) {
    this.currentTheme = initialTheme;

    // Register built-in themes
    this.registerTheme(defaultTheme);
    this.registerTheme(darkTheme);
    this.registerTheme(highContrastTheme);

    // Load custom themes
    this.loadCustomThemes();
  }

  /**
   * Get current theme
   */
  getTheme(): ThemeConfig {
    return this.currentTheme;
  }

  /**
   * Get theme by name
   */
  getThemeByName(name: string): ThemeConfig | undefined {
    return this.themes.get(name);
  }

  /**
   * Get all available themes
   */
  getAllThemes(): ThemeConfig[] {
    return Array.from(this.themes.values());
  }

  /**
   * Set theme by name
   */
  setThemeByName(name: string): boolean {
    const theme = this.themes.get(name);
    if (theme) {
      this.setTheme(theme);
      return true;
    }
    return false;
  }

  /**
   * Set theme
   */
  setTheme(theme: ThemeConfig): void {
    this.currentTheme = theme;
    this.notifyThemeChange();
  }

  /**
   * Register a theme
   */
  registerTheme(theme: ThemeConfig): void {
    this.themes.set(theme.name, theme);
  }

  /**
   * Save a custom theme
   */
  saveTheme(theme: ThemeConfig): boolean {
    try {
      const themesDir = path.resolve("themes");

      // Ensure themes directory exists
      if (!fs.existsSync(themesDir)) {
        fs.mkdirSync(themesDir, { recursive: true });
      }

      // Convert theme to JSON format
      const themeJson = JSON.stringify(theme, null, 2);

      // Save theme to file
      const filePath = path.join(
        themesDir,
        `${theme.name.replace(/\s+/g, "")}.json`
      );
      fs.writeFileSync(filePath, themeJson, "utf8");

      // Register theme
      this.registerTheme(theme);

      return true;
    } catch (error) {
      console.error("Failed to save theme:", error);
      return false;
    }
  }

  /**
   * Load custom themes from disk
   */
  private loadCustomThemes(): void {
    try {
      const themesDir = path.resolve("themes");

      // Skip if themes directory doesn't exist
      if (!fs.existsSync(themesDir)) {
        return;
      }

      // Read all JSON files in themes directory
      const files = fs.readdirSync(themesDir);
      for (const file of files) {
        if (file.endsWith(".json")) {
          try {
            const filePath = path.join(themesDir, file);
            const themeJson = fs.readFileSync(filePath, "utf8");
            const theme = JSON.parse(themeJson) as ThemeConfig;

            // Validate theme
            if (this.isValidTheme(theme)) {
              this.registerTheme(theme);
            }
          } catch (err) {
            console.warn(`Failed to load theme from ${file}:`, err);
          }
        }
      }
    } catch (error) {
      console.error("Failed to load custom themes:", error);
    }
  }

  /**
   * Validate theme structure
   */
  private isValidTheme(theme: any): theme is ThemeConfig {
    return (
      theme &&
      typeof theme.name === "string" &&
      theme.colors &&
      theme.typography &&
      theme.spacing &&
      theme.borders &&
      theme.shadows
    );
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
    this.themeChangeListeners.forEach((listener) =>
      listener(this.currentTheme)
    );
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
      boxShadow: shadows.small,
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
      marginBottom: spacing.sm,
    };
  }

  /**
   * Get widget content styles
   */
  getWidgetContentStyles(): Record<string, any> {
    const { spacing } = this.currentTheme;

    return {
      padding: spacing.sm,
    };
  }

  /**
   * Get alert styles
   */
  getAlertStyles(
    type: "success" | "warning" | "error" | "info"
  ): Record<string, any> {
    const { colors, spacing, borders } = this.currentTheme;

    const backgroundColor = {
      success: colors.success,
      warning: colors.warning,
      error: colors.error,
      info: colors.info,
    }[type];

    return {
      backgroundColor,
      color: colors.text,
      padding: spacing.sm,
      borderRadius: borders.radius.small,
      marginBottom: spacing.sm,
    };
  }
}
