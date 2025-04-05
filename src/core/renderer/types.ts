/**
 * types.ts
 * 
 * Type definitions for the View system.
 */

// Custom property types for ViewStyle
export type CustomStyleProperty = string | number | boolean | null | undefined;
export type CustomStyleProperties = {
  [key: `--${string}`]: CustomStyleProperty;
};
export type ComplexStyleProperty = FlexProperties | GridProperties | TransitionValue | TransitionValue[] | BoxShadowValue | BoxShadowValue[] | string | string[];

// Props type for ViewElement
export type ViewElementProps = {
  [key: string]: string | number | boolean | null | undefined | ViewElement | ViewElement[];
};

// Custom event types for ViewEvents
export type CustomEventType = string;
export type CustomEventHandler = (event: CustomEvent) => void;

// Re-export existing types
export type BorderStyle = 'none' | 'single' | 'double' | 'rounded' | 'bold' | 'dashed' | '1px solid #ddd' | '1px solid #ccc';
export type DisplayType = 'block' | 'inline' | 'flex' | 'grid' | 'inline-block' | 'table' | 'none';
export type PositionType = 'static' | 'relative' | 'absolute' | 'fixed' | 'sticky';
export type Spacing = number | string;
export type FlexDirection = 'row' | 'column';
export type JustifyContent = 'start' | 'center' | 'end' | 'space-between' | 'space-around';
export type AlignItems = 'start' | 'center' | 'end' | 'stretch';

// Component types
export type ComponentType = 
  | 'box' 
  | 'text' 
  | 'button' 
  | 'select' 
  | 'slider' 
  | 'image' 
  | 'flex' 
  | 'grid'
  | 'list'
  | 'table'
  | 'form'
  | 'modal'
  | 'ol'
  | 'ul'
  | 'tr'
  | 'th'
  | 'td'
  | 'div'
  | 'label'
  | 'textarea'
  | 'input'
  | 'h3';

// Style interfaces
export interface FlexProperties {
  direction?: FlexDirection;
  justify?: JustifyContent;
  align?: AlignItems;
  wrap?: boolean;
  grow?: number;
  shrink?: number;
  basis?: string | number;
}

export interface GridProperties {
  columns?: number | string;
  rows?: number | string;
  gap?: number | string;
  areas?: string[][];
  columnGap?: number | string;
  rowGap?: number | string;
}

// Additional style type definitions
export type ColorValue = string;
export type SizeValue = number | string;
export type BorderRadiusValue = number | string | {
  topLeft?: number | string;
  topRight?: number | string;
  bottomRight?: number | string;
  bottomLeft?: number | string;
};
export type BoxShadowValue = string | {
  offsetX?: number;
  offsetY?: number;
  blurRadius?: number;
  spreadRadius?: number;
  color?: string;
  inset?: boolean;
};
export type TransformValue = string | {
  translate?: { x?: number | string; y?: number | string; z?: number | string };
  rotate?: { x?: number | string; y?: number | string; z?: number | string };
  scale?: { x?: number | string; y?: number | string; z?: number | string };
  skew?: { x?: number | string; y?: number | string };
};
export type TransitionValue = string | {
  property?: string;
  duration?: number | string;
  timingFunction?: string;
  delay?: number | string;
};

// Event handling types
export interface ViewEvents {
  // Mouse events
  onClick?: (event: MouseEvent) => void;
  onMouseDown?: (event: MouseEvent) => void;
  onMouseUp?: (event: MouseEvent) => void;
  onMouseMove?: (event: MouseEvent) => void;
  onMouseEnter?: (event: MouseEvent) => void;
  onMouseLeave?: (event: MouseEvent) => void;
  onMouseOver?: (event: MouseEvent) => void;
  onMouseOut?: (event: MouseEvent) => void;
  onDoubleClick?: (event: MouseEvent) => void;
  onContextMenu?: (event: MouseEvent) => void;
  onWheel?: (event: WheelEvent) => void;
  
