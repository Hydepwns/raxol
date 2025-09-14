/**
 * TreeMap Widget Component
 * 
 * A dashboard widget that displays hierarchical data using the TreeMap visualization component.
 */

import { TreeMap, TreeMapNode, TreeMapOptions } from '../../visualization/TreeMap';
import { WidgetConfig } from '../types';

export interface TreeMapWidgetConfig extends WidgetConfig {
  type: 'treemap';
  data: {
    root: TreeMapNode;
    options?: TreeMapOptions;
  };
  options?: {
    showToolbar?: boolean;
    allowExport?: boolean;
    autoRefresh?: boolean;
    refreshInterval?: number;
    showBreadcrumbs?: boolean;
    allowDrilldown?: boolean;
  };
}

export interface TreeMapWidgetEvents {
  onDataUpdate?: (widgetId: string, data: TreeMapNode) => void;
  onExport?: (widgetId: string, format: 'png' | 'jpeg' | 'json') => void;
  onRefresh?: (widgetId: string) => void;
  onNodeClick?: (widgetId: string, node: TreeMapNode) => void;
  onNodeHover?: (widgetId: string, node: TreeMapNode) => void;
  onBreadcrumbClick?: (widgetId: string, node: TreeMapNode) => void;
}

export class TreeMapWidget {
  private container: HTMLElement;
  private config: TreeMapWidgetConfig;
  private events: TreeMapWidgetEvents;
  private treeMap?: TreeMap;
  private toolbar?: HTMLElement;
  private breadcrumbs?: HTMLElement;
  private refreshInterval?: number;
  private currentRoot: TreeMapNode;
  private navigationStack: TreeMapNode[] = [];

  constructor(
    container: HTMLElement,
    config: TreeMapWidgetConfig,
    events: TreeMapWidgetEvents = {}
  ) {
    this.container = container;
    this.config = config;
    this.events = events;
    this.currentRoot = config.data.root;

    this.initialize();
  }

  private initialize(): void {
    this.createToolbar();
    this.createBreadcrumbs();
    this.createTreeMap();
    this.setupAutoRefresh();
  }

  private createToolbar(): void {
    if (!this.config.options?.showToolbar) return;

    this.toolbar = document.createElement('div');
    this.toolbar.className = 'treemap-widget-toolbar';
    this.toolbar.style.cssText = `
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 8px;
      padding: 8px;
      border-bottom: 1px solid #e0e0e0;
      background-color: #f8f9fa;
    `;

    // Left side - navigation
    const navControls = document.createElement('div');
    navControls.style.cssText = `
      display: flex;
      gap: 4px;
    `;

    // Back button
    const backBtn = this.createToolbarButton('←', 'Go back');
    backBtn.addEventListener('click', () => this.navigateBack());
    navControls.appendChild(backBtn);

    // Home button
    const homeBtn = this.createToolbarButton('🏠', 'Go to root');
    homeBtn.addEventListener('click', () => this.navigateToRoot());
    navControls.appendChild(homeBtn);

    this.toolbar.appendChild(navControls);

    // Right side - controls
    const controls = document.createElement('div');
    controls.style.cssText = `
      display: flex;
      gap: 4px;
    `;

    // Refresh button
    const refreshBtn = this.createToolbarButton('🔄', 'Refresh data');
    refreshBtn.addEventListener('click', () => this.refresh());
    controls.appendChild(refreshBtn);

    // Export buttons
    if (this.config.options?.allowExport) {
      const exportPngBtn = this.createToolbarButton('📊', 'Export as PNG');
      exportPngBtn.addEventListener('click', () => this.exportTreeMap('png'));
      controls.appendChild(exportPngBtn);

      const exportJsonBtn = this.createToolbarButton('📄', 'Export as JSON');
      exportJsonBtn.addEventListener('click', () => this.exportTreeMap('json'));
      controls.appendChild(exportJsonBtn);
    }

    // Color scheme selector
    const colorSelector = document.createElement('select');
    colorSelector.style.cssText = `
      padding: 4px 8px;
      border: 1px solid #ccc;
      border-radius: 4px;
      background-color: white;
      font-size: 12px;
    `;

    const colorSchemes = [
      { value: 'category', label: 'By Category' },
      { value: 'depth', label: 'By Depth' },
      { value: 'value', label: 'By Value' }
    ];

    colorSchemes.forEach(scheme => {
      const option = document.createElement('option');
      option.value = scheme.value;
      option.textContent = scheme.label;
      colorSelector.appendChild(option);
    });

    colorSelector.addEventListener('change', (e) => {
      const newScheme = (e.target as HTMLSelectElement).value as any;
      this.updateColorScheme(newScheme);
    });

    controls.appendChild(colorSelector);
    this.toolbar.appendChild(controls);
    this.container.appendChild(this.toolbar);
  }

