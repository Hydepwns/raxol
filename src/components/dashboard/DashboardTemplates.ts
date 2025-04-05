/**
 * DashboardTemplates.ts
 * 
 * Manages predefined dashboard templates that users can use as starting points
 * for creating new dashboards. Templates include layout configurations and
 * widget setups for common use cases.
 */

import { Template, LayoutWithWidgets } from './types';
import { ConfigurationManager } from './ConfigurationManager';

/**
 * Template manager options
 */
interface TemplateManagerOptions {
  /**
   * Configuration manager instance
   */
  configManager: ConfigurationManager;
  
  /**
   * Storage namespace for templates
   */
  namespace?: string;
}

/**
 * Dashboard template manager
 */
export class DashboardTemplates {
  private configManager: ConfigurationManager;
  private namespace: string;
  
  /**
   * Constructor
   */
  constructor(options: TemplateManagerOptions) {
    this.configManager = options.configManager;
    this.namespace = options.namespace || 'raxol-templates';
  }
  
  /**
   * Get all available templates
   */
  async getTemplates(): Promise<Template[]> {
    try {
      const templates = await this.configManager.listLayouts();
      const result: Template[] = [];
      
      for (const name of templates) {
        if (name.startsWith(this.namespace)) {
          const config = await this.configManager.loadLayout(name);
          const templateId = name.replace(`${this.namespace}:`, '');
          
          result.push({
            id: templateId,
            name: config.name || templateId,
            description: config.description,
            thumbnail: config.thumbnail,
            config: {
              layout: config.layout,
              widgets: config.widgets
            }
          });
        }
      }
      
      return result;
    } catch (error) {
      console.error('Failed to get templates:', error);
      return [];
    }
  }
  
  /**
   * Save a new template
   */
  async saveTemplate(template: Template): Promise<void> {
    const key = `${this.namespace}:${template.id}`;
    
    await this.configManager.saveLayout(key, template.config.layout, template.config.widgets);
  }
  
  /**
   * Load a template by ID
   */
  async loadTemplate(templateId: string): Promise<Template | null> {
    try {
      const key = `${this.namespace}:${templateId}`;
      const config = await this.configManager.loadLayout(key);
      
      return {
        id: templateId,
        name: config.name || templateId,
        description: config.description,
        thumbnail: config.thumbnail,
        config: {
          layout: config.layout,
          widgets: config.widgets
        }
      };
    } catch (error) {
      console.error(`Failed to load template '${templateId}':`, error);
      return null;
    }
  }
  
  /**
   * Delete a template
   */
  async deleteTemplate(templateId: string): Promise<void> {
    const key = `${this.namespace}:${templateId}`;
    await this.configManager.deleteLayout(key);
  }
  
  /**
   * Export a template to JSON
   */
  async exportTemplate(templateId: string): Promise<string> {
    const template = await this.loadTemplate(templateId);
    
    if (!template) {
      throw new Error(`Template '${templateId}' not found`);
    }
    
    return JSON.stringify(template, null, 2);
  }
  
  /**
   * Import a template from JSON
   */
  async importTemplate(templateJson: string): Promise<void> {
    try {
      const template: Template = JSON.parse(templateJson);
      
      if (!template.id || !template.config) {
        throw new Error('Invalid template format');
      }
      
      await this.saveTemplate(template);
    } catch (error) {
      console.error('Failed to import template:', error);
      throw error;
    }
  }
  
  /**
   * Get default templates
   */
  getDefaultTemplates(): Template[] {
    return [
      {
        id: 'default-analytics',
        name: 'Analytics Dashboard',
        description: 'A dashboard for displaying analytics data with charts and metrics',
        config: {
          layout: {
            columns: 3,
            gap: 10,
            breakpoints: {
              small: 480,
              medium: 768,
              large: 1200
            }
          },
          widgets: [
            {
              id: 'chart-1',
              title: 'Performance Metrics',
              content: null, // This would be a ChartWidget component
              position: { x: 0, y: 0 },
              size: { width: 2, height: 2 },
              isResizable: true,
              isDraggable: true
            },
            {
              id: 'chart-2',
              title: 'User Activity',
              content: null, // This would be a ChartWidget component
              position: { x: 2, y: 0 },
              size: { width: 1, height: 2 },
              isResizable: true,
              isDraggable: true
            },
            {
              id: 'treemap-1',
              title: 'Resource Usage',
              content: null, // This would be a TreeMapWidget component
              position: { x: 0, y: 2 },
              size: { width: 3, height: 2 },
              isResizable: true,
              isDraggable: true
            }
          ]
        }
      },
      {
        id: 'default-monitoring',
        name: 'System Monitoring',
        description: 'A dashboard for monitoring system resources and performance',
        config: {
          layout: {
            columns: 4,
            gap: 10,
            breakpoints: {
              small: 480,
              medium: 768,
              large: 1200
            }
          },
          widgets: [
            {
              id: 'chart-1',
              title: 'CPU Usage',
              content: null, // This would be a ChartWidget component
              position: { x: 0, y: 0 },
              size: { width: 2, height: 1 },
              isResizable: true,
              isDraggable: true
            },
            {
              id: 'chart-2',
              title: 'Memory Usage',
              content: null, // This would be a ChartWidget component
              position: { x: 2, y: 0 },
              size: { width: 2, height: 1 },
              isResizable: true,
              isDraggable: true
            },
            {
              id: 'chart-3',
              title: 'Network Traffic',
              content: null, // This would be a ChartWidget component
              position: { x: 0, y: 1 },
              size: { width: 2, height: 1 },
              isResizable: true,
              isDraggable: true
            },
            {
              id: 'chart-4',
              title: 'Disk I/O',
              content: null, // This would be a ChartWidget component
              position: { x: 2, y: 1 },
              size: { width: 2, height: 1 },
              isResizable: true,
              isDraggable: true
            }
          ]
        }
      }
    ];
  }
} 