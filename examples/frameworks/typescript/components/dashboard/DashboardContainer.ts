/**
 * Dashboard Container Component
 * 
 * Main container for managing dashboard layout, widgets, and interactions.
 */

import { WidgetConfig, LayoutConfig, DashboardConfig, DashboardEvents, GridSystem, DragState, DropZone, DashboardTheme, lightTheme, darkTheme } from './types';

export class DashboardContainer {
  private container: HTMLElement;
  private config: DashboardConfig;
  private events: DashboardEvents;
  private theme: DashboardTheme;
  private grid: GridSystem;
  private dragState: DragState;
  private widgets: Map<string, HTMLElement> = new Map();
  private observers: ResizeObserver[] = [];

  constructor(
    container: HTMLElement,
    config: DashboardConfig,
    events: DashboardEvents = {},
    theme?: DashboardTheme
  ) {
    this.container = container;
    this.config = config;
    this.events = events;
    this.theme = theme || (config.theme === 'dark' ? darkTheme : lightTheme);
    this.dragState = { isDragging: false };

    this.initialize();
  }

  private initialize(): void {
    this.setupContainer();
    this.calculateGrid();
    this.createWidgets();
    this.setupAutoRefresh();
    this.setupEventListeners();
  }

  private setupContainer(): void {
    this.container.className = 'raxol-dashboard-container';
    this.container.style.cssText = `
      position: relative;
      width: 100%;
      height: 100%;
      background-color: ${this.theme.colors.background};
      color: ${this.theme.colors.text};
      font-family: ${this.theme.fonts.primary};
      padding: ${this.theme.spacing.md}px;
      box-sizing: border-box;
      overflow: hidden;
    `;

    // Add title if provided
    if (this.config.title) {
      const titleElement = document.createElement('h2');
      titleElement.textContent = this.config.title;
      titleElement.style.cssText = `
        margin: 0 0 ${this.theme.spacing.lg}px 0;
        font-size: 24px;
        font-weight: 600;
        color: ${this.theme.colors.text};
      `;
      this.container.appendChild(titleElement);
    }

    // Create grid container
    const gridContainer = document.createElement('div');
    gridContainer.className = 'raxol-dashboard-grid';
    gridContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: calc(100% - ${this.config.title ? 60 : 0}px);
      display: grid;
      grid-template-columns: repeat(${this.config.layout.columns}, 1fr);
      grid-template-rows: repeat(${this.config.layout.rows}, 1fr);
      gap: ${this.config.layout.gap || this.theme.spacing.md}px;
    `;
    this.container.appendChild(gridContainer);
  }

  private calculateGrid(): void {
    const gap = this.config.layout.gap || this.theme.spacing.md;
    const containerRect = this.container.getBoundingClientRect();
    const gridContainer = this.container.querySelector('.raxol-dashboard-grid') as HTMLElement;
    
    if (gridContainer) {
      const gridRect = gridContainer.getBoundingClientRect();
      
      this.grid = {
        columns: this.config.layout.columns,
        rows: this.config.layout.rows,
        gap,
        cellWidth: (gridRect.width - gap * (this.config.layout.columns - 1)) / this.config.layout.columns,
        cellHeight: (gridRect.height - gap * (this.config.layout.rows - 1)) / this.config.layout.rows,
        cells: Array(this.config.layout.rows).fill(null).map(() => 
          Array(this.config.layout.columns).fill(null).map(() => ({ occupied: false }))
        )
      };
    }
  }

  private createWidgets(): void {
    const gridContainer = this.container.querySelector('.raxol-dashboard-grid') as HTMLElement;
    if (!gridContainer) return;

    this.config.widgets.forEach(widgetConfig => {
      const widgetElement = this.createWidgetElement(widgetConfig);
      this.widgets.set(widgetConfig.id, widgetElement);
      gridContainer.appendChild(widgetElement);
      this.positionWidget(widgetElement, widgetConfig);
      this.markGridCells(widgetConfig, true);
    });
  }

  private createWidgetElement(config: WidgetConfig): HTMLElement {
    const widget = document.createElement('div');
    widget.className = 'raxol-dashboard-widget';
    widget.dataset.widgetId = config.id;
    widget.dataset.widgetType = config.type;

    // Base widget styles
    widget.style.cssText = `
      position: absolute;
      background-color: ${this.theme.colors.surface};
      border: 1px solid ${this.theme.colors.border};
      border-radius: ${this.theme.spacing.sm}px;
      box-shadow: ${this.theme.shadows.light};
      transition: box-shadow 0.2s ease;
      cursor: move;
      overflow: hidden;
      z-index: 1;
    `;

    // Apply custom styles
    if (config.style) {
      Object.assign(widget.style, config.style);
    }

    // Create widget header
    const header = document.createElement('div');
    header.className = 'widget-header';
    header.style.cssText = `
      padding: ${this.theme.spacing.sm}px ${this.theme.spacing.md}px;
      background-color: ${this.theme.colors.primary}15;
      border-bottom: 1px solid ${this.theme.colors.border};
      font-weight: 600;
      display: flex;
      justify-content: space-between;
      align-items: center;
      user-select: none;
    `;

    const title = document.createElement('span');
    title.textContent = config.title;
    title.style.color = this.theme.colors.text;
    header.appendChild(title);

    // Create widget controls
    const controls = document.createElement('div');
    controls.className = 'widget-controls';
    controls.style.cssText = `
      display: flex;
      gap: ${this.theme.spacing.xs}px;
    `;

    // Add minimize/maximize buttons
    const minimizeBtn = this.createControlButton('−');
    const maximizeBtn = this.createControlButton('□');
    const closeBtn = this.createControlButton('×');

    controls.appendChild(minimizeBtn);
    controls.appendChild(maximizeBtn);
    controls.appendChild(closeBtn);
    header.appendChild(controls);

    // Create widget content area
    const content = document.createElement('div');
    content.className = 'widget-content';
    content.style.cssText = `
      padding: ${this.theme.spacing.md}px;
      height: calc(100% - ${32 + this.theme.spacing.sm * 2}px);
      overflow: auto;
    `;

    widget.appendChild(header);
    widget.appendChild(content);

    // Setup widget interactions
    this.setupWidgetInteractions(widget, config);

    return widget;
  }

  private createControlButton(symbol: string): HTMLElement {
    const button = document.createElement('button');
    button.textContent = symbol;
    button.style.cssText = `
      width: 20px;
      height: 20px;
      border: none;
      background-color: transparent;
      color: ${this.theme.colors.text};
      cursor: pointer;
      border-radius: 2px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      line-height: 1;
    `;

    button.addEventListener('mouseenter', () => {
      button.style.backgroundColor = this.theme.colors.border;
    });

    button.addEventListener('mouseleave', () => {
      button.style.backgroundColor = 'transparent';
    });

    return button;
  }

  private setupWidgetInteractions(widget: HTMLElement, config: WidgetConfig): void {
    let isDragging = false;
    let startX = 0;
    let startY = 0;
    let startLeft = 0;
    let startTop = 0;

    const header = widget.querySelector('.widget-header') as HTMLElement;

    header.addEventListener('mousedown', (e: MouseEvent) => {
      if ((e.target as HTMLElement).tagName === 'BUTTON') return;

      isDragging = true;
      startX = e.clientX;
      startY = e.clientY;
      startLeft = widget.offsetLeft;
      startTop = widget.offsetTop;

      widget.style.zIndex = '1000';
      widget.style.boxShadow = this.theme.shadows.heavy;

      this.dragState.isDragging = true;
      this.dragState.draggedWidget = config;

      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    });

    const handleMouseMove = (e: MouseEvent) => {
      if (!isDragging) return;

      const deltaX = e.clientX - startX;
      const deltaY = e.clientY - startY;

      widget.style.left = (startLeft + deltaX) + 'px';
      widget.style.top = (startTop + deltaY) + 'px';

      // Show drop zones
      this.updateDropZones(e.clientX, e.clientY);
    };

    const handleMouseUp = (e: MouseEvent) => {
      if (!isDragging) return;

      isDragging = false;
      widget.style.zIndex = '1';
      widget.style.boxShadow = this.theme.shadows.light;

      // Snap to grid
      const dropZone = this.findValidDropZone(e.clientX, e.clientY, config);
      if (dropZone) {
        this.moveWidget(config, dropZone);
      } else {
        // Snap back to original position
        this.positionWidget(widget, config);
      }

      this.dragState.isDragging = false;
      this.dragState.draggedWidget = undefined;

      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };

    // Setup control button handlers
    const controls = widget.querySelectorAll('.widget-controls button');
    const [minimizeBtn, maximizeBtn, closeBtn] = Array.from(controls);

    minimizeBtn.addEventListener('click', () => this.minimizeWidget(config.id));
    maximizeBtn.addEventListener('click', () => this.maximizeWidget(config.id));
    closeBtn.addEventListener('click', () => this.removeWidget(config.id));

    // Widget click handler
    widget.addEventListener('click', (e: MouseEvent) => {
      if (this.events.onWidgetClick && !isDragging) {
        this.events.onWidgetClick(config.id, config);
      }
    });
  }

  private positionWidget(widget: HTMLElement, config: WidgetConfig): void {
    const { x, y, width, height } = config.position;
    
    widget.style.left = (x * (this.grid.cellWidth + this.grid.gap)) + 'px';
    widget.style.top = (y * (this.grid.cellHeight + this.grid.gap)) + 'px';
    widget.style.width = (width * this.grid.cellWidth + (width - 1) * this.grid.gap) + 'px';
    widget.style.height = (height * this.grid.cellHeight + (height - 1) * this.grid.gap) + 'px';
  }

  private markGridCells(config: WidgetConfig, occupied: boolean): void {
    const { x, y, width, height } = config.position;
    
    for (let row = y; row < y + height; row++) {
      for (let col = x; col < x + width; col++) {
        if (row < this.grid.rows && col < this.grid.columns) {
          this.grid.cells[row][col].occupied = occupied;
          this.grid.cells[row][col].widgetId = occupied ? config.id : undefined;
        }
      }
    }
  }

  private updateDropZones(mouseX: number, mouseY: number): void {
    // In a full implementation, this would show visual drop zone indicators
    console.log('Updating drop zones at', mouseX, mouseY);
  }

  private findValidDropZone(mouseX: number, mouseY: number, widget: WidgetConfig): DropZone | null {
    const gridContainer = this.container.querySelector('.raxol-dashboard-grid') as HTMLElement;
    if (!gridContainer) return null;

    const rect = gridContainer.getBoundingClientRect();
    const x = Math.floor((mouseX - rect.left) / (this.grid.cellWidth + this.grid.gap));
    const y = Math.floor((mouseY - rect.top) / (this.grid.cellHeight + this.grid.gap));

    // Check if the position is valid
    if (x >= 0 && y >= 0 && 
        x + widget.position.width <= this.grid.columns && 
        y + widget.position.height <= this.grid.rows) {
      
      // Check if cells are available
      let canPlace = true;
      for (let row = y; row < y + widget.position.height; row++) {
        for (let col = x; col < x + widget.position.width; col++) {
          if (this.grid.cells[row][col].occupied && 
              this.grid.cells[row][col].widgetId !== widget.id) {
            canPlace = false;
            break;
          }
        }
        if (!canPlace) break;
      }

      if (canPlace) {
        return {
          x,
          y,
          width: widget.position.width,
          height: widget.position.height,
          valid: true,
          occupied: false
        };
      }
    }

    return null;
  }

  private moveWidget(config: WidgetConfig, dropZone: DropZone): void {
    // Clear old position
    this.markGridCells(config, false);

    // Update config
    config.position.x = dropZone.x;
    config.position.y = dropZone.y;

    // Mark new position
    this.markGridCells(config, true);

    // Update visual position
    const widget = this.widgets.get(config.id);
    if (widget) {
      this.positionWidget(widget, config);
    }

    // Trigger event
    if (this.events.onWidgetMove) {
      this.events.onWidgetMove(config.id, config.position);
    }
  }

  private minimizeWidget(widgetId: string): void {
    const widget = this.widgets.get(widgetId);
    if (!widget) return;

    const content = widget.querySelector('.widget-content') as HTMLElement;
    const isMinimized = content.style.display === 'none';

    content.style.display = isMinimized ? 'block' : 'none';
    widget.style.height = isMinimized ? 'auto' : '32px';
  }

  private maximizeWidget(widgetId: string): void {
    const widget = this.widgets.get(widgetId);
    if (!widget) return;

    const isMaximized = widget.style.position === 'fixed';

    if (isMaximized) {
      // Restore to grid position
      widget.style.position = 'absolute';
      widget.style.zIndex = '1';
      const config = this.config.widgets.find(w => w.id === widgetId);
      if (config) {
        this.positionWidget(widget, config);
      }
    } else {
      // Maximize to full screen
      widget.style.position = 'fixed';
      widget.style.top = '0';
      widget.style.left = '0';
      widget.style.width = '100vw';
      widget.style.height = '100vh';
      widget.style.zIndex = '2000';
    }
  }

  private removeWidget(widgetId: string): void {
    const widget = this.widgets.get(widgetId);
    if (!widget) return;

    // Clear grid cells
    const config = this.config.widgets.find(w => w.id === widgetId);
    if (config) {
      this.markGridCells(config, false);
    }

    // Remove from DOM
    widget.remove();
    this.widgets.delete(widgetId);

    // Update config
    this.config.widgets = this.config.widgets.filter(w => w.id !== widgetId);

    // Trigger event
    if (this.events.onWidgetRemove) {
      this.events.onWidgetRemove(widgetId);
    }
  }

  private setupAutoRefresh(): void {
    if (!this.config.autoRefresh?.enabled) return;

    setInterval(() => {
      this.config.widgets.forEach(widget => {
        if (this.events.onWidgetDataUpdate) {
          // In a real implementation, this would fetch fresh data
          this.events.onWidgetDataUpdate(widget.id, { refreshed: true });
        }
      });
    }, this.config.autoRefresh.interval);
  }

  private setupEventListeners(): void {
    // Window resize handler
    const resizeHandler = () => {
      this.calculateGrid();
      this.config.widgets.forEach(config => {
        const widget = this.widgets.get(config.id);
        if (widget) {
          this.positionWidget(widget, config);
        }
      });
    };

    window.addEventListener('resize', resizeHandler);
    this.observers.push({
      disconnect: () => window.removeEventListener('resize', resizeHandler)
    } as any);
  }

  // Public methods
  public addWidget(config: WidgetConfig): void {
    // Find available space
    const position = this.findAvailableSpace(config.position.width, config.position.height);
    if (!position) {
      console.warn('No available space for widget');
      return;
    }

    config.position = position;
    this.config.widgets.push(config);

    const widget = this.createWidgetElement(config);
    this.widgets.set(config.id, widget);

    const gridContainer = this.container.querySelector('.raxol-dashboard-grid') as HTMLElement;
    if (gridContainer) {
      gridContainer.appendChild(widget);
      this.positionWidget(widget, config);
      this.markGridCells(config, true);
    }

    if (this.events.onWidgetAdd) {
      this.events.onWidgetAdd(config);
    }
  }

  private findAvailableSpace(width: number, height: number): { x: number; y: number; width: number; height: number } | null {
    for (let y = 0; y <= this.grid.rows - height; y++) {
      for (let x = 0; x <= this.grid.columns - width; x++) {
        let canPlace = true;
        
        for (let row = y; row < y + height; row++) {
          for (let col = x; col < x + width; col++) {
            if (this.grid.cells[row][col].occupied) {
              canPlace = false;
              break;
            }
          }
          if (!canPlace) break;
        }

        if (canPlace) {
          return { x, y, width, height };
        }
      }
    }

    return null;
  }

  public updateWidget(widgetId: string, updates: Partial<WidgetConfig>): void {
    const config = this.config.widgets.find(w => w.id === widgetId);
    if (!config) return;

    Object.assign(config, updates);

    const widget = this.widgets.get(widgetId);
    if (widget) {
      // Update title if changed
      if (updates.title) {
        const titleElement = widget.querySelector('.widget-header span');
        if (titleElement) {
          titleElement.textContent = updates.title;
        }
      }

      // Update position if changed
      if (updates.position) {
        this.markGridCells(config, false);
        this.positionWidget(widget, config);
        this.markGridCells(config, true);
      }

      // Update styles if changed
      if (updates.style) {
        Object.assign(widget.style, updates.style);
      }
    }
  }

  public getWidget(widgetId: string): WidgetConfig | undefined {
    return this.config.widgets.find(w => w.id === widgetId);
  }

  public getAllWidgets(): WidgetConfig[] {
    return [...this.config.widgets];
  }

  public updateTheme(newTheme: DashboardTheme): void {
    this.theme = newTheme;
    this.setupContainer(); // Reapply styles
    
    // Update all widgets
    this.widgets.forEach((widget, widgetId) => {
      const config = this.getWidget(widgetId);
      if (config) {
        const newWidget = this.createWidgetElement(config);
        widget.replaceWith(newWidget);
        this.widgets.set(widgetId, newWidget);
        this.positionWidget(newWidget, config);
      }
    });
  }

  public exportConfig(): DashboardConfig {
    return { ...this.config };
  }

  public destroy(): void {
    this.observers.forEach(observer => observer.disconnect());
    this.widgets.clear();
    this.container.innerHTML = '';
  }
}