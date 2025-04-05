/**
 * View.ts
 * 
 * Core view system for rendering UI elements.
 * Provides box model layout, text rendering, and basic styling.
 */

import { ViewPerformance } from '../performance/ViewPerformance';
import { UpdateBatcher } from './UpdateBatcher';
import {
  BorderStyle,
  DisplayType,
  PositionType,
  Spacing,
  FlexDirection,
  JustifyContent,
  AlignItems,
  ComponentType,
  CustomStyleProperty,
  CustomStyleProperties,
  ComplexStyleProperty,
  FlexProperties,
  GridProperties,
  ColorValue,
  SizeValue,
  BorderRadiusValue,
  BoxShadowValue,
  TransformValue,
  TransitionValue,
  ViewEvents,
  ViewStyle,
  ViewElement,
  ViewOptions,
  ButtonOptions,
  SelectOptions,
  SliderOptions,
  ImageOptions,
  FormOptions,
  ModalOptions,
  TabsOptions,
  AccordionOptions,
  InfiniteScrollOptions,
  LazyLoadOptions,
  DragAndDropOptions,
  TableOptions,
  ViewComponent,
  ViewUpdate
} from './types';

export class View {
  private static performance = ViewPerformance.getInstance();
  private static updateQueue: ViewUpdate[] = [];
  private static isProcessingUpdates = false;
  private static renderCallbacks: Array<() => void> = [];
  private static renderTimeout: number | null = null;
  private static updateBatcher = new UpdateBatcher();

  /**
   * Creates a box view element
   */
  static box(options: ViewOptions = {}): ViewElement {
    const { style = {}, children = [], content, events, className, border, props } = options;
    return {
      type: 'box',
      style: { ...style, border: border || style.border },
      children,
      content: typeof content === 'string' ? content : undefined,
      events,
      className,
      props
    };
  }

  /**
   * Creates a text view element
   */
  static text(content: string, options: ViewOptions = {}): ViewElement {
    const { style = {}, events, className, props } = options;
    return {
      type: 'text',
      style,
      content,
      events,
      className,
      props
    };
  }

  /**
   * Creates a button view element
   */
  static button(options: ButtonOptions = {}): ViewElement {
    const { style = {}, children = [], content, events, className, border, props, disabled, type, value } = options;
    return {
      type: 'button',
      style: { ...style, border: border || style.border },
      children,
      content: typeof content === 'string' ? content : undefined,
      events,
      className,
      props: { ...props, disabled, type, value }
    };
  }

  /**
   * Creates a select view element
   */
  static select(options: SelectOptions): ViewElement {
    const { style = {}, events, className, props, options: selectOptions, value, multiple, disabled } = options;
    const optionElements: ViewElement[] = selectOptions?.map(opt => ({
      type: 'div',
      style: {},
      content: opt.label,
      props: { value: opt.value }
    })) || [];

    return {
      type: 'select',
      style,
      events,
      className,
      children: optionElements,
      props: { 
        ...props, 
        value, 
        multiple, 
        disabled 
      }
    };
  }

  /**
   * Creates a slider view element
   */
  static slider(options: SliderOptions = {}): ViewElement {
    const { style = {}, events, className, props, min, max, step, value, disabled } = options;
    return {
      type: 'slider',
      style,
      events,
      className,
      props: { ...props, min, max, step, value, disabled }
    };
  }

  /**
   * Creates an image view element
   */
  static image(options: ImageOptions): ViewElement {
    const { style = {}, events, className, props, src, alt, width, height, objectFit } = options;
    return {
      type: 'image',
      style: { ...style, width, height },
      events,
      className,
      props: { ...props, src, alt, objectFit }
    };
  }

  /**
   * Creates a flex container view
   */
  static flex(options: ViewOptions & {
    direction?: FlexDirection;
    justify?: JustifyContent;
    align?: AlignItems;
    wrap?: boolean;
  } = {}): ViewElement {
    const { style = {}, children = [], content, events, className, border, props, direction, justify, align, wrap } = options;
    
    // Create a properly typed flex property
    const flexProperties: FlexProperties = {
      direction: direction || style.flex?.direction,
      justify: justify || style.flex?.justify,
      align: align || style.flex?.align,
      wrap: wrap !== undefined ? wrap : style.flex?.wrap
    };
    
    return {
      type: 'flex' as ComponentType,
      style: {
        ...style,
        border: border || style.border,
        display: 'flex' as DisplayType,
        flex: flexProperties
      },
      children,
      content: typeof content === 'string' ? content : undefined,
      events,
      className,
      props
    };
  }