  private createBreadcrumbs(): void {
    if (!this.config.options?.showBreadcrumbs) return;

    this.breadcrumbs = document.createElement('div');
    this.breadcrumbs.className = 'treemap-widget-breadcrumbs';
    this.breadcrumbs.style.cssText = `
      padding: 8px;
      background-color: #ffffff;
      border-bottom: 1px solid #e0e0e0;
      font-size: 12px;
      overflow-x: auto;
      white-space: nowrap;
    `;

    this.container.appendChild(this.breadcrumbs);
    this.updateBreadcrumbs();
  }

  private updateBreadcrumbs(): void {
    if (!this.breadcrumbs) return;

    this.breadcrumbs.innerHTML = '';

    // Add root
    const rootCrumb = this.createBreadcrumb(this.config.data.root, true);
    this.breadcrumbs.appendChild(rootCrumb);

    // Add navigation path
    this.navigationStack.forEach((node, index) => {
      // Add separator
      const separator = document.createElement('span');
      separator.textContent = ' / ';
      separator.style.color = '#6c757d';
      this.breadcrumbs!.appendChild(separator);

      // Add breadcrumb
      const isLast = index === this.navigationStack.length - 1;
      const crumb = this.createBreadcrumb(node, isLast);
      this.breadcrumbs!.appendChild(crumb);
    });
  }

  private createBreadcrumb(node: TreeMapNode, isCurrent: boolean): HTMLElement {
    const crumb = document.createElement('span');
    crumb.textContent = node.name;
    crumb.style.cssText = `
      cursor: ${isCurrent ? 'default' : 'pointer'};
      color: ${isCurrent ? '#495057' : '#007bff'};
      font-weight: ${isCurrent ? 'bold' : 'normal'};
    `;

    if (!isCurrent) {
      crumb.addEventListener('click', () => {
        this.navigateToNode(node);
        if (this.events.onBreadcrumbClick) {
          this.events.onBreadcrumbClick(this.config.id, node);
        }
      });

      crumb.addEventListener('mouseenter', () => {
        crumb.style.textDecoration = 'underline';
      });

      crumb.addEventListener('mouseleave', () => {
        crumb.style.textDecoration = 'none';
      });
    }

    return crumb;
  }

  private createToolbarButton(symbol: string, title: string): HTMLButtonElement {
    const button = document.createElement('button');
    button.textContent = symbol;
    button.title = title;
    button.style.cssText = `
      padding: 4px 8px;
      border: 1px solid #ccc;
      border-radius: 4px;
      background-color: white;
      cursor: pointer;
      font-size: 12px;
      transition: background-color 0.2s;
    `;

    button.addEventListener('mouseenter', () => {
      button.style.backgroundColor = '#e9ecef';
    });

    button.addEventListener('mouseleave', () => {
      button.style.backgroundColor = 'white';
    });

    return button;
  }

