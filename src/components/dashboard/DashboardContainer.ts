/**
 * DashboardContainer.ts
 * 
 * Main container component for the Raxol dashboard layout system.
 * This component manages the overall dashboard layout, handles
 * responsive behavior, coordinates widget interactions, and manages
 * dashboard state.
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/renderer/view';
import { GridSystem } from './GridSystem';
import { WidgetContainer } from './WidgetContainer';
import { ConfigurationManager } from './ConfigurationManager';
import { DashboardTemplates } from './DashboardTemplates';
import { WidgetCustomizer } from './WidgetCustomizer';
import { LayoutConfig, WidgetConfig, Position, Size, DashboardTheme, Template } from './types';
import { WidgetStateManager } from './WidgetStateManager';
import { WidgetFactory, WidgetFactoryConfig } from './WidgetFactory';
import { PerformanceMonitor } from './PerformanceMonitor';
import { WidgetType } from './widgets';
import { ThemeManager, ThemeConfig } from './ThemeManager';
import { ThemeSelector } from './ThemeSelector';
import { defaultTheme } from './themes/default';
import { DashboardToolbar } from './DashboardToolbar';
import { DashboardSettings, DashboardSettingsConfig } from './DashboardSettings';
import { WidgetCustomizationPanel } from './WidgetCustomizationPanel';
import { WidgetTemplateSelector, WidgetTemplate } from './WidgetTemplateSelector';
import { WidgetDataSourceManager, DataSourceConfig } from './WidgetDataSourceManager';
import { WidgetDataBinding, DataBindingConfig } from './WidgetDataBinding';
import { WidgetDataTransformer, DataTransformConfig, DataFormatConfig } from './WidgetDataTransformer';
import { WidgetDataValidator, ValidationRule, ValidationResult } from './WidgetDataValidator';
import { WidgetDataCache, CacheConfig } from './WidgetDataCache';
import { WidgetDataSync, SyncGroup, SyncConfig } from './WidgetDataSync';
import { WidgetDataError, ErrorConfig, ErrorType, ErrorSeverity, ErrorHandlerConfig } from './WidgetDataError';
import { WidgetDataLogger, LogLevel, LoggerConfig } from './WidgetDataLogger';
import { WidgetDataMetrics, MetricType, MetricConfig, MetricsConfig } from './WidgetDataMetrics';

/**
 * Dashboard container configuration
 */
export interface DashboardContainerConfig {
  /**
   * Dashboard title
   */
  title: string;
  
  /**
   * Dashboard description
   */
  description?: string;
  
  /**
   * Dashboard widgets
   */
  widgets: Array<{
    /**
     * Widget type
     */
    type: WidgetType;
    
    /**
     * Widget configuration
     */
    config: Partial<WidgetConfig>;
    
    /**
     * Widget position
     */
    position: {
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
      rowSpan?: number;
      
      /**
       * Column span
       */
      columnSpan?: number;
    };
  }>;
  
  /**
   * Dashboard layout
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
   * Widget factory configuration
   */
  widgetFactoryConfig?: WidgetFactoryConfig;
  
  /**
   * Initial theme
   */
  theme?: ThemeConfig;
  
  /**
   * Callback for when the dashboard is refreshed
   */
  onRefresh?: () => void;
  
  /**
   * Callback for when the dashboard is saved
   */
  onSave?: () => void;
  
  /**
   * Callback for when the dashboard is reset
   */
  onReset?: () => void;
}

/**
 * Dashboard container state
 */
interface DashboardContainerState {
  /**
   * Widget instances
   */
  widgets: Array<WidgetConfig>;
  
  /**
   * Widget positions
   */
  positions: Map<string, {
    row: number;
    column: number;
    rowSpan: number;
    columnSpan: number;
  }>;
  
  /**
   * Current theme
   */
  theme: ThemeConfig;
  
  /**
   * Whether the dashboard is in edit mode
   */
  isEditMode: boolean;
  
  showSettings: boolean;
  
  customizingWidgetId: string | null;
  customizingWidgetType: WidgetType | null;
  customizingWidgetConfig: any | null;
  
  isTemplateSelectorOpen: boolean;
  templates: WidgetTemplate[];
  
  /**
   * Dashboard layout configuration
   */
  layout: LayoutConfig;
}

/**
 * Dashboard container component
 */
export class DashboardContainer extends RaxolComponent<DashboardContainerConfig, DashboardContainerState> {
  /**
   * Configuration manager
   */
  private configManager: ConfigurationManager;
  
  /**
   * Template manager
   */
  private templateManager: DashboardTemplates;
  
  /**
   * Widget state manager
   */
  private stateManager: WidgetStateManager;
  
  /**
   * Widget factory
   */
  private widgetFactory: WidgetFactory;
  
  /**
   * Performance monitor
   */
  private performanceMonitor: PerformanceMonitor;
  
  /**
   * Theme manager
   */
  private themeManager: ThemeManager;
  
  /**
   * Data source manager
   */
  private dataSourceManager: WidgetDataSourceManager;
  
  /**
   * Data binding
   */
  private dataBinding: WidgetDataBinding;
  
  /**
   * Data transformer
   */
  private dataTransformer: WidgetDataTransformer;
  
  /**
   * Data validator
   */
  private dataValidator: WidgetDataValidator;
  
  /**
   * Data cache
   */
  private dataCache: WidgetDataCache;
  
  /**
   * Data sync
   */
  private dataSync: WidgetDataSync;
  
  /**
   * Data error
   */
  private dataError: WidgetDataError;
  
  /**
   * Data logger
   */
  private dataLogger: WidgetDataLogger;
  
  /**
   * Data metrics
   */
  private dataMetrics: WidgetDataMetrics;
  