  /**
   * Creates a grid container view
   */
  static grid(options: ViewOptions & {
    columns?: number | string;
    rows?: number | string;
    gap?: number | string;
    areas?: string[][];
  } = {}): ViewElement {
    const { style = {}, children = [], content, events, className, border, props, columns, rows, gap, areas } = options;
    
    // Create a properly typed grid property
    const gridProperties: GridProperties = {
      columns: columns || style.grid?.columns,
      rows: rows || style.grid?.rows,
      gap: gap || style.grid?.gap,
      areas: areas || style.grid?.areas
    };
    
    return {
      type: 'grid' as ComponentType,
      style: {
        ...style,
        border: border || style.border,
        display: 'grid' as DisplayType,
        grid: gridProperties
      },
      children,
      content: typeof content === 'string' ? content : undefined,
      events,
      className,
      props
    };
  }

  /**
   * Creates a list component for rendering lists of items
   */
  static list(options: ViewOptions & {
    items?: ViewElement[];
    ordered?: boolean;
    compact?: boolean;
  } = {}): ViewElement {
    const { style = {}, children = [], content, events, className, border, props, items, ordered, compact } = options;
    return {
      type: ordered ? 'ol' : 'ul',
      style: {
        ...style,
        border: border || style.border,
        padding: compact ? '0.5em' : style.padding,
        margin: compact ? '0.5em 0' : style.margin
      },
      children: items || children,
      content: typeof content === 'string' ? content : undefined,
      events,
      className,
      props
    };
  }
  
  /**
   * Creates a table component for rendering tabular data
   */
  static table(options: TableOptions): ViewElement {
    const { style = {}, events, className, props, headers, rows } = options;
    return {
      type: 'table' as ComponentType,
      style,
      children: [
        {
          type: 'tr' as ComponentType,
          style: { borderBottom: '1px solid #ddd' },
          children: headers.map(header => ({
            type: 'th' as ComponentType,
            content: header,
            style: { fontWeight: 'bold' }
          }))
        },
        ...rows.map(row => ({
          type: 'tr' as ComponentType,
          style: { borderBottom: '1px solid #ddd' },
          children: row.map(cell => ({
            type: 'td' as ComponentType,
            content: cell,
            style: {}
          }))
        }))
      ],
      events,
      className,
      props
    };
  }
  
  /**
   * Creates a form component for collecting user input
   */
  static form(options: FormOptions): ViewElement {
    const { style = {}, events, className, props, fields, submitLabel = 'Submit', onSubmit } = options;
    const formChildren: ViewElement[] = fields.map(field => ({
      type: 'div',
      style: { marginBottom: '1em' },
      children: [
        {
          type: 'label',
          content: field.label,
          style: { display: 'block', marginBottom: '0.5em' }
        },
        {
          type: field.type === 'textarea' ? 'textarea' : 'input',
          style: {
            width: '100%',
            padding: '0.5em',
            border: '1px solid #ddd',
            borderRadius: '4px'
          },
          props: {
            type: field.type,
            name: field.name,
            placeholder: field.placeholder,
            required: field.required,
            ...(field.type === 'select' && field.options ? {
              children: field.options.map(opt => ({
                type: 'div',
                style: {
                  padding: '0.5em',
                  cursor: 'pointer'
                },
                content: opt.label,
                props: { value: opt.value }
              }))
            } : {})
          }
        }
      ]
    }));

    formChildren.push({
      type: 'button',
      content: submitLabel,
      style: {
        backgroundColor: '#007bff',
        color: 'white',
        padding: '0.5em 1em',
        border: 'none',
        borderRadius: '4px',
        cursor: 'pointer'
      },
      events: {
        onClick: (e) => {
          e.preventDefault();
          const formData = new FormData(e.target as HTMLFormElement);
          const data: Record<string, any> = {};
          formData.forEach((value, key) => {
            data[key] = value;
          });
          onSubmit?.(data);
        }
      }
    });

    return {
      type: 'form',
      style,
      children: formChildren,
      events: {
        ...events,
        onSubmit: (e) => {
          e.preventDefault();
          const formData = new FormData(e.target as HTMLFormElement);
          const data: Record<string, any> = {};
          formData.forEach((value, key) => {
            data[key] = value;
          });
          onSubmit?.(data);
        }
      },
      className,
      props
    };
  }
  
