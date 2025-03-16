/**
 * WidgetContainer.ts
 * 
 * A container for dashboard widgets that supports dragging, resizing,
 * and configuration options. This component wraps the actual widget content
 * and adds the necessary controls and interaction handlers.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/view';
import { Position, Size, WidgetConfig, Control } from './types';

/**
 * Widget container props
 */
export interface WidgetContainerProps extends WidgetConfig {
  /**
   * Whether the widget is currently in edit mode
   */
  isEditable?: boolean;
  
  /**
   * Callback for when dragging starts
   */
  onDragStart?: () => void;
  
  /**
   * Callback for when dragging ends
   */
  onDragEnd?: () => void;
  
  /**
   * Callback for when widget is moved
   */
  onDragMove?: (position: Position) => void;
  
  /**
   * Callback for when widget is resized
   */
  onResize?: (size: Size) => void;
  
  /**
   * Callback for when widget is removed
   */
  onRemove?: () => void;
}

/**
 * Widget container state
 */
interface WidgetContainerState {
  /**
   * Whether the widget is being dragged
   */
  isDragging: boolean;
  
  /**
   * Whether the widget is being resized
   */
  isResizing: boolean;
  
  /**
   * Current widget position
   */
  position: Position;
  
  /**
   * Current widget size
   */
  size: Size;
  
  /**
   * Whether the widget controls are expanded
   */
  areControlsExpanded: boolean;
}

/**
 * Widget container component
 */
export class WidgetContainer extends RaxolComponent<WidgetContainerProps, WidgetContainerState> {
  /**
   * Initial drag position
   */
  private dragStartPosition: { x: number; y: number } | null = null;
  
  /**
   * Initial widget position
   */
  private initialPosition: Position | null = null;
  
  /**
   * Initial resize dimensions
   */
  private resizeStartDimensions: { width: number; height: number } | null = null;
  
  /**
   * Initial widget size
   */
  private initialSize: Size | null = null;
  
  /**
   * Constructor
   */
  constructor(props: WidgetContainerProps) {
    super(props);
    
    // Initialize state
    this.state = {
      isDragging: false,
      isResizing: false,
      position: props.position || { x: 0, y: 0 },
      size: props.size || { width: 1, height: 1 },
      areControlsExpanded: false
    };
    
    // Bind methods
    this.handleDragStart = this.handleDragStart.bind(this);
    this.handleDragMove = this.handleDragMove.bind(this);
    this.handleDragEnd = this.handleDragEnd.bind(this);
    this.handleResizeStart = this.handleResizeStart.bind(this);
    this.handleResizeMove = this.handleResizeMove.bind(this);
    this.handleResizeEnd = this.handleResizeEnd.bind(this);
    this.handleRemove = this.handleRemove.bind(this);
    this.toggleControls = this.toggleControls.bind(this);
  }
  
  /**
   * Handle drag start
   */
  private handleDragStart(event: any): void {
    if (!this.props.isDraggable || !this.props.isEditable) {
      return;
    }
    
    // Store initial positions
    this.dragStartPosition = { x: event.clientX, y: event.clientY };
    this.initialPosition = { ...this.state.position };
    
    // Update state
    this.setState({ isDragging: true });
    
    // Notify parent
    if (this.props.onDragStart) {
      this.props.onDragStart();
    }
    
    // Add document-level event listeners
    document.addEventListener('mousemove', this.handleDragMove);
    document.addEventListener('mouseup', this.handleDragEnd);
  }
  
  /**
   * Handle drag move
   */
  private handleDragMove(event: MouseEvent): void {
    if (!this.state.isDragging || !this.dragStartPosition || !this.initialPosition) {
      return;
    }
    
    // Calculate delta movement
    const deltaX = event.clientX - this.dragStartPosition.x;
    const deltaY = event.clientY - this.dragStartPosition.y;
    
    // Convert pixel delta to grid units (this is a simplified calculation)
    // In a real implementation, this would account for grid cell size
    const gridDeltaX = Math.round(deltaX / 100);
    const gridDeltaY = Math.round(deltaY / 100);
    
    // Calculate new position
    const newPosition: Position = {
      x: this.initialPosition.x + gridDeltaX,
      y: this.initialPosition.y + gridDeltaY
    };
    
    // Apply constraints (example: prevent negative positions)
    newPosition.x = Math.max(0, newPosition.x);
    newPosition.y = Math.max(0, newPosition.y);
    
    // Update state
    this.setState({ position: newPosition });
    
    // Notify parent
    if (this.props.onDragMove) {
      this.props.onDragMove(newPosition);
    }
  }
  
  /**
   * Handle drag end
   */
  private handleDragEnd(): void {
    if (!this.state.isDragging) {
      return;
    }
    
    // Clean up
    this.dragStartPosition = null;
    this.initialPosition = null;
    
    // Update state
    this.setState({ isDragging: false });
    
    // Notify parent
    if (this.props.onDragEnd) {
      this.props.onDragEnd();
    }
    
    // Remove document-level event listeners
    document.removeEventListener('mousemove', this.handleDragMove);
    document.removeEventListener('mouseup', this.handleDragEnd);
  }
  
