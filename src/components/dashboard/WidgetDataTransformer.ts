/**
 * WidgetDataTransformer.ts
 * 
 * Handles data transformation and formatting for widgets.
 */

/**
 * Data transformation configuration
 */
export interface DataTransformConfig {
  /**
   * Transform ID
   */
  id: string;
  
  /**
   * Transform type
   */
  type: 'map' | 'filter' | 'reduce' | 'format' | 'custom';
  
  /**
   * Transform function
   */
  transform: (data: any) => any;
  
  /**
   * Transform options
   */
  options?: Record<string, any>;
}

/**
 * Data format configuration
 */
export interface DataFormatConfig {
  /**
   * Format ID
   */
  id: string;
  
  /**
   * Format type
   */
  type: 'number' | 'date' | 'currency' | 'percentage' | 'custom';
  
  /**
   * Format options
   */
  options: {
    /**
     * Locale for formatting
     */
    locale?: string;
    
    /**
     * Number format options
     */
    numberFormat?: Intl.NumberFormatOptions;
    
    /**
     * Date format options
     */
    dateFormat?: Intl.DateTimeFormatOptions;
    
    /**
     * Currency format options
     */
    currencyFormat?: Intl.NumberFormatOptions;
    
    /**
     * Custom format function
     */
    format?: (value: any) => string;
  };
}

/**
 * Widget data transformer
 */
export class WidgetDataTransformer {
  /**
   * Transformations
   */
  private transformations: Map<string, DataTransformConfig>;
  
  /**
   * Formats
   */
  private formats: Map<string, DataFormatConfig>;
  
  /**
   * Constructor
   */
  constructor() {
    this.transformations = new Map();
    this.formats = new Map();
  }
  
  /**
   * Register a transformation
   */
  registerTransform(config: DataTransformConfig): void {
    this.transformations.set(config.id, config);
  }
  
  /**
   * Unregister a transformation
   */
  unregisterTransform(id: string): void {
    this.transformations.delete(id);
  }
  
  /**
   * Register a format
   */
  registerFormat(config: DataFormatConfig): void {
    this.formats.set(config.id, config);
  }
  
  /**
   * Unregister a format
   */
  unregisterFormat(id: string): void {
    this.formats.delete(id);
  }
  
  /**
   * Transform data
   */
  transform(data: any, transformId: string): any {
    const transform = this.transformations.get(transformId);
    
    if (transform) {
      return transform.transform(data);
    }
    
    return data;
  }
  
  /**
   * Format data
   */
  format(data: any, formatId: string): string {
    const format = this.formats.get(formatId);
    
    if (format) {
      const { type, options } = format;
      
      switch (type) {
        case 'number':
          return new Intl.NumberFormat(
            options.locale,
            options.numberFormat
          ).format(data);
        
        case 'date':
          return new Intl.DateTimeFormat(
            options.locale,
            options.dateFormat
          ).format(new Date(data));
        
        case 'currency':
          return new Intl.NumberFormat(
            options.locale,
            {
              style: 'currency',
              ...options.currencyFormat
            }
          ).format(data);
        
        case 'percentage':
          return new Intl.NumberFormat(
            options.locale,
            {
              style: 'percent',
              ...options.numberFormat
            }
          ).format(data);
        
        case 'custom':
          return options.format ? options.format(data) : String(data);
        
        default:
          return String(data);
      }
    }
    
    return String(data);
  }
  
  /**
   * Create a number format
   */
  createNumberFormat(
    id: string,
    options: Intl.NumberFormatOptions & { locale?: string } = {}
  ): void {
    this.registerFormat({
      id,
      type: 'number',
      options: {
        locale: options.locale,
        numberFormat: options
      }
    });
  }
  
  /**
   * Create a date format
   */
  createDateFormat(
    id: string,
    options: Intl.DateTimeFormatOptions & { locale?: string } = {}
  ): void {
    this.registerFormat({
      id,
      type: 'date',
      options: {
        locale: options.locale,
        dateFormat: options
      }
    });
  }
  
  /**
   * Create a currency format
   */
  createCurrencyFormat(
    id: string,
    currency: string,
    options: Intl.NumberFormatOptions & { locale?: string } = {}
  ): void {
    this.registerFormat({
      id,
      type: 'currency',
      options: {
        locale: options.locale,
        currencyFormat: {
          style: 'currency',
          currency,
          ...options
        }
      }
    });
  }
  
  /**
   * Create a percentage format
   */
  createPercentageFormat(
    id: string,
    options: Intl.NumberFormatOptions & { locale?: string } = {}
  ): void {
    this.registerFormat({
      id,
      type: 'percentage',
      options: {
        locale: options.locale,
        numberFormat: {
          style: 'percent',
          ...options
        }
      }
    });
  }
  
  /**
   * Create a custom format
   */
  createCustomFormat(
    id: string,
    format: (value: any) => string
  ): void {
    this.registerFormat({
      id,
      type: 'custom',
      options: {
        format
      }
    });
  }
} 