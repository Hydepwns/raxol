/**
 * TreeMap Visualization Component
 * 
 * A treemap component for displaying hierarchical data using nested rectangles.
 * Each rectangle's area represents a quantitative value.
 */

// TreeMap data types
export interface TreeMapNode {
  name: string;
  value?: number;
  children?: TreeMapNode[];
  color?: string;
  metadata?: Record<string, any>;
  parent?: TreeMapNode;
  depth?: number;
  x?: number;
  y?: number;
  width?: number;
  height?: number;
}

export interface TreeMapOptions {
  width?: number;
  height?: number;
  padding?: number;
  title?: string;
  colors?: string[];
  colorScheme?: 'category' | 'depth' | 'value';
  showLabels?: boolean;
  labelThreshold?: number;
  animation?: {
    enabled?: boolean;
    duration?: number;
    easing?: 'linear' | 'ease' | 'ease-in' | 'ease-out';
  };
  interactions?: {
    hover?: boolean;
    click?: boolean;
    zoom?: boolean;
  };
  theme?: 'light' | 'dark';
  border?: {
    width?: number;
    color?: string;
  };
}

export interface TreeMapEvents {
  onNodeClick?: (node: TreeMapNode) => void;
  onNodeHover?: (node: TreeMapNode) => void;
  onNodeLeave?: (node: TreeMapNode) => void;
}

interface LayoutRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * TreeMap component class
 */
export class TreeMap {
  private container: HTMLElement;
  private data: TreeMapNode;
  private options: TreeMapOptions;
  private events: TreeMapEvents;
  private canvas?: HTMLCanvasElement;
  private context?: CanvasRenderingContext2D;
  private layoutNodes: TreeMapNode[] = [];
  private hoveredNode?: TreeMapNode;

  constructor(
    container: HTMLElement,
    data: TreeMapNode,
    options: TreeMapOptions = {},
    events: TreeMapEvents = {}
  ) {
    this.container = container;
    this.data = data;
    this.options = this.mergeDefaultOptions(options);
    this.events = events;

    this.initialize();
  }

  private mergeDefaultOptions(options: TreeMapOptions): TreeMapOptions {
    return {
      width: 800,
      height: 600,
      padding: 2,
      title: '',
      colors: [
        '#3498db', '#e74c3c', '#2ecc71', '#f39c12', '#9b59b6', 
        '#1abc9c', '#34495e', '#e67e22', '#95a5a6', '#16a085'
      ],
      colorScheme: 'category',
      showLabels: true,
      labelThreshold: 0.05, // Show labels only if area > 5% of total
      animation: {
        enabled: true,
        duration: 1000,
        easing: 'ease-out',
        ...options.animation
      },
      interactions: {
        hover: true,
        click: true,
        zoom: false,
        ...options.interactions
      },
      theme: 'light',
      border: {
        width: 1,
        color: '#ffffff',
        ...options.border
      },
      ...options
    };
  }

  private initialize(): void {
    this.createCanvas();
    this.setupEventListeners();
    this.calculateLayout();
    this.render();
  }

  private createCanvas(): void {
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.options.width!;
    this.canvas.height = this.options.height!;
    this.canvas.style.border = '1px solid #ccc';
    
    this.context = this.canvas.getContext('2d')!;
    this.container.appendChild(this.canvas);
  }

  private setupEventListeners(): void {
    if (!this.canvas) return;

    this.canvas.addEventListener('click', this.handleClick.bind(this));
    this.canvas.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.canvas.addEventListener('mouseleave', this.handleMouseLeave.bind(this));
  }

  private handleClick(event: MouseEvent): void {
    if (!this.events.onNodeClick || !this.canvas) return;

    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    const node = this.findNodeAtPosition(x, y);
    if (node) {
      this.events.onNodeClick(node);
    }
  }

