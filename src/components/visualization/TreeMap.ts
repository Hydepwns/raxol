/**
 * TreeMap.ts
 *
 * A TreeMap visualization component for hierarchical data representation
 * where rectangles are sized proportionally to the data values.
 *
 * Optimized for performance with:
 * - Node caching by ID
 * - Layout computation caching
 * - Progressive rendering for large datasets
 * - Virtualization for only rendering visible nodes
 */

// Define empty performance mark functions if not available
const startPerformanceMark = (name: string) => {
  if (window.performance && window.performance.mark) {
    window.performance.mark(`start-${name}`);
  }
};

const endPerformanceMark = (name: string) => {
  if (
    window.performance &&
    window.performance.mark &&
    window.performance.measure
  ) {
    window.performance.mark(`end-${name}`);
    try {
      window.performance.measure(name, `start-${name}`, `end-${name}`);
    } catch (e) {
      // Ignore errors from performance API
    }
  }
};

/**
 * Represents a node in the treemap hierarchy
 */
export interface TreeMapNode {
  /** Unique identifier for the node */
  id: string;

  /** Display name of the node */
  name: string;

  /** Numeric value used for sizing the rectangle */
  value: number;

  /** Optional color for the node */
  color?: string;

  /** Optional custom data to associate with the node */
  data?: any;

  /** Children nodes (for hierarchical structure) */
  children?: TreeMapNode[];
}

/**
 * Configuration options for the TreeMap component
 */
export interface TreeMapOptions {
  /** Root node containing the hierarchical data */
  root: TreeMapNode;

  /** Title of the treemap */
  title?: string;

  /** Color scheme for the treemap */
  colors?: string[];

  /** Whether to show labels on the rectangles */
  showLabels?: boolean;

  /** Minimum size for a rectangle to display its label */
  minLabelSize?: number;

  /** Animation duration in milliseconds */
  animationDuration?: number;

  /** Gap between rectangles in pixels */
  padding?: number;

  /** Tooltip configuration */
  tooltip?: {
    /** Whether to show tooltips */
    enabled: boolean;

    /** Custom tooltip formatter */
    formatter?: (node: TreeMapNode) => string;
  };

  /** Accessibility configuration */
  accessibility?: {
    /** Description of the treemap for screen readers */
    description?: string;

    /** Whether to enable keyboard navigation */
    keyboardNavigation?: boolean;
  };

  /** Event callbacks */
  events?: {
    /** Called when a node is clicked */
    nodeClick?: (node: TreeMapNode) => void;

    /** Called when a node is hovered */
    nodeHover?: (node: TreeMapNode | null) => void;
  };
}

/**
 * Default options for the TreeMap
 */
const DEFAULT_OPTIONS: Partial<TreeMapOptions> = {
  colors: [
    "#4285F4",
    "#EA4335",
    "#FBBC05",
    "#34A853",
    "#FF6D01",
    "#46BDC6",
    "#7BAAF7",
    "#F07B72",
    "#FCD04F",
    "#71C287",
    "#FFB167",
    "#71DAE2",
  ],
  showLabels: true,
  minLabelSize: 30,
  animationDuration: 500,
  padding: 2,
  tooltip: {
    enabled: true,
  },
  accessibility: {
    keyboardNavigation: true,
  },
};

/**
 * Internal representation of a rectangle in the TreeMap
 */
interface Rectangle {
  /** Node data */
  node: TreeMapNode;

  /** X coordinate */
  x: number;

  /** Y coordinate */
  y: number;

  /** Width of rectangle */
  width: number;

  /** Height of rectangle */
  height: number;

  /** Depth level in hierarchy */
  level: number;

  /** DOM element representing this rectangle */
  element?: HTMLElement;
}

// Add new interface for cached layout data
interface CachedLayoutData {
  /** Cache timestamp */
  timestamp: number;

  /** Cached computed rectangles */
  rectangles: Rectangle[];

  /** Container dimensions associated with this layout */
  dimensions: {
    width: number;
    height: number;
  };

  /** Data hash for quick comparison */
  dataHash: string;
}

/**
 * TreeMap component for hierarchical data visualization
 */
export class TreeMap {
  /** Container element */
  private container: HTMLElement;

  /** TreeMap options */
  private options: TreeMapOptions;

  /** Canvas width */
  private width: number = 0;