  // Keyboard events
  onKeyDown?: (event: KeyboardEvent) => void;
  onKeyUp?: (event: KeyboardEvent) => void;
  onKeyPress?: (event: KeyboardEvent) => void;
  
  // Focus events
  onFocus?: (event: FocusEvent) => void;
  onBlur?: (event: FocusEvent) => void;
  
  // Form events
  onChange?: (event: Event) => void;
  onInput?: (event: Event) => void;
  onSubmit?: (event: Event) => void;
  onReset?: (event: Event) => void;
  onInvalid?: (event: Event) => void;
  
  // Drag and drop events
  onDrag?: (event: DragEvent) => void;
  onDragStart?: (event: DragEvent) => void;
  onDragEnd?: (event: DragEvent) => void;
  onDragEnter?: (event: DragEvent) => void;
  onDragLeave?: (event: DragEvent) => void;
  onDragOver?: (event: DragEvent) => void;
  onDrop?: (event: DragEvent) => void;
  
  // Touch events
  onTouchStart?: (event: TouchEvent) => void;
  onTouchMove?: (event: TouchEvent) => void;
  onTouchEnd?: (event: TouchEvent) => void;
  onTouchCancel?: (event: TouchEvent) => void;
  
  // Animation events
  onAnimationStart?: (event: AnimationEvent) => void;
  onAnimationEnd?: (event: AnimationEvent) => void;
  onAnimationIteration?: (event: AnimationEvent) => void;
  
  // Transition events
  onTransitionStart?: (event: TransitionEvent) => void;
  onTransitionEnd?: (event: TransitionEvent) => void;
  
  // Scroll events
  onScroll?: (event: Event) => void;
  
  // Custom events
  onCustomEvent?: (event: CustomEvent) => void;
}

// Style interface
export interface ViewStyle {
  // Layout properties
  width?: SizeValue;
  height?: SizeValue;
  minWidth?: SizeValue;
  minHeight?: SizeValue;
  maxWidth?: SizeValue;
  maxHeight?: SizeValue;
  
  // Box model
  border?: BorderStyle;
  borderWidth?: number | string | {
    top?: number | string;
    right?: number | string;
    bottom?: number | string;
    left?: number | string;
  };
  borderColor?: ColorValue | {
    top?: ColorValue;
    right?: ColorValue;
    bottom?: ColorValue;
    left?: ColorValue;
  };
  borderStyle?: 'solid' | 'dashed' | 'dotted' | 'none' | {
    top?: 'solid' | 'dashed' | 'dotted' | 'none';
    right?: 'solid' | 'dashed' | 'dotted' | 'none';
    bottom?: 'solid' | 'dashed' | 'dotted' | 'none';
    left?: 'solid' | 'dashed' | 'dotted' | 'none';
  };
  borderRadius?: BorderRadiusValue;
  backgroundColor?: ColorValue;
  color?: ColorValue;
  
  // Spacing
  padding?: Spacing | {
    top?: Spacing;
    right?: Spacing;
    bottom?: Spacing;
    left?: Spacing;
  };
  margin?: Spacing | {
    top?: Spacing;
    right?: Spacing;
    bottom?: Spacing;
    left?: Spacing;
  };
  
  // Positioning
  display?: DisplayType;
  position?: PositionType;
  top?: SizeValue;
  right?: SizeValue;
  bottom?: SizeValue;
  left?: SizeValue;
  zIndex?: number;
  
  // Layout systems
  flex?: FlexProperties;
  grid?: GridProperties;
  
  // Visual properties
  opacity?: number;
  overflow?: 'visible' | 'hidden' | 'scroll' | 'auto';
  cursor?: string;
  transition?: TransitionValue | TransitionValue[];
  transform?: TransformValue;
  boxShadow?: BoxShadowValue | BoxShadowValue[];
  