  private handleMouseMove(event: MouseEvent): void {
    if (!this.canvas) return;

    const rect = this.canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    const node = this.findNodeAtPosition(x, y);
    
    if (node !== this.hoveredNode) {
      if (this.hoveredNode && this.events.onNodeLeave) {
        this.events.onNodeLeave(this.hoveredNode);
      }
      
      this.hoveredNode = node;
      
      if (node && this.events.onNodeHover) {
        this.events.onNodeHover(node);
      }
      
      // Re-render to show hover effect
      this.render();
    }
  }

  private handleMouseLeave(): void {
    if (this.hoveredNode && this.events.onNodeLeave) {
      this.events.onNodeLeave(this.hoveredNode);
    }
    this.hoveredNode = undefined;
    this.render();
  }

  private findNodeAtPosition(x: number, y: number): TreeMapNode | undefined {
    return this.layoutNodes.find(node => 
      node.x !== undefined && node.y !== undefined &&
      node.width !== undefined && node.height !== undefined &&
      x >= node.x && x <= node.x + node.width &&
      y >= node.y && y <= node.y + node.height
    );
  }

  private calculateLayout(): void {
    this.layoutNodes = [];
    this.normalizeData(this.data);
    
    const totalArea = this.options.width! * this.options.height!;
    const rootRect: LayoutRect = {
      x: 0,
      y: 0,
      width: this.options.width!,
      height: this.options.height!
    };

    this.layoutNode(this.data, rootRect, 0);
  }

  private normalizeData(node: TreeMapNode, parent?: TreeMapNode): number {
    node.parent = parent;
    node.depth = parent ? (parent.depth || 0) + 1 : 0;

    if (node.children && node.children.length > 0) {
      // Internal node - sum children values
      node.value = node.children.reduce((sum, child) => {
        return sum + this.normalizeData(child, node);
      }, 0);
    } else {
      // Leaf node - ensure it has a value
      node.value = node.value || 1;
    }

    return node.value;
  }

  private layoutNode(node: TreeMapNode, rect: LayoutRect, depth: number): void {
    node.x = rect.x;
    node.y = rect.y;
    node.width = rect.width;
    node.height = rect.height;
    node.depth = depth;

    this.layoutNodes.push(node);

    if (!node.children || node.children.length === 0) {
      return;
    }

    // Apply padding
    const padding = this.options.padding!;
    const innerRect: LayoutRect = {
      x: rect.x + padding,
      y: rect.y + padding,
      width: rect.width - 2 * padding,
      height: rect.height - 2 * padding
    };

    // Use squarified treemap algorithm
    this.squarify(node.children, innerRect, node.value!);
  }

  private squarify(children: TreeMapNode[], rect: LayoutRect, totalValue: number): void {
    if (children.length === 0) return;

    // Sort children by value (descending)
    const sortedChildren = [...children].sort((a, b) => (b.value || 0) - (a.value || 0));
    
    this.squarifyRecursive(sortedChildren, rect, totalValue, []);
  }

  private squarifyRecursive(
    children: TreeMapNode[], 
    rect: LayoutRect, 
    totalValue: number, 
    row: TreeMapNode[]
  ): void {
    if (children.length === 0) {
      if (row.length > 0) {
        this.layoutRow(row, rect, totalValue);
      }
      return;
    }

    const child = children[0];
    const newRow = [...row, child];

    if (row.length === 0 || this.worst(row, rect) >= this.worst(newRow, rect)) {
      // Add to current row
      this.squarifyRecursive(children.slice(1), rect, totalValue, newRow);
    } else {
      // Layout current row and start new one
      this.layoutRow(row, rect, totalValue);
      
      const rowValue = row.reduce((sum, node) => sum + (node.value || 0), 0);
      const remainingRect = this.getRemainingRect(rect, rowValue, totalValue);
      const remainingValue = totalValue - rowValue;
      
      this.squarifyRecursive(children, remainingRect, remainingValue, []);
    }
  }

