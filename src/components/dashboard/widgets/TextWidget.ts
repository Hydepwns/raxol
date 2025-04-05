/**
 * TextWidget.ts
 * 
 * A widget component for displaying text content in the dashboard.
 * Supports markdown formatting, code highlighting, and customizable styling.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { WidgetConfig } from '../types';

/**
 * Text widget configuration
 */
export interface TextWidgetConfig extends WidgetConfig {
  /**
   * Text content to display
   */
  content: string;
  
  /**
   * Whether to enable markdown formatting
   */
  enableMarkdown?: boolean;
  
  /**
   * Whether to enable code highlighting
   */
  enableCodeHighlighting?: boolean;
  
  /**
   * Text alignment
   */
  textAlign?: 'left' | 'center' | 'right' | 'justify';
  
  /**
   * Font size in pixels
   */
  fontSize?: number;
  
  /**
   * Font family
   */
  fontFamily?: string;
  
  /**
   * Line height
   */
  lineHeight?: number;
  
  /**
   * Whether to show text controls
   */
  showControls?: boolean;
}

/**
 * Text widget state
 */
interface TextWidgetState {
  /**
   * Current text content
   */
  content: string;
  
  /**
   * Whether markdown is enabled
   */
  isMarkdownEnabled: boolean;
  
  /**
   * Whether code highlighting is enabled
   */
  isCodeHighlightingEnabled: boolean;
  
  /**
   * Whether controls are expanded
   */
  areControlsExpanded: boolean;
}

/**
 * Text widget component
 */
export class TextWidget extends RaxolComponent<TextWidgetConfig, TextWidgetState> {
  /**
   * Constructor
   */
  constructor(props: TextWidgetConfig) {
    super(props);
    
    this.state = {
      content: props.content || '',
      isMarkdownEnabled: props.enableMarkdown || false,
      isCodeHighlightingEnabled: props.enableCodeHighlighting || false,
      areControlsExpanded: false
    };
  }
  
  /**
   * Toggle controls visibility
   */
  private toggleControls(): void {
    this.setState({
      areControlsExpanded: !this.state.areControlsExpanded
    });
  }
  
  /**
   * Toggle markdown formatting
   */
  private toggleMarkdown(): void {
    this.setState({
      isMarkdownEnabled: !this.state.isMarkdownEnabled
    });
  }
  
  /**
   * Toggle code highlighting
   */
  private toggleCodeHighlighting(): void {
    this.setState({
      isCodeHighlightingEnabled: !this.state.isCodeHighlightingEnabled
    });
  }
  
  /**
   * Update text content
   */
  private updateContent(content: string): void {
    this.setState({ content });
  }
  
  /**
   * Render controls
   */
  private renderControls(): ViewElement {
    if (!this.props.showControls) {
      return View.box({ style: { display: 'none' } });
    }
    
    return View.box({
      style: {
        padding: 10,
        border: 'single',
        marginTop: 10,
        display: this.state.areControlsExpanded ? 'block' : 'none'
      },
      children: [
        View.flex({
          direction: 'column',
          gap: 10,
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Text Controls', { style: { fontWeight: 'bold' } }),
                View.box({
                  style: { cursor: 'pointer' },
                  onClick: () => this.toggleControls(),
                  children: [View.text('▼')]
                })
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Markdown'),
                View.box({
                  style: { 
                    width: 40, 
                    height: 20, 
                    backgroundColor: this.state.isMarkdownEnabled ? '#4CAF50' : '#ccc',
                    borderRadius: 4,
                    cursor: 'pointer'
                  },
                  onClick: () => this.toggleMarkdown()
                })
              ]
            }),
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Code Highlighting'),
                View.box({
                  style: { 
                    width: 40, 
                    height: 20, 
                    backgroundColor: this.state.isCodeHighlightingEnabled ? '#4CAF50' : '#ccc',
                    borderRadius: 4,
                    cursor: 'pointer'
                  },
                  onClick: () => this.toggleCodeHighlighting()
                })
              ]
            })
          ]
        })
      ]
    });
  }
  
  /**
   * Render the widget
   */
  render(): ViewElement {
    const { textAlign = 'left', fontSize = 14, fontFamily = 'monospace', lineHeight = 1.5 } = this.props;
    
    return View.box({
      style: {
        padding: 15,
        backgroundColor: this.props.backgroundColor || '#ffffff',
        border: this.props.border || 'single',
        ...this.props.styles
      },
      children: [
        View.flex({
          direction: 'column',
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text(this.props.title, { style: { fontWeight: 'bold', fontSize: 16 } }),
                this.props.showControls ? View.box({
                  style: { cursor: 'pointer' },
                  onClick: () => this.toggleControls(),
                  children: [View.text('⚙️')]
                }) : View.box({ style: { display: 'none' } })
              ]
            }),
            View.box({
              style: {
                marginTop: 10,
                textAlign,
                fontSize,
                fontFamily,
                lineHeight,
                whiteSpace: 'pre-wrap',
                overflow: 'auto',
                maxHeight: 'calc(100% - 40px)'
              },
              children: [View.text(this.state.content)]
            }),
            this.renderControls()
          ]
        })
      ]
    });
  }
} 