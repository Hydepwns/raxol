/**
 * WidgetCustomizer.ts
 * 
 * A component for customizing widget appearance and behavior.
 * Provides a UI for modifying widget properties such as size, position,
 * colors, and other visual attributes.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/view';
import { WidgetConfig, Position, Size, Control } from './types';

/**
 * Widget customizer props
 */
export interface WidgetCustomizerProps {
  /**
   * Widget configuration to customize
   */
  widget: WidgetConfig;
  
  /**
   * Callback when widget configuration changes
   */
  onWidgetChange: (widget: WidgetConfig) => void;
  
  /**
   * Callback when customization is cancelled
   */
  onCancel: () => void;
  
  /**
   * Callback when customization is applied
   */
  onApply: () => void;
}

/**
 * Widget customizer state
 */
interface WidgetCustomizerState {
  /**
   * Current widget configuration
   */
  widget: WidgetConfig;
  
  /**
   * Whether the widget is being previewed
   */
  isPreviewing: boolean;
}

/**
 * Color options for widget customization
 */
const colorOptions = [
  { name: 'Default', value: 'transparent' },
  { name: 'White', value: '#ffffff' },
  { name: 'Light Gray', value: '#f5f5f5' },
  { name: 'Gray', value: '#e0e0e0' },
  { name: 'Dark Gray', value: '#bdbdbd' },
  { name: 'Blue', value: '#2196f3' },
  { name: 'Green', value: '#4caf50' },
  { name: 'Red', value: '#f44336' },
  { name: 'Yellow', value: '#ffeb3b' },
  { name: 'Purple', value: '#9c27b0' }
];

/**
 * Border style options
 */
const borderOptions = [
  { name: 'None', value: 'none' },
  { name: 'Single', value: 'single' },
  { name: 'Double', value: 'double' },
  { name: 'Rounded', value: 'rounded' }
];

/**
 * Widget customizer component
 */
export class WidgetCustomizer extends RaxolComponent<WidgetCustomizerProps, WidgetCustomizerState> {
  /**
   * Constructor
   */
  constructor(props: WidgetCustomizerProps) {
    super(props);
    
    // Initialize state
    this.state = {
      widget: { ...props.widget },
      isPreviewing: false
    };
    
    // Bind methods
    this.handleTitleChange = this.handleTitleChange.bind(this);
    this.handlePositionChange = this.handlePositionChange.bind(this);
    this.handleSizeChange = this.handleSizeChange.bind(this);
    this.handleBackgroundColorChange = this.handleBackgroundColorChange.bind(this);
    this.handleBorderChange = this.handleBorderChange.bind(this);
    this.handleCustomStyleChange = this.handleCustomStyleChange.bind(this);
    this.togglePreview = this.togglePreview.bind(this);
    this.handleApply = this.handleApply.bind(this);
    this.handleCancel = this.handleCancel.bind(this);
  }
  
