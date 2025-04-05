/**
 * WidgetCustomizationPanel.ts
 * 
 * Component for customizing widget settings and configuration.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';
import { WidgetType } from './widgets';

/**
 * Widget customization panel configuration
 */
export interface WidgetCustomizationPanelConfig {
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Widget type
   */
  type: WidgetType;
  
  /**
   * Current widget configuration
   */
  config: any;
  
  /**
   * Callback for when configuration changes
   */
  onConfigChange?: (config: any) => void;
  
  /**
   * Callback for when customization is saved
   */
  onSave?: () => void;
  
  /**
   * Callback for when customization is cancelled
   */
  onCancel?: () => void;
}

/**
 * Widget customization panel state
 */
interface WidgetCustomizationPanelState {
  /**
   * Current configuration
   */
  config: any;
}

/**
 * Widget customization panel component
 */
export class WidgetCustomizationPanel extends RaxolComponent<WidgetCustomizationPanelConfig, WidgetCustomizationPanelState> {
  /**
   * Constructor
   */
  constructor(props: WidgetCustomizationPanelConfig) {
    super(props);
    
    this.state = {
      config: { ...props.config }
    };
  }
  
  /**
   * Handle configuration change
   */
  private handleConfigChange(key: string, value: any): void {
    const { onConfigChange } = this.props;
    
    this.setState({
      config: {
        ...this.state.config,
        [key]: value
      }
    });
    
    if (onConfigChange) {
      onConfigChange({
        ...this.state.config,
        [key]: value
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
   * Render text input
   */
  private renderTextInput(
    label: string,
    value: string,
    onChange: (value: string) => void
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
            padding: theme.spacing.sm,
            border: 'single',
            borderRadius: theme.borders.radius.small,
            backgroundColor: theme.colors.background,
            color: theme.colors.text
          },
          content: value,
          onInput: (e) => onChange(e.target.value)
        })
      ]
    });
  }
  
  /**
   * Render number input
   */
  private renderNumberInput(
    label: string,
    value: number,
    onChange: (value: number) => void,
    min?: number,
    max?: number
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
            padding: theme.spacing.sm,
            border: 'single',
            borderRadius: theme.borders.radius.small,
            backgroundColor: theme.colors.background,
            color: theme.colors.text
          },
          content: value.toString(),
          type: 'number',
          min: min?.toString(),
          max: max?.toString(),
          onInput: (e) => onChange(parseFloat(e.target.value))
        })
      ]
    });
  }
  
  /**
   * Render boolean input
   */
  private renderBooleanInput(
    label: string,
    value: boolean,
    onChange: (value: boolean) => void
  ): ViewElement {
    const { theme } = this.props;
    
    return View.box({
      style: {
        marginBottom: theme.spacing.md
      },
      children: [
        View.flex({
          direction: 'row',
          align: 'center',
          style: {
            gap: theme.spacing.sm
          },
          children: [
            View.box({
              style: {
                width: '20px',
                height: '20px',
                border: 'single',
                borderRadius: theme.borders.radius.small,
                backgroundColor: value ? theme.colors.primary : theme.colors.background,
                cursor: 'pointer'
              },
              onClick: () => onChange(!value)
            }),
            View.text(label, {
              style: {
                fontSize: theme.typography.fontSize.medium,
                fontWeight: theme.typography.fontWeight.medium
              }
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render the customization panel
   */
  render(): ViewElement {
    const { theme, type } = this.props;
    const { config } = this.state;
    
    return View.box({
      style: {
        padding: theme.spacing.lg,
        backgroundColor: theme.colors.background,
        color: theme.colors.text,
        fontFamily: theme.typography.fontFamily
      },
      children: [
        View.text(`Customize ${type} Widget`, {
          style: {
            fontSize: theme.typography.fontSize.large,
            fontWeight: theme.typography.fontWeight.bold,
            marginBottom: theme.spacing.lg
          }
        }),
        
        // Widget-specific configuration fields
        View.box({
          style: {
            marginBottom: theme.spacing.lg
          },
          children: [
            this.renderTextInput(
              'Title',
              config.title || '',
              (value) => this.handleConfigChange('title', value)
            ),
            this.renderNumberInput(
              'Refresh Interval (seconds)',
              config.refreshInterval || 60,
              (value) => this.handleConfigChange('refreshInterval', value),
              1,
              3600
            ),
            this.renderBooleanInput(
              'Auto Refresh',
              config.autoRefresh !== false,
              (value) => this.handleConfigChange('autoRefresh', value)
            )
          ]
        }),
        
        // Action buttons
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