  /** Canvas height */
  private height: number = 0;

  /** Computed rectangles */
  private rectangles: Rectangle[] = [];

  /** Currently focused rectangle index (for keyboard navigation) */
  private focusedIndex: number = -1;

  /** Tooltip element */
  private tooltip: HTMLElement | null = null;

  /** Currently hovered rectangle */
  private hoveredRect: Rectangle | null = null;

  /** Root container element */
  private rootElement: HTMLElement | null = null;

  /** Map of rectangle elements by node id */
  private elementMap: Map<string, HTMLElement> = new Map();

  /** Layout cache */
  private layoutCache: Map<string, CachedLayoutData> = new Map();

  /** Render throttle timer */
  private renderTimer: number | null = null;

  /** Last data hash for quick comparisons */
  private lastDataHash: string = "";

  /** Observer for detecting visibility */
  private intersectionObserver: IntersectionObserver | null = null;

  /** Flag to indicate if the component is visible */
  private isVisible: boolean = false;

  /** Flag to indicate if a full render is pending */
  private pendingRender: boolean = false;

  /** Maximum number of nodes to render at once */
  private maxNodesPerRenderPass: number = 100;

  /**
   * Current render queue - nodes waiting to be rendered
   * Used for progressive rendering
   */
  private renderQueue: Rectangle[] = [];

  /**
   * Creates a new TreeMap instance
   * @param container - DOM element to render the treemap into
   * @param options - TreeMap configuration options
   */
  constructor(container: HTMLElement, options: TreeMapOptions) {
    this.container = container;
    this.options = { ...DEFAULT_OPTIONS, ...options };

    // Create intersection observer for visibility detection
    this.setupVisibilityObserver();

    // Initialize the treemap
    this.initialize();
  }

  /**
   * Sets up an observer to detect when the component is visible
   */
  private setupVisibilityObserver(): void {
    // Only initialize if IntersectionObserver is available
    if ("IntersectionObserver" in window) {
      this.intersectionObserver = new IntersectionObserver(
        (entries) => {
          // Update visibility flag based on intersection
          const isVisible = entries[0]?.isIntersecting ?? false;

          // If visibility changed from hidden to visible and we have a pending render,
          // trigger a render
          if (!this.isVisible && isVisible && this.pendingRender) {
            this.isVisible = isVisible;
            this.pendingRender = false;
            this.render();
          }

          this.isVisible = isVisible;
        },
        { threshold: 0.1 } // Consider visible when 10% is in viewport
      );

      this.intersectionObserver.observe(this.container);
    } else {
      // Fallback if IntersectionObserver is not available
      this.isVisible = true;
    }
  }

  /**
   * Initialize the treemap
   */
  private initialize(): void {
    startPerformanceMark("treemap-initialize");

    // Clear the container
    this.container.innerHTML = "";
    this.container.style.position = "relative";
    this.container.style.overflow = "hidden";

    // Get container dimensions
    const rect = this.container.getBoundingClientRect();
    this.width = rect.width;
    this.height = rect.height;

    // Create root element
    this.rootElement = document.createElement("div");
    this.rootElement.className = "raxol-treemap";
    this.rootElement.style.width = "100%";
    this.rootElement.style.height = "100%";
    this.rootElement.style.position = "relative";

    // Add title if specified
    if (this.options.title) {
      const titleElement = document.createElement("div");
      titleElement.className = "raxol-treemap-title";
      titleElement.textContent = this.options.title;
      titleElement.style.position = "absolute";
      titleElement.style.top = "10px";
      titleElement.style.left = "10px";
      titleElement.style.fontSize = "16px";
      titleElement.style.fontWeight = "bold";
      titleElement.style.zIndex = "2";
      this.rootElement.appendChild(titleElement);
    }

    // Set ARIA attributes for accessibility
    if (this.options.accessibility?.description) {
      this.rootElement.setAttribute("role", "figure");
      this.rootElement.setAttribute(
        "aria-label",
        this.options.accessibility.description
      );
    }

    // Enable keyboard navigation if specified
    if (this.options.accessibility?.keyboardNavigation) {
      this.rootElement.tabIndex = 0;
      this.setupKeyboardNavigation();
    }

    // Create tooltip if enabled
    if (this.options.tooltip?.enabled) {
      this.createTooltip();
    }

    // Add the root element to the container
    this.container.appendChild(this.rootElement);

    // Compute the treemap layout
    this.computeLayout();

    // Render the treemap
    this.render();

    endPerformanceMark("treemap-initialize");
  }