  private worst(row: TreeMapNode[], rect: LayoutRect): number {
    if (row.length === 0) return Infinity;

    const rowValue = row.reduce((sum, node) => sum + (node.value || 0), 0);
    const rowWidth = Math.min(rect.width, rect.height);
    const rowHeight = Math.max(rect.width, rect.height);

    const maxValue = Math.max(...row.map(node => node.value || 0));
    const minValue = Math.min(...row.map(node => node.value || 0));

    const s = rowValue;
    const w = rowWidth;

    return Math.max(
      (w * w * maxValue) / (s * s),
      (s * s) / (w * w * minValue)
    );
  }

  private layoutRow(row: TreeMapNode[], rect: LayoutRect, totalValue: number): void {
    const rowValue = row.reduce((sum, node) => sum + (node.value || 0), 0);
    const isVertical = rect.width < rect.height;
    
    if (isVertical) {
      // Layout horizontally within vertical space
      const rowHeight = (rowValue / totalValue) * rect.height;
      let x = rect.x;
      
      row.forEach(node => {
        const nodeWidth = ((node.value || 0) / rowValue) * rect.width;
        const nodeRect: LayoutRect = {
          x: x,
          y: rect.y,
          width: nodeWidth,
          height: rowHeight
        };
        
        this.layoutNode(node, nodeRect, (node.parent?.depth || 0) + 1);
        x += nodeWidth;
      });
    } else {
      // Layout vertically within horizontal space
      const rowWidth = (rowValue / totalValue) * rect.width;
      let y = rect.y;
      
      row.forEach(node => {
        const nodeHeight = ((node.value || 0) / rowValue) * rect.height;
        const nodeRect: LayoutRect = {
          x: rect.x,
          y: y,
          width: rowWidth,
          height: nodeHeight
        };
        
        this.layoutNode(node, nodeRect, (node.parent?.depth || 0) + 1);
        y += nodeHeight;
      });
    }
  }

  private getRemainingRect(rect: LayoutRect, usedValue: number, totalValue: number): LayoutRect {
    const isVertical = rect.width < rect.height;
    
    if (isVertical) {
      const usedHeight = (usedValue / totalValue) * rect.height;
      return {
        x: rect.x,
        y: rect.y + usedHeight,
        width: rect.width,
        height: rect.height - usedHeight
      };
    } else {
      const usedWidth = (usedValue / totalValue) * rect.width;
      return {
        x: rect.x + usedWidth,
        y: rect.y,
        width: rect.width - usedWidth,
        height: rect.height
      };
    }
  }

  private render(): void {
    if (!this.context) return;

    // Clear canvas
    this.context.clearRect(0, 0, this.options.width!, this.options.height!);

    // Draw background
    this.context.fillStyle = this.options.theme === 'dark' ? '#2c3e50' : '#ffffff';
    this.context.fillRect(0, 0, this.options.width!, this.options.height!);

    // Draw nodes
    this.layoutNodes.forEach((node, index) => {
      this.drawNode(node, index);
    });

    // Draw title
    if (this.options.title) {
      this.drawTitle();
    }
  }

  private drawNode(node: TreeMapNode, index: number): void {
    if (!this.context || node.x === undefined || node.y === undefined ||
        node.width === undefined || node.height === undefined) return;

    // Get node color
    const color = this.getNodeColor(node, index);
    
    // Apply hover effect
    const isHovered = node === this.hoveredNode;
    const fillColor = isHovered ? this.lightenColor(color, 0.1) : color;

    // Draw rectangle
    this.context.fillStyle = fillColor;
    this.context.fillRect(node.x, node.y, node.width, node.height);

    // Draw border
    if (this.options.border!.width! > 0) {
      this.context.strokeStyle = this.options.border!.color!;
      this.context.lineWidth = this.options.border!.width!;
      this.context.strokeRect(node.x, node.y, node.width, node.height);
    }

    // Draw label
    if (this.options.showLabels && this.shouldShowLabel(node)) {
      this.drawLabel(node);
    }
  }