  /**
   * Creates a modal component for displaying content in a dialog
   */
  static modal(options: ModalOptions): ViewElement {
    const { style = {}, children = [], content, events, className, props, title, isOpen = false, onClose, size = 'medium' } = options;
    const sizeStyles = {
      small: { width: '300px', maxWidth: '90%' },
      medium: { width: '500px', maxWidth: '90%' },
      large: { width: '800px', maxWidth: '90%' }
    };

    return {
      type: 'div' as ComponentType,
      style: {
        ...style,
        display: isOpen ? 'flex' as DisplayType : 'none' as DisplayType,
        position: 'fixed' as PositionType,
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        justifyContent: 'center' as JustifyContent,
        alignItems: 'center' as AlignItems,
        zIndex: 1000
      },
      children: [
        {
          type: 'div' as ComponentType,
          style: {
            backgroundColor: 'white',
            padding: '1em',
            borderRadius: '4px',
            boxShadow: '0 2px 10px rgba(0, 0, 0, 0.1)',
            ...sizeStyles[size]
          },
          children: [
            title ? {
              type: 'h3' as ComponentType,
              content: title,
              style: { marginTop: 0, marginBottom: '1em' }
            } : null,
            {
              type: 'div' as ComponentType,
              style: { marginBottom: '1em' },
              children: children.length > 0 ? children : [content].filter(Boolean) as ViewElement[]
            },
            {
              type: 'button' as ComponentType,
              content: 'Close',
              style: {
                position: 'absolute' as PositionType,
                top: '1em',
                right: '1em',
                background: 'none',
                border: 'none' as BorderStyle,
                cursor: 'pointer',
                fontSize: '1.2em'
              },
              events: {
                onClick: onClose
              }
            }
          ].filter(Boolean) as ViewElement[]
        }
      ],
      events,
      className,
      props
    };
  }

  /**
   * Creates a virtualized list component for efficiently rendering large lists
   */
  static virtualList(options: ViewOptions & {
    items: ViewElement[];
    itemHeight: number;
    containerHeight: number;
    overscan?: number;
    onScroll?: (scrollTop: number) => void;
  }): ViewElement {
    const { style = {}, items, itemHeight, containerHeight, overscan = 3, onScroll } = options;
    const totalHeight = items.length * itemHeight;
    const visibleItems = Math.ceil(containerHeight / itemHeight);
    const startIndex = Math.max(0, Math.floor(window.scrollY / itemHeight) - overscan);
    const endIndex = Math.min(items.length, startIndex + visibleItems + overscan * 2);
    const visibleItemsElements = items.slice(startIndex, endIndex).map((item, index) => ({
      ...item,
      style: {
        ...item.style,
        position: 'absolute' as PositionType,
        top: `${(startIndex + index) * itemHeight}px`,
        height: `${itemHeight}px`,
        width: '100%'
      }
    }));

    return {
      type: 'div' as ComponentType,
      style: {
        ...style,
        position: 'relative' as PositionType,
        height: `${containerHeight}px`,
        overflow: 'auto' as const
      },
      children: [
        {
          type: 'div' as ComponentType,
          style: {
            position: 'absolute' as PositionType,
            top: 0,
            left: 0,
            right: 0,
            height: `${totalHeight}px`
          }
        },
        ...visibleItemsElements
      ],
      events: {
        onScroll: (e) => {
          const scrollTop = (e.target as HTMLElement).scrollTop;
          onScroll?.(scrollTop);
        }
      }
    };
  }
  
