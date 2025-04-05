/**
 * WidgetTemplateSelector.ts
 * 
 * Component for selecting predefined widget templates.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';
import { WidgetType } from './widgets';

/**
 * Widget template configuration
 */
export interface WidgetTemplate {
  /**
   * Template ID
   */
  id: string;
  
  /**
   * Template name
   */
  name: string;
  
  /**
   * Template description
   */
  description: string;
  
  /**
   * Widget type
   */
  type: WidgetType;
  
  /**
   * Default widget configuration
   */
  config: any;
  
  /**
   * Template thumbnail
   */
  thumbnail?: string;
}

/**
 * Template selector configuration
 */
export interface WidgetTemplateSelectorConfig {
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Available templates
   */
  templates: WidgetTemplate[];
  
  /**
   * Callback for when a template is selected
   */
  onTemplateSelect?: (template: WidgetTemplate) => void;
  
  /**
   * Callback for when selection is cancelled
   */
  onCancel?: () => void;
}

/**
 * Template selector state
 */
interface WidgetTemplateSelectorState {
  /**
   * Selected template ID
   */
  selectedTemplateId: string | null;
}

/**
 * Widget template selector component
 */
export class WidgetTemplateSelector extends RaxolComponent<WidgetTemplateSelectorConfig, WidgetTemplateSelectorState> {
  /**
   * Constructor
   */
  constructor(props: WidgetTemplateSelectorConfig) {
    super(props);
    
    this.state = {
      selectedTemplateId: null
    };
  }
  
  /**
   * Handle template selection
   */
  private handleTemplateSelect(template: WidgetTemplate): void {
    const { onTemplateSelect } = this.props;
    
    this.setState({
      selectedTemplateId: template.id
    });
    
    if (onTemplateSelect) {
      onTemplateSelect(template);
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
   * Render template card
   */
  private renderTemplateCard(template: WidgetTemplate): ViewElement {
    const { theme } = this.props;
    const { selectedTemplateId } = this.state;
    
    return View.box({
      style: {
        padding: theme.spacing.md,
        border: 'single',
        borderRadius: theme.borders.radius.small,
        backgroundColor: selectedTemplateId === template.id ? theme.colors.primary : theme.colors.background,
        color: selectedTemplateId === template.id ? theme.colors.background : theme.colors.text,
        cursor: 'pointer',
        marginBottom: theme.spacing.md
      },
      onClick: () => this.handleTemplateSelect(template),
      children: [
        View.text(template.name, {
          style: {
            fontSize: theme.typography.fontSize.medium,
            fontWeight: theme.typography.fontWeight.medium,
            marginBottom: theme.spacing.xs
          }
        }),
        View.text(template.description, {
          style: {
            fontSize: theme.typography.fontSize.small,
            marginBottom: theme.spacing.sm
          }
        }),
        template.thumbnail && View.box({
          style: {
            width: '100%',
            height: '100px',
            backgroundColor: theme.colors.background,
            borderRadius: theme.borders.radius.small,
            overflow: 'hidden'
          },
          children: [
            View.image({
              src: template.thumbnail,
              style: {
                width: '100%',
                height: '100%',
                objectFit: 'cover'
              }
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render the template selector
   */
  render(): ViewElement {
    const { theme, templates } = this.props;
    
    return View.box({
      style: {
        padding: theme.spacing.lg,
        backgroundColor: theme.colors.background,
        color: theme.colors.text,
        fontFamily: theme.typography.fontFamily
      },
      children: [
        View.text('Select Widget Template', {
          style: {
            fontSize: theme.typography.fontSize.large,
            fontWeight: theme.typography.fontWeight.bold,
            marginBottom: theme.spacing.lg
          }
        }),
        
        // Template list
        View.box({
          style: {
            marginBottom: theme.spacing.lg,
            maxHeight: '400px',
            overflow: 'auto'
          },
          children: templates.map(template => this.renderTemplateCard(template))
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
            })
          ]
        })
      ]
    });
  }
} 