  private createTreeMap(): void {
    const treeMapContainer = document.createElement('div');
    treeMapContainer.className = 'treemap-widget-content';
    
    const toolbarHeight = this.toolbar ? 48 : 0;
    const breadcrumbHeight = this.breadcrumbs ? 36 : 0;
    
    treeMapContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: calc(100% - ${toolbarHeight + breadcrumbHeight}px);
      overflow: hidden;
    `;

    this.container.appendChild(treeMapContainer);

    // Calculate TreeMap dimensions
    const containerRect = treeMapContainer.getBoundingClientRect();
    const treeMapOptions: TreeMapOptions = {
      width: containerRect.width || 400,
      height: containerRect.height || 300,
      ...this.config.data.options
    };

    // Create TreeMap with event handlers
    this.treeMap = new TreeMap(
      treeMapContainer,
      this.currentRoot,
      treeMapOptions,
      {
        onNodeClick: (node) => {
          this.handleNodeClick(node);
        },
        onNodeHover: (node) => {
          this.showTooltip(node);
          if (this.events.onNodeHover) {
            this.events.onNodeHover(this.config.id, node);
          }
        },
        onNodeLeave: () => {
          this.hideTooltip();
        }
      }
    );
  }

  private handleNodeClick(node: TreeMapNode): void {
    if (this.events.onNodeClick) {
      this.events.onNodeClick(this.config.id, node);
    }

    // Drill down if node has children and drilldown is enabled
    if (this.config.options?.allowDrilldown && node.children && node.children.length > 0) {
      this.drillDown(node);
    }
  }

  private drillDown(node: TreeMapNode): void {
    this.navigationStack.push(this.currentRoot);
    this.currentRoot = node;
    
    if (this.treeMap) {
      this.treeMap.updateData(node);
    }

    this.updateBreadcrumbs();
    this.updateNavigationButtons();
  }

  private navigateBack(): void {
    if (this.navigationStack.length === 0) return;

    this.currentRoot = this.navigationStack.pop()!;
    
    if (this.treeMap) {
      this.treeMap.updateData(this.currentRoot);
    }

    this.updateBreadcrumbs();
    this.updateNavigationButtons();
  }

  private navigateToRoot(): void {
    this.navigationStack = [];
    this.currentRoot = this.config.data.root;
    
    if (this.treeMap) {
      this.treeMap.updateData(this.currentRoot);
    }

    this.updateBreadcrumbs();
    this.updateNavigationButtons();
  }

  private navigateToNode(node: TreeMapNode): void {
    // Find the path to this node and update navigation stack
    const pathToNode = this.findPathToNode(this.config.data.root, node);
    if (pathToNode) {
      this.navigationStack = pathToNode.slice(0, -1); // Exclude the target node
      this.currentRoot = node;
      
      if (this.treeMap) {
        this.treeMap.updateData(node);
      }

      this.updateBreadcrumbs();
      this.updateNavigationButtons();
    }
  }

  private findPathToNode(root: TreeMapNode, target: TreeMapNode): TreeMapNode[] | null {
    if (root === target) {
      return [root];
    }

    if (root.children) {
      for (const child of root.children) {
        const path = this.findPathToNode(child, target);
        if (path) {
          return [root, ...path];
        }
      }
    }

    return null;
  }

  private updateNavigationButtons(): void {
    if (!this.toolbar) return;

    const backBtn = this.toolbar.querySelector('button') as HTMLButtonElement;
    if (backBtn) {
      backBtn.disabled = this.navigationStack.length === 0;
      backBtn.style.opacity = backBtn.disabled ? '0.5' : '1';
      backBtn.style.cursor = backBtn.disabled ? 'not-allowed' : 'pointer';
    }
  }

  private showTooltip(node: TreeMapNode): void {
    // Remove existing tooltip
    this.hideTooltip();

    // Create new tooltip
    const tooltip = document.createElement('div');
    tooltip.className = 'treemap-tooltip';
    tooltip.style.cssText = `
      position: absolute;
      background-color: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 8px 12px;
      border-radius: 4px;
      font-size: 12px;
      pointer-events: none;
      z-index: 1000;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      white-space: nowrap;
      max-width: 200px;
    `;

    const childrenCount = node.children ? node.children.length : 0;
    const isLeaf = childrenCount === 0;

    tooltip.innerHTML = `
      <div><strong>${node.name}</strong></div>
      <div>Value: ${node.value || 0}</div>
      ${!isLeaf ? `<div>Children: ${childrenCount}</div>` : ''}
      ${node.metadata ? `<div>${JSON.stringify(node.metadata)}</div>` : ''}
      ${!isLeaf && this.config.options?.allowDrilldown ? '<div style="font-style: italic;">Click to drill down</div>' : ''}
    `;

    this.container.appendChild(tooltip);
  }

  private hideTooltip(): void {
    const tooltip = this.container.querySelector('.treemap-tooltip');
    if (tooltip) {
      tooltip.remove();
    }
  }

  private updateColorScheme(newScheme: 'category' | 'depth' | 'value'): void {
    if (!this.treeMap) return;

    this.treeMap.updateOptions({ colorScheme: newScheme });
  }

  private refresh(): void {
    if (this.events.onRefresh) {
      this.events.onRefresh(this.config.id);
    }

    // Animate refresh button
    const refreshBtn = this.toolbar?.querySelector('button[title="Refresh data"]') as HTMLButtonElement;
    if (refreshBtn) {
      refreshBtn.style.transform = 'rotate(360deg)';
      refreshBtn.style.transition = 'transform 0.5s ease';
      
      setTimeout(() => {
        refreshBtn.style.transform = 'rotate(0deg)';
        refreshBtn.style.transition = '';
      }, 500);
    }
  }

  private exportTreeMap(format: 'png' | 'jpeg' | 'json'): void {
    if (!this.treeMap) return;

    try {
      let exportData: string;

      if (format === 'json') {
        exportData = JSON.stringify({
          config: this.config,
          currentRoot: this.currentRoot,
          navigationStack: this.navigationStack,
          timestamp: new Date().toISOString()
        }, null, 2);

        // Create and download JSON file
        const blob = new Blob([exportData], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `treemap-${this.config.id}-${Date.now()}.json`;
        link.click();
        URL.revokeObjectURL(url);
      } else {
        exportData = this.treeMap.exportAsImage(format);

        // Create and download image file
        const link = document.createElement('a');
        link.href = exportData;
        link.download = `treemap-${this.config.id}-${Date.now()}.${format}`;
        link.click();
      }

      if (this.events.onExport) {
        this.events.onExport(this.config.id, format);
      }
    } catch (error) {
      console.error('Failed to export treemap:', error);
    }
  }

  private setupAutoRefresh(): void {
    if (!this.config.options?.autoRefresh) return;

    const interval = this.config.options.refreshInterval || 30000; // Default 30 seconds

    this.refreshInterval = setInterval(() => {
      this.refresh();
    }, interval) as any;
  }

  // Public methods
  public updateData(newRoot: TreeMapNode): void {
    this.config.data.root = newRoot;
    this.currentRoot = newRoot;
    this.navigationStack = [];
    
    if (this.treeMap) {
      this.treeMap.updateData(newRoot);
    }

    this.updateBreadcrumbs();
    this.updateNavigationButtons();

    if (this.events.onDataUpdate) {
      this.events.onDataUpdate(this.config.id, newRoot);
    }
  }

  public updateOptions(newOptions: Partial<TreeMapOptions>): void {
    this.config.data.options = { ...this.config.data.options, ...newOptions };
    
    if (this.treeMap) {
      this.treeMap.updateOptions(newOptions);
    }
  }

  public resize(width: number, height: number): void {
    if (this.treeMap) {
      this.treeMap.updateOptions({ width, height });
    }
  }

  public getCurrentNode(): TreeMapNode {
    return this.currentRoot;
  }

  public getNavigationPath(): TreeMapNode[] {
    return [this.config.data.root, ...this.navigationStack, this.currentRoot];
  }

  public getConfig(): TreeMapWidgetConfig {
    return { ...this.config };
  }

  public destroy(): void {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }

    if (this.treeMap) {
      this.treeMap.destroy();
    }

    this.hideTooltip();
    this.container.innerHTML = '';
  }

  // Static factory method
  public static create(
    container: HTMLElement,
    config: Partial<TreeMapWidgetConfig>,
    events?: TreeMapWidgetEvents
  ): TreeMapWidget {
    const defaultConfig: TreeMapWidgetConfig = {
      id: `treemap-widget-${Date.now()}`,
      type: 'treemap',
      title: 'TreeMap Widget',
      position: { x: 0, y: 0, width: 3, height: 3 },
      data: {
        root: {
          name: 'Root',
          children: [
            { name: 'Child 1', value: 100 },
            { name: 'Child 2', value: 200 },
            { name: 'Child 3', value: 150 }
          ]
        },
        options: {
          width: 400,
          height: 300,
          title: 'Sample TreeMap'
        }
      },
      options: {
        showToolbar: true,
        allowExport: true,
        autoRefresh: false,
        refreshInterval: 30000,
        showBreadcrumbs: true,
        allowDrilldown: true
      }
    };

    const mergedConfig = { ...defaultConfig, ...config } as TreeMapWidgetConfig;
    return new TreeMapWidget(container, mergedConfig, events);
  }
}