  /**
   * Handle title change
   */
  private handleTitleChange(event: any): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        title: event.target.value
      }
    });
  }
  
  /**
   * Handle position change
   */
  private handlePositionChange(position: Position): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        position
      }
    });
  }
  
  /**
   * Handle size change
   */
  private handleSizeChange(size: Size): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        size
      }
    });
  }
  
  /**
   * Handle background color change
   */
  private handleBackgroundColorChange(color: string): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        backgroundColor: color
      }
    });
  }
  
  /**
   * Handle border change
   */
  private handleBorderChange(border: 'none' | 'single' | 'double' | 'rounded'): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        border
      }
    });
  }
  
  /**
   * Handle custom style change
   */
  private handleCustomStyleChange(property: string, value: any): void {
    const { widget } = this.state;
    
    this.setState({
      widget: {
        ...widget,
        styles: {
          ...widget.styles,
          [property]: value
        }
      }
    });
  }
  
  /**
   * Toggle preview mode
   */
  private togglePreview(): void {
    this.setState({ isPreviewing: !this.state.isPreviewing });
  }
  
  /**
   * Handle apply button click
   */
  private handleApply(): void {
    const { widget } = this.state;
    const { onWidgetChange, onApply } = this.props;
    
    onWidgetChange(widget);
    onApply();
  }
  
  /**
   * Handle cancel button click
   */
  private handleCancel(): void {
    const { onCancel } = this.props;
    onCancel();
  }
  
  /**
   * Render the widget customizer
   */
  render() {
    const { widget, isPreviewing } = this.state;
    
    return (
      <div className="widget-customizer">
        <div className="widget-customizer-header">
          <h3>Customize Widget</h3>
          
          <div className="widget-customizer-actions">
            <button
              className="widget-customizer-preview-button"
              onClick={this.togglePreview}
            >
              {isPreviewing ? 'Edit' : 'Preview'}
            </button>
            
            <button
              className="widget-customizer-cancel-button"
              onClick={this.handleCancel}
            >
              Cancel
            </button>
            
            <button
              className="widget-customizer-apply-button"
              onClick={this.handleApply}
            >
              Apply
            </button>
          </div>
        </div>
        
        {isPreviewing ? (
          <div className="widget-customizer-preview">
            <div
              className="widget-preview"
              style={{
                backgroundColor: widget.backgroundColor || 'transparent',
                border: widget.border === 'none' ? 'none' : 
                        widget.border === 'single' ? '1px solid #ccc' :
                        widget.border === 'double' ? '3px double #ccc' :
                        widget.border === 'rounded' ? '1px solid #ccc' : 'none',
                borderRadius: widget.border === 'rounded' ? '8px' : '0',
                width: `${widget.size?.width || 1}00px`,
                height: `${widget.size?.height || 1}00px`,
                ...widget.styles
              }}
            >
              <div className="widget-preview-header">
                <h4>{widget.title}</h4>
              </div>
              
              <div className="widget-preview-content">
                <p>Widget Preview</p>
                <p>Position: ({widget.position?.x || 0}, {widget.position?.y || 0})</p>
                <p>Size: {widget.size?.width || 1} x {widget.size?.height || 1}</p>
              </div>
            </div>
          </div>
        ) : (
          <div className="widget-customizer-form">
            <div className="widget-customizer-section">
              <h4>Basic Settings</h4>
              
              <div className="widget-customizer-field">
                <label>Title</label>
                <input
                  type="text"
                  value={widget.title}
                  onChange={this.handleTitleChange}
                />
              </div>
              
              <div className="widget-customizer-field">
                <label>Position</label>
                <div className="widget-customizer-position">
                  <div>
                    <label>X</label>
                    <input
                      type="number"
                      value={widget.position?.x || 0}
                      onChange={(e) => this.handlePositionChange({
                        x: parseInt(e.target.value) || 0,
                        y: widget.position?.y || 0
                      })}
                    />
                  </div>
                  
                  <div>
                    <label>Y</label>
                    <input
                      type="number"
                      value={widget.position?.y || 0}
                      onChange={(e) => this.handlePositionChange({
                        x: widget.position?.x || 0,
                        y: parseInt(e.target.value) || 0
                      })}
                    />
                  </div>
                </div>
              </div>
              
              <div className="widget-customizer-field">
                <label>Size</label>
                <div className="widget-customizer-size">
                  <div>
                    <label>Width</label>
                    <input
                      type="number"
                      value={widget.size?.width || 1}
                      onChange={(e) => this.handleSizeChange({
                        width: parseInt(e.target.value) || 1,
                        height: widget.size?.height || 1
                      })}
                    />
                  </div>
                  
                  <div>
                    <label>Height</label>
                    <input
                      type="number"
                      value={widget.size?.height || 1}
                      onChange={(e) => this.handleSizeChange({
                        width: widget.size?.width || 1,
                        height: parseInt(e.target.value) || 1
                      })}
                    />
                  </div>
                </div>
              </div>
            </div>
            
            <div className="widget-customizer-section">
              <h4>Appearance</h4>
              
              <div className="widget-customizer-field">
                <label>Background Color</label>
                <div className="widget-customizer-colors">
                  {colorOptions.map(color => (
                    <div
                      key={color.value}
                      className={`widget-customizer-color-option ${
                        widget.backgroundColor === color.value ? 'selected' : ''
                      }`}
                      style={{ backgroundColor: color.value }}
                      onClick={() => this.handleBackgroundColorChange(color.value)}
                    >
                      {color.name}
                    </div>
                  ))}
                </div>
              </div>
              
              <div className="widget-customizer-field">
                <label>Border Style</label>
                <div className="widget-customizer-borders">
                  {borderOptions.map(border => (
                    <div
                      key={border.value}
                      className={`widget-customizer-border-option ${
                        widget.border === border.value ? 'selected' : ''
                      }`}
                      onClick={() => this.handleBorderChange(border.value as any)}
                    >
                      {border.name}
                    </div>
                  ))}
                </div>
              </div>
              
              <div className="widget-customizer-field">
                <label>Custom Styles</label>
                <div className="widget-customizer-custom-styles">
                  <div>
                    <label>Padding</label>
                    <input
                      type="text"
                      value={widget.styles?.padding || ''}
                      placeholder="10px"
                      onChange={(e) => this.handleCustomStyleChange('padding', e.target.value)}
                    />
                  </div>
                  
                  <div>
                    <label>Border Radius</label>
                    <input
                      type="text"
                      value={widget.styles?.borderRadius || ''}
                      placeholder="4px"
                      onChange={(e) => this.handleCustomStyleChange('borderRadius', e.target.value)}
                    />
                  </div>
                  
                  <div>
                    <label>Box Shadow</label>
                    <input
                      type="text"
                      value={widget.styles?.boxShadow || ''}
                      placeholder="0 2px 4px rgba(0,0,0,0.1)"
                      onChange={(e) => this.handleCustomStyleChange('boxShadow', e.target.value)}
                    />
                  </div>
                </div>
              </div>
            </div>
            
            <div className="widget-customizer-section">
              <h4>Behavior</h4>
              
              <div className="widget-customizer-field">
                <label>
                  <input
                    type="checkbox"
                    checked={widget.isResizable !== false}
                    onChange={(e) => this.setState({
                      widget: {
                        ...widget,
                        isResizable: e.target.checked
                      }
                    })}
                  />
                  Resizable
                </label>
              </div>
              
              <div className="widget-customizer-field">
                <label>
                  <input
                    type="checkbox"
                    checked={widget.isDraggable !== false}
                    onChange={(e) => this.setState({
                      widget: {
                        ...widget,
                        isDraggable: e.target.checked
                      }
                    })}
                  />
                  Draggable
                </label>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }
} 