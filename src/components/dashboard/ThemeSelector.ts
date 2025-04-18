/**
 * ThemeSelector.ts
 *
 * Component for selecting and switching between dashboard themes.
 */

import { RaxolComponent } from "../../core/component";
import { View } from "../../core/renderer/view";
import { ThemeManager, ThemeConfig } from "./ThemeManager";

/**
 * Theme selector configuration
 */
export interface ThemeSelectorConfig {
  /**
   * Theme manager instance
   */
  themeManager: ThemeManager;

  /**
   * Whether to show theme preview
   */
  showPreview?: boolean;

  /**
   * Whether to show theme description
   */
  showDescription?: boolean;

  /**
   * Change handler
   */
  onChange?: (theme: ThemeConfig) => void;

  /**
   * Component ID
   */
  id?: string;

  /**
   * CSS class names
   */
  className?: string[];

  /**
   * Custom styles
   */
  style?: Record<string, any>;
}

/**
 * Theme selector state
 */
interface ThemeSelectorState {
  /**
   * Selected theme name
   */
  selectedThemeName: string;
}

/**
 * Theme selector component
 */
export class ThemeSelector extends RaxolComponent<
  ThemeSelectorConfig,
  ThemeSelectorState
> {
  /**
   * Component name
   */
  public static readonly componentName = "ThemeSelector";

  /**
   * Theme manager
   */
  private themeManager: ThemeManager;

  /**
   * Constructor
   */
  constructor(props: ThemeSelectorConfig) {
    super(props);

    this.themeManager = this.props.themeManager;

    this.state = {
      selectedThemeName: this.themeManager.getTheme().name,
    };
  }

  /**
   * Render component
   */
  render(): View {
    const themes = this.themeManager.getAllThemes();

    // Create dropdown options
    const options = themes.map((theme) => ({
      value: theme.name,
      label: theme.name,
      selected: theme.name === this.state.selectedThemeName,
    }));

    // Create theme previews if enabled
    const previews = this.props.showPreview
      ? themes.map((theme) => this.createThemePreview(theme))
      : [];

    // Create theme selector
    return {
      type: "container",
      attributes: {
        id: this.props.id || "theme-selector",
        class: ["theme-selector", ...(this.props.className || [])],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "8px",
          ...this.props.style,
        },
      },
      children: [
        {
          type: "dropdown",
          attributes: {
            id: `${this.props.id || "theme-selector"}-dropdown`,
            class: ["theme-selector-dropdown"],
            style: {
              width: "100%",
            },
            onChange: (e: any) => this.handleThemeChange(e.target.value),
          },
          children: options.map((option) => ({
            type: "option",
            attributes: {
              value: option.value,
              selected: option.selected,
            },
            children: [{ type: "text", value: option.label }],
          })),
        },
        ...(previews.length > 0
          ? [
              {
                type: "container",
                attributes: {
                  class: ["theme-previews"],
                  style: {
                    display: "flex",
                    flexWrap: "wrap",
                    gap: "8px",
                  },
                },
                children: previews,
              },
            ]
          : []),
      ],
    };
  }

  /**
   * Handle theme change
   */
  private handleThemeChange(themeName: string): void {
    if (this.themeManager.setThemeByName(themeName)) {
      this.setState({ selectedThemeName: themeName });

      // Call change handler if provided
      if (this.props.onChange) {
        const theme = this.themeManager.getThemeByName(themeName);
        if (theme) {
          this.props.onChange(theme);
        }
      }
    }
  }

  /**
   * Create theme preview
   */
  private createThemePreview(theme: ThemeConfig): View {
    return {
      type: "container",
      attributes: {
        class: ["theme-preview"],
        style: {
          display: "flex",
          flexDirection: "column",
          width: "120px",
          height: "80px",
          padding: "8px",
          borderRadius: theme.borders.radius.small,
          backgroundColor: theme.colors.background,
          border: `${theme.borders.width.thin} solid ${theme.colors.border}`,
          cursor: "pointer",
        },
        onClick: () => this.handleThemeChange(theme.name),
      },
      children: [
        {
          type: "text",
          attributes: {
            style: {
              color: theme.colors.text,
              fontFamily: theme.typography.fontFamily,
              fontSize: theme.typography.fontSize.small,
              fontWeight: String(theme.typography.fontWeight.bold),
            },
          },
          value: theme.name,
        },
        {
          type: "container",
          attributes: {
            style: {
              display: "flex",
              gap: "4px",
              marginTop: "8px",
            },
          },
          children: [
            // Color swatches
            this.createColorSwatch(theme.colors.primary),
            this.createColorSwatch(theme.colors.secondary),
            this.createColorSwatch(theme.colors.success),
            this.createColorSwatch(theme.colors.warning),
            this.createColorSwatch(theme.colors.error),
          ],
        },
      ],
    };
  }

  /**
   * Create color swatch
   */
  private createColorSwatch(color: string): View {
    return {
      type: "container",
      attributes: {
        style: {
          width: "16px",
          height: "16px",
          backgroundColor: color,
          borderRadius: "2px",
        },
      },
      children: [],
    };
  }
}