  /**
   * Creates a virtualized grid component for efficiently rendering large grids
   */
  static virtualGrid(options: ViewOptions & {
    items: ViewElement[];
    columnCount: number;
    itemWidth: number;
    itemHeight: number;
    containerWidth: number;
    containerHeight: number;
    overscan?: number;
    onScroll?: (scrollTop: number, scrollLeft: number) => void;
  }): ViewElement {
    const { style = {}, items, columnCount, itemWidth, itemHeight, containerWidth, containerHeight, overscan = 3, onScroll } = options;
    const rowCount = Math.ceil(items.length / columnCount);
    const totalWidth = columnCount * itemWidth;
    const totalHeight = rowCount * itemHeight;
    const visibleColumns = Math.ceil(containerWidth / itemWidth);
    const visibleRows = Math.ceil(containerHeight / itemHeight);
    const startCol = Math.max(0, Math.floor(window.scrollX / itemWidth) - overscan);
    const startRow = Math.max(0, Math.floor(window.scrollY / itemHeight) - overscan);
    const endCol = Math.min(columnCount, startCol + visibleColumns + overscan * 2);
    const endRow = Math.min(rowCount, startRow + visibleRows + overscan * 2);

    const visibleItemsElements = items
      .slice(startRow * columnCount + startCol, endRow * columnCount + endCol)
      .map((item, index) => {
        const row = Math.floor((startRow * columnCount + startCol + index) / columnCount);
        const col = (startRow * columnCount + startCol + index) % columnCount;
        return {
          ...item,
          style: {
            ...item.style,
            position: 'absolute' as PositionType,
            top: `${row * itemHeight}px`,
            left: `${col * itemWidth}px`,
            width: `${itemWidth}px`,
            height: `${itemHeight}px`
          }
        };
      });

    return {
      type: 'div' as ComponentType,
      style: {
        ...style,
        position: 'relative' as PositionType,
        width: `${containerWidth}px`,
        height: `${containerHeight}px`,
        overflow: 'auto' as const
      },
      children: [
        {
          type: 'div' as ComponentType,
          style: {
            position: 'absolute' as PositionType,
            top: 0,
            left: 0,
            width: `${totalWidth}px`,
            height: `${totalHeight}px`
          }
        },
        ...visibleItemsElements
      ],
      events: {
        onScroll: (e) => {
          const { scrollTop, scrollLeft } = e.target as HTMLElement;
          onScroll?.(scrollTop, scrollLeft);
        }
      }
    };
  }

  /**
   * Creates a responsive component that adapts to different screen sizes
   */
  static responsive(options: ViewOptions & {
    breakpoints?: {
      xs?: number;
      sm?: number;
      md?: number;
      lg?: number;
      xl?: number;
    };
    xs?: ViewElement;
    sm?: ViewElement;
    md?: ViewElement;
    lg?: ViewElement;
    xl?: ViewElement;
    default?: ViewElement;
  }): ViewElement {
    const { style = {}, breakpoints = {}, xs, sm, md, lg, xl, default: defaultElement } = options;
    const defaultBreakpoints = {
      xs: 0,
      sm: 576,
      md: 768,
      lg: 992,
      xl: 1200
    };
    const finalBreakpoints = { ...defaultBreakpoints, ...breakpoints };

    return {
      type: 'div' as ComponentType,
      style: {
        ...style,
        position: 'relative' as PositionType
      },
      children: [
        xs && {
          type: 'div' as ComponentType,
          style: {
            display: 'block',
            [`@media (min-width: ${finalBreakpoints.sm}px)`]: {
              display: 'none'
            }
          },
          children: [xs]
        },
        sm && {
          type: 'div' as ComponentType,
          style: {
            display: 'none',
            [`@media (min-width: ${finalBreakpoints.sm}px) and (max-width: ${finalBreakpoints.md - 1}px)`]: {
              display: 'block'
            }
          },
          children: [sm]
        },
        md && {
          type: 'div' as ComponentType,
          style: {
            display: 'none',
            [`@media (min-width: ${finalBreakpoints.md}px) and (max-width: ${finalBreakpoints.lg - 1}px)`]: {
              display: 'block'
            }
          },
          children: [md]
        },
        lg && {
          type: 'div' as ComponentType,
          style: {
            display: 'none',
            [`@media (min-width: ${finalBreakpoints.lg}px) and (max-width: ${finalBreakpoints.xl - 1}px)`]: {
              display: 'block'
            }
          },
          children: [lg]
        },
        xl && {
          type: 'div' as ComponentType,
          style: {
            display: 'none',
            [`@media (min-width: ${finalBreakpoints.xl}px)`]: {
              display: 'block'
            }
          },
          children: [xl]
        },
        defaultElement && {
          type: 'div' as ComponentType,
          style: {
            display: 'none',
            [`@media (min-width: ${finalBreakpoints.xl}px)`]: {
              display: 'block'
            }
          },
          children: [defaultElement]
        }
      ].filter(Boolean) as ViewElement[]
    };
  }
  
