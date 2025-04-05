/**
 * Dashboard Widgets Library
 * 
 * This file exports all available dashboard widgets for easy integration.
 */

// Export widget components
export { ChartWidget, ChartWidgetConfig } from './ChartWidget';
export { TreeMapWidget, TreeMapWidgetConfig } from './TreeMapWidget';
export { TableWidget, TableWidgetConfig } from './TableWidget';
export { TextWidget, TextWidgetConfig } from './TextWidget';
export { ImageWidget, ImageWidgetConfig } from './ImageWidget';
export { PerformanceWidget, PerformanceWidgetConfig } from './PerformanceWidget';

// Export widget types
export type WidgetType = 
  | 'chart'
  | 'treeMap'
  | 'table'
  | 'text'
  | 'image'
  | 'performance';

// Widget factory function
export const createWidget = (
  type: WidgetType,
  config: any
): any => {
  switch (type) {
    case 'chart':
      return new ChartWidget(config);
    case 'treeMap':
      return new TreeMapWidget(config);
    case 'table':
      return new TableWidget(config);
    case 'text':
      return new TextWidget(config);
    case 'image':
      return new ImageWidget(config);
    case 'performance':
      return new PerformanceWidget(config);
    default:
      throw new Error(`Unknown widget type: ${type}`);
  }
}; 