  /**
   * Handle resize start
   */
  private handleResizeStart(event: any): void {
    if (!this.props.isResizable || !this.props.isEditable) {
      return;
    }
    
    // Prevent event bubbling to avoid triggering drag start
    event.stopPropagation();
    
    // Store initial dimensions
    this.resizeStartDimensions = { width: event.clientX, height: event.clientY };
    this.initialSize = { ...this.state.size };
    
    // Update state
    this.setState({ isResizing: true });
    
    // Add document-level event listeners
    document.addEventListener('mousemove', this.handleResizeMove);
    document.addEventListener('mouseup', this.handleResizeEnd);
  }
  
  /**
   * Handle resize move
   */
  private handleResizeMove(event: MouseEvent): void {
    if (!this.state.isResizing || !this.resizeStartDimensions || !this.initialSize) {
      return;
    }
    
    // Calculate delta
    const deltaWidth = event.clientX - this.resizeStartDimensions.width;
    const deltaHeight = event.clientY - this.resizeStartDimensions.height;
    
    // Convert pixel delta to grid units (simplified)
    const gridDeltaWidth = Math.round(deltaWidth / 100);
    const gridDeltaHeight = Math.round(deltaHeight / 100);
    
    // Calculate new size
    const newSize: Size = {
      width: this.initialSize.width + gridDeltaWidth,
      height: this.initialSize.height + gridDeltaHeight
    };
    
    // Apply min/max constraints
    if (this.props.minSize) {
      newSize.width = Math.max(this.props.minSize.width, newSize.width);
      newSize.height = Math.max(this.props.minSize.height, newSize.height);
    }
    
    if (this.props.maxSize) {
      newSize.width = Math.min(this.props.maxSize.width, newSize.width);
      newSize.height = Math.min(this.props.maxSize.height, newSize.height);
    }
    
    // Ensure minimum reasonable size
    newSize.width = Math.max(1, newSize.width);
    newSize.height = Math.max(1, newSize.height);
    
    // Update state
    this.setState({ size: newSize });
    
    // Notify parent
    if (this.props.onResize) {
      this.props.onResize(newSize);
    }
  }
  
  /**
   * Handle resize end
   */
  private handleResizeEnd(): void {
    if (!this.state.isResizing) {
      return;
    }
    
    // Clean up
    this.resizeStartDimensions = null;
    this.initialSize = null;
    
    // Update state
    this.setState({ isResizing: false });
    
    // Remove document-level event listeners
    document.removeEventListener('mousemove', this.handleResizeMove);
    document.removeEventListener('mouseup', this.handleResizeEnd);
  }
  
  /**
   * Handle widget removal
   */
  private handleRemove(): void {
    if (this.props.onRemove) {
      this.props.onRemove();
    }
  }
  
  /**
   * Toggle controls expansion
   */
  private toggleControls(): void {
    this.setState({ areControlsExpanded: !this.state.areControlsExpanded });
  }
  
  /**
   * Render the widget container
   */
  render() {
    const { title, content, additionalControls, isEditable, backgroundColor, border } = this.props;
    const { isDragging, isResizing, areControlsExpanded } = this.state;
    
    // Build widget header
    const widgetHeader = View.box({
      border: 'none',
      children: [
        // Widget title
        View.text(title),
        
        // Widget controls
        View.box({
          border: 'none',
          children: [
            // Toggle controls button
            View.button({
              label: areControlsExpanded ? '▲' : '▼',
              onClick: this.toggleControls
            }),
            
            // Additional controls (only shown when expanded)
            ...(areControlsExpanded ? this.renderAdditionalControls(additionalControls) : [])
          ]
        })
      ]
    });
    
    // Build widget content
    const widgetContent = View.box({
      border: 'none',
      children: [content]
    });
    
    // Build resize handle (only shown in edit mode)
    const resizeHandle = isEditable && this.props.isResizable ? View.box({
      border: 'none',
      classes: ['resize-handle', isResizing ? 'resizing' : ''],
      onMouseDown: this.handleResizeStart
    }) : null;
    
    // Combine all elements
    return View.box({
      border: border || 'single',
      backgroundColor: backgroundColor,
      classes: [
        'widget-container',
        isDragging ? 'dragging' : '',
        isResizing ? 'resizing' : '',
        isEditable ? 'editable' : ''
      ],
      onMouseDown: isEditable ? this.handleDragStart : undefined,
      children: [
        widgetHeader,
        widgetContent,
        resizeHandle
      ]
    });
  }
  
  /**
   * Render additional widget controls
   */
  private renderAdditionalControls(controls?: Control[]) {
    const defaultControls = [];
    
    // Add remove button if in edit mode
    if (this.props.isEditable) {
      defaultControls.push(
        View.button({
          label: '✕',
          onClick: this.handleRemove
        })
      );
    }
    
    // Add custom additional controls
    const customControls = controls?.map(control => {
      if (control.type === 'button') {
        return View.button({
          label: control.label || '',
          onClick: control.onClick
        });
      } else if (control.type === 'custom' && control.component) {
        return control.component;
      }
      
      // Default fallback for unsupported control types
      return null;
    }).filter(Boolean) || [];
    
    return [...defaultControls, ...customControls];
  }
}
