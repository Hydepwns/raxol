/**
 * GridSystem.ts
 * 
 * A responsive grid layout system for organizing dashboard widgets.
 * Handles widget placement, sizing, and responsive behavior.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/view';
import { LayoutConfig, Breakpoints } from './types';

/**
 * Grid system props
 */
export interface GridSystemProps {
  /**
   * Number of columns in the grid
   */
  columns: number;
  
  /**
   * Gap between grid cells
   */
  gap?: number;
  
  /**
   * Responsive breakpoints
   */
  breakpoints?: Breakpoints;
  
  /**
   * Default row height
   */
  rowHeight?: number;
  
  /**
   * Show grid lines
   */
  showGridLines?: boolean;
  
  /**
   * Grid background color
   */
  backgroundColor?: string;
  
  /**
   * Grid line color
   */
  gridLineColor?: string;
}

/**
 * Grid system state
 */
interface GridSystemState {
  /**
   * Current column count based on viewport
   */
  currentColumns: number;
  
  /**
   * Current viewport width
   */
  viewportWidth: number;
  
  /**
   * Current grid cell size
   */
  cellSize: {
    width: number;
    height: number;
  };
}

/**
 * Grid system component
 */
export class GridSystem extends RaxolComponent<GridSystemProps, GridSystemState> {
  /**
   * Default grid gap
   */
  private static DEFAULT_GAP = 10;
  
  /**
   * Default row height
   */
  private static DEFAULT_ROW_HEIGHT = 100;
  
  /**
   * Default breakpoints
   */
  private static DEFAULT_BREAKPOINTS: Breakpoints = {
    small: 480,
    medium: 768,
    large: 1200
  };
  
  /**
   * Constructor
   */
  constructor(props: GridSystemProps) {
    super(props);
    
    this.state = {
      currentColumns: props.columns,
      viewportWidth: this.getViewportWidth(),
      cellSize: this.calculateCellSize(props.columns)
    };
    
    // Bind methods
    this.handleResize = this.handleResize.bind(this);
    this.withChildren = this.withChildren.bind(this);
  }
  
  /**
   * Component did mount
   */
  componentDidMount() {
    // Add resize listener
    window.addEventListener('resize', this.handleResize);
    
    // Initial calculation
    this.updateGridLayout();
  }
  
  /**
   * Component will unmount
   */
  componentWillUnmount() {
    // Remove resize listener
    window.removeEventListener('resize', this.handleResize);
  }
  
  /**
   * Handle window resize
   */
  private handleResize() {
    this.updateGridLayout();
  }
  
  /**
   * Update grid layout based on viewport
   */
  private updateGridLayout() {
    const viewportWidth = this.getViewportWidth();
    const breakpoints = this.props.breakpoints || GridSystem.DEFAULT_BREAKPOINTS;
    
    // Determine column count based on viewport width
    let columns = this.props.columns;
    
    if (viewportWidth <= breakpoints.small) {
      columns = 1;
    } else if (viewportWidth <= breakpoints.medium) {
      columns = Math.min(2, this.props.columns);
    }
    
    this.setState({
      currentColumns: columns,
      viewportWidth,
      cellSize: this.calculateCellSize(columns)
    });
  }
  
  /**
   * Get current viewport width
   */
  private getViewportWidth(): number {
    return window.innerWidth;
  }
  
  /**
   * Calculate cell size based on column count
   */
  private calculateCellSize(columns: number): { width: number; height: number } {
    const gap = this.props.gap || GridSystem.DEFAULT_GAP;
    const viewportWidth = this.getViewportWidth();
    
    // Calculate cell width
    const totalGapWidth = gap * (columns - 1);
    const cellWidth = (viewportWidth - totalGapWidth) / columns;
    
    // Use specified or default row height
    const cellHeight = this.props.rowHeight || GridSystem.DEFAULT_ROW_HEIGHT;
    
    return {
      width: cellWidth,
      height: cellHeight
    };
  }
  
  /**
   * Get grid template
   */
  private getGridTemplate(): string {
    const columns = this.state.currentColumns;
    const gap = this.props.gap || GridSystem.DEFAULT_GAP;
    
    return `repeat(${columns}, 1fr) / ${gap}px`;
  }
  
  /**
   * Render the grid with children
   */
  withChildren(children: RaxolComponent[]) {
    this.props = {
      ...this.props,
      children
    };
    
    return this;
  }
  
  /**
   * Render the grid
   */
  render() {
    const { showGridLines, backgroundColor, gridLineColor } = this.props;
    const gap = this.props.gap || GridSystem.DEFAULT_GAP;
    
    // Create grid container
    return View.box({
      style: {
        display: 'grid',
        gridTemplateColumns: `repeat(${this.state.currentColumns}, 1fr)`,
        gap: `${gap}px`,
        backgroundColor: backgroundColor || 'transparent',
        border: showGridLines ? `1px solid ${gridLineColor || '#eee'}` : 'none'
      },
      children: this.props.children
    });
  }
} 