  // Typography
  fontSize?: SizeValue;
  fontFamily?: string | string[];
  fontWeight?: number | string;
  lineHeight?: number | string;
  textAlign?: 'left' | 'center' | 'right' | 'justify';
  textDecoration?: 'none' | 'underline' | 'line-through';
  letterSpacing?: number | string;
  textTransform?: 'none' | 'capitalize' | 'uppercase' | 'lowercase';
  whiteSpace?: 'normal' | 'nowrap' | 'pre' | 'pre-line' | 'pre-wrap';
  wordBreak?: 'normal' | 'break-all' | 'keep-all' | 'break-word';
  
  // Accessibility
  ariaLabel?: string;
  ariaHidden?: boolean;
  role?: string;
  
  // Animation
  animation?: {
    name?: string;
    duration?: number | string;
    timingFunction?: string;
    delay?: number | string;
    iterationCount?: number | string;
    direction?: 'normal' | 'reverse' | 'alternate' | 'alternate-reverse';
    fillMode?: 'none' | 'forwards' | 'backwards' | 'both';
  };
  
  // Print styles
  pageBreakBefore?: 'auto' | 'always' | 'avoid' | 'left' | 'right';
  pageBreakAfter?: 'auto' | 'always' | 'avoid' | 'left' | 'right';
  pageBreakInside?: 'auto' | 'avoid';
  
  // Custom properties
  [key: string]: CustomStyleProperty | CustomStyleProperties | ComplexStyleProperty | undefined;
}

// View element interface
export interface ViewElement {
  type: ComponentType;
  style: ViewStyle;
  children?: ViewElement[];
  content?: string;
  events?: ViewEvents;
  className?: string;
  props?: ViewElementProps;
  key?: string | number;
  ref?: (element: HTMLElement) => void;
  data?: Record<string, any>;
  state?: Record<string, any>;
  lifecycle?: {
    onMount?: () => void;
    onUnmount?: () => void;
    onUpdate?: (prevProps: Record<string, any>, nextProps: Record<string, any>) => void;
  };
  // Additional properties for enhanced functionality
  id?: string;
  tabIndex?: number;
  ariaLabel?: string;
  ariaHidden?: boolean;
  role?: string;
  disabled?: boolean;
  hidden?: boolean;
  focusable?: boolean;
  draggable?: boolean;
  animation?: {
    name?: string;
    duration?: number | string;
    timingFunction?: string;
    delay?: number | string;
    iterationCount?: number | string;
    direction?: 'normal' | 'reverse' | 'alternate' | 'alternate-reverse';
    fillMode?: 'none' | 'forwards' | 'backwards' | 'both';
  };
}

// View options interface
export interface ViewOptions {
  style?: ViewStyle;
  children?: ViewElement[];
  content?: string | ViewElement;
  events?: ViewEvents;
  className?: string;
  border?: BorderStyle;
  props?: ViewElementProps;
}

// Component options interfaces
export interface ButtonOptions extends ViewOptions {
  disabled?: boolean;
  type?: 'button' | 'submit' | 'reset';
  value?: string;
}

export interface TableOptions extends ViewOptions {
  headers: string[];
  rows: string[][];
}

export interface SelectOptions extends ViewOptions {
  options: Array<{ value: string; label: string }>;
  value?: string;
  multiple?: boolean;
  disabled?: boolean;
}

export interface SliderOptions extends ViewOptions {
  min?: number;
  max?: number;
  step?: number;
  value?: number;
  disabled?: boolean;
}

export interface ImageOptions extends ViewOptions {
  src: string;
  alt?: string;
  width?: number | string;
  height?: number | string;
  objectFit?: 'contain' | 'cover' | 'fill' | 'none' | 'scale-down';
}

export interface FormOptions extends ViewOptions {
  fields: Array<{
    type: 'text' | 'number' | 'email' | 'password' | 'checkbox' | 'radio' | 'select' | 'textarea';
    name: string;
    label: string;
    placeholder?: string;
    required?: boolean;
    options?: Array<{ value: string; label: string }>;
  }>;
  submitLabel?: string;
  onSubmit?: (data: Record<string, any>) => void;
}

