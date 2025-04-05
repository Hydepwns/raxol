/**
 * WidgetDataValidator.ts
 * 
 * Handles data validation for widgets.
 */

/**
 * Validation rule configuration
 */
export interface ValidationRule {
  /**
   * Rule ID
   */
  id: string;
  
  /**
   * Rule type
   */
  type: 'required' | 'type' | 'range' | 'pattern' | 'custom';
  
  /**
   * Rule function
   */
  validate: (value: any) => boolean;
  
  /**
   * Error message
   */
  message: string;
  
  /**
   * Rule options
   */
  options?: Record<string, any>;
}

/**
 * Validation result
 */
export interface ValidationResult {
  /**
   * Whether the value is valid
   */
  isValid: boolean;
  
  /**
   * Validation errors
   */
  errors: string[];
}

/**
 * Widget data validator
 */
export class WidgetDataValidator {
  /**
   * Validation rules
   */
  private rules: Map<string, ValidationRule>;
  
  /**
   * Constructor
   */
  constructor() {
    this.rules = new Map();
  }
  
  /**
   * Register a validation rule
   */
  registerRule(rule: ValidationRule): void {
    this.rules.set(rule.id, rule);
  }
  
  /**
   * Unregister a validation rule
   */
  unregisterRule(id: string): void {
    this.rules.delete(id);
  }
  
  /**
   * Validate a value against rules
   */
  validate(value: any, ruleIds: string[]): ValidationResult {
    const errors: string[] = [];
    
    ruleIds.forEach(id => {
      const rule = this.rules.get(id);
      
      if (rule && !rule.validate(value)) {
        errors.push(rule.message);
      }
    });
    
    return {
      isValid: errors.length === 0,
      errors
    };
  }
  
  /**
   * Create a required rule
   */
  createRequiredRule(id: string, message: string = 'Value is required'): ValidationRule {
    return {
      id,
      type: 'required',
      validate: (value: any) => value !== null && value !== undefined && value !== '',
      message
    };
  }
  
  /**
   * Create a type rule
   */
  createTypeRule(id: string, type: string, message: string = `Value must be of type ${type}`): ValidationRule {
    return {
      id,
      type: 'type',
      validate: (value: any) => typeof value === type,
      message
    };
  }
  
  /**
   * Create a range rule
   */
  createRangeRule(
    id: string,
    min: number,
    max: number,
    message: string = `Value must be between ${min} and ${max}`
  ): ValidationRule {
    return {
      id,
      type: 'range',
      validate: (value: any) => {
        const num = Number(value);
        return !isNaN(num) && num >= min && num <= max;
      },
      message
    };
  }
  
  /**
   * Create a pattern rule
   */
  createPatternRule(
    id: string,
    pattern: RegExp,
    message: string = 'Value does not match the required pattern'
  ): ValidationRule {
    return {
      id,
      type: 'pattern',
      validate: (value: any) => pattern.test(String(value)),
      message
    };
  }
  
  /**
   * Create a custom rule
   */
  createCustomRule(
    id: string,
    validate: (value: any) => boolean,
    message: string
  ): ValidationRule {
    return {
      id,
      type: 'custom',
      validate,
      message
    };
  }
  
  /**
   * Create a number rule
   */
  createNumberRule(
    id: string,
    message: string = 'Value must be a number'
  ): ValidationRule {
    return {
      id,
      type: 'type',
      validate: (value: any) => !isNaN(Number(value)),
      message
    };
  }
  
  /**
   * Create an integer rule
   */
  createIntegerRule(
    id: string,
    message: string = 'Value must be an integer'
  ): ValidationRule {
    return {
      id,
      type: 'type',
      validate: (value: any) => Number.isInteger(Number(value)),
      message
    };
  }
  
  /**
   * Create a date rule
   */
  createDateRule(
    id: string,
    message: string = 'Value must be a valid date'
  ): ValidationRule {
    return {
      id,
      type: 'type',
      validate: (value: any) => !isNaN(Date.parse(value)),
      message
    };
  }
  
  /**
   * Create an email rule
   */
  createEmailRule(
    id: string,
    message: string = 'Value must be a valid email address'
  ): ValidationRule {
    return {
      id,
      type: 'pattern',
      validate: (value: any) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value)),
      message
    };
  }
  
  /**
   * Create a URL rule
   */
  createUrlRule(
    id: string,
    message: string = 'Value must be a valid URL'
  ): ValidationRule {
    return {
      id,
      type: 'pattern',
      validate: (value: any) => {
        try {
          new URL(String(value));
          return true;
        } catch {
          return false;
        }
      },
      message
    };
  }
} 