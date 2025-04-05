/**
 * ThemeSelector.ts
 * 
 * Component for selecting and switching between dashboard themes.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeManager, ThemeConfig } from './ThemeManager';
import { defaultTheme } from './themes/default';
import { darkTheme } from './themes/dark';

/**
 * Theme selector configuration
 */
export interface ThemeSelectorConfig {
  /**
   * Theme manager instance
   */
  themeManager: ThemeManager;
  
  /**
   * Available themes
   */
  themes?: ThemeConfig[];
  
  /**
   * Whether to show theme preview
   */
  showPreview?: boolean;
  
  /**
   * Whether to show theme description
   */
  showDescription?: boolean;
}

/**
 * Theme selector state
 */
interface ThemeSelectorState {
  /**
   * Whether the selector is expanded
   */
  isExpanded: boolean;
  
  /**
   * Current theme
   */
  currentTheme: ThemeConfig;
}

/**
 * Theme selector component
 */
export class ThemeSelector extends RaxolComponent<ThemeSelectorConfig, ThemeSelectorState> {
  /**
   * Constructor
   */
  constructor(props: ThemeSelectorConfig) {
    super(props);
    
    this.state = {
      isExpanded: false,
      currentTheme: props.themeManager.getTheme()
    };
  }
  
  /**
   * Component did mount
   */
  componentDidMount(): void {
    // Add theme change listener
    this.props.themeManager.addThemeChangeListener(this.handleThemeChange.bind(this));
  }
  
  /**
   * Component will unmount
   */
  componentWillUnmount(): void {
    // Remove theme change listener
    this.props.themeManager.removeThemeChangeListener(this.handleThemeChange.bind(this));
  }
  
  /**
   * Handle theme change
   */
  private handleThemeChange(theme: ThemeConfig): void {
    this.setState({ currentTheme: theme });
  }
  
  /**
   * Toggle selector
   */
  private toggleSelector(): void {
    this.setState({
      isExpanded: !this.state.isExpanded
    });
  }
  
  /**
   * Set theme
   */
  private setTheme(theme: ThemeConfig): void {
    this.props.themeManager.setTheme(theme);
  }
  
  /**
   * Get available themes
   */
  private getAvailableThemes(): ThemeConfig[] {
    return this.props.themes || [defaultTheme, darkTheme];
  }
  
  /**
   * Render theme preview
   */
  private renderThemePreview(theme: ThemeConfig): ViewElement {
    if (!this.props.showPreview) {
      return null;
    }
    
    const { colors, typography, spacing, borders } = theme;
    
    return View.box({
      style: {
        width: '100%',
        height: '60px',
        backgroundColor: colors.background,
        border: `${borders.width.regular} solid ${colors.border}`,
        borderRadius: borders.radius.small,
        padding: spacing.sm,
        marginTop: spacing.sm
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.text('Preview', {
              style: {
                color: colors.text,
                fontFamily: typography.fontFamily,
                fontSize: typography.fontSize.small,
                fontWeight: typography.fontWeight.bold
              }
            }),
            View.flex({
              direction: 'row',
              style: {
                marginTop: spacing.xs
              },
              children: [
                View.box({
                  style: {
                    width: '20px',
                    height: '20px',
                    backgroundColor: colors.primary,
                    borderRadius: borders.radius.small,
                    marginRight: spacing.xs
                  }
                }),
                View.box({
                  style: {
                    width: '20px',
                    height: '20px',
                    backgroundColor: colors.secondary,
                    borderRadius: borders.radius.small,
                    marginRight: spacing.xs
                  }
                }),
                View.box({
                  style: {
                    width: '20px',
                    height: '20px',
                    backgroundColor: colors.success,
                    borderRadius: borders.radius.small
                  }
                })
              ]
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render theme option
   */
  private renderThemeOption(theme: ThemeConfig): ViewElement {
    const { currentTheme } = this.state;
    const isSelected = theme.name === currentTheme.name;
    
    return View.box({
      style: {
        padding: '10px',
        border: 'single',
        marginBottom: '5px',
        cursor: 'pointer',
        backgroundColor: isSelected ? currentTheme.colors.primary : 'transparent'
      },
      onClick: () => this.setTheme(theme),
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text(theme.name, {
                  style: {
                    fontWeight: 'bold',
                    color: isSelected ? currentTheme.colors.background : currentTheme.colors.text
                  }
                }),
                isSelected ? View.text('✓', {
                  style: {
                    color: currentTheme.colors.background
                  }
                }) : null
              ]
            }),
            this.props.showDescription ? View.text(theme.description || '', {
              style: {
                fontSize: '12px',
                color: isSelected ? currentTheme.colors.background : currentTheme.colors.text,
                marginTop: '5px'
              }
            }) : null,
            this.renderThemePreview(theme)
          ]
        })
      ]
    });
  }
  
  /**
   * Render the selector
   */
  render(): ViewElement {
    const { currentTheme, isExpanded } = this.state;
    const availableThemes = this.getAvailableThemes();
    
    return View.box({
      style: {
        position: 'relative'
      },
      children: [
        View.box({
          style: {
            padding: '10px',
            border: 'single',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between'
          },
          onClick: () => this.toggleSelector(),
          children: [
            View.text('Theme', { style: { fontWeight: 'bold' } }),
            View.text(isExpanded ? '▼' : '▶')
          ]
        }),
        isExpanded ? View.box({
          style: {
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            backgroundColor: currentTheme.colors.background,
            border: 'single',
            padding: '10px',
            zIndex: 1000
          },
          children: availableThemes.map(theme => this.renderThemeOption(theme))
        }) : null
      ]
    });
  }
} 