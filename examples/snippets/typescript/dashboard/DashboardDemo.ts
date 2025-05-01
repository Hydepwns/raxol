/**
 * DashboardDemo.ts
 * 
 * A demo application that showcases the Raxol dashboard with visualization widgets.
 */

import { DashboardContainer } from '../../components/dashboard/DashboardContainer';
import { ChartWidget, ChartWidgetConfig } from '../../components/dashboard/widgets/ChartWidget';
import { TreeMapWidget, TreeMapWidgetConfig } from '../../components/dashboard/widgets/TreeMapWidget';
import { LayoutConfig, WidgetConfig } from '../../components/dashboard/types';
import { View } from '../../core/renderer';

/**
 * Create a demo dashboard with visualization widgets
 */
export function createDashboardDemo(container: HTMLElement): void {
  // Create layout configuration
  const layout: LayoutConfig = {
    columns: 3,
    gap: 10,
    breakpoints: {
      small: 480,
      medium: 768,
      large: 1200
    }
  };
  
  // Create chart widget
  const chartWidget: ChartWidgetConfig = {
    id: 'sales-chart',
    title: 'Sales Performance',
    content: View.box({
      style: {
        width: '100%',
        height: '100%',
        border: 'none'
      }
    }),
    chartOptions: {
      type: 'line',
      title: 'Monthly Sales',
      series: [{
        name: 'Sales',
        data: [
          { x: 'Jan', y: 42 },
          { x: 'Feb', y: 53 },
          { x: 'Mar', y: 61 },
          { x: 'Apr', y: 48 },
          { x: 'May', y: 55 },
          { x: 'Jun', y: 67 }
        ]
      }],
      accessibility: {
        description: 'Line chart showing monthly sales figures'
      }
    },
    position: { x: 0, y: 0 },
    size: { width: 2, height: 1 },
    isResizable: true,
    isDraggable: true
  };
  
  // Create TreeMap widget
  const treeMapWidget: TreeMapWidgetConfig = {
    id: 'product-categories',
    title: 'Product Categories',
    content: View.box({
      style: {
        width: '100%',
        height: '100%',
        border: 'none'
      }
    }),
    treeMapOptions: {
      root: {
        id: 'root',
        name: 'Products',
        value: 0,
        children: [
          {
            id: 'electronics',
            name: 'Electronics',
            value: 0,
            children: [
              { id: 'phones', name: 'Phones', value: 1200 },
              { id: 'laptops', name: 'Laptops', value: 800 },
              { id: 'tablets', name: 'Tablets', value: 600 }
            ]
          },
          {
            id: 'clothing',
            name: 'Clothing',
            value: 0,
            children: [
              { id: 'shirts', name: 'Shirts', value: 400 },
              { id: 'pants', name: 'Pants', value: 300 },
              { id: 'shoes', name: 'Shoes', value: 500 }
            ]
          },
          {
            id: 'accessories',
            name: 'Accessories',
            value: 0,
            children: [
              { id: 'watches', name: 'Watches', value: 200 },
              { id: 'jewelry', name: 'Jewelry', value: 300 },
              { id: 'bags', name: 'Bags', value: 400 }
            ]
          }
        ]
      },
      showLabels: true,
      padding: 2,
      accessibility: {
        description: 'TreeMap showing product categories by sales value'
      }
    },
    position: { x: 2, y: 0 },
    size: { width: 1, height: 1 },
    isResizable: true,
    isDraggable: true
  };
  
  // Create widgets array
  const widgets: WidgetConfig[] = [
    chartWidget,
    treeMapWidget
  ];
  
  // Create dashboard
  const dashboard = new DashboardContainer({
    widgets,
    layout,
    onLayoutChange: (newLayout) => {
      console.log('Layout changed:', newLayout);
    },
    onWidgetAdd: (widget) => {
      console.log('Widget added:', widget);
    },
    onWidgetRemove: (widgetId) => {
      console.log('Widget removed:', widgetId);
    },
    onWidgetResize: (widgetId, size) => {
      console.log('Widget resized:', widgetId, size);
    }
  });
  
  // Render dashboard
  container.appendChild(dashboard.render().element);
}

/**
 * Run the dashboard demo
 */
export function runDashboardDemo(): void {
  // Create container
  const container = document.createElement('div');
  container.style.width = '100%';
  container.style.height = '100vh';
  container.style.padding = '20px';
  container.style.boxSizing = 'border-box';
  
  // Add title
  const title = document.createElement('h1');
  title.textContent = 'Raxol Dashboard Demo';
  title.style.textAlign = 'center';
  title.style.margin = '0 0 20px 0';
  container.appendChild(title);
  
  // Create dashboard
  createDashboardDemo(container);
  
  // Add to document
  document.body.appendChild(container);
} 