  private getNodeColor(node: TreeMapNode, index: number): string {
    if (node.color) return node.color;

    const colors = this.options.colors!;
    
    switch (this.options.colorScheme) {
      case 'depth':
        return colors[(node.depth || 0) % colors.length];
      case 'value':
        const maxValue = Math.max(...this.layoutNodes.map(n => n.value || 0));
        const ratio = (node.value || 0) / maxValue;
        return this.interpolateColor('#e8f5e8', '#2ecc71', ratio);
      case 'category':
      default:
        return colors[index % colors.length];
    }
  }

  private shouldShowLabel(node: TreeMapNode): boolean {
    if (!node.width || !node.height) return false;
    
    const nodeArea = node.width * node.height;
    const totalArea = this.options.width! * this.options.height!;
    const areaRatio = nodeArea / totalArea;
    
    return areaRatio >= this.options.labelThreshold!;
  }

  private drawLabel(node: TreeMapNode): void {
    if (!this.context || !node.x || !node.y || !node.width || !node.height) return;

    const centerX = node.x + node.width / 2;
    const centerY = node.y + node.height / 2;

    this.context.fillStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#2c3e50';
    this.context.font = 'bold 12px Arial';
    this.context.textAlign = 'center';
    this.context.textBaseline = 'middle';

    // Check if text fits
    const textWidth = this.context.measureText(node.name).width;
    if (textWidth < node.width - 10) {
      this.context.fillText(node.name, centerX, centerY - 6);
      
      // Draw value if there's space
      if (node.height > 30 && node.value) {
        this.context.font = '10px Arial';
        this.context.fillText(node.value.toString(), centerX, centerY + 8);
      }
    }

    // Reset text properties
    this.context.textAlign = 'left';
    this.context.textBaseline = 'alphabetic';
  }

  private drawTitle(): void {
    if (!this.context || !this.options.title) return;

    this.context.font = 'bold 16px Arial';
    this.context.fillStyle = this.options.theme === 'dark' ? '#ecf0f1' : '#2c3e50';
    this.context.textAlign = 'center';
    this.context.fillText(this.options.title, this.options.width! / 2, 25);
    this.context.textAlign = 'left';
  }

  private lightenColor(color: string, amount: number): string {
    // Simple color lightening - in production you'd use a proper color library
    const hex = color.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);

    const newR = Math.min(255, Math.floor(r + (255 - r) * amount));
    const newG = Math.min(255, Math.floor(g + (255 - g) * amount));
    const newB = Math.min(255, Math.floor(b + (255 - b) * amount));

    return `#${newR.toString(16).padStart(2, '0')}${newG.toString(16).padStart(2, '0')}${newB.toString(16).padStart(2, '0')}`;
  }

  private interpolateColor(color1: string, color2: string, ratio: number): string {
    // Simple color interpolation
    const hex1 = color1.replace('#', '');
    const hex2 = color2.replace('#', '');
    
    const r1 = parseInt(hex1.substr(0, 2), 16);
    const g1 = parseInt(hex1.substr(2, 2), 16);
    const b1 = parseInt(hex1.substr(4, 2), 16);
    
    const r2 = parseInt(hex2.substr(0, 2), 16);
    const g2 = parseInt(hex2.substr(2, 2), 16);
    const b2 = parseInt(hex2.substr(4, 2), 16);

    const r = Math.floor(r1 + (r2 - r1) * ratio);
    const g = Math.floor(g1 + (g2 - g1) * ratio);
    const b = Math.floor(b1 + (b2 - b1) * ratio);

    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  // Public methods
  public updateData(newData: TreeMapNode): void {
    this.data = newData;
    this.calculateLayout();
    this.render();
  }

  public updateOptions(newOptions: Partial<TreeMapOptions>): void {
    this.options = { ...this.options, ...newOptions };
    this.calculateLayout();
    this.render();
  }

  public exportAsImage(format: 'png' | 'jpeg' = 'png'): string {
    if (!this.canvas) throw new Error('Canvas not initialized');
    return this.canvas.toDataURL(`image/${format}`);
  }

  public destroy(): void {
    if (this.canvas && this.canvas.parentNode) {
      this.canvas.parentNode.removeChild(this.canvas);
    }
  }
}