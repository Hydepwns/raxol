/**
 * ImageWidget.ts
 * 
 * A widget component for displaying images in the dashboard.
 * Supports various image formats, resizing, and customizable styling.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { WidgetConfig } from '../types';

/**
 * Image widget configuration
 */
export interface ImageWidgetConfig extends WidgetConfig {
  /**
   * Image source URL
   */
  src: string;
  
  /**
   * Image alt text
   */
  alt?: string;
  
  /**
   * Image fit mode
   */
  fit?: 'contain' | 'cover' | 'fill' | 'none' | 'scale-down';
  
  /**
   * Whether to show image controls
   */
  showControls?: boolean;
  
  /**
   * Whether to enable image rotation
   */
  enableRotation?: boolean;
  
  /**
   * Whether to enable image zoom
   */
  enableZoom?: boolean;
}

/**
 * Image widget state
 */
interface ImageWidgetState {
  /**
   * Current rotation angle in degrees
   */
  rotation: number;
  
  /**
   * Current zoom level
   */
  zoom: number;
  
  /**
   * Whether controls are expanded
   */
  areControlsExpanded: boolean;
}

/**
 * Image widget component
 */
export class ImageWidget extends RaxolComponent<ImageWidgetConfig, ImageWidgetState> {
  /**
   * Constructor
   */
  constructor(props: ImageWidgetConfig) {
    super(props);
    
    this.state = {
      rotation: 0,
      zoom: 1,
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
   * Rotate image
   */
  private rotateImage(direction: 'left' | 'right'): void {
    if (!this.props.enableRotation) return;
    
    const rotationStep = 90;
    const newRotation = direction === 'left' 
      ? (this.state.rotation - rotationStep) % 360
      : (this.state.rotation + rotationStep) % 360;
    
    this.setState({ rotation: newRotation });
  }
  
  /**
   * Zoom image
   */
  private zoomImage(direction: 'in' | 'out'): void {
    if (!this.props.enableZoom) return;
    
    const zoomStep = 0.25;
    const newZoom = direction === 'in'
      ? Math.min(this.state.zoom + zoomStep, 3)
      : Math.max(this.state.zoom - zoomStep, 0.5);
    
    this.setState({ zoom: newZoom });
  }
  
  /**
   * Reset image transformations
   */
  private resetImage(): void {
    this.setState({
      rotation: 0,
      zoom: 1
    });
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
          children: [
            View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Image Controls', { style: { fontWeight: 'bold' } }),
                View.box({
                  style: { cursor: 'pointer' },
                  onClick: () => this.toggleControls(),
                  children: [View.text('▼')]
                })
              ]
            }),
            this.props.enableRotation ? View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Rotation'),
                View.flex({
                  direction: 'row',
                  children: [
                    View.box({
                      style: { 
                        width: 30, 
                        height: 30, 
                        backgroundColor: '#f0f0f0',
                        borderRadius: 4,
                        cursor: 'pointer',
                        marginRight: 5,
                        display: 'flex',
                        justifyContent: 'center',
                        alignItems: 'center'
                      },
                      onClick: () => this.rotateImage('left'),
                      children: [View.text('↺')]
                    }),
                    View.box({
                      style: { 
                        width: 30, 
                        height: 30, 
                        backgroundColor: '#f0f0f0',
                        borderRadius: 4,
                        cursor: 'pointer',
                        display: 'flex',
                        justifyContent: 'center',
                        alignItems: 'center'
                      },
                      onClick: () => this.rotateImage('right'),
                      children: [View.text('↻')]
                    })
                  ]
                })
              ]
            }) : View.box({ style: { display: 'none' } }),
            this.props.enableZoom ? View.flex({
              direction: 'row',
              justify: 'space-between',
              children: [
                View.text('Zoom'),
                View.flex({
                  direction: 'row',
                  children: [
                    View.box({
                      style: { 
                        width: 30, 
                        height: 30, 
                        backgroundColor: '#f0f0f0',
                        borderRadius: 4,
                        cursor: 'pointer',
                        marginRight: 5,
                        display: 'flex',
                        justifyContent: 'center',
                        alignItems: 'center'
                      },
                      onClick: () => this.zoomImage('out'),
                      children: [View.text('-')]
                    }),
                    View.box({
                      style: { 
                        width: 30, 
                        height: 30, 
                        backgroundColor: '#f0f0f0',
                        borderRadius: 4,
                        cursor: 'pointer',
                        display: 'flex',
                        justifyContent: 'center',
                        alignItems: 'center'
                      },
                      onClick: () => this.zoomImage('in'),
                      children: [View.text('+')]
                    })
                  ]
                })
              ]
            }) : View.box({ style: { display: 'none' } }),
            View.flex({
              direction: 'row',
              justify: 'center',
              children: [
                View.box({
                  style: { 
                    padding: '5px 10px',
                    backgroundColor: '#f0f0f0',
                    borderRadius: 4,
                    cursor: 'pointer',
                    marginTop: 10
                  },
                  onClick: () => this.resetImage(),
                  children: [View.text('Reset')]
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
    const { src, alt = '', fit = 'contain' } = this.props;
    
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
                overflow: 'hidden',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                height: 'calc(100% - 40px)'
              },
              children: [
                View.box({
                  style: {
                    width: '100%',
                    height: '100%',
                    backgroundImage: `url(${src})`,
                    backgroundSize: fit,
                    backgroundPosition: 'center',
                    backgroundRepeat: 'no-repeat',
                    transform: `rotate(${this.state.rotation}deg) scale(${this.state.zoom})`,
                    transition: 'transform 0.3s ease'
                  }
                })
              ]
            }),
            this.renderControls()
          ]
        })
      ]
    });
  }
} 