  /**
   * Applies a media query to an element
   */
  static mediaQuery(options: { query: string; style: ViewStyle }): ViewElement {
    const { query, style } = options;
    return {
      type: 'div',
      style: {
        ...style,
        '@media': {
          [query]: style
        }
      }
    };
  }

  /**
   * Creates a component with composition helpers
   */
  static createComponent<T extends Partial<ViewOptions>>(
    type: ComponentType,
    defaultOptions: T = {} as T
  ): ViewComponent<T> {
    const component = (options: T): ViewElement => {
      const { style = {}, children = [], content, events, className, border, props } = { ...defaultOptions, ...options };
      return {
        type,
        style: { ...style, border: border || style.border },
        children,
        content: typeof content === 'string' ? content : undefined,
        events,
        className,
        props
      };
    };

    component.compose = (children: ViewElement[]): ViewElement => {
      return component({ children } as T);
    };

    component.withStyle = (style: ViewStyle): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, style } as T);
    };

    component.withEvents = (events: ViewEvents): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, events } as T);
    };

    component.withProps = (props: Record<string, any>): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, props } as T);
    };

    component.withClassName = (className: string): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, className } as T);
    };

    component.withContent = (content: string): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, content } as T);
    };

    component.withKey = (key: string | number): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, key } as T);
    };

    component.withRef = (ref: (element: HTMLElement) => void): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, ref } as T);
    };

    component.withData = (data: Record<string, any>): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, data } as T);
    };

    component.withState = (state: Record<string, any>): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, state } as T);
    };

    component.withLifecycle = (lifecycle: {
      onMount?: () => void;
      onUnmount?: () => void;
      onUpdate?: (prevProps: Record<string, any>, nextProps: Record<string, any>) => void;
    }): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, lifecycle } as T);
    };

    component.withAccessibility = (accessibility: {
      ariaLabel?: string;
      ariaHidden?: boolean;
      role?: string;
      tabIndex?: number;
    }): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, ...accessibility } as T);
    };

    component.withAnimation = (animation: {
      name?: string;
      duration?: number | string;
      timingFunction?: string;
      delay?: number | string;
      iterationCount?: number | string;
      direction?: 'normal' | 'reverse' | 'alternate' | 'alternate-reverse';
      fillMode?: 'none' | 'forwards' | 'backwards' | 'both';
    }): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, animation } as T);
    };

    component.withDisabled = (disabled: boolean): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, disabled } as T);
    };

    component.withHidden = (hidden: boolean): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, hidden } as T);
    };

    component.withFocusable = (focusable: boolean): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, focusable } as T);
    };

    component.withDraggable = (draggable: boolean): ViewComponent<T> => {
      return View.createComponent(type, { ...defaultOptions, draggable } as T);
    };

    component.withHOC = <P extends Partial<ViewOptions>>(
      hoc: (component: ViewComponent<T>) => ViewComponent<P>
    ): ViewComponent<P> => {
      return hoc(component);
    };

    return component;
  }

  /**
   * Get performance metrics
   */
  static getPerformanceMetrics() {
    return View.performance.getMetrics();
  }

  /**
   * Get component metrics
   */
  static getComponentMetrics(type: string) {
    return View.performance.getComponentMetrics(type);
  }

  /**
   * Get all component metrics
   */
  static getAllComponentMetrics() {
    return View.performance.getAllComponentMetrics();
  }

  /**
   * Optimizes rendering of elements based on performance metrics
   * This method analyzes the elements and applies optimizations to improve rendering performance
   */
  static optimizeRendering(elements: ViewElement[]): ViewElement[] {
    return elements.map(element => {
      if (element.children) {
        element.children = View.optimizeRendering(element.children);
      }
      return element;
    });
  }

  static tabs(options: TabsOptions): ViewElement {
    const { style = {}, tabs, activeTab, onChange, orientation = 'horizontal', variant = 'default' } = options;
    const tabList: ViewElement[] = tabs.map(tab => ({
      type: 'button',
      content: tab.label,
      style: {
        padding: '0.5em 1em',
        border: 'none',
        backgroundColor: tab.id === activeTab ? '#007bff' : 'transparent',
        color: tab.id === activeTab ? 'white' : 'inherit',
        cursor: 'pointer',
        ...(variant === 'pills' && {
          borderRadius: '1em',
          margin: '0 0.25em'
        }),
        ...(variant === 'underline' && {
          borderBottom: tab.id === activeTab ? '2px solid #007bff' : 'none'
        })
      },
      events: {
        onClick: () => onChange?.(tab.id)
      }
    }));

    const activeTabContent = tabs.find(tab => tab.id === activeTab)?.content;

    return {
      type: 'div',
      style: {
        ...style,
        display: 'flex',
        flexDirection: orientation === 'vertical' ? 'row' : 'column'
      },
      children: [
        {
          type: 'div',
          style: {
            display: 'flex',
            flexDirection: orientation === 'vertical' ? 'column' : 'row',
            borderBottom: variant === 'default' ? '1px solid #ddd' : 'none'
          },
          children: tabList
        },
        activeTabContent && {
          type: 'div',
          style: {
            padding: '1em',
            flex: 1
          },
          children: [activeTabContent]
        }
      ].filter(Boolean) as ViewElement[]
    };
  }

  static accordion(options: AccordionOptions): ViewElement {
    const { style = {}, sections, activeSection, onChange, allowMultiple = false, variant = 'default' } = options;
    const activeSections = Array.isArray(activeSection) 
      ? activeSection 
      : activeSection ? [activeSection] : [];

    const sectionElements: ViewElement[] = sections.map(section => {
      const isActive = activeSections.includes(section.id);
      return {
        type: 'div' as ComponentType,
        style: {
          border: variant === 'bordered' ? '1px solid #ddd' as BorderStyle : 'none' as BorderStyle,
          marginBottom: '0.5em',
          borderRadius: '4px',
          overflow: 'hidden' as const
        },
        children: [
          {
            type: 'button' as ComponentType,
            content: section.title,
            style: {
              width: '100%',
              padding: '1em',
              border: 'none' as BorderStyle,
              backgroundColor: isActive ? '#f8f9fa' : 'white',
              cursor: 'pointer',
              textAlign: 'left' as const,
              display: 'flex' as DisplayType,
              justifyContent: 'space-between' as JustifyContent,
              alignItems: 'center' as AlignItems
            },
            events: {
              onClick: () => {
                if (allowMultiple) {
                  const newActiveSections = isActive
                    ? activeSections.filter(id => id !== section.id)
                    : [...activeSections, section.id];
                  onChange?.(newActiveSections);
                } else {
                  onChange?.(isActive ? [] : [section.id]);
                }
              }
            }
          },
          {
            type: 'div' as ComponentType,
            style: {
              padding: '1em',
              display: isActive ? 'block' as DisplayType : 'none' as DisplayType,
              borderTop: variant === 'bordered' ? '1px solid #ddd' as BorderStyle : 'none' as BorderStyle
            },
            children: [section.content]
          }
        ]
      };
    });

    return {
      type: 'div' as ComponentType,
      style,
      children: sectionElements
    };
  }

  static infiniteScroll(options: InfiniteScrollOptions): ViewElement {
    const { style = {}, children = [], content, events, className, props, items, itemHeight, containerHeight, overscan = 3, onScroll, onLoadMore, loadingThreshold = 100, loadingIndicator } = options;
    const totalHeight = items.length * itemHeight;
    const visibleItems = Math.ceil(containerHeight / itemHeight);
    const startIndex = Math.max(0, Math.floor(window.scrollY / itemHeight) - overscan);
    const endIndex = Math.min(items.length, startIndex + visibleItems + overscan * 2);
    
    const visibleItemsElements = items.slice(startIndex, endIndex).map((item, index) => ({
      type: 'div' as ComponentType,
      style: {
        position: 'absolute' as PositionType,
        top: `${(startIndex + index) * itemHeight}px`,
        height: `${itemHeight}px`,
        width: '100%'
      },
      children: [item]
    }));

    const containerStyle: ViewStyle = {
      ...style,
      position: 'relative' as PositionType,
      height: `${containerHeight}px`,
      width: '100%',
      overflow: 'auto' as const
    };

    const contentStyle: ViewStyle = {
      position: 'absolute' as PositionType,
      top: 0,
      left: 0,
      right: 0,
      height: `${totalHeight}px`
    };

    const loadingStyle: ViewStyle = {
      position: 'absolute' as PositionType,
      top: `${totalHeight}px`,
      left: 0,
      right: 0,
      padding: '1em',
      textAlign: 'center' as const
    };

    const contentElement = {
      type: 'div' as ComponentType,
      style: contentStyle
    };

    const loadingElement = loadingIndicator ? {
      type: 'div' as ComponentType,
      style: loadingStyle,
      children: [loadingIndicator]
    } : undefined;

    return {
      type: 'div' as ComponentType,
      style: containerStyle,
      children: [
        contentElement,
        ...visibleItemsElements,
        ...(loadingElement ? [loadingElement] : [])
      ],
      events: {
        ...events,
        onScroll: (e: Event) => {
          const target = e.target as HTMLElement;
          const scrollTop = target.scrollTop;
          onScroll?.(scrollTop);
          if (target.scrollHeight - scrollTop - target.clientHeight < loadingThreshold) {
            onLoadMore?.();
          }
        }
      },
      className,
      props
    };
  }

  static lazyLoad(options: LazyLoadOptions): ViewElement {
    const { style = {}, src, placeholder, threshold = 0.1, onLoad, onError } = options;
    
    return {
      type: 'div' as ComponentType,
      style,
      children: [
        {
          type: 'div' as ComponentType,
          style: { 
            width: '100%', 
            height: 'auto',
            backgroundImage: `url(${src})`,
            backgroundSize: 'cover',
            backgroundPosition: 'center'
          },
          events: {
            onCustomEvent: (e: CustomEvent) => {
              if (e.type === 'load') {
                onLoad?.();
              } else if (e.type === 'error') {
                onError?.(e.detail as Error);
              }
            }
          }
        }
      ]
    };
  }

  static dragAndDrop(options: DragAndDropOptions): ViewElement {
    const { style = {}, items, onDragStart, onDragOver, onDrop, onDragEnd, draggableItemStyle, dropTargetStyle } = options;
    
    return {
      type: 'div' as ComponentType,
      style,
      children: items.map((item, index) => ({
        type: 'div' as ComponentType,
        style: {
          ...(draggableItemStyle || {}),
          cursor: 'move',
          padding: '0.5em',
          margin: '0.25em 0',
          backgroundColor: 'white',
          border: '1px solid #ddd' as BorderStyle,
          borderRadius: '4px'
        },
        props: {
          draggable: true
        },
        events: {
          onDragStart: (e: DragEvent) => {
            if (e.dataTransfer) {
              e.dataTransfer.setData('text/plain', index.toString());
            }
            onDragStart?.(item, index);
          },
          onDragOver: (e: DragEvent) => {
            e.preventDefault();
            onDragOver?.(item, index);
          },
          onDrop: (e: DragEvent) => {
            e.preventDefault();
            const sourceIndex = parseInt(e.dataTransfer?.getData('text/plain') || '0', 10);
            onDrop?.(item, sourceIndex, index);
          },
          onDragEnd: () => onDragEnd?.(item, index)
        },
        children: [item]
      }))
    };
  }

  static batchUpdates(updates: ViewUpdate[]): void {
    View.updateQueue.push(...updates);
    if (!View.isProcessingUpdates) {
      View.processUpdateQueue();
    }
  }

  private static processUpdateQueue(): void {
    if (View.updateQueue.length === 0) {
      View.isProcessingUpdates = false;
      return;
    }

    View.isProcessingUpdates = true;
    const update = View.updateQueue.shift();
    if (update) {
      update();
      requestAnimationFrame(() => View.processUpdateQueue());
    }
  }

  static debounceRender(callback: () => void, delay: number = 16): void {
    if (View.renderTimeout) {
      clearTimeout(View.renderTimeout);
    }
    View.renderTimeout = window.setTimeout(() => {
      callback();
      View.renderTimeout = null;
    }, delay);
  }
} 