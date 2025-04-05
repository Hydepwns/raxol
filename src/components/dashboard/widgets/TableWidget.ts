/**
 * TableWidget.ts
 * 
 * A widget component for displaying tabular data in the dashboard.
 * Supports sorting, filtering, and pagination.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { WidgetConfig } from '../types';

/**
 * Column configuration for table widget
 */
export interface TableColumn {
  /**
   * Column ID
   */
  id: string;
  
  /**
   * Column header
   */
  header: string;
  
  /**
   * Column width (optional)
   */
  width?: number;
  
  /**
   * Whether the column is sortable
   */
  sortable?: boolean;
  
  /**
   * Whether the column is filterable
   */
  filterable?: boolean;
  
  /**
   * Custom renderer for cell content
   */
  render?: (value: any, row: any) => any;
}

/**
 * Table widget props
 */
export interface TableWidgetProps extends WidgetConfig {
  /**
   * Table columns configuration
   */
  columns: TableColumn[];
  
  /**
   * Table data
   */
  data: any[];
  
  /**
   * Whether to show pagination
   */
  pagination?: boolean;
  
  /**
   * Number of rows per page
   */
  pageSize?: number;
  
  /**
   * Whether to show column filters
   */
  showFilters?: boolean;
  
  /**
   * Whether to show column sorting
   */
  showSorting?: boolean;
  
  /**
   * Whether to show row selection
   */
  selectable?: boolean;
  
  /**
   * Callback when a row is selected
   */
  onRowSelect?: (row: any) => void;
  
  /**
   * Callback when a column is sorted
   */
  onSort?: (columnId: string, direction: 'asc' | 'desc') => void;
  
  /**
   * Callback when a column is filtered
   */
  onFilter?: (columnId: string, value: any) => void;
}

/**
 * Table widget state
 */
interface TableWidgetState {
  /**
   * Current page number
   */
  currentPage: number;
  
  /**
   * Current sort column
   */
  sortColumn: string | null;
  
  /**
   * Current sort direction
   */
  sortDirection: 'asc' | 'desc' | null;
  
  /**
   * Current filters
   */
  filters: Record<string, any>;
  
  /**
   * Selected rows
   */
  selectedRows: string[];
}

/**
 * Table widget component
 */
export class TableWidget extends RaxolComponent<TableWidgetProps, TableWidgetState> {
  /**
   * Constructor
   */
  constructor(props: TableWidgetProps) {
    super(props);
    
    // Initialize state
    this.state = {
      currentPage: 1,
      sortColumn: null,
      sortDirection: null,
      filters: {},
      selectedRows: []
    };
    
    // Bind methods
    this.handlePageChange = this.handlePageChange.bind(this);
    this.handleSort = this.handleSort.bind(this);
    this.handleFilter = this.handleFilter.bind(this);
    this.handleRowSelect = this.handleRowSelect.bind(this);
  }
  
  /**
   * Handle page change
   */
  private handlePageChange(page: number): void {
    this.setState({ currentPage: page });
  }
  
  /**
   * Handle column sort
   */
  private handleSort(columnId: string): void {
    const { sortColumn, sortDirection } = this.state;
    
    // Determine new sort direction
    let newDirection: 'asc' | 'desc' = 'asc';
    
    if (sortColumn === columnId) {
      if (sortDirection === 'asc') {
        newDirection = 'desc';
      } else if (sortDirection === 'desc') {
        // Reset sorting
        this.setState({ sortColumn: null, sortDirection: null });
        
        // Notify parent
        if (this.props.onSort) {
          this.props.onSort(columnId, 'asc');
        }
        
        return;
      }
    }
    
    // Update state
    this.setState({
      sortColumn: columnId,
      sortDirection: newDirection
    });
    
    // Notify parent
    if (this.props.onSort) {
      this.props.onSort(columnId, newDirection);
    }
  }
  
  /**
   * Handle column filter
   */
  private handleFilter(columnId: string, value: any): void {
    const { filters } = this.state;
    
    // Update filters
    const newFilters = { ...filters };
    
    if (value === null || value === '') {
      delete newFilters[columnId];
    } else {
      newFilters[columnId] = value;
    }
    
    // Update state
    this.setState({
      filters: newFilters,
      currentPage: 1 // Reset to first page when filtering
    });
    
    // Notify parent
    if (this.props.onFilter) {
      this.props.onFilter(columnId, value);
    }
  }
  
  /**
   * Handle row selection
   */
  private handleRowSelect(rowId: string): void {
    const { selectedRows } = this.state;
    
    // Toggle selection
    const newSelectedRows = selectedRows.includes(rowId)
      ? selectedRows.filter(id => id !== rowId)
      : [...selectedRows, rowId];
    
    // Update state
    this.setState({ selectedRows: newSelectedRows });
    
    // Notify parent
    if (this.props.onRowSelect) {
      const selectedRow = this.props.data.find(row => row.id === rowId);
      if (selectedRow) {
        this.props.onRowSelect(selectedRow);
      }
    }
  }
  