export interface ModalOptions extends Omit<ViewOptions, 'content'> {
  title?: string;
  isOpen?: boolean;
  onClose?: () => void;
  size?: 'small' | 'medium' | 'large';
  content?: ViewElement;
}

export interface TabsOptions extends ViewOptions {
  tabs: Array<{
    id: string;
    label: string;
    content: ViewElement;
  }>;
  activeTab?: string;
  onChange?: (tabId: string) => void;
  orientation?: 'horizontal' | 'vertical';
  variant?: 'default' | 'pills' | 'underline';
}

export interface AccordionOptions extends ViewOptions {
  sections: Array<{
    id: string;
    title: string;
    content: ViewElement;
  }>;
  activeSection?: string | string[];
  onChange?: (sectionId: string | string[]) => void;
  allowMultiple?: boolean;
  variant?: 'default' | 'bordered';
}

export interface InfiniteScrollOptions extends ViewOptions {
  items: ViewElement[];
  itemHeight: number;
  containerHeight: number;
  overscan?: number;
  onScroll?: (scrollTop: number) => void;
  onLoadMore?: () => void;
  loadingThreshold?: number;
  loadingIndicator?: ViewElement;
}

export interface LazyLoadOptions extends ViewOptions {
  src: string;
  placeholder?: ViewElement;
  threshold?: number;
  onLoad?: () => void;
  onError?: (error: Error | unknown) => void;
}

export interface DragAndDropOptions extends ViewOptions {
  items: ViewElement[];
  onDragStart?: (item: ViewElement, index: number) => void;
  onDragOver?: (item: ViewElement, index: number) => void;
  onDrop?: (item: ViewElement, sourceIndex: number, targetIndex: number) => void;
  onDragEnd?: (item: ViewElement, index: number) => void;
  draggableItemStyle?: ViewStyle;
  dropTargetStyle?: ViewStyle;
}

// View component type
export interface ViewComponent<T extends Partial<ViewOptions> = Partial<ViewOptions>> {
  (options: T): ViewElement;
  compose?: (children: ViewElement[]) => ViewElement;
  withStyle?: (style: ViewStyle) => ViewComponent<T>;
  withEvents?: (events: ViewEvents) => ViewComponent<T>;
  withProps?: (props: ViewElementProps) => ViewComponent<T>;
  // Enhanced composition methods
  withClassName?: (className: string) => ViewComponent<T>;
  withContent?: (content: string) => ViewComponent<T>;
  withKey?: (key: string | number) => ViewComponent<T>;
  withRef?: (ref: (element: HTMLElement) => void) => ViewComponent<T>;
  withData?: (data: Record<string, any>) => ViewComponent<T>;
  withState?: (state: Record<string, any>) => ViewComponent<T>;
  withLifecycle?: (lifecycle: {
    onMount?: () => void;
    onUnmount?: () => void;
    onUpdate?: (prevProps: Record<string, any>, nextProps: Record<string, any>) => void;
  }) => ViewComponent<T>;
  withAccessibility?: (accessibility: {
    ariaLabel?: string;
    ariaHidden?: boolean;
    role?: string;
    tabIndex?: number;
  }) => ViewComponent<T>;
  withAnimation?: (animation: {
    name?: string;
    duration?: number | string;
    timingFunction?: string;
    delay?: number | string;
    iterationCount?: number | string;
    direction?: 'normal' | 'reverse' | 'alternate' | 'alternate-reverse';
    fillMode?: 'none' | 'forwards' | 'backwards' | 'both';
  }) => ViewComponent<T>;
  withDisabled?: (disabled: boolean) => ViewComponent<T>;
  withHidden?: (hidden: boolean) => ViewComponent<T>;
  withFocusable?: (focusable: boolean) => ViewComponent<T>;
  withDraggable?: (draggable: boolean) => ViewComponent<T>;
  // Higher-order component pattern
  withHOC?: <P extends Partial<ViewOptions>>(
    hoc: (component: ViewComponent<T>) => ViewComponent<P>
  ) => ViewComponent<P>;
}

// View update type
export type ViewUpdate = () => void; 