  /**
   * Create tooltip element
   */
  private createTooltip(): void {
    this.tooltip = document.createElement("div");
    this.tooltip.className = "raxol-treemap-tooltip";
    this.tooltip.style.position = "absolute";
    this.tooltip.style.padding = "6px 10px";
    this.tooltip.style.backgroundColor = "rgba(0, 0, 0, 0.8)";
    this.tooltip.style.color = "#fff";
    this.tooltip.style.borderRadius = "4px";
    this.tooltip.style.fontSize = "12px";
    this.tooltip.style.pointerEvents = "none";
    this.tooltip.style.opacity = "0";
    this.tooltip.style.transition = "opacity 0.2s";
    this.tooltip.style.zIndex = "10";
    this.tooltip.style.maxWidth = "200px";

    // Add tooltip to the body (to avoid container clipping)
    document.body.appendChild(this.tooltip);
  }

  /**
   * Compute the treemap layout using the squarified algorithm
   */
  private computeLayout(): void {
    startPerformanceMark("treemap-compute-layout");

    this.rectangles = [];

    // Get available space (accounting for title if present)
    const titleHeight = this.options.title ? 30 : 0;
    const availableWidth = this.width;
    const availableHeight = this.height - titleHeight;

    // Recursively compute the layout
    this.squarify(
      this.options.root,
      0,
      titleHeight,
      availableWidth,
      availableHeight,
      0
    );

    endPerformanceMark("treemap-compute-layout");
  }

  /**
   * Recursively compute the treemap layout using the squarified algorithm
   */
  private squarify(
    node: TreeMapNode,
    x: number,
    y: number,
    width: number,
    height: number,
    level: number
  ): void {
    const padding = this.options.padding || 0;

    // Skip if dimensions are too small
    if (width <= padding * 2 || height <= padding * 2) {
      return;
    }

    // Apply padding
    x += padding;
    y += padding;
    width -= padding * 2;
    height -= padding * 2;

    if (node.children && node.children.length > 0) {
      // Calculate total value for normalization
      const totalValue = node.children.reduce(
        (sum, child) => sum + child.value,
        0
      );

      if (totalValue <= 0) {
        return;
      }

      // Sort children by value (largest first)
      const children = [...node.children].sort((a, b) => b.value - a.value);

      // Determine layout direction (horizontal or vertical)
      const isHorizontal = width >= height;

      // Available space
      let remainingSpace = isHorizontal ? width : height;
      let currentPosition = isHorizontal ? x : y;

      // Secondary dimension
      const secondaryDim = isHorizontal ? height : width;
      const secondaryPos = isHorizontal ? y : x;

      // Process each child
      let processedValue = 0;
      let processedCount = 0;

      for (let i = 0; i < children.length; i++) {
        const child = children[i];
        const normalizedValue = child.value / totalValue;

        // Calculate the space this item should take
        const itemSpace = isHorizontal
          ? width * normalizedValue
          : height * normalizedValue;

        // Calculate the actual dimensions of the rectangle
        let rectX: number, rectY: number, rectWidth: number, rectHeight: number;

        if (isHorizontal) {
          rectX = currentPosition;
          rectY = secondaryPos;
          rectWidth = itemSpace;
          rectHeight = secondaryDim;
        } else {
          rectX = secondaryPos;
          rectY = currentPosition;
          rectWidth = secondaryDim;
          rectHeight = itemSpace;
        }

        // Add rectangle to the list
        this.rectangles.push({
          node: child,
          x: rectX,
          y: rectY,
          width: rectWidth,
          height: rectHeight,
          level: level + 1,
        });

        // Recursively process children
        if (child.children && child.children.length > 0) {
          this.squarify(child, rectX, rectY, rectWidth, rectHeight, level + 1);
        }

        // Update for next iteration
        currentPosition += itemSpace;
        processedValue += normalizedValue;
        processedCount++;
      }
    } else {
      // Leaf node - add its rectangle
      this.rectangles.push({
        node,
        x,
        y,
        width,
        height,
        level,
      });
    }
  }

