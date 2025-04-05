/**
 * TreeMapWidget.ts
 * 
 * A widget component that wraps the TreeMap visualization for use in the dashboard.
 * Provides controls for TreeMap configuration and data updates.
 */

import { RaxolComponent } from '../../../core/component';
import { View } from '../../../core/renderer/view';
import { TreeMap, TreeMapOptions, TreeMapNode } from '../../visualization/TreeMap';
import { WidgetConfig } from '../types';

/**
 * TreeMap widget configuration
 */
export interface TreeMapWidgetConfig extends WidgetConfig {
  /**
   * TreeMap options
   */
  treeMapOptions: TreeMapOptions;
  
  /**
   * Whether to show TreeMap controls
   */
  showControls?: boolean;
  
  /**
   * Whether to enable real-time updates
   */
  enableRealTime?: boolean;
  
  /**
   * Update interval in milliseconds (for real-time updates)
   */
  updateInterval?: number;
}

/**
 * TreeMap widget state
 */
interface TreeMapWidgetState {
  /**
   * Current TreeMap options
   */
  treeMapOptions: TreeMapOptions;
  
  /**
   * Whether controls are expanded
   */
  areControlsExpanded: boolean;
  
  /**
   * Whether real-time updates are enabled
   */
  isRealTimeEnabled: boolean;
}

/**
 * TreeMap widget component
 */
export class TreeMapWidget extends RaxolComponent<TreeMapWidgetConfig, TreeMapWidgetState> {
  private treeMap: TreeMap | null = null;
  private updateTimer: number | null = null;
  
  /**
   * Constructor
   */
  constructor(props: TreeMapWidgetConfig) {
    super(props);
    
    // Initialize state
    this.state = {
      treeMapOptions: props.treeMapOptions,
      areControlsExpanded: false,
      isRealTimeEnabled: props.enableRealTime || false
    };
    
    // Bind methods
    this.toggleControls = this.toggleControls.bind(this);
    this.toggleRealTime = this.toggleRealTime.bind(this);
    this.updateTreeMapOptions = this.updateTreeMapOptions.bind(this);
    this.updateTreeMapData = this.updateTreeMapData.bind(this);
  }
  
  /**
   * Initialize the TreeMap
   */
  private initializeTreeMap(): void {
    // Create container for the TreeMap
    const container = document.createElement('div');
    container.style.width = '100%';
    container.style.height = '100%';
    
    // Create TreeMap instance
    this.treeMap = new TreeMap(container, this.state.treeMapOptions);
    
    // Add container to the widget content
    this.setContent(container);
  }
  
  /**
   * Toggle TreeMap controls visibility
   */
  private toggleControls(): void {
    this.setState({ areControlsExpanded: !this.state.areControlsExpanded });
  }
  
  /**
   * Toggle real-time updates
   */
  private toggleRealTime(): void {
    const isEnabled = !this.state.isRealTimeEnabled;
    
    if (isEnabled) {
      // Start update timer
      this.updateTimer = window.setInterval(() => {
        this.updateTreeMapData();
      }, this.props.updateInterval || 5000);
    } else {
      // Clear update timer
      if (this.updateTimer) {
        window.clearInterval(this.updateTimer);
        this.updateTimer = null;
      }
    }
    
    this.setState({ isRealTimeEnabled: isEnabled });
  }
  
  /**
   * Update TreeMap options
   */
  private updateTreeMapOptions(options: Partial<TreeMapOptions>): void {
    const newOptions = { ...this.state.treeMapOptions, ...options };
    this.setState({ treeMapOptions: newOptions });
    
    if (this.treeMap) {
      this.treeMap.updateOptions(newOptions);
    }
  }
  
  /**
   * Update TreeMap data
   */
  private updateTreeMapData(): void {
    // This is a placeholder - in a real implementation,
    // this would fetch new data from a data source
    const newData = this.generateSampleData();
    
    if (this.treeMap) {
      this.treeMap.updateData(newData);
    }
  }
  
  /**
   * Generate sample data for demonstration
   */
  private generateSampleData(): TreeMapNode {
    // This is just example data - in a real implementation,
    // this would come from a data source
    return {
      id: 'root',
      name: 'Sample Data',
      value: 0,
      children: Array.from({ length: 5 }, (_, i) => ({
        id: `node-${i}`,
        name: `Category ${i + 1}`,
        value: Math.random() * 100,
        children: Array.from({ length: 3 }, (_, j) => ({
          id: `node-${i}-${j}`,
          name: `Subcategory ${j + 1}`,
          value: Math.random() * 50
        }))
      }))
    };
  }
  
  /**
   * Render TreeMap controls
   */
  private renderControls(): View {
    const { areControlsExpanded, isRealTimeEnabled } = this.state;
    
    if (!areControlsExpanded) {
      return View.box({
        border: 'none',
        children: [
          View.button({
            label: 'Show Controls',
            onClick: this.toggleControls
          })
        ]
      });
    }
    
    return View.box({
      border: 'single',
      children: [
        // Show labels toggle
        View.button({
          label: this.state.treeMapOptions.showLabels ? 'Hide Labels' : 'Show Labels',
          onClick: () => this.updateTreeMapOptions({
            showLabels: !this.state.treeMapOptions.showLabels
          })
        }),
        
        // Padding control
        View.slider({
          label: 'Padding',
          min: 0,
          max: 10,
          value: this.state.treeMapOptions.padding || 2,
          onChange: (value) => this.updateTreeMapOptions({ padding: value })
        }),
        
        // Real-time toggle
        View.button({
          label: isRealTimeEnabled ? 'Disable Real-time' : 'Enable Real-time',
          onClick: this.toggleRealTime
        }),
        
        // Hide controls button
        View.button({
          label: 'Hide Controls',
          onClick: this.toggleControls
        })
      ]
    });
  }
  
  /**
   * Render the widget
   */
  render(): View {
    // Initialize TreeMap if not already done
    if (!this.treeMap) {
      this.initializeTreeMap();
    }
    
    return View.box({
      border: 'single',
      children: [
        // Widget header
        View.box({
          border: 'none',
          children: [
            View.text(this.props.title),
            View.button({
              label: this.state.areControlsExpanded ? '▲' : '▼',
              onClick: this.toggleControls
            })
          ]
        }),
        
        // TreeMap controls
        this.renderControls(),
        
        // TreeMap content (handled by initializeTreeMap)
        View.box({
          border: 'none',
          style: {
            flex: 1,
            minHeight: '200px'
          }
        })
      ]
    });
  }
  
  /**
   * Clean up resources
   */
  destroy(): void {
    if (this.updateTimer) {
      window.clearInterval(this.updateTimer);
      this.updateTimer = null;
    }
    
    if (this.treeMap) {
      this.treeMap.destroy();
      this.treeMap = null;
    }
  }
} 