  /**
   * Get filtered and sorted data
   */
  private getProcessedData(): any[] {
    const { data } = this.props;
    const { sortColumn, sortDirection, filters } = this.state;
    
    // Apply filters
    let filteredData = [...data];
    
    Object.entries(filters).forEach(([columnId, value]) => {
      filteredData = filteredData.filter(row => {
        const cellValue = row[columnId];
        
        if (typeof value === 'string') {
          return String(cellValue).toLowerCase().includes(String(value).toLowerCase());
        }
        
        return cellValue === value;
      });
    });
    
    // Apply sorting
    if (sortColumn && sortDirection) {
      filteredData.sort((a, b) => {
        const aValue = a[sortColumn];
        const bValue = b[sortColumn];
        
        if (aValue === bValue) return 0;
        
        const comparison = aValue < bValue ? -1 : 1;
        return sortDirection === 'asc' ? comparison : -comparison;
      });
    }
    
    return filteredData;
  }
  
  /**
   * Get paginated data
   */
  private getPaginatedData(): any[] {
    const { pageSize = 10 } = this.props;
    const { currentPage } = this.state;
    
    const processedData = this.getProcessedData();
    const startIndex = (currentPage - 1) * pageSize;
    const endIndex = startIndex + pageSize;
    
    return processedData.slice(startIndex, endIndex);
  }
  
  /**
   * Get total number of pages
   */
  private getTotalPages(): number {
    const { pageSize = 10 } = this.props;
    const processedData = this.getProcessedData();
    
    return Math.ceil(processedData.length / pageSize);
  }
  
  /**
   * Render the table widget
   */
  render() {
    const { columns, title, pagination = true, showFilters = true, showSorting = true, selectable = false } = this.props;
    const { currentPage, sortColumn, sortDirection, selectedRows } = this.state;
    
    const paginatedData = this.getPaginatedData();
    const totalPages = this.getTotalPages();
    
    return (
      <div className="table-widget">
        <div className="table-widget-header">
          <h3>{title}</h3>
        </div>
        
        <div className="table-widget-content">
          <table className="table-widget-table">
            <thead>
              <tr>
                {selectable && (
                  <th className="table-widget-checkbox">
                    <input
                      type="checkbox"
                      checked={selectedRows.length === paginatedData.length}
                      onChange={() => {
                        if (selectedRows.length === paginatedData.length) {
                          this.setState({ selectedRows: [] });
                        } else {
                          this.setState({
                            selectedRows: paginatedData.map(row => row.id)
                          });
                        }
                      }}
                    />
                  </th>
                )}
                
                {columns.map(column => (
                  <th
                    key={column.id}
                    className={`table-widget-column ${column.sortable ? 'sortable' : ''}`}
                    style={{ width: column.width ? `${column.width}px` : 'auto' }}
                    onClick={() => column.sortable && this.handleSort(column.id)}
                  >
                    <div className="table-widget-column-header">
                      {column.header}
                      
                      {showSorting && column.sortable && sortColumn === column.id && (
                        <span className="table-widget-sort-indicator">
                          {sortDirection === 'asc' ? '↑' : '↓'}
                        </span>
                      )}
                    </div>
                    
                    {showFilters && column.filterable && (
                      <div className="table-widget-filter">
                        <input
                          type="text"
                          placeholder={`Filter ${column.header}`}
                          onChange={(e) => this.handleFilter(column.id, e.target.value)}
                        />
                      </div>
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            
            <tbody>
              {paginatedData.map((row, rowIndex) => (
                <tr
                  key={row.id || rowIndex}
                  className={selectedRows.includes(row.id) ? 'selected' : ''}
                  onClick={() => selectable && this.handleRowSelect(row.id)}
                >
                  {selectable && (
                    <td className="table-widget-checkbox">
                      <input
                        type="checkbox"
                        checked={selectedRows.includes(row.id)}
                        onChange={() => this.handleRowSelect(row.id)}
                        onClick={(e) => e.stopPropagation()}
                      />
                    </td>
                  )}
                  
                  {columns.map(column => (
                    <td key={column.id}>
                      {column.render
                        ? column.render(row[column.id], row)
                        : row[column.id]}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        {pagination && totalPages > 1 && (
          <div className="table-widget-pagination">
            <button
              disabled={currentPage === 1}
              onClick={() => this.handlePageChange(currentPage - 1)}
            >
              Previous
            </button>
            
            <span>
              Page {currentPage} of {totalPages}
            </span>
            
            <button
              disabled={currentPage === totalPages}
              onClick={() => this.handlePageChange(currentPage + 1)}
            >
              Next
            </button>
          </div>
        )}
      </div>
    );
  }
} 