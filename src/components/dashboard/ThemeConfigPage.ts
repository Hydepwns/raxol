/**
 * ThemeConfigPage.ts
 *
 * Theme configuration page component that allows users to customize and save themes.
 */

import { RaxolComponent } from "../../core/component";
import { View } from "../../core/renderer/view";
import { ThemeManager, ThemeConfig } from "./ThemeManager";
import { ThemeSelector } from "./ThemeSelector";

/**
 * Theme configuration page properties
 */
export interface ThemeConfigPageProps {
  /**
   * Theme manager instance
   */
  themeManager: ThemeManager;

  /**
   * ID for the component
   */
  id?: string;

  /**
   * Save callback
   */
  onSave?: (theme: ThemeConfig) => void;

  /**
   * Cancel callback
   */
  onCancel?: () => void;
}

/**
 * Theme configuration page state
 */
interface ThemeConfigPageState {
  /**
   * Current theme being edited
   */
  currentTheme: ThemeConfig;

  /**
   * Whether the theme has been modified
   */
  isModified: boolean;

  /**
   * Active section tab
   */
  activeSection: "colors" | "typography" | "spacing" | "borders" | "shadows";
}

/**
 * Theme configuration page component
 */
export class ThemeConfigPage extends RaxolComponent<
  ThemeConfigPageProps,
  ThemeConfigPageState