  /**
   * Constructor
   */
  constructor(props: DashboardContainerConfig) {
    super(props);
    
    // Initialize managers
    this.configManager = new ConfigurationManager();
    this.templateManager = new DashboardTemplates();
    this.stateManager = new WidgetStateManager();
    this.dataSourceManager = new WidgetDataSourceManager();
    this.dataBinding = new WidgetDataBinding();
    this.dataTransformer = new WidgetDataTransformer();
    this.dataValidator = new WidgetDataValidator();
    this.dataCache = new WidgetDataCache({
      defaultExpiration: 5 * 60 * 1000, // 5 minutes
      maxSize: 100,
      enabled: true
    });
    this.dataSync = new WidgetDataSync();
    this.dataError = new WidgetDataError();
    this.dataLogger = new WidgetDataLogger({
      minLevel: LogLevel.INFO,
      logToConsole: true,
      maxHistorySize: 1000
    });
    this.dataMetrics = new WidgetDataMetrics({
      enabled: true,
      maxHistorySize: 1000,
      aggregationInterval: 60000, // 1 minute
      thresholds: {
        'data_source:global:response_time': 1000, // 1 second
        'transformation:global:processing_time': 500, // 500 milliseconds
        'validation:global:processing_time': 200, // 200 milliseconds
        'cache:global:hit_ratio': 0.8, // 80% cache hit ratio
        'binding:global:update_time': 100, // 100 milliseconds
        'sync:global:sync_time': 300, // 300 milliseconds
        'error:global:error_rate': 0.01 // 1% error rate
      }
    });
    
    // Initialize performance monitor
    this.performanceMonitor = new PerformanceMonitor();
    
    // Initialize theme manager
    this.themeManager = new ThemeManager(props.theme || defaultTheme);
    
    // Initialize widget factory
    this.widgetFactory = new WidgetFactory({
      performanceMonitor: this.performanceMonitor,
      ...props.widgetFactoryConfig
    });
    
    // Initialize state
    this.state = {
      widgets: [],
      positions: new Map(),
      theme: props.theme || defaultTheme,
      isEditMode: false,
      showSettings: false,
      customizingWidgetId: null,
      customizingWidgetType: null,
      customizingWidgetConfig: null,
      isTemplateSelectorOpen: false,
      templates: [
        {
          id: 'chart-line',
          name: 'Line Chart',
          description: 'Display data as a line chart',
          type: 'chart',
          config: {
            type: 'line',
            title: 'Line Chart',
            autoRefresh: true,
            refreshInterval: 60
          }
        },
        {
          id: 'chart-bar',
          name: 'Bar Chart',
          description: 'Display data as a bar chart',
          type: 'chart',
          config: {
            type: 'bar',
            title: 'Bar Chart',
            autoRefresh: true,
            refreshInterval: 60
          }
        },
        {
          id: 'chart-pie',
          name: 'Pie Chart',
          description: 'Display data as a pie chart',
          type: 'chart',
          config: {
            type: 'pie',
            title: 'Pie Chart',
            autoRefresh: true,
            refreshInterval: 60
          }
        },
        {
          id: 'text',
          name: 'Text Widget',
          description: 'Display text content',
          type: 'text',
          config: {
            title: 'Text Widget',
            content: 'Enter text here',
            autoRefresh: false
          }
        },
        {
          id: 'image',
          name: 'Image Widget',
          description: 'Display an image',
          type: 'image',
          config: {
            title: 'Image Widget',
            src: '',
            autoRefresh: false
          }
        },
        {
          id: 'performance',
          name: 'Performance Widget',
          description: 'Monitor system performance',
          type: 'performance',
          config: {
            title: 'Performance Monitor',
            autoRefresh: true,
            refreshInterval: 5
          }
        }
      ],
      layout: props.layout
    };
    
    // Initialize default formats
    this.initializeDefaultFormats();
    
    // Initialize default validation rules
    this.initializeDefaultValidationRules();
    
    // Bind methods
    this.handleWidgetDragStart = this.handleWidgetDragStart.bind(this);
    this.handleWidgetDragEnd = this.handleWidgetDragEnd.bind(this);
    this.handleWidgetDragMove = this.handleWidgetDragMove.bind(this);
    this.handleWidgetResize = this.handleWidgetResize.bind(this);
    this.handleWidgetRemove = this.handleWidgetRemove.bind(this);
    this.handleWidgetCustomize = this.handleWidgetCustomize.bind(this);
    this.handleWidgetCustomizeApply = this.handleWidgetCustomizeApply.bind(this);
    this.handleWidgetCustomizeCancel = this.handleWidgetCustomizeCancel.bind(this);
    this.toggleEditMode = this.toggleEditMode.bind(this);
    this.saveLayout = this.saveLayout.bind(this);
    this.loadLayout = this.loadLayout.bind(this);
    this.openTemplateSelector = this.openTemplateSelector.bind(this);
    this.closeTemplateSelector = this.closeTemplateSelector.bind(this);
    this.applyTemplate = this.applyTemplate.bind(this);
    this.loadTemplates = this.loadTemplates.bind(this);
  }
  
  /**
   * Component did mount
   */
  componentDidMount(): void {
    // Initialize widgets
    this.initializeWidgets();
    
    // Start performance monitoring
    this.performanceMonitor.startMonitoring();
    
    // Add theme change listener
    this.themeManager.addThemeChangeListener(this.handleThemeChange.bind(this));
    
    // Initialize widget states
    this.stateManager.initializeFromWidgets(this.state.widgets);
    
    // Add state change listener
    this.stateManager.addStateChangeListener(this.handleWidgetStateChange);
    
    // Initialize data sources and bindings
    this.initializeDataSourcesAndBindings();
  }
  
  /**
   * Component will unmount
   */
  componentWillUnmount(): void {
    // Stop performance monitoring
    this.performanceMonitor.stopMonitoring();
    
    // Remove theme change listener
    this.themeManager.removeThemeChangeListener(this.handleThemeChange.bind(this));
    
    // Remove state change listener
    this.stateManager.removeStateChangeListener(this.handleWidgetStateChange);
    
    // Clean up data sources and bindings
    this.cleanupDataSourcesAndBindings();
  }
  
  /**
   * Handle theme change
   */
  private handleThemeChange(theme: ThemeConfig): void {
    this.setState({ theme });
  }
  
