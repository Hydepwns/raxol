/**
 * DashboardSettings.ts
 * 
 * Component for managing dashboard settings and configuration.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';

/**
 * Dashboard settings configuration
 */
export interface DashboardSettingsConfig {
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Dashboard layout
   */
  layout: {
    /**
     * Number of rows
     */
    rows: number;
    
    /**
     * Number of columns
     */
    columns: number;
  };
  
  /**
   * Callback for when layout changes
   */
  onLayoutChange?: (layout: { rows: number; columns: number }) => void;
  
  /**
   * Callback for when settings are saved
   */
  onSave?: () => void;
  
  /**
   * Callback for when settings are cancelled
   */
  onCancel?: () => void;
}

/**
 * Dashboard settings state
 */
interface DashboardSettingsState {
  /**
   * Current layout
   */
  layout: {
    /**
     * Number of rows
     */
    rows: number;
    
    /**
     * Number of columns
     */
    columns: number;
  };
}

/**
 * Dashboard settings component
 */
export class DashboardSettings extends RaxolComponent<DashboardSettingsConfig, DashboardSettingsState> {
  /**
   * Constructor
   */
  constructor(props: DashboardSettingsConfig) {
    super(props);
    
    this.state = {
      layout: { ...props.layout }
    };
  }
  
  /**
   * Handle layout change
   */
  private handleLayoutChange(field: 'rows' | 'columns', value: number): void {
    const { onLayoutChange } = this.props;
    
    this.setState({
      layout: {
        ...this.state.layout,
        [field]: value
      }
    });
    
    if (onLayoutChange) {
      onLayoutChange({
        ...this.state.layout,
        [field]: value
      });
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
   * Handle cancel
   */
  private handleCancel(): void {
    const { onCancel } = this.props;
    
    if (onCancel) {
      onCancel();
    }
  }
  
  /**
   * Render number input
   */
  private renderNumberInput(
    label: string,
    value: number,
    onChange: (value: number) => void,
    min: number = 1,
    max: number = 12
  ): ViewElement {
    const { theme } = this.props;
    
    return View.box({
      style: {
        marginBottom: theme.spacing.md
      },
      children: [
        View.text(label, {
          style: {
            fontSize: theme.typography.fontSize.medium,
            fontWeight: theme.typography.fontWeight.medium,
            marginBottom: theme.spacing.xs
          }
        }),
        View.box({
          style: {
            display: 'flex',
            alignItems: 'center'
          },
          children: [
            View.box({
              style: {
                padding: theme.spacing.sm,
                border: 'single',
                borderRadius: theme.borders.radius.small,
                backgroundColor: theme.colors.background,
                color: theme.colors.text,
                width: '60px',
                textAlign: 'center'
              },
              children: [View.text(value.toString())]
            }),
            View.flex({
              direction: 'column',
              style: {
                marginLeft: theme.spacing.sm
              },
              children: [
                View.box({
                  style: {
                    padding: theme.spacing.xs,
                    border: 'single',
                    borderRadius: theme.borders.radius.small,
                    cursor: 'pointer',
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text
                  },
                  onClick: () => onChange(Math.min(value + 1, max)),
                  children: [View.text('▲')]
                }),
                View.box({
                  style: {
                    padding: theme.spacing.xs,
                    border: 'single',
                    borderRadius: theme.borders.radius.small,
                    cursor: 'pointer',
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text
                  },
                  onClick: () => onChange(Math.max(value - 1, min)),
                  children: [View.text('▼')]
                })
              ]
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render the settings
   */
  render(): ViewElement {
    const { theme } = this.props;
    const { layout } = this.state;
    
    return View.box({
      style: {
        padding: theme.spacing.lg,
        backgroundColor: theme.colors.background,
        color: theme.colors.text,
        fontFamily: theme.typography.fontFamily
      },
      children: [
        View.text('Dashboard Settings', {
          style: {
            fontSize: theme.typography.fontSize.large,
            fontWeight: theme.typography.fontWeight.bold,
            marginBottom: theme.spacing.lg
          }
        }),
        View.box({
          style: {
            marginBottom: theme.spacing.lg
          },
          children: [
            this.renderNumberInput(
              'Number of Rows',
              layout.rows,
              (value) => this.handleLayoutChange('rows', value)
            ),
            this.renderNumberInput(
              'Number of Columns',
              layout.columns,
              (value) => this.handleLayoutChange('columns', value)
            )
          ]
        }),
        View.flex({
          direction: 'row',
          justify: 'flex-end',
          style: {
            marginTop: theme.spacing.lg
          },
          children: [
            View.box({
              style: {
                padding: theme.spacing.sm,
                border: 'single',
                borderRadius: theme.borders.radius.small,
                cursor: 'pointer',
                backgroundColor: theme.colors.background,
                color: theme.colors.text,
                marginRight: theme.spacing.sm
              },
              onClick: this.handleCancel.bind(this),
              children: [View.text('Cancel')]
            }),
            View.box({
              style: {
                padding: theme.spacing.sm,
                border: 'single',
                borderRadius: theme.borders.radius.small,
                cursor: 'pointer',
                backgroundColor: theme.colors.primary,
                color: theme.colors.background
              },
              onClick: this.handleSave.bind(this),
              children: [View.text('Save')]
            })
          ]
        })
      ]
    });
  }
} 