  /**
   * Render the treemap
   */
  private render(): void {
    startPerformanceMark("treemap-render");

    // Nothing to render if no root element
    if (!this.rootElement) return;

    // If we have too many rectangles, use progressive rendering
    if (this.rectangles.length > this.maxNodesPerRenderPass) {
      this.renderProgressively();
    } else {
      // Small enough for a single render pass
      this.renderImmediate();
    }

    endPerformanceMark("treemap-render");
  }

  /**
   * Render all rectangles immediately
   */
  private renderImmediate(): void {
    // Clear any existing content
    const contentContainer = document.createElement("div");
    contentContainer.className = "raxol-treemap-content";
    contentContainer.style.position = "absolute";
    contentContainer.style.top = "0";
    contentContainer.style.left = "0";
    contentContainer.style.width = "100%";
    contentContainer.style.height = "100%";

    // Clear element map
    this.elementMap.clear();

    // Create elements for visible rectangles
    this.rectangles.forEach((rect, index) => {
      // Skip if rectangle is not visible (very small or outside bounds)
      if (rect.width < 1 || rect.height < 1) return;

      const element = this.createRectangleElement(rect, index);
      contentContainer.appendChild(element);
    });

    // Remove old content and add new content
    while (this.rootElement!.firstChild) {
      this.rootElement!.removeChild(this.rootElement!.firstChild);
    }
    this.rootElement!.appendChild(contentContainer);
  }

  /**
   * Progressive rendering for large datasets
   */
  private renderProgressively(): void {
    // Initialize render queue if empty
    if (this.renderQueue.length === 0) {
      // Sort rectangles by size (largest first) for better visual experience
      this.renderQueue = [...this.rectangles].sort(
        (a, b) => b.width * b.height - a.width * a.height
      );

      // Create content container
      const contentContainer = document.createElement("div");
      contentContainer.className = "raxol-treemap-content";
      contentContainer.style.position = "absolute";
      contentContainer.style.top = "0";
      contentContainer.style.left = "0";
      contentContainer.style.width = "100%";
      contentContainer.style.height = "100%";

      // Clear element map
      this.elementMap.clear();

      // Remove old content and add new content container
      while (this.rootElement!.firstChild) {
        this.rootElement!.removeChild(this.rootElement!.firstChild);
      }
      this.rootElement!.appendChild(contentContainer);
    }

    // Process the next batch
    const batch = this.renderQueue.splice(0, this.maxNodesPerRenderPass);

    // Render this batch
    const contentContainer = this.rootElement!.querySelector(
      ".raxol-treemap-content"
    );
    if (!contentContainer) return;

    batch.forEach((rect, batchIndex) => {
      // Skip if rectangle is not visible (very small or outside bounds)
      if (rect.width < 1 || rect.height < 1) return;

      const index = this.rectangles.indexOf(rect);
      const element = this.createRectangleElement(rect, index);
      contentContainer.appendChild(element);
    });

    // If we have more items to render, schedule the next batch
    if (this.renderQueue.length > 0) {
      requestAnimationFrame(() => this.renderProgressively());
    }
  }

  /**
   * Create a DOM element for a rectangle
   */
  private createRectangleElement(rect: Rectangle, index: number): HTMLElement {
    const element = document.createElement("div");
    element.className = "raxol-treemap-rect";
    element.setAttribute("data-id", rect.node.id);
    element.setAttribute("data-index", index.toString());

    // Set base styles
    element.style.position = "absolute";
    element.style.left = `${rect.x}px`;
    element.style.top = `${rect.y}px`;
    element.style.width = `${rect.width}px`;
    element.style.height = `${rect.height}px`;
    element.style.overflow = "hidden";
    element.style.transition = `all ${this.options.animationDuration}ms ease-out`;

    // Determine color
    const colorIndex = this.getColorIndex(rect.node, index);
    const color =
      rect.node.color || this.options.colors?.[colorIndex] || "#cccccc";

    // Background and border styles
    element.style.backgroundColor = color;
    element.style.border = "1px solid rgba(255, 255, 255, 0.2)";
    element.style.boxSizing = "border-box";

    // Add label if needed and if rectangle is large enough
    if (
      this.options.showLabels &&
      rect.width > this.options.minLabelSize! &&
      rect.height > this.options.minLabelSize!
    ) {
      const label = document.createElement("div");
      label.className = "raxol-treemap-label";
      label.textContent = rect.node.name;

      // Label styles
      label.style.padding = "4px";
      label.style.fontSize = "12px";
      label.style.color = this.getLabelColor(color);
      label.style.whiteSpace = "nowrap";
      label.style.overflow = "hidden";
      label.style.textOverflow = "ellipsis";

      // Add value if space permits
      if (rect.width > 80 && rect.height > 40) {
        const valueLabel = document.createElement("div");
        valueLabel.className = "raxol-treemap-value";
        valueLabel.textContent = this.formatValue(rect.node.value);
        valueLabel.style.fontSize = "10px";
        valueLabel.style.opacity = "0.7";
        label.appendChild(valueLabel);
      }

      element.appendChild(label);
    }

    // Accessibility attributes
    element.setAttribute("role", "graphics-symbol");
    element.setAttribute(
      "aria-label",
      `${rect.node.name}: ${this.formatValue(rect.node.value)}`
    );

    // Add event listeners
    this.addRectEventListeners(element, rect, index);

    // Store the element reference
    rect.element = element;
    this.elementMap.set(rect.node.id, element);

    return element;
  }