  /**
   * Initialize widgets
   */
  private initializeWidgets(): void {
    const { widgets } = this.props;
    const widgetInstances = widgets.map(widget => this.widgetFactory.createWidget(widget.type, widget.config));
    
    // Update state
    this.setState({
      widgets: widgetInstances,
      positions: new Map(widgets.map((widget, index) => [
        `widget-${index}`,
        {
          row: widget.position.row,
          column: widget.position.column,
          rowSpan: widget.position.rowSpan || 1,
          columnSpan: widget.position.columnSpan || 1
        }
      ]))
    });
    
    // Initialize widget states
    this.stateManager.initializeFromWidgets(widgetInstances);
  }
  
  /**
   * Handle widget state change
   */
  private handleWidgetStateChange(widgetId: string, state: any): void {
    // Find the widget
    const widgetIndex = this.state.widgets.findIndex(w => w.id === widgetId);
    
    if (widgetIndex === -1) return;
    
    // Update widget
    const updatedWidgets = [...this.state.widgets];
    updatedWidgets[widgetIndex] = {
      ...updatedWidgets[widgetIndex],
      content: {
        ...updatedWidgets[widgetIndex].content,
        ...state
      }
    };
    
    // Update state
    this.setState({ widgets: updatedWidgets });
  }
  
  /**
   * Load available templates
   */
  private async loadTemplates(): Promise<void> {
    try {
      const templates = await this.templateManager.getTemplates();
      
      // If no templates exist, add default templates
      if (templates.length === 0) {
        const defaultTemplates = this.templateManager.getDefaultTemplates();
        
        for (const template of defaultTemplates) {
          await this.templateManager.saveTemplate(template);
        }
        
        this.setState({ templates: defaultTemplates });
      } else {
        this.setState({ templates });
      }
    } catch (error) {
      console.error('Failed to load templates:', error);
    }
  }
  
  /**
   * Open template selector
   */
  private openTemplateSelector(): void {
    this.setState({ isTemplateSelectorOpen: true });
  }
  
  /**
   * Close template selector
   */
  private closeTemplateSelector(): void {
    this.setState({ isTemplateSelectorOpen: false });
  }
  
  /**
   * Apply a template
   */
  private async applyTemplate(templateId: string): Promise<void> {
    try {
      const template = await this.templateManager.loadTemplate(templateId);
      
      if (template) {
        this.setState({
          layout: template.config.layout,
          widgets: template.config.widgets,
          isTemplateSelectorOpen: false
        });
        
        // Notify layout change
        if (this.props.onLayoutChange) {
          this.props.onLayoutChange(template.config.layout);
        }
      }
    } catch (error) {
      console.error(`Failed to apply template '${templateId}':`, error);
    }
  }
  
  /**
   * Handle widget customize
   */
  private handleWidgetCustomize(widgetId: string): void {
    const widget = this.state.widgets.find(w => w.id === widgetId);
    
    if (widget) {
      this.setState({
        customizingWidgetId: widget.id,
        customizingWidgetType: widget.type,
        customizingWidgetConfig: { ...widget.config }
      });
    }
  }
  
  /**
   * Handle widget customize apply
   */
  private handleWidgetCustomizeApply(updatedWidget: WidgetConfig): void {
    const { widgets } = this.state;
    
    // Update widget
    const updatedWidgets = widgets.map(widget => {
      if (widget.id === updatedWidget.id) {
        return updatedWidget;
      }
      return widget;
    });
    
    this.setState({
      widgets: updatedWidgets,
      customizingWidgetId: null
    });
  }
  
  /**
   * Handle widget customize cancel
   */
  private handleWidgetCustomizeCancel(): void {
    this.setState({
      customizingWidgetId: null,
      customizingWidgetType: null,
      customizingWidgetConfig: null
    });
  }
  
  /**
   * Get default layout configuration
   */
  private getDefaultLayout(): LayoutConfig {
    return {
      columns: 3,
      gap: 10,
      breakpoints: {
        small: 480,
        medium: 768,
        large: 1200
      }
    };
  }
  
  /**
   * Handle widget drag start event
   */
  private handleWidgetDragStart(widgetId: string): void {
    this.setState({ draggingWidgetId: widgetId });
  }
  
  /**
   * Handle widget drag end event
   */
  private handleWidgetDragEnd(): void {
    this.setState({ draggingWidgetId: null });
    
    // Notify layout change
    if (this.props.onLayoutChange) {
      this.props.onLayoutChange(this.state.layout);
    }
  }
  
  /**
   * Handle widget drag move event
   */
  private handleWidgetDragMove(widgetId: string, position: Position): void {
    // Update widget position
    const updatedWidgets = this.state.widgets.map(widget => {
      if (widget.id === widgetId) {
        return { ...widget, position };
      }
      return widget;
    });
    
    this.setState({ widgets: updatedWidgets });
  }
  
  /**
   * Handle widget resize event
   */
  private handleWidgetResize(widgetId: string, size: Size): void {
    // Update widget size
    const updatedWidgets = this.state.widgets.map(widget => {
      if (widget.id === widgetId) {
        return { ...widget, size };
      }
      return widget;
    });
    
    this.setState({ widgets: updatedWidgets });
    
    // Notify widget resize
    if (this.props.onWidgetResize) {
      this.props.onWidgetResize(widgetId, size);
    }
  }
  
  /**
   * Handle widget remove event
   */
  private handleWidgetRemove(widgetId: string): void {
    // Remove widget
    const updatedWidgets = this.state.widgets.filter(widget => widget.id !== widgetId);
    this.setState({ widgets: updatedWidgets });
    
    // Notify widget remove
    if (this.props.onWidgetRemove) {
      this.props.onWidgetRemove(widgetId);
    }
  }
  
  /**
   * Toggle dashboard edit mode
   */
  private toggleEditMode(): void {
    this.setState({ isEditMode: !this.state.isEditMode });
  }
  
  /**
   * Save current layout
   */
  private async saveLayout(name: string): Promise<void> {
    const layoutConfig = {
      layout: this.state.layout,
      widgets: this.state.widgets
    };
    
    await this.configManager.saveLayout(name, layoutConfig);
  }
  
