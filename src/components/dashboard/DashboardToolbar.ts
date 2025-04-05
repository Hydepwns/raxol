/**
 * DashboardToolbar.ts
 * 
 * Toolbar component for dashboard actions and controls.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';
import { ThemeSelector } from './ThemeSelector';

/**
 * Dashboard toolbar configuration
 */
export interface DashboardToolbarConfig {
  /**
   * Dashboard title
   */
  title: string;
  
  /**
   * Dashboard description
   */
  description?: string;
  
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Theme manager instance
   */
  themeManager: any;
  
  /**
   * Whether the dashboard is in edit mode
   */
  isEditMode?: boolean;
  
  /**
   * Callback for when edit mode is toggled
   */
  onEditModeToggle?: (isEditMode: boolean) => void;
  
  /**
   * Callback for when the dashboard is refreshed
   */
  onRefresh?: () => void;
  
  /**
   * Callback for when the dashboard is saved
   */
  onSave?: () => void;
  
  /**
   * Callback for when the dashboard is reset
   */
  onReset?: () => void;
  
  /**
   * Callback for when the settings button is clicked
   */
  onSettingsClick?: () => void;
}

/**
 * Dashboard toolbar state
 */
interface DashboardToolbarState {
  /**
   * Whether the toolbar menu is expanded
   */
  isMenuExpanded: boolean;
}

/**
 * Dashboard toolbar component
 */
export class DashboardToolbar extends RaxolComponent<DashboardToolbarConfig, DashboardToolbarState> {
  /**
   * Constructor
   */
  constructor(props: DashboardToolbarConfig) {
    super(props);
    
    this.state = {
      isMenuExpanded: false
    };
  }
  
  /**
   * Toggle menu
   */
  private toggleMenu(): void {
    this.setState({
      isMenuExpanded: !this.state.isMenuExpanded
    });
  }
  
  /**
   * Toggle edit mode
   */
  private toggleEditMode(): void {
    const { isEditMode, onEditModeToggle } = this.props;
    
    if (onEditModeToggle) {
      onEditModeToggle(!isEditMode);
    }
  }
  
  /**
   * Handle refresh
   */
  private handleRefresh(): void {
    const { onRefresh } = this.props;
    
    if (onRefresh) {
      onRefresh();
    }
  }
  
  /**
   * Handle save
   */
  private handleSave(): void {
    const { onSave } = this.props;
    
    if (onSave) {
      onSave();
    }
  }
  
  /**
   * Handle reset
   */
  private handleReset(): void {
    const { onReset } = this.props;
    
    if (onReset) {
      onReset();
    }
  }
  
  /**
   * Render toolbar button
   */
  private renderButton(
    icon: string,
    label: string,
    onClick: () => void,
    isActive?: boolean
  ): ViewElement {
    const { theme } = this.props;
    
    return View.box({
      style: {
        padding: theme.spacing.sm,
        border: 'single',
        borderRadius: theme.borders.radius.small,
        cursor: 'pointer',
        backgroundColor: isActive ? theme.colors.primary : 'transparent',
        color: isActive ? theme.colors.background : theme.colors.text,
        marginRight: theme.spacing.sm,
        display: 'flex',
        alignItems: 'center'
      },
      onClick,
      children: [
        View.text(icon, { style: { marginRight: theme.spacing.xs } }),
        View.text(label)
      ]
    });
  }
  
  /**
   * Render the toolbar
   */
  render(): ViewElement {
    const { title, description, theme, isEditMode, onSettingsClick } = this.props;
    const { isMenuExpanded } = this.state;
    
    return View.box({
      style: {
        padding: theme.spacing.md,
        borderBottom: `${theme.borders.width.regular} solid ${theme.colors.border}`,
        backgroundColor: theme.colors.background
      },
      children: [
        View.flex({
          direction: 'row',
          justify: 'space-between',
          align: 'center',
          children: [
            View.box({
              children: [
                View.text(title, {
                  style: {
                    fontSize: theme.typography.fontSize.large,
                    fontWeight: theme.typography.fontWeight.bold,
                    color: theme.colors.text
                  }
                }),
                description ? View.text(description, {
                  style: {
                    fontSize: theme.typography.fontSize.small,
                    color: theme.colors.secondary,
                    marginTop: theme.spacing.xs
                  }
                }) : null
              ]
            }),
            View.flex({
              direction: 'row',
              align: 'center',
              children: [
                this.renderButton('🔄', 'Refresh', this.handleRefresh.bind(this)),
                this.renderButton('💾', 'Save', this.handleSave.bind(this)),
                this.renderButton('↺', 'Reset', this.handleReset.bind(this)),
                this.renderButton(
                  isEditMode ? '✓' : '✎',
                  isEditMode ? 'Done' : 'Edit',
                  this.toggleEditMode.bind(this),
                  isEditMode
                ),
                View.box({
                  style: { marginLeft: theme.spacing.md },
                  children: [
                    ThemeSelector({
                      themeManager: this.props.themeManager,
                      showPreview: true,
                      showDescription: true
                    })
                  ]
                }),
                View.box({
                  style: {
                    padding: theme.spacing.sm,
                    border: 'single',
                    borderRadius: theme.borders.radius.small,
                    cursor: 'pointer',
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text
                  },
                  onClick: onSettingsClick,
                  children: [View.text('⚙️ Settings')]
                })
              ]
            })
          ]
        })
      ]
    });
  }
} 