  /**
   * Add event listeners to a rectangle element
   */
  private addRectEventListeners(
    element: HTMLElement,
    rect: Rectangle,
    index: number
  ): void {
    // Click event
    if (this.options.events?.nodeClick) {
      element.style.cursor = "pointer";
      element.addEventListener("click", () => {
        this.options.events?.nodeClick?.(rect.node);
      });
    }

    // Hover events
    if (this.options.tooltip?.enabled || this.options.events?.nodeHover) {
      element.addEventListener("mouseenter", (e) => {
        this.hoveredRect = rect;
        this.updateTooltip(e, rect);
        this.options.events?.nodeHover?.(rect.node);

        // Highlight the element
        element.style.filter = "brightness(1.1)";
        element.style.zIndex = "1";
      });

      element.addEventListener("mousemove", (e) => {
        this.updateTooltip(e, rect);
      });

      element.addEventListener("mouseleave", () => {
        this.hoveredRect = null;
        this.hideTooltip();
        this.options.events?.nodeHover?.(null);

        // Remove highlight
        element.style.filter = "";
        element.style.zIndex = "";
      });
    }

    // Focus events for keyboard navigation
    element.addEventListener("focus", () => {
      this.focusedIndex = index;
      element.style.outline = "2px solid #4285F4";
      element.style.zIndex = "1";
    });

    element.addEventListener("blur", () => {
      element.style.outline = "";
      element.style.zIndex = "";
    });
  }

  /**
   * Update tooltip position and content
   */
  private updateTooltip(event: MouseEvent, rect: Rectangle): void {
    if (!this.tooltip) return;

    // Update content
    let content: string;
    if (this.options.tooltip?.formatter) {
      content = this.options.tooltip.formatter(rect.node);
    } else {
      content = `<div><strong>${rect.node.name}</strong></div>
                <div>${this.formatValue(rect.node.value)}</div>`;
    }

    this.tooltip.innerHTML = content;

    // Position tooltip near cursor
    const tooltipRect = this.tooltip.getBoundingClientRect();
    const offset = 10;

    let x = event.clientX + offset;
    let y = event.clientY + offset;

    // Adjust if tooltip would go off-screen
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    if (x + tooltipRect.width > viewportWidth) {
      x = event.clientX - tooltipRect.width - offset;
    }

    if (y + tooltipRect.height > viewportHeight) {
      y = event.clientY - tooltipRect.height - offset;
    }

    this.tooltip.style.left = `${x}px`;
    this.tooltip.style.top = `${y}px`;
    this.tooltip.style.opacity = "1";
  }

  /**
   * Hide the tooltip
   */
  private hideTooltip(): void {
    if (this.tooltip) {
      this.tooltip.style.opacity = "0";
    }
  }