  /**
   * Load a saved layout
   */
  private async loadLayout(name: string): Promise<void> {
    try {
      const layoutConfig = await this.configManager.loadLayout(name);
      
      this.setState({
        layout: layoutConfig.layout,
        widgets: layoutConfig.widgets
      });
      
      // Notify layout change
      if (this.props.onLayoutChange) {
        this.props.onLayoutChange(layoutConfig.layout);
      }
    } catch (error) {
      console.error(`Failed to load layout '${name}':`, error);
    }
  }
  
  /**
   * Handle settings toggle
   */
  private handleSettingsToggle(): void {
    this.setState({
      showSettings: !this.state.showSettings
    });
  }
  
  /**
   * Handle layout change
   */
  private handleLayoutChange(layout: { rows: number; columns: number }): void {
    // Update layout configuration
    this.setState({
      layout: {
        ...this.state.layout,
        ...layout
      }
    });
  }
  
  /**
   * Handle settings save
   */
  private handleSettingsSave(): void {
    this.setState({
      showSettings: false
    });
  }
  
  /**
   * Handle settings cancel
   */
  private handleSettingsCancel(): void {
    this.setState({
      showSettings: false
    });
  }
  
  /**
   * Handle widget configuration change
   */
  private handleWidgetConfigChange(config: any): void {
    this.setState({
      customizingWidgetConfig: config
    });
  }
  
  /**
   * Handle widget customization save
   */
  private handleWidgetCustomizationSave(): void {
    const { customizingWidgetId, customizingWidgetConfig } = this.state;
    
    if (customizingWidgetId && customizingWidgetConfig) {
      const widget = this.state.widgets.find(w => w.id === customizingWidgetId);
      
      if (widget) {
        this.setState({
          widgets: this.state.widgets.map(w => {
            if (w.id === customizingWidgetId) {
              return {
                ...w,
                config: customizingWidgetConfig
              };
            }
            return w;
          }),
          customizingWidgetId: null,
          customizingWidgetType: null,
          customizingWidgetConfig: null
        });
      }
    }
  }
  
  /**
   * Handle template selection
   */
  private handleTemplateSelect(template: WidgetTemplate): void {
    const { isEditMode } = this.state;
    
    if (isEditMode) {
      // Generate a unique ID for the new widget
      const widgetId = `widget-${Date.now()}`;
      
      // Add the widget to the grid
      this.setState({
        widgets: [...this.state.widgets, {
          id: widgetId,
          type: template.type,
          config: { ...template.config }
        }],
        isTemplateSelectorOpen: false
      });
    }
  }
  
  /**
   * Handle template selector toggle
   */
  private handleTemplateSelectorToggle(): void {
    this.setState({
      isTemplateSelectorOpen: !this.state.isTemplateSelectorOpen
    });
  }
  
  /**
   * Initialize data sources and bindings
   */
  private initializeDataSourcesAndBindings() {
    const { widgets } = this.state;
    
    widgets.forEach(widget => {
      if (widget.config.dataSource) {
        // Register data source
        this.dataSourceManager.registerDataSource(widget.config.dataSource);
        
        // Create data binding
        const bindingConfig: DataBindingConfig = {
          id: `binding-${widget.id}`,
          sourceId: widget.config.dataSource.id,
          targetId: widget.id,
          transform: widget.config.dataTransform,
          updateInterval: widget.config.updateInterval,
          updateOnChange: true,
          validationRules: widget.config.validationRules
        };
        
        this.dataBinding.createBinding(bindingConfig);
        
        // Add data source listener
        this.dataSourceManager.addListener(
          widget.config.dataSource.id,
          (data) => this.handleDataSourceUpdate(widget.config.dataSource.id, data)
        );
        
        // Add binding listener
        this.dataBinding.addListener(
          bindingConfig.id,
          (value) => this.handleBindingUpdate(widget.id, value)
        );
      }
    });
  }
  
  /**
   * Clean up data sources and bindings
   */
  private cleanupDataSourcesAndBindings() {
    const { widgets } = this.state;
    
    widgets.forEach(widget => {
      if (widget.config.dataSource) {
        // Clean up data source
        this.dataSourceManager.unregisterDataSource(widget.config.dataSource.id);
        
        // Clean up data binding
        this.dataBinding.removeBinding(`binding-${widget.id}`);
      }
    });
  }
  
  /**
   * Initialize default formats
   */
  private initializeDefaultFormats() {
    // Number formats
    this.dataTransformer.createNumberFormat('default-number', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    });
    
    this.dataTransformer.createNumberFormat('integer', {
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    });
    
    this.dataTransformer.createNumberFormat('decimal', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
    
    // Date formats
    this.dataTransformer.createDateFormat('default-date', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
    
    this.dataTransformer.createDateFormat('short-date', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric'
    });
    
    this.dataTransformer.createDateFormat('long-date', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      weekday: 'long'
    });
    
