/**
 * WidgetContainer.ts
 * 
 * Component for managing individual widgets within grid cells.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';
import { WidgetType, createWidget } from './widgets';

/**
 * Widget container configuration
 */
export interface WidgetContainerConfig {
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Widget type
   */
  type: WidgetType;
  
  /**
   * Widget configuration
   */
  config: any;
  
  /**
   * Whether the widget is being customized
   */
  isCustomizing: boolean;
  
  /**
   * Callback for when the widget is removed
   */
  onRemove?: () => void;
  
  /**
   * Callback for when the widget is customized
   */
  onCustomize?: () => void;
}

/**
 * Widget container state
 */
interface WidgetContainerState {
  /**
   * Widget instance
   */
  widget: any;
}

/**
 * Widget container component
 */
export class WidgetContainer extends RaxolComponent<WidgetContainerConfig, WidgetContainerState> {
  /**
   * Constructor
   */
  constructor(props: WidgetContainerConfig) {
    super(props);
    
    this.state = {
      widget: createWidget(props.type, props.config)
    };
  }
  
  /**
   * Handle widget removal
   */
  private handleRemove(): void {
    const { onRemove } = this.props;
    
    if (onRemove) {
      onRemove();
    }
  }
  
  /**
   * Handle widget customization
   */
  private handleCustomize(): void {
    const { onCustomize } = this.props;
    
    if (onCustomize) {
      onCustomize();
    }
  }
  
  /**
   * Render the widget
   */
  render(): ViewElement {
    const { theme, isCustomizing } = this.props;
    const { widget } = this.state;
    
    return View.box({
      style: {
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        backgroundColor: theme.colors.background,
        border: 'single',
        borderRadius: theme.borders.radius.small,
        overflow: 'hidden'
      },
      children: [
        // Widget header
        View.flex({
          direction: 'row',
          justify: 'space-between',
          align: 'center',
          style: {
            padding: theme.spacing.sm,
            borderBottom: 'single',
            backgroundColor: theme.colors.background
          },
          children: [
            View.text(widget.getTitle(), {
              style: {
                fontSize: theme.typography.fontSize.medium,
                fontWeight: theme.typography.fontWeight.medium
              }
            }),
            View.flex({
              direction: 'row',
              gap: theme.spacing.xs,
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
                  onClick: this.handleCustomize.bind(this),
                  children: [View.text('⚙️')]
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
                  onClick: this.handleRemove.bind(this),
                  children: [View.text('🗑️')]
                })
              ]
            })
          ]
        }),
        
        // Widget content
        View.box({
          style: {
            flex: 1,
            padding: theme.spacing.md,
            overflow: 'auto'
          },
          children: [widget.render()]
        })
      ]
    });
  }
}