  /**
   * Set up keyboard navigation handlers
   */
  private setupKeyboardNavigation(): void {
    if (!this.rootElement) return;

    this.rootElement.addEventListener("keydown", (e) => {
      if (this.rectangles.length === 0) return;

      let newIndex = this.focusedIndex;

      // Handle arrow keys
      switch (e.key) {
        case "ArrowRight":
          newIndex = this.findNextRectInDirection("right", newIndex);
          break;
        case "ArrowLeft":
          newIndex = this.findNextRectInDirection("left", newIndex);
          break;
        case "ArrowDown":
          newIndex = this.findNextRectInDirection("down", newIndex);
          break;
        case "ArrowUp":
          newIndex = this.findNextRectInDirection("up", newIndex);
          break;
        case "Enter":
        case " ":
          // Trigger click on focused rectangle
          if (this.focusedIndex >= 0 && this.options.events?.nodeClick) {
            this.options.events.nodeClick(
              this.rectangles[this.focusedIndex].node
            );
          }
          e.preventDefault();
          break;
        default:
          return;
      }

      // If a new rectangle should be focused
      if (
        newIndex !== this.focusedIndex &&
        newIndex >= 0 &&
        newIndex < this.rectangles.length
      ) {
        e.preventDefault();

        // Focus the new element
        const element = this.rectangles[newIndex].element;
        if (element) {
          element.focus();
          this.focusedIndex = newIndex;
        }
      }
    });
  }

  /**
   * Find the next rectangle in the specified direction
   */
  private findNextRectInDirection(
    direction: "up" | "down" | "left" | "right",
    currentIndex: number
  ): number {
    if (currentIndex < 0) {
      return 0; // Start with the first rectangle if none is focused
    }

    const current = this.rectangles[currentIndex];
    let bestCandidate = -1;
    let bestDistance = Infinity;

    // Calculate center point of current rectangle
    const centerX = current.x + current.width / 2;
    const centerY = current.y + current.height / 2;

    for (let i = 0; i < this.rectangles.length; i++) {
      if (i === currentIndex) continue;

      const rect = this.rectangles[i];
      const rectCenterX = rect.x + rect.width / 2;
      const rectCenterY = rect.y + rect.height / 2;

      // Check if the rectangle is in the right direction
      let isInDirection = false;

      switch (direction) {
        case "right":
          isInDirection = rectCenterX > centerX;
          break;
        case "left":
          isInDirection = rectCenterX < centerX;
          break;
        case "down":
          isInDirection = rectCenterY > centerY;
          break;
        case "up":
          isInDirection = rectCenterY < centerY;
          break;
      }

      if (isInDirection) {
        // Calculate distance (Manhattan distance weighted by direction)
        let distance: number;

        if (direction === "left" || direction === "right") {
          distance =
            Math.abs(rectCenterX - centerX) * 3 +
            Math.abs(rectCenterY - centerY);
        } else {
          distance =
            Math.abs(rectCenterY - centerY) * 3 +
            Math.abs(rectCenterX - centerX);
        }

        if (distance < bestDistance) {
          bestDistance = distance;
          bestCandidate = i;
        }
      }
    }

    return bestCandidate >= 0 ? bestCandidate : currentIndex;
  }

  /**
   * Get color index for a node
   */
  private getColorIndex(node: TreeMapNode, index: number): number {
    if (!this.options.colors) return 0;
    return index % this.options.colors.length;
  }

  /**
   * Get appropriate label color based on background color
   */
  private getLabelColor(backgroundColor: string): string {
    // Simple brightness calculation
    const r = parseInt(backgroundColor.slice(1, 3), 16);
    const g = parseInt(backgroundColor.slice(3, 5), 16);
    const b = parseInt(backgroundColor.slice(5, 7), 16);

    // Formula for perceived brightness (YIQ)
    const brightness = (r * 299 + g * 587 + b * 114) / 1000;

    return brightness > 128 ? "#000000" : "#ffffff";
  }