    // Currency formats
    this.dataTransformer.createCurrencyFormat('usd', 'USD', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
    
    this.dataTransformer.createCurrencyFormat('eur', 'EUR', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
    
    // Percentage formats
    this.dataTransformer.createPercentageFormat('default-percentage', {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1
    });
    
    this.dataTransformer.createPercentageFormat('decimal-percentage', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }
  
  /**
   * Initialize default validation rules
   */
  private initializeDefaultValidationRules() {
    // Required rule
    this.dataValidator.registerRule(
      this.dataValidator.createRequiredRule('required')
    );
    
    // Type rules
    this.dataValidator.registerRule(
      this.dataValidator.createTypeRule('string', 'string')
    );
    
    this.dataValidator.registerRule(
      this.dataValidator.createTypeRule('number', 'number')
    );
    
    this.dataValidator.registerRule(
      this.dataValidator.createTypeRule('boolean', 'boolean')
    );
    
    // Number rules
    this.dataValidator.registerRule(
      this.dataValidator.createNumberRule('number')
    );
    
    this.dataValidator.registerRule(
      this.dataValidator.createIntegerRule('integer')
    );
    
    // Range rules
    this.dataValidator.registerRule(
      this.dataValidator.createRangeRule('positive', 0, Infinity)
    );
    
    this.dataValidator.registerRule(
      this.dataValidator.createRangeRule('percentage', 0, 100)
    );
    
    // Pattern rules
    this.dataValidator.registerRule(
      this.dataValidator.createEmailRule('email')
    );
    
    this.dataValidator.registerRule(
      this.dataValidator.createUrlRule('url')
    );
    
    // Date rule
    this.dataValidator.registerRule(
      this.dataValidator.createDateRule('date')
    );
  }
  
  /**
   * Handle data source update
   */
  private handleDataSourceUpdate(sourceId: string, data: any) {
    // Find bindings for this source
    const bindings = Array.from(this.dataBinding['bindings'].values())
      .filter(binding => binding.sourceId === sourceId);
    
    // Update bindings
    bindings.forEach(binding => {
      const startTime = Date.now();
      
      try {
        // Log data source update
        this.dataLogger.info(
          'Updating data source',
          { data },
          binding.targetId,
          sourceId,
          'data_source_update'
        );
        
        // Track data source update
        this.dataMetrics.trackMetric({
          type: MetricType.DATA_SOURCE,
          name: 'response_time',
          value: Date.now() - startTime,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { data }
        });
        
        // Check cache first
        const cacheKey = `data-${binding.id}`;
        const cachedData = this.dataCache.get(cacheKey);
        
        if (cachedData) {
          // Log cache hit
          this.dataLogger.debug(
            'Cache hit',
            { cacheKey, cachedData },
            binding.targetId,
            sourceId,
            'cache_hit'
          );
          
          // Track cache hit
          this.dataMetrics.trackMetric({
            type: MetricType.CACHE,
            name: 'hit',
            value: 1,
            widgetId: binding.targetId,
            sourceId: sourceId,
            details: { cacheKey, cachedData }
          });
          
          // Use cached data
          this.dataBinding.updateValue(binding.id, cachedData);
          return;
        }
        
        // Log cache miss
        this.dataLogger.debug(
          'Cache miss',
          { cacheKey },
          binding.targetId,
          sourceId,
          'cache_miss'
        );
        
        // Track cache miss
        this.dataMetrics.trackMetric({
          type: MetricType.CACHE,
          name: 'miss',
          value: 1,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { cacheKey }
        });
        
        // Transform data if needed
        const transformStartTime = Date.now();
        const transformedData = binding.transform
          ? this.dataTransformer.transform(data, binding.transform)
          : data;
        
        // Track transformation time
        this.dataMetrics.trackMetric({
          type: MetricType.TRANSFORMATION,
          name: 'processing_time',
          value: Date.now() - transformStartTime,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { transform: binding.transform, data: transformedData }
        });
        
        // Log data transformation
        if (binding.transform) {
          this.dataLogger.debug(
            'Data transformation',
            { transform: binding.transform, data: transformedData },
            binding.targetId,
            sourceId,
            'data_transformation'
          );
        }
        
        // Validate data if rules are specified
        if (binding.validationRules && binding.validationRules.length > 0) {
          const validationStartTime = Date.now();
          const validationResult = this.dataValidator.validate(
            transformedData,
            binding.validationRules
          );
          
          // Track validation time
          this.dataMetrics.trackMetric({
            type: MetricType.VALIDATION,
            name: 'processing_time',
            value: Date.now() - validationStartTime,
            widgetId: binding.targetId,
            sourceId: sourceId,
            details: { rules: binding.validationRules, result: validationResult }
          });
          
          if (!validationResult.isValid) {
            // Track validation error
            this.dataMetrics.trackMetric({
              type: MetricType.ERROR,
              name: 'validation_error',
              value: 1,
              widgetId: binding.targetId,
              sourceId: sourceId,
              details: { errors: validationResult.errors }
            });
            
            // Log validation error
            this.dataLogger.error(
              'Data validation failed',
              { errors: validationResult.errors },
              binding.targetId,
              sourceId,
              'data_validation'
            );
            
            // Handle validation errors
            this.handleValidationError(binding.targetId, validationResult.errors);
            return;
          }
          
          // Track validation success
          this.dataMetrics.trackMetric({
            type: MetricType.VALIDATION,
            name: 'success',
            value: 1,
            widgetId: binding.targetId,
            sourceId: sourceId,
            details: { rules: binding.validationRules }
          });
          
          // Log validation success
          this.dataLogger.debug(
            'Data validation successful',
            { rules: binding.validationRules },
            binding.targetId,
            sourceId,
            'data_validation'
          );
        }
        
        // Cache transformed data
        this.dataCache.set(cacheKey, transformedData);
        
        // Log cache update
        this.dataLogger.debug(
          'Cache update',
          { cacheKey, data: transformedData },
          binding.targetId,
          sourceId,
          'cache_update'
        );
        
        // Update binding
        const bindingStartTime = Date.now();
        this.dataBinding.updateValue(binding.id, transformedData);
        
        // Track binding update time
        this.dataMetrics.trackMetric({
          type: MetricType.BINDING,
          name: 'update_time',
          value: Date.now() - bindingStartTime,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { bindingId: binding.id, value: transformedData }
        });
        
        // Log binding update
        this.dataLogger.debug(
          'Binding update',
          { bindingId: binding.id, value: transformedData },
          binding.targetId,
          sourceId,
          'binding_update'
        );
        
        // Handle data sync
        const syncStartTime = Date.now();
        this.dataSync.handleDataChange(binding.targetId);
        
        // Track sync time
        this.dataMetrics.trackMetric({
          type: MetricType.SYNC,
          name: 'sync_time',
          value: Date.now() - syncStartTime,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { widgetId: binding.targetId }
        });
        
        // Log data sync
        this.dataLogger.debug(
          'Data sync triggered',
          { widgetId: binding.targetId },
          binding.targetId,
          sourceId,
          'data_sync'
        );
      } catch (error) {
        // Track error
        this.dataMetrics.trackMetric({
          type: MetricType.ERROR,
          name: 'error',
          value: 1,
          widgetId: binding.targetId,
          sourceId: sourceId,
          details: { error }
        });
        
        // Log error
        this.dataLogger.error(
          'Error updating data source',
          { error },
          binding.targetId,
          sourceId,
          'data_source_update'
        );
        
        // Handle error
        this.handleDataError({
          type: ErrorType.DATA_SOURCE,
          severity: ErrorSeverity.HIGH,
          message: 'Error updating data source',
          details: error,
          widgetId: binding.targetId,
          sourceId: sourceId
        });
      }
    });
  }
  
  /**
   * Handle binding update
   */
  private handleBindingUpdate(widgetId: string, value: any) {
    const widget = this.state.widgets.find(w => w.id === widgetId);
    
    if (widget && widget.config.format) {
      // Format value if needed
      const formattedValue = this.dataTransformer.format(value, widget.config.format);
      
      // Update widget state with formatted value
      this.stateManager.updateWidgetState(widgetId, { data: formattedValue });
    } else {
      // Update widget state with raw value
      this.stateManager.updateWidgetState(widgetId, { data: value });
    }
  }
  
  /**
   * Handle add widget
   */
  private handleAddWidget(widgetType: string, config: any) {
    const newWidget = {
      id: `widget-${Date.now()}`,
      type: widgetType,
      config: {
        ...config,
        dataSource: config.dataSource ? {
          id: `datasource-${Date.now()}`,
          ...config.dataSource
        } : undefined,
        transform: config.transform,
        format: config.format,
        validationRules: config.validationRules,
        cacheConfig: config.cacheConfig,
        syncConfig: config.syncConfig,
        errorConfig: config.errorConfig,
        loggerConfig: config.loggerConfig,
        metricsConfig: config.metricsConfig
      }
    };
    
    // Log widget creation
    this.dataLogger.info(
      'Creating widget',
      { widgetType, config: newWidget.config },
      newWidget.id,
      undefined,
      'widget_creation'
    );
    
    // Track widget creation
    this.dataMetrics.trackMetric({
      type: MetricType.PERFORMANCE,
      name: 'widget_creation',
      value: 1,
      widgetId: newWidget.id,
      details: { widgetType, config: newWidget.config }
    });
    
    // Register error handler if configured
    if (newWidget.config.errorConfig) {
      this.dataError.registerHandler(newWidget.id, newWidget.config.errorConfig);
      
      // Log error handler registration
      this.dataLogger.debug(
        'Error handler registered',
        { config: newWidget.config.errorConfig },
        newWidget.id,
        undefined,
        'error_handler_registration'
      );
    }
    
    // Configure logger if specified
    if (newWidget.config.loggerConfig) {
      this.dataLogger.setConfig(newWidget.config.loggerConfig);
      
      // Log logger configuration
      this.dataLogger.debug(
        'Logger configured',
        { config: newWidget.config.loggerConfig },
        newWidget.id,
        undefined,
        'logger_configuration'
      );
    }
    
    // Configure metrics if specified
    if (newWidget.config.metricsConfig) {
      this.dataMetrics.setConfig(newWidget.config.metricsConfig);
      
      // Log metrics configuration
      this.dataLogger.debug(
        'Metrics configured',
        { config: newWidget.config.metricsConfig },
        newWidget.id,
        undefined,
        'metrics_configuration'
      );
    }
    
    // Register data source and binding if configured
    if (newWidget.config.dataSource) {
      try {
        // Register data source
        this.dataSourceManager.registerDataSource(newWidget.config.dataSource);
        
        // Log data source registration
        this.dataLogger.debug(
          'Data source registered',
          { source: newWidget.config.dataSource },
          newWidget.id,
          newWidget.config.dataSource.id,
          'data_source_registration'
        );
        
        // Track data source registration
        this.dataMetrics.trackMetric({
          type: MetricType.DATA_SOURCE,
          name: 'registration',
          value: 1,
          widgetId: newWidget.id,
          sourceId: newWidget.config.dataSource.id,
          details: { source: newWidget.config.dataSource }
        });
        
        // Create data binding
        const bindingConfig: DataBindingConfig = {
          id: `binding-${newWidget.id}`,
          sourceId: newWidget.config.dataSource.id,
          targetId: newWidget.id,
          transform: newWidget.config.transform,
          updateInterval: newWidget.config.updateInterval,
          updateOnChange: true,
          validationRules: newWidget.config.validationRules
        };
        
        this.dataBinding.createBinding(bindingConfig);
        
        // Log binding creation
        this.dataLogger.debug(
          'Data binding created',
          { binding: bindingConfig },
          newWidget.id,
          newWidget.config.dataSource.id,
          'binding_creation'
        );
        
        // Track binding creation
        this.dataMetrics.trackMetric({
          type: MetricType.BINDING,
          name: 'creation',
          value: 1,
          widgetId: newWidget.id,
          sourceId: newWidget.config.dataSource.id,
          details: { binding: bindingConfig }
        });
        
        // Add listeners
        this.dataSourceManager.addListener(
          newWidget.config.dataSource.id,
          (data) => this.handleDataSourceUpdate(newWidget.config.dataSource.id, data)
        );
        
        this.dataBinding.addListener(
          bindingConfig.id,
          (value) => this.handleBindingUpdate(newWidget.id, value)
        );
        
        // Log listener registration
        this.dataLogger.debug(
          'Listeners registered',
          { bindingId: bindingConfig.id },
          newWidget.id,
          newWidget.config.dataSource.id,
          'listener_registration'
        );
        
        // Track listener registration
        this.dataMetrics.trackMetric({
          type: MetricType.BINDING,
          name: 'listener_registration',
          value: 1,
          widgetId: newWidget.id,
          sourceId: newWidget.config.dataSource.id,
          details: { bindingId: bindingConfig.id }
        });
        
        // Configure cache if specified
        if (newWidget.config.cacheConfig) {
          this.dataCache.setConfig(newWidget.config.cacheConfig);
          
          // Log cache configuration
          this.dataLogger.debug(
            'Cache configured',
            { config: newWidget.config.cacheConfig },
            newWidget.id,
            newWidget.config.dataSource.id,
            'cache_configuration'
          );
          
          // Track cache configuration
          this.dataMetrics.trackMetric({
            type: MetricType.CACHE,
            name: 'configuration',
            value: 1,
            widgetId: newWidget.id,
            sourceId: newWidget.config.dataSource.id,
            details: { config: newWidget.config.cacheConfig }
          });
        }
        
        // Configure sync if specified
        if (newWidget.config.syncConfig) {
          const syncGroup: SyncGroup = {
            id: `sync-${newWidget.id}`,
            widgetIds: [newWidget.id],
            config: newWidget.config.syncConfig
          };
          
          this.dataSync.createGroup(syncGroup);
          
          // Log sync group creation
          this.dataLogger.debug(
            'Sync group created',
            { group: syncGroup },
            newWidget.id,
            newWidget.config.dataSource.id,
            'sync_group_creation'
          );
          
          // Track sync group creation
          this.dataMetrics.trackMetric({
            type: MetricType.SYNC,
            name: 'group_creation',
            value: 1,
            widgetId: newWidget.id,
            sourceId: newWidget.config.dataSource.id,
            details: { group: syncGroup }
          });
        }
      } catch (error) {
        // Track error
        this.dataMetrics.trackMetric({
          type: MetricType.ERROR,
          name: 'configuration_error',
          value: 1,
          widgetId: newWidget.id,
          details: { error }
        });
        
        // Log error
        this.dataLogger.error(
          'Error configuring widget data source',
          { error },
          newWidget.id,
          undefined,
          'widget_configuration'
        );
        
        // Handle error
        this.handleDataError({
          type: ErrorType.DATA_SOURCE,
          severity: ErrorSeverity.HIGH,
          message: 'Error configuring widget data source',
          details: error,
          widgetId: newWidget.id
        });
      }
    }
    
    // Add widget to state
    this.setState({
      widgets: [...this.state.widgets, newWidget]
    });
    
    // Log widget state update
    this.dataLogger.debug(
      'Widget state updated',
      { widget: newWidget },
      newWidget.id,
      undefined,
      'widget_state_update'
    );
    
    // Track widget state update
    this.dataMetrics.trackMetric({
      type: MetricType.PERFORMANCE,
      name: 'state_update',
      value: 1,
      widgetId: newWidget.id,
      details: { widget: newWidget }
    });
    
    // Handle widget mount
    this.dataSync.handleWidgetMount(newWidget.id);
    
    // Log widget mount
    this.dataLogger.debug(
      'Widget mounted',
      { widgetId: newWidget.id },
      newWidget.id,
      undefined,
      'widget_mount'
    );
    
    // Track widget mount
    this.dataMetrics.trackMetric({
      type: MetricType.PERFORMANCE,
      name: 'mount',
      value: 1,
      widgetId: newWidget.id,
      details: { widgetId: newWidget.id }
    });
  }
  
  /**
   * Handle remove widget
   */
  private handleRemoveWidget(widgetId: string) {
    const widget = this.state.widgets.find(w => w.id === widgetId);
    
    if (widget) {
      // Log widget removal
      this.dataLogger.info(
        'Removing widget',
        { widget },
        widgetId,
        undefined,
        'widget_removal'
      );
      
      // Track widget removal
      this.dataMetrics.trackMetric({
        type: MetricType.PERFORMANCE,
        name: 'removal',
        value: 1,
        widgetId: widgetId,
        details: { widget }
      });
      
      // Handle widget unmount
      this.dataSync.handleWidgetUnmount(widgetId);
      
      // Log widget unmount
      this.dataLogger.debug(
        'Widget unmounted',
        { widgetId },
        widgetId,
        undefined,
        'widget_unmount'
      );
      
      // Track widget unmount
      this.dataMetrics.trackMetric({
        type: MetricType.PERFORMANCE,
        name: 'unmount',
        value: 1,
        widgetId: widgetId,
        details: { widgetId }
      });
      
      // Unregister error handler
      this.dataError.unregisterHandler(widgetId);
      
      // Log error handler unregistration
      this.dataLogger.debug(
        'Error handler unregistered',
        { widgetId },
        widgetId,
        undefined,
        'error_handler_unregistration'
      );
      
      // Track error handler unregistration
      this.dataMetrics.trackMetric({
        type: MetricType.ERROR,
        name: 'handler_unregistration',
        value: 1,
        widgetId: widgetId,
        details: { widgetId }
      });
      
      if (widget.config.dataSource) {
        try {
          // Clean up data source
          this.dataSourceManager.unregisterDataSource(widget.config.dataSource.id);
          
          // Log data source cleanup
          this.dataLogger.debug(
            'Data source cleaned up',
            { sourceId: widget.config.dataSource.id },
            widgetId,
            widget.config.dataSource.id,
            'data_source_cleanup'
          );
          
          // Track data source cleanup
          this.dataMetrics.trackMetric({
            type: MetricType.DATA_SOURCE,
            name: 'cleanup',
            value: 1,
            widgetId: widgetId,
            sourceId: widget.config.dataSource.id,
            details: { sourceId: widget.config.dataSource.id }
          });
          
          // Clean up data binding
          this.dataBinding.removeBinding(`binding-${widgetId}`);
          
          // Log binding cleanup
          this.dataLogger.debug(
            'Data binding cleaned up',
            { bindingId: `binding-${widgetId}` },
            widgetId,
            widget.config.dataSource.id,
            'binding_cleanup'
          );
          
          // Track binding cleanup
          this.dataMetrics.trackMetric({
            type: MetricType.BINDING,
            name: 'cleanup',
            value: 1,
            widgetId: widgetId,
            sourceId: widget.config.dataSource.id,
            details: { bindingId: `binding-${widgetId}` }
          });
          
          // Clean up cache
          this.dataCache.delete(`data-binding-${widgetId}`);
          
          // Log cache cleanup
          this.dataLogger.debug(
            'Cache cleaned up',
            { cacheKey: `data-binding-${widgetId}` },
            widgetId,
            widget.config.dataSource.id,
            'cache_cleanup'
          );
          
          // Track cache cleanup
          this.dataMetrics.trackMetric({
            type: MetricType.CACHE,
            name: 'cleanup',
            value: 1,
            widgetId: widgetId,
            sourceId: widget.config.dataSource.id,
            details: { cacheKey: `data-binding-${widgetId}` }
          });
          
          // Clean up sync
          this.dataSync.removeGroup(`sync-${widgetId}`);
          
          // Log sync cleanup
          this.dataLogger.debug(
            'Sync group cleaned up',
            { groupId: `sync-${widgetId}` },
            widgetId,
            widget.config.dataSource.id,
            'sync_cleanup'
          );
          
          // Track sync cleanup
          this.dataMetrics.trackMetric({
            type: MetricType.SYNC,
            name: 'cleanup',
            value: 1,
            widgetId: widgetId,
            sourceId: widget.config.dataSource.id,
            details: { groupId: `sync-${widgetId}` }
          });
        } catch (error) {
          // Track error
          this.dataMetrics.trackMetric({
            type: MetricType.ERROR,
            name: 'cleanup_error',
            value: 1,
            widgetId: widgetId,
            sourceId: widget.config.dataSource.id,
            details: { error }
          });
          
          // Log error
          this.dataLogger.error(
            'Error cleaning up widget data source',
            { error },
            widgetId,
            widget.config.dataSource.id,
            'data_source_cleanup'
          );
          
          // Handle error
          this.handleDataError({
            type: ErrorType.DATA_SOURCE,
            severity: ErrorSeverity.MEDIUM,
            message: 'Error cleaning up widget data source',
            details: error,
            widgetId: widgetId
          });
        }
      }
    }
    
    // Remove widget from state
    this.setState({
      widgets: this.state.widgets.filter(w => w.id !== widgetId)
    });
    
    // Log state update
    this.dataLogger.debug(
      'Widget state updated',
      { widgetId },
      widgetId,
      undefined,
      'widget_state_update'
    );
    
    // Track state update
    this.dataMetrics.trackMetric({
      type: MetricType.PERFORMANCE,
      name: 'state_update',
      value: 1,
      widgetId: widgetId,
      details: { widgetId }
    });
  }
  
  /**
   * Handle validation error
   */
  private handleValidationError(widgetId: string, errors: string[]) {
    // Update widget state with validation errors
    this.stateManager.updateWidgetState(widgetId, {
      error: errors.join(', '),
      isValid: false
    });
  }
  
  private handleDataError(error: ErrorConfig): void {
    this.dataError.handleError(error);
  }
  
  /**
   * Render the dashboard
   */
  render(): ViewElement {
    const { title, description, layout, onRefresh, onSave, onReset } = this.props;
    const { theme, isEditMode, customizingWidgetId, customizingWidgetType, customizingWidgetConfig, showSettings, isTemplateSelectorOpen, templates } = this.state;
    const widgetIds = this.state.widgets.map(w => w.id);

    return View.box({
      style: {
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        backgroundColor: theme.colors.background,
        color: theme.colors.text,
        fontFamily: theme.typography.fontFamily
      },
      children: [
        View.component(DashboardToolbar, {
          title,
          description,
          theme,
          isEditMode,
          onRefresh,
          onSave,
          onReset,
          onEditModeToggle: this.toggleEditMode.bind(this),
          onSettingsClick: this.handleSettingsToggle.bind(this)
        }),
        View.box({
          style: {
            flex: 1,
            padding: theme.spacing.lg,
            overflow: 'auto'
          },
          children: [
            View.box({
              style: {
                display: 'grid',
                gridTemplateRows: `repeat(${layout.rows}, 1fr)`,
                gridTemplateColumns: `repeat(${layout.columns}, 1fr)`,
                gap: theme.spacing.md
              },
              children: widgetIds.map(id => 
                View.component(WidgetContainer, {
                  key: id,
                  ...this.state.widgets.find(w => w.id === id),
                  isEditable: isEditMode,
                  onDragStart: () => this.handleWidgetDragStart(id),
                  onDragEnd: this.handleWidgetDragEnd,
                  onDragMove: (position) => this.handleWidgetDragMove(id, position),
                  onResize: (size) => this.handleWidgetResize(id, size),
                  onRemove: () => this.handleWidgetRemove(id),
                  onCustomize: () => this.handleWidgetCustomize(id)
                })
              )
            })
          ]
        }),
        customizingWidgetId && customizingWidgetType && customizingWidgetConfig && View.box({
          style: {
            position: 'absolute',
            top: 0,
            right: 0,
            bottom: 0,
            width: '300px',
            backgroundColor: theme.colors.background,
            borderLeft: 'single',
            zIndex: 100
          },
          children: [
            View.component(WidgetCustomizationPanel, {
              theme,
              type: customizingWidgetType,
              config: customizingWidgetConfig,
              onConfigChange: this.handleWidgetConfigChange.bind(this),
              onSave: this.handleWidgetCustomizationSave.bind(this),
              onCancel: this.handleWidgetCustomizeCancel.bind(this)
            })
          ]
        }),
        isTemplateSelectorOpen && View.box({
          style: {
            position: 'absolute',
            top: 0,
            right: 0,
            bottom: 0,
            width: '300px',
            backgroundColor: theme.colors.background,
            borderLeft: 'single',
            zIndex: 100
          },
          children: [
            View.component(WidgetTemplateSelector, {
              theme,
              templates,
              onTemplateSelect: this.handleTemplateSelect.bind(this),
              onCancel: this.handleTemplateSelectorToggle.bind(this)
            })
          ]
        }),
        View.component(ThemeSelector, {
          themeManager: this.themeManager,
          showPreview: true,
          showDescription: true
        }),
        showSettings && View.box({
          style: {
            position: 'absolute',
            top: 0,
            right: 0,
            bottom: 0,
            width: '300px',
            backgroundColor: theme.colors.background,
            borderLeft: 'single',
            zIndex: 100
          },
          children: [
            View.component(DashboardSettings, {
              theme,
              layout,
              onLayoutChange: this.handleLayoutChange.bind(this),
              onSave: this.handleSettingsSave.bind(this),
              onCancel: this.handleSettingsCancel.bind(this)
            })
          ]
        })
      ]
    });
  }
} 