> {
  /**
   * Component name
   */
  public static readonly componentName = "ThemeConfigPage";

  /**
   * Theme selector component
   */
  private themeSelector: ThemeSelector;

  /**
   * Constructor
   */
  constructor(props: ThemeConfigPageProps) {
    super(props);

    this.state = {
      currentTheme: JSON.parse(JSON.stringify(props.themeManager.getTheme())),
      isModified: false,
      activeSection: "colors",
    };

    // Create theme selector
    this.themeSelector = new ThemeSelector({
      themeManager: props.themeManager,
      showPreview: true,
      onChange: this.handleThemeChange.bind(this),
    });
  }

  /**
   * Render component
   */
  render(): View {
    const { currentTheme, isModified, activeSection } = this.state;

    return {
      type: "container",
      attributes: {
        id: this.props.id || "theme-config-page",
        class: ["theme-config-page"],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "16px",
          padding: "16px",
        },
      },
      children: [
        // Header
        {
          type: "container",
          attributes: {
            class: ["theme-config-header"],
            style: {
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            },
          },
          children: [
            {
              type: "text",
              attributes: {
                style: {
                  fontSize: "20px",
                  fontWeight: "bold",
                },
              },
              value: "Theme Configuration",
            },
            {
              type: "container",
              attributes: {
                class: ["theme-actions"],
                style: {
                  display: "flex",
                  gap: "8px",
                },
              },
              children: [
                {
                  type: "button",
                  attributes: {
                    class: ["button", "button-secondary"],
                    disabled: !isModified,
                    onClick: this.handleCancel.bind(this),
                  },
                  children: [{ type: "text", value: "Cancel" }],
                },
                {
                  type: "button",
                  attributes: {
                    class: ["button", "button-primary"],
                    disabled: !isModified,
                    onClick: this.handleSave.bind(this),
                  },
                  children: [{ type: "text", value: "Save" }],
                },
              ],
            },
          ],
        },

        // Theme selector
        this.themeSelector.render(),

        // Theme properties
        {
          type: "container",
          attributes: {
            class: ["theme-properties"],
          },
          children: [
            // Tabs
            {
              type: "container",
              attributes: {
                class: ["tabs"],
                style: {
                  display: "flex",
                  gap: "2px",
                  marginBottom: "16px",
                },
              },
              children: [
                this.renderTab("colors", "Colors"),
                this.renderTab("typography", "Typography"),
                this.renderTab("spacing", "Spacing"),
                this.renderTab("borders", "Borders"),
                this.renderTab("shadows", "Shadows"),
              ],
            },

            // Content
            {
              type: "container",
              attributes: {
                class: ["tab-content"],
              },
              children: [
                activeSection === "colors" ? this.renderColorsSection() : null,
                activeSection === "typography"
                  ? this.renderTypographySection()
                  : null,
                activeSection === "spacing"
                  ? this.renderSpacingSection()
                  : null,
                activeSection === "borders"
                  ? this.renderBordersSection()
                  : null,
                activeSection === "shadows"
                  ? this.renderShadowsSection()
                  : null,
              ],
            },
          ],
        },

        // Theme actions
        {
          type: "container",
          attributes: {
            class: ["theme-config-actions"],
            style: {
              display: "flex",
              justifyContent: "space-between",
              marginTop: "16px",
            },
          },
          children: [
            {
              type: "button",
              attributes: {
                class: ["button", "button-action"],
                onClick: this.handleExport.bind(this),
              },
              children: [{ type: "text", value: "Export Theme" }],
            },
            {
              type: "button",
              attributes: {
                class: ["button", "button-action"],
                onClick: this.handleCreateNew.bind(this),
              },
              children: [{ type: "text", value: "Create New Theme" }],
            },
          ],
        },
      ],
    };
  }

  /**
   * Render tab button
   */
  private renderTab(id: string, label: string): View {
    const { activeSection } = this.state;
    const isActive = activeSection === id;

    return {
      type: "button",
      attributes: {
        class: ["tab", isActive ? "tab-active" : ""],
        style: {
          padding: "8px 16px",
          backgroundColor: isActive ? "#1976d2" : "#f5f5f5",
          color: isActive ? "#ffffff" : "#333333",
          border: "none",
          cursor: "pointer",
        },
        onClick: () => this.setState({ activeSection: id as any }),
      },
      children: [{ type: "text", value: label }],
    };
  }

  /**
   * Render colors section
   */
  private renderColorsSection(): View {
    const { currentTheme } = this.state;
    const colors = currentTheme.colors;

    return {
      type: "container",
      attributes: {
        class: ["colors-section"],
        style: {
          display: "grid",
          gridTemplateColumns: "repeat(2, 1fr)",
          gap: "16px",
        },
      },
      children: Object.entries(colors).map(([key, value]) =>
        this.renderColorInput(key, value)
      ),
    };
  }

  /**
   * Render color input
   */
  private renderColorInput(key: string, value: string): View {
    return {
      type: "container",
      attributes: {
        class: ["color-input-group"],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "4px",
        },
      },
      children: [
        {
          type: "text",
          attributes: {
            style: {
              fontWeight: "bold",
            },
          },
          value: this.formatLabel(key),
        },
        {
          type: "container",
          attributes: {
            style: {
              display: "flex",
              gap: "8px",
              alignItems: "center",
            },
          },
          children: [
            {
              type: "container",
              attributes: {
                style: {
                  width: "32px",
                  height: "32px",
                  backgroundColor: value,
                  border: "1px solid #cccccc",
                },
              },
              children: [],
            },
            {
              type: "input",
              attributes: {
                type: "text",
                value: value,
                style: {
                  flex: 1,
                },
                onChange: (e: any) =>
                  this.handleColorChange(key, e.target.value),
              },
              children: [],
            },
          ],
        },
      ],
    };
  }

  /**
   * Render typography section
   */
  private renderTypographySection(): View {
    const { currentTheme } = this.state;
    const typography = currentTheme.typography;

    return {
      type: "container",
      attributes: {
        class: ["typography-section"],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "16px",
        },
      },
      children: [
        // Font family
        {
          type: "container",
          attributes: {
            class: ["input-group"],
            style: {
              display: "flex",
              flexDirection: "column",
              gap: "4px",
            },
          },
          children: [
            {
              type: "text",
              attributes: {
                style: {
                  fontWeight: "bold",
                },
              },
              value: "Font Family",
            },
            {
              type: "input",
              attributes: {
                type: "text",
                value: typography.fontFamily,
                onChange: (e: any) =>
                  this.handleTypographyChange("fontFamily", e.target.value),
              },
              children: [],
            },
          ],
        },

        // Font sizes
        {
          type: "container",
          attributes: {
            class: ["font-sizes"],
            style: {
              display: "grid",
              gridTemplateColumns: "repeat(2, 1fr)",
              gap: "16px",
            },
          },
          children: Object.entries(typography.fontSize).map(([key, value]) =>
            this.renderInputGroup(
              `Font Size (${this.formatLabel(key)})`,
              value,
              (e: any) =>
                this.handleTypographyNestedChange(
                  "fontSize",
                  key,
                  e.target.value
                )
            )
          ),
        },

        // Font weights
        {
          type: "container",
          attributes: {
            class: ["font-weights"],
            style: {
              display: "grid",
              gridTemplateColumns: "repeat(2, 1fr)",
              gap: "16px",
            },
          },
          children: Object.entries(typography.fontWeight).map(([key, value]) =>
            this.renderInputGroup(
              `Font Weight (${this.formatLabel(key)})`,
              String(value),
              (e: any) =>
                this.handleTypographyNestedChange(
                  "fontWeight",
                  key,
                  parseInt(e.target.value, 10)
                )
            )
          ),
        },
      ],
    };
  }

  /**
   * Render spacing section
   */
  private renderSpacingSection(): View {
    const { currentTheme } = this.state;
    const spacing = currentTheme.spacing;

    return {
      type: "container",
      attributes: {
        class: ["spacing-section"],
        style: {
          display: "grid",
          gridTemplateColumns: "repeat(2, 1fr)",
          gap: "16px",
        },
      },
      children: Object.entries(spacing).map(([key, value]) =>
        this.renderInputGroup(
          `Spacing (${this.formatLabel(key)})`,
          value,
          (e: any) => this.handleSpacingChange(key, e.target.value)
        )
      ),
    };
  }

  /**
   * Render borders section
   */
  private renderBordersSection(): View {
    const { currentTheme } = this.state;
    const borders = currentTheme.borders;

    return {
      type: "container",
      attributes: {
        class: ["borders-section"],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "16px",
        },
      },
      children: [
        // Border radius
        {
          type: "container",
          attributes: {
            class: ["border-radius"],
            style: {
              display: "flex",
              flexDirection: "column",
              gap: "8px",
            },
          },
          children: [
            {
              type: "text",
              attributes: {
                style: {
                  fontWeight: "bold",
                },
              },
              value: "Border Radius",
            },
            {
              type: "container",
              attributes: {
                style: {
                  display: "grid",
                  gridTemplateColumns: "repeat(2, 1fr)",
                  gap: "16px",
                },
              },
              children: Object.entries(borders.radius).map(([key, value]) =>
                this.renderInputGroup(this.formatLabel(key), value, (e: any) =>
                  this.handleBordersNestedChange("radius", key, e.target.value)
                )
              ),
            },
          ],
        },

        // Border width
        {
          type: "container",
          attributes: {
            class: ["border-width"],
            style: {
              display: "flex",
              flexDirection: "column",
              gap: "8px",
            },
          },
          children: [
            {
              type: "text",
              attributes: {
                style: {
                  fontWeight: "bold",
                },
              },
              value: "Border Width",
            },
            {
              type: "container",
              attributes: {
                style: {
                  display: "grid",
                  gridTemplateColumns: "repeat(2, 1fr)",
                  gap: "16px",
                },
              },
              children: Object.entries(borders.width).map(([key, value]) =>
                this.renderInputGroup(this.formatLabel(key), value, (e: any) =>
                  this.handleBordersNestedChange("width", key, e.target.value)
                )
              ),
            },
          ],
        },
      ],
    };
  }

  /**
   * Render shadows section
   */
  private renderShadowsSection(): View {
    const { currentTheme } = this.state;
    const shadows = currentTheme.shadows;

    return {
      type: "container",
      attributes: {
        class: ["shadows-section"],
        style: {
          display: "grid",
          gridTemplateColumns: "repeat(1, 1fr)",
          gap: "16px",
        },
      },
      children: Object.entries(shadows).map(([key, value]) =>
        this.renderInputGroup(
          `Shadow (${this.formatLabel(key)})`,
          value,
          (e: any) => this.handleShadowsChange(key, e.target.value)
        )
      ),
    };
  }

  /**
   * Render input group
   */
  private renderInputGroup(
    label: string,
    value: string,
    onChange: (e: any) => void
  ): View {
    return {
      type: "container",
      attributes: {
        class: ["input-group"],
        style: {
          display: "flex",
          flexDirection: "column",
          gap: "4px",
        },
      },
      children: [
        {
          type: "text",
          attributes: {
            style: {
              fontWeight: "bold",
            },
          },
          value: label,
        },
        {
          type: "input",
          attributes: {
            type: "text",
            value: value,
            onChange: onChange,
          },
          children: [],
        },
      ],
    };
  }

  /**
   * Format property key as a label
   */
  private formatLabel(key: string): string {
    return key
      .replace(/([A-Z])/g, " $1")
      .replace(/^./, (str) => str.toUpperCase());
  }

  /**
   * Handle theme change
   */
  private handleThemeChange(theme: ThemeConfig): void {
    this.setState({
      currentTheme: JSON.parse(JSON.stringify(theme)),
      isModified: false,
    });
  }

  /**
   * Handle color change
   */
  private handleColorChange(key: string, value: string): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        colors: {
          ...currentTheme.colors,
          [key]: value,
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle typography change
   */
  private handleTypographyChange(key: string, value: any): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        typography: {
          ...currentTheme.typography,
          [key]: value,
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle nested typography change
   */
  private handleTypographyNestedChange(
    parent: string,
    key: string,
    value: any
  ): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        typography: {
          ...currentTheme.typography,
          [parent]: {
            ...currentTheme.typography[parent],
            [key]: value,
          },
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle spacing change
   */
  private handleSpacingChange(key: string, value: string): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        spacing: {
          ...currentTheme.spacing,
          [key]: value,
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle nested borders change
   */
  private handleBordersNestedChange(
    parent: string,
    key: string,
    value: any
  ): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        borders: {
          ...currentTheme.borders,
          [parent]: {
            ...currentTheme.borders[parent],
            [key]: value,
          },
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle shadows change
   */
  private handleShadowsChange(key: string, value: string): void {
    const { currentTheme } = this.state;

    this.setState({
      currentTheme: {
        ...currentTheme,
        shadows: {
          ...currentTheme.shadows,
          [key]: value,
        },
      },
      isModified: true,
    });
  }

  /**
   * Handle save
   */
  private handleSave(): void {
    const { currentTheme } = this.state;
    const { themeManager, onSave } = this.props;

    // Save the theme
    themeManager.saveTheme(currentTheme);

    // Apply the theme
    themeManager.setTheme(currentTheme);

    // Reset modified flag
    this.setState({ isModified: false });

    // Call save callback
    if (onSave) {
      onSave(currentTheme);
    }
  }

  /**
   * Handle cancel
   */
  private handleCancel(): void {
    const { themeManager, onCancel } = this.props;

    // Reset to the current theme
    this.setState({
      currentTheme: JSON.parse(JSON.stringify(themeManager.getTheme())),
      isModified: false,
    });

    // Call cancel callback
    if (onCancel) {
      onCancel();
    }
  }

  /**
   * Handle export
   */
  private handleExport(): void {
    const { currentTheme } = this.state;

    // Create a JSON string of the theme
    const json = JSON.stringify(currentTheme, null, 2);

    // Use a textarea to copy to clipboard
    const textarea = document.createElement("textarea");
    textarea.value = json;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);

    // Show a notification
    alert("Theme copied to clipboard as JSON");
  }

  /**
   * Handle create new theme
   */
  private handleCreateNew(): void {
    const { currentTheme } = this.state;

    // Create a new theme based on the current one
    const newTheme: ThemeConfig = {
      ...JSON.parse(JSON.stringify(currentTheme)),
      name: `${currentTheme.name} Copy`,
    };

    // Set as current theme
    this.setState({
      currentTheme: newTheme,
      isModified: true,
    });
  }
}