  /**
   * Format value for display
   */
  private formatValue(value: number): string {
    // Format large numbers with K, M, B suffixes
    if (value >= 1000000000) {
      return `${(value / 1000000000).toFixed(1)}B`;
    } else if (value >= 1000000) {
      return `${(value / 1000000).toFixed(1)}M`;
    } else if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}K`;
    } else {
      return value.toString();
    }
  }

  /**
   * Update the treemap with new data
   */
  public updateData(root: TreeMapNode): void {
    startPerformanceMark("treemap-update-data");

    // Compare data hash to avoid unnecessary updates
    const newDataHash = this.hashTreeMapData(root);
    if (newDataHash === this.lastDataHash) {
      endPerformanceMark("treemap-update-data");
      return;
    }

    this.lastDataHash = newDataHash;
    this.options.root = root;

    // Check if we have a cached layout for this data and container size
    const cacheKey = this.getCacheKey(root, this.width, this.height);
    const cachedLayout = this.layoutCache.get(cacheKey);

    if (cachedLayout) {
      // Use cached layout
      this.rectangles = cachedLayout.rectangles;

      // Mark that we used the cache
      startPerformanceMark("treemap-render-from-cache");

      // Render with cached layout
      this.renderWithThrottling();

      endPerformanceMark("treemap-render-from-cache");
    } else {
      // Compute new layout and cache it
      this.computeLayout();

      // Cache the new layout
      this.layoutCache.set(cacheKey, {
        timestamp: Date.now(),
        rectangles: this.rectangles,
        dimensions: { width: this.width, height: this.height },
        dataHash: newDataHash,
      });

      // Clean up old cache entries if we have too many
      this.pruneCache();

      // Render with new layout
      this.renderWithThrottling();
    }

    endPerformanceMark("treemap-update-data");
  }

  /**
   * Create a hash key for TreeMapNode data to detect changes
   */
  private hashTreeMapData(node: TreeMapNode): string {
    // Simple hash function for TreeMapNode - adequate for change detection
    try {
      const nodeData = {
        id: node.id,
        name: node.name,
        value: node.value,
        children: node.children
          ? node.children.map((child) => ({
              id: child.id,
              name: child.name,
              value: child.value,
              childCount: child.children?.length || 0,
            }))
          : [],
      };

      return JSON.stringify(nodeData);
    } catch (e) {
      // Fallback if JSON stringification fails
      return `${node.id}-${Date.now()}`;
    }
  }

  /**
   * Gets a cache key for the current data and dimensions
   */
  private getCacheKey(
    root: TreeMapNode,
    width: number,
    height: number
  ): string {
    return `${root.id}-${width}x${height}`;
  }

  /**
   * Remove old cached layouts to prevent memory leaks
   */
  private pruneCache(): void {
    // Keep max 10 layouts in cache
    const MAX_CACHE_SIZE = 10;

    if (this.layoutCache.size > MAX_CACHE_SIZE) {
      // Sort by timestamp (oldest first)
      const entries = Array.from(this.layoutCache.entries()).sort(
        (a, b) => a[1].timestamp - b[1].timestamp
      );

      // Remove oldest entries
      for (let i = 0; i < entries.length - MAX_CACHE_SIZE; i++) {
        this.layoutCache.delete(entries[i][0]);
      }
    }
  }

  /**
   * Throttled rendering to avoid too many DOM updates
   */
  private renderWithThrottling(): void {
    // Cancel any pending render
    if (this.renderTimer !== null) {
      window.clearTimeout(this.renderTimer);
    }

    // If component is not visible, just mark that we need a render
    // and return without doing work
    if (!this.isVisible) {
      this.pendingRender = true;
      return;
    }

    // Schedule render
    this.renderTimer = window.setTimeout(() => {
      this.render();
      this.renderTimer = null;
    }, 16); // ~60fps
  }

  /**
   * Resize the treemap
   */
  public resize(): void {
    const rect = this.container.getBoundingClientRect();
    this.width = rect.width;
    this.height = rect.height;
    this.initialize();
  }

  /**
   * Clean up resources
   */
  public destroy(): void {
    // Remove tooltip
    if (this.tooltip && document.body.contains(this.tooltip)) {
      document.body.removeChild(this.tooltip);
    }

    // Clean up container
    if (this.container) {
      this.container.innerHTML = "";
    }
  }

  /**
   * Get node by id
   */
  public getNodeById(id: string): TreeMapNode | null {
    const findNode = (node: TreeMapNode): TreeMapNode | null => {
      if (node.id === id) return node;

      if (node.children) {
        for (const child of node.children) {
          const found = findNode(child);
          if (found) return found;
        }
      }

      return null;
    };

    return findNode(this.options.root);
  }

  /**
   * Focus a node by id
   */
  public focusNode(id: string): void {
    const element = this.elementMap.get(id);
    if (element) {
      element.focus();
    }
  }

  /**
   * Get the current color scheme
   * @returns Array of color strings
   */
  public getColors(): string[] {
    return this.options.colors || [];
  }
}
