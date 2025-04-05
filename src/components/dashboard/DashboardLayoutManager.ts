/**
 * DashboardLayoutManager.ts
 * 
 * Manages the grid layout system for the dashboard.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { ThemeConfig } from './ThemeManager';

/**
 * Grid cell configuration
 */
export interface GridCell {
  /**
   * Row index
   */
  row: number;
  
  /**
   * Column index
   */
  column: number;
  
  /**
   * Row span
   */
  rowSpan: number;
  
  /**
   * Column span
   */
  columnSpan: number;
}

/**
 * Layout manager configuration
 */
export interface DashboardLayoutManagerConfig {
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Grid layout configuration
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
   * Grid cells
   */
  cells: Map<string, GridCell>;
  
  /**
   * Callback for when a cell is clicked
   */
  onCellClick?: (cellId: string) => void;
  
  /**
   * Callback for when a cell is dragged
   */
  onCellDrag?: (cellId: string, position: { x: number; y: number }) => void;
  
  /**
   * Callback for when a cell is resized
   */
  onCellResize?: (cellId: string, size: { rows: number; columns: number }) => void;
}

/**
 * Layout manager state
 */
interface DashboardLayoutManagerState {
  /**
   * Currently dragged cell
   */
  draggedCell: string | null;
  
  /**
   * Currently resized cell
   */
  resizedCell: string | null;
  
  /**
   * Drag start position
   */
  dragStart: { x: number; y: number } | null;
}

/**
 * Dashboard layout manager component
 */
export class DashboardLayoutManager extends RaxolComponent<DashboardLayoutManagerConfig, DashboardLayoutManagerState> {
  /**
   * Constructor
   */
  constructor(props: DashboardLayoutManagerConfig) {
    super(props);
    
    this.state = {
      draggedCell: null,
      resizedCell: null,
      dragStart: null
    };
  }
  
  /**
   * Handle cell click
   */
  private handleCellClick(cellId: string): void {
    const { onCellClick } = this.props;
    
    if (onCellClick) {
      onCellClick(cellId);
    }
  }
  
  /**
   * Handle cell drag start
   */
  private handleCellDragStart(cellId: string, event: MouseEvent): void {
    this.setState({
      draggedCell: cellId,
      dragStart: {
        x: event.clientX,
        y: event.clientY
      }
    });
  }
  
  /**
   * Handle cell drag
   */
  private handleCellDrag(event: MouseEvent): void {
    const { draggedCell, dragStart } = this.state;
    const { onCellDrag } = this.props;
    
    if (draggedCell && dragStart && onCellDrag) {
      onCellDrag(draggedCell, {
        x: event.clientX - dragStart.x,
        y: event.clientY - dragStart.y
      });
    }
  }
  
  /**
   * Handle cell drag end
   */
  private handleCellDragEnd(): void {
    this.setState({
      draggedCell: null,
      dragStart: null
    });
  }
  
  /**
   * Handle cell resize start
   */
  private handleCellResizeStart(cellId: string): void {
    this.setState({
      resizedCell: cellId
    });
  }
  
  /**
   * Handle cell resize
   */
  private handleCellResize(event: MouseEvent): void {
    const { resizedCell } = this.state;
    const { onCellResize } = this.props;
    
    if (resizedCell && onCellResize) {
      // Calculate new size based on mouse position
      const cell = this.props.cells.get(resizedCell);
      if (cell) {
        const newRows = Math.max(1, Math.floor(event.clientY / 50));
        const newColumns = Math.max(1, Math.floor(event.clientX / 50));
        
        onCellResize(resizedCell, {
          rows: newRows,
          columns: newColumns
        });
      }
    }
  }
  
  /**
   * Handle cell resize end
   */
  private handleCellResizeEnd(): void {
    this.setState({
      resizedCell: null
    });
  }
  
  /**
   * Render a grid cell
   */
  private renderCell(cellId: string, cell: GridCell): ViewElement {
    const { theme } = this.props;
    const { draggedCell, resizedCell } = this.state;
    
    return View.box({
      style: {
        gridRow: `${cell.row} / span ${cell.rowSpan}`,
        gridColumn: `${cell.column} / span ${cell.columnSpan}`,
        padding: theme.spacing.md,
        border: 'single',
        borderRadius: theme.borders.radius.small,
        backgroundColor: theme.colors.background,
        cursor: draggedCell === cellId ? 'grabbing' : 'grab',
        position: 'relative'
      },
      onClick: () => this.handleCellClick(cellId),
      onMouseDown: (e) => this.handleCellDragStart(cellId, e),
      onMouseMove: (e) => this.handleCellDrag(e),
      onMouseUp: () => this.handleCellDragEnd(),
      onMouseLeave: () => this.handleCellDragEnd(),
      children: [
        // Resize handle
        View.box({
          style: {
            position: 'absolute',
            bottom: 0,
            right: 0,
            width: '10px',
            height: '10px',
            cursor: 'nwse-resize',
            backgroundColor: theme.colors.primary
          },
          onMouseDown: () => this.handleCellResizeStart(cellId),
          onMouseMove: (e) => this.handleCellResize(e),
          onMouseUp: () => this.handleCellResizeEnd(),
          onMouseLeave: () => this.handleCellResizeEnd()
        })
      ]
    });
  }
  
  /**
   * Render the layout
   */
  render(): ViewElement {
    const { theme, layout, cells } = this.props;
    
    return View.box({
      style: {
        display: 'grid',
        gridTemplateRows: `repeat(${layout.rows}, 1fr)`,
        gridTemplateColumns: `repeat(${layout.columns}, 1fr)`,
        gap: theme.spacing.md,
        padding: theme.spacing.md,
        height: '100%',
        backgroundColor: theme.colors.background
      },
      children: Array.from(cells.entries()).map(([cellId, cell]) =>
        this.renderCell(cellId, cell)
      )
    });
  }
} 