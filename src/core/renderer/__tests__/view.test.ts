/**
 * view.test.ts
 * 
 * Tests for the enhanced View system.
 */

import { 
  View, 
  ViewElement, 
  ViewStyle, 
  ViewEvents, 
  ViewComponent,
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
  DragAndDropOptions
} from '../view';
import { ViewPerformance } from '../../performance/ViewPerformance';

// Mock ViewPerformance
jest.mock('../../performance/ViewPerformance', () => {
  return {
    ViewPerformance: {
      getInstance: jest.fn().mockReturnValue({
        recordComponentCreate: jest.fn(),
        recordComponentRender: jest.fn(),
        recordComponentUpdate: jest.fn(),
        recordComponentOperation: jest.fn(),
        getMetrics: jest.fn().mockReturnValue({
          memory: {
            usedJSHeapSize: 1000000,
            totalJSHeapSize: 2000000,
            jsHeapSizeLimit: 5000000
          },
          timing: {
            navigationStart: 0,
            fetchStart: 10,
            domainLookupStart: 20,
            domainLookupEnd: 30,
            connectStart: 40,
            connectEnd: 50,
            requestStart: 60,
            responseStart: 70,
            responseEnd: 80,
            domLoading: 90,
            domInteractive: 100,
            domContentLoadedEventStart: 110,
            domContentLoadedEventEnd: 120,
            domComplete: 130,
            loadEventStart: 140,
            loadEventEnd: 150
          },
          rendering: {
            componentCreateTime: 5,
            renderTime: 10,
            updateTime: 2,
            layoutTime: 3,
            paintTime: 4
          }
        }),
        getComponentMetrics: jest.fn().mockReturnValue({
          type: 'box',
          createTime: 1,
          renderTime: 2,
          updateCount: 3,
          childCount: 4,
          memoryUsage: 5
        }),
        getAllComponentMetrics: jest.fn().mockReturnValue([
          {
            type: 'box',
            createTime: 1,
            renderTime: 2,
            updateCount: 3,
            childCount: 4,
            memoryUsage: 5
          },
          {
            type: 'text',
            createTime: 0.5,
            renderTime: 1,
            updateCount: 2,
            childCount: 0,
            memoryUsage: 2
          }
        ])
      })
    }
  };
});

// Mock performance API
global.performance = {
  now: jest.fn().mockReturnValue(1000)
} as any;

describe('View System', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Basic Components', () => {
    it('should create a box element', () => {
      const box = View.box({
        style: { width: 100, height: 100 },
        className: 'test-box'
      });

      expect(box.type).toBe('box');
      expect(box.style.width).toBe(100);
      expect(box.style.height).toBe(100);
      expect(box.className).toBe('test-box');
    });

    it('should create a text element', () => {
      const text = View.text('Hello World', {
        style: { color: 'red' },
        className: 'test-text'
      });

      expect(text.type).toBe('text');
      expect(text.content).toBe('Hello World');
      expect(text.style.color).toBe('red');
      expect(text.className).toBe('test-text');
    });

    it('should create a button element', () => {
      const button = View.button({
        value: 'Click Me',
        disabled: true,
        style: { backgroundColor: 'blue' },
        className: 'test-button'
      });

      expect(button.type).toBe('button');
      expect(button.content).toBe('Click Me');
      expect(button.style.backgroundColor).toBe('blue');
      expect(button.style.cursor).toBe('not-allowed');
      expect(button.style.opacity).toBe(0.5);
      expect(button.className).toBe('test-button');
      expect(button.props?.disabled).toBe(true);
    });

    it('should create a select element', () => {
      const options = [
        { value: '1', label: 'Option 1' },
        { value: '2', label: 'Option 2' }
      ];
      
      const select = View.select({
        options,
        value: '1',
        multiple: true,
        disabled: true,
        style: { width: 200 },
        className: 'test-select'
      });

      expect(select.type).toBe('select');
      expect(select.style.width).toBe(200);
      expect(select.style.cursor).toBe('not-allowed');
      expect(select.className).toBe('test-select');
      expect(select.props?.value).toBe('1');
      expect(select.props?.multiple).toBe(true);
      expect(select.props?.disabled).toBe(true);
      expect(select.children?.length).toBe(2);
    });

    it('should create a slider element', () => {
      const slider = View.slider({
        min: 0,
        max: 100,
        step: 5,
        value: 50,
        disabled: true,
        style: { width: 200 },
        className: 'test-slider'
      });

      expect(slider.type).toBe('slider');
      expect(slider.style.width).toBe(200);
      expect(slider.style.cursor).toBe('not-allowed');
      expect(slider.className).toBe('test-slider');
      expect(slider.props?.min).toBe(0);
      expect(slider.props?.max).toBe(100);
      expect(slider.props?.step).toBe(5);
      expect(slider.props?.value).toBe(50);
      expect(slider.props?.disabled).toBe(true);
    });

    it('should create an image element', () => {
      const image = View.image({
        src: 'test.jpg',
        alt: 'Test Image',
        width: 200,
        height: 150,
        objectFit: 'cover',
        style: { borderRadius: 5 },
        className: 'test-image'
      });

      expect(image.type).toBe('image');
      expect(image.style.width).toBe(200);
      expect(image.style.height).toBe(150);
      expect(image.style.objectFit).toBe('cover');
      expect(image.style.borderRadius).toBe(5);
      expect(image.className).toBe('test-image');
      expect(image.props?.src).toBe('test.jpg');
      expect(image.props?.alt).toBe('Test Image');
    });
  });

  describe('Layout Components', () => {
    it('should create a flex container', () => {
      const flex = View.flex({
        direction: 'column',
        justify: 'center',
        align: 'center',
        wrap: true,
        style: { width: 300, height: 200 },
        className: 'test-flex'
      });

      expect(flex.type).toBe('box');
      expect(flex.style.display).toBe('flex');
      expect(flex.style.flexDirection).toBe('column');
      expect(flex.style.justifyContent).toBe('center');
      expect(flex.style.alignItems).toBe('center');
      expect(flex.style.flexWrap).toBe('wrap');
      expect(flex.style.width).toBe(300);
      expect(flex.style.height).toBe(200);
      expect(flex.className).toBe('test-flex');
    });

    it('should create a grid container', () => {
      const grid = View.grid({
        columns: 3,
        rows: 2,
        gap: 10,
        areas: [['header', 'header', 'header'], ['sidebar', 'main', 'sidebar']],
        style: { width: 600, height: 400 },
        className: 'test-grid'
      });

      expect(grid.type).toBe('box');
      expect(grid.style.display).toBe('grid');
      expect(grid.style.gridTemplateColumns).toBe(3);
      expect(grid.style.gridTemplateRows).toBe(2);
      expect(grid.style.gap).toBe(10);
      expect(grid.style.width).toBe(600);
      expect(grid.style.height).toBe(400);
      expect(grid.className).toBe('test-grid');
    });
  });

  describe('Component Composition', () => {
    it('should create a component with composition helpers', () => {
      const button = View.createComponent<ButtonOptions>('button', {
        style: { backgroundColor: 'blue', color: 'white' },
        className: 'base-button'
      }) as ViewComponent<ButtonOptions> & {
        withStyle: (style: Partial<ViewStyle>) => ViewComponent<ButtonOptions>;
        withProps: (props: Partial<ButtonOptions>) => ViewComponent<ButtonOptions>;
        withAccessibility: (accessibility: { ariaLabel: string; role: string; tabIndex: number }) => ViewComponent<ButtonOptions>;
      };

      const primaryButton = button.withStyle({ backgroundColor: 'green' }) as ViewComponent<ButtonOptions> & {
        withProps: (props: Partial<ButtonOptions>) => ViewComponent<ButtonOptions>;
        withAccessibility: (accessibility: { ariaLabel: string; role: string; tabIndex: number }) => ViewComponent<ButtonOptions>;
      };

      const disabledButton = primaryButton.withProps({ disabled: true }) as ViewComponent<ButtonOptions> & {
        withProps: (props: Partial<ButtonOptions>) => ViewComponent<ButtonOptions>;
        withAccessibility: (accessibility: { ariaLabel: string; role: string; tabIndex: number }) => ViewComponent<ButtonOptions>;
      };

      const submitButton = disabledButton.withProps({ type: 'submit' }) as ViewComponent<ButtonOptions> & {
        withAccessibility: (accessibility: { ariaLabel: string; role: string; tabIndex: number }) => ViewComponent<ButtonOptions>;
      };

      const accessibleButton = submitButton.withAccessibility({ 
        ariaLabel: 'Submit Form',
        role: 'button',
        tabIndex: 0
      });

      const element = accessibleButton({ value: 'Submit' });

      expect(element.type).toBe('button');
      expect(element.style.backgroundColor).toBe('green');
      expect(element.style.color).toBe('white');
      expect(element.className).toBe('base-button');
      expect(element.props?.disabled).toBe(true);
      expect(element.props?.type).toBe('submit');
      expect(element.content).toBe('Submit');
      expect(element.ariaLabel).toBe('Submit Form');
      expect(element.role).toBe('button');
      expect(element.tabIndex).toBe(0);
    });

    it('should compose components with children', () => {
      const container = View.createComponent('box', {
        style: { padding: 10 },
        className: 'container'
      }) as ViewComponent<{}> & {
        compose: (children: ViewElement[]) => ViewElement;
      };

      const child1 = View.text('Child 1');
      const child2 = View.text('Child 2');

      const element = container.compose([child1, child2]);

      expect(element.type).toBe('box');
      expect(element.style.padding).toBe(10);
      expect(element.className).toBe('container');
      expect(element.children?.length).toBe(2);
      expect(element.children?.[0].type).toBe('text');
      expect(element.children?.[0].content).toBe('Child 1');
      expect(element.children?.[1].type).toBe('text');
      expect(element.children?.[1].content).toBe('Child 2');
    });

    it('should create a higher-order component', () => {
      const button = View.createComponent<ButtonOptions>('button') as ViewComponent<ButtonOptions> & {
        withHOC: (hoc: (component: ViewComponent<ButtonOptions>) => ViewComponent<ButtonOptions>) => ViewComponent<ButtonOptions>;
      };

      // Create a HOC that adds a loading state
      const withLoading = (component: ViewComponent<ButtonOptions>) => {
        return (options: ButtonOptions) => {
          const element = component(options);
          return {
            ...element,
            props: {
              ...element.props,
              loading: true
            },
            content: 'Loading...'
          };
        };
      };

      const loadingButton = button.withHOC(withLoading);
      const element = loadingButton({ value: 'Click Me' });

      expect(element.type).toBe('button');
      expect(element.content).toBe('Loading...');
      expect(element.props?.loading).toBe(true);
    });
  });

  describe('Enhanced ViewElement Properties', () => {
    it('should support animation properties', () => {
      const element = View.box({
        style: {
          animation: {
            name: 'fadeIn',
            duration: '0.5s',
            timingFunction: 'ease-in-out',
            delay: '0.2s',
            iterationCount: '1',
            direction: 'normal',
            fillMode: 'forwards'
          }
        }
      });

      expect(element.style.animation).toBeDefined();
      expect(element.style.animation?.name).toBe('fadeIn');
      expect(element.style.animation?.duration).toBe('0.5s');
      expect(element.style.animation?.timingFunction).toBe('ease-in-out');
      expect(element.style.animation?.delay).toBe('0.2s');
      expect(element.style.animation?.iterationCount).toBe('1');
      expect(element.style.animation?.direction).toBe('normal');
      expect(element.style.animation?.fillMode).toBe('forwards');
    });

    it('should support accessibility properties', () => {
      const element = View.box({
        style: {},
        props: {
          accessibility: {
            ariaLabel: 'Test Box',
            ariaHidden: true,
            role: 'region',
            tabIndex: 0
          }
        }
      });

      expect(element.ariaLabel).toBe('Test Box');
      expect(element.ariaHidden).toBe(true);
      expect(element.role).toBe('region');
      expect(element.tabIndex).toBe(0);
    });

    it('should support lifecycle methods', () => {
      const onMount = jest.fn();
      const onUnmount = jest.fn();
      const onUpdate = jest.fn();

      const element = View.box({
        style: {},
        props: {
          lifecycle: {
            onMount,
            onUnmount,
            onUpdate
          }
        }
      });

      expect(element.lifecycle?.onMount).toBe(onMount);
      expect(element.lifecycle?.onUnmount).toBe(onUnmount);
      expect(element.lifecycle?.onUpdate).toBe(onUpdate);
    });
  });

  describe('Component Methods', () => {
    test('form method creates a form element', () => {
      const formOptions: FormOptions = {
        fields: [
          {
            type: 'text',
            name: 'username',
            label: 'Username',
            placeholder: 'Enter username',
            required: true
          },
          {
            type: 'password',
            name: 'password',
            label: 'Password',
            placeholder: 'Enter password',
            required: true
          }
        ],
        submitLabel: 'Login',
        onSubmit: jest.fn()
      };

      const formElement = View.form(formOptions);

      expect(formElement.type).toBe('form');
      expect(formElement.children).toBeDefined();
      expect(formElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('form', expect.any(Number));
    });

    test('modal method creates a modal element', () => {
      const modalOptions: ModalOptions = {
        title: 'Test Modal',
        isOpen: true,
        onClose: jest.fn(),
        size: 'medium'
      };

      const modalElement = View.modal(modalOptions);

      expect(modalElement.type).toBe('div');
      expect(modalElement.children).toBeDefined();
      expect(modalElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('modal', expect.any(Number));
    });

    test('tabs method creates a tabs element', () => {
      const tabsOptions: TabsOptions = {
        tabs: [
          {
            id: 'tab1',
            label: 'Tab 1',
            content: View.text('Tab 1 Content')
          },
          {
            id: 'tab2',
            label: 'Tab 2',
            content: View.text('Tab 2 Content')
          }
        ],
        activeTab: 'tab1',
        onChange: jest.fn()
      };

      const tabsElement = View.tabs(tabsOptions);

      expect(tabsElement.type).toBe('div');
      expect(tabsElement.children).toBeDefined();
      expect(tabsElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('tabs', expect.any(Number));
    });

    test('accordion method creates an accordion element', () => {
      const accordionOptions: AccordionOptions = {
        sections: [
          {
            id: 'section1',
            title: 'Section 1',
            content: View.text('Section 1 Content')
          },
          {
            id: 'section2',
            title: 'Section 2',
            content: View.text('Section 2 Content')
          }
        ],
        activeSection: 'section1',
        onChange: jest.fn()
      };

      const accordionElement = View.accordion(accordionOptions);

      expect(accordionElement.type).toBe('div');
      expect(accordionElement.children).toBeDefined();
      expect(accordionElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('accordion', expect.any(Number));
    });

    test('infiniteScroll method creates an infinite scroll element', () => {
      const infiniteScrollOptions: InfiniteScrollOptions = {
        items: [
          View.text('Item 1'),
          View.text('Item 2'),
          View.text('Item 3')
        ],
        itemHeight: 50,
        containerHeight: 200,
        onScroll: jest.fn(),
        onLoadMore: jest.fn()
      };

      const infiniteScrollElement = View.infiniteScroll(infiniteScrollOptions);

      expect(infiniteScrollElement.type).toBe('div');
      expect(infiniteScrollElement.children).toBeDefined();
      expect(infiniteScrollElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('infiniteScroll', expect.any(Number));
    });

    test('lazyLoad method creates a lazy load element', () => {
      const lazyLoadOptions: LazyLoadOptions = {
        src: 'https://example.com/image.jpg',
        onLoad: jest.fn(),
        onError: jest.fn()
      };

      const lazyLoadElement = View.lazyLoad(lazyLoadOptions);

      expect(lazyLoadElement.type).toBe('div');
      expect(lazyLoadElement.children).toBeDefined();
      expect(lazyLoadElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('lazyLoad', expect.any(Number));
    });

    test('dragAndDrop method creates a drag and drop element', () => {
      const dragAndDropOptions: DragAndDropOptions = {
        items: [
          View.text('Item 1'),
          View.text('Item 2'),
          View.text('Item 3')
        ],
        onDragStart: jest.fn(),
        onDragOver: jest.fn(),
        onDrop: jest.fn(),
        onDragEnd: jest.fn()
      };

      const dragAndDropElement = View.dragAndDrop(dragAndDropOptions);

      expect(dragAndDropElement.type).toBe('div');
      expect(dragAndDropElement.children).toBeDefined();
      expect(dragAndDropElement.children!.length).toBeGreaterThan(0);
      expect(ViewPerformance.getInstance().recordComponentCreate).toHaveBeenCalledWith('dragAndDrop', expect.any(Number));
    });
  });

  describe('Performance Optimizations', () => {
    test('optimizeRendering method optimizes elements', () => {
      const elements: ViewElement[] = [
        View.box({
          style: {
            marginTop: 10,
            marginRight: 10,
            marginBottom: 10,
            marginLeft: 10,
            paddingTop: 5,
            paddingRight: 5,
            paddingBottom: 5,
            paddingLeft: 5
          },
          children: [
            View.text('Hello World')
          ]
        })
      ];

      const optimizedElements = View.optimizeRendering(elements);

      expect(optimizedElements.length).toBe(1);
      expect(optimizedElements[0].style).toBeDefined();
      expect(optimizedElements[0].style!.margin).toBe(10);
      expect(optimizedElements[0].style!.padding).toBe(5);
      expect(ViewPerformance.getInstance().recordComponentOperation).toHaveBeenCalledWith('optimizeRendering', expect.any(Number));
    });

    test('batchUpdates method batches updates', () => {
      const updates = [
        jest.fn(),
        jest.fn(),
        jest.fn()
      ];

      View.batchUpdates(updates);

      expect(ViewPerformance.getInstance().recordComponentOperation).toHaveBeenCalledWith('batchUpdates', expect.any(Number));
    });

    test('debounceRender method debounces render callbacks', () => {
      jest.useFakeTimers();

      const callback = jest.fn();
      View.debounceRender(callback, 100);

      expect(ViewPerformance.getInstance().recordComponentOperation).toHaveBeenCalledWith('debounceRender', expect.any(Number));

      jest.advanceTimersByTime(100);
      expect(callback).toHaveBeenCalled();

      jest.useRealTimers();
    });
  });

  describe('Modal', () => {
    it('should create a modal with the correct properties', () => {
      const modal = View.modal({
        title: 'Test Modal',
        isOpen: true,
        onClose: () => {},
        size: 'medium',
        content: View.text('Modal content'),
        style: { width: '500px' },
        children: [View.text('Child content')],
        className: 'test-modal',
        props: { 'data-test': 'test' },
        events: {
          onClick: () => {}
        }
      });

      expect(modal.type).toBe('modal');
      expect(modal.props?.title).toBe('Test Modal');
      expect(modal.props?.isOpen).toBe(true);
      expect(modal.props?.size).toBe('medium');
      expect(modal.props?.content).toBeDefined();
      expect(modal.style.width).toBe('500px');
      expect(modal.children).toHaveLength(1);
      expect(modal.className).toBe('test-modal');
      expect(modal.props?.['data-test']).toBe('test');
      expect(modal.events?.onClick).toBeDefined();
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const modal = View.modal({
        title: 'Test Modal',
        isOpen: true,
        onClose: () => {},
        content: View.text('Modal content'),
        events: {
          onClick
        }
      });

      // Simulate click event
      if (modal.events?.onClick) {
        modal.events.onClick(new MouseEvent('click'));
      }

      expect(onClick).toHaveBeenCalled();
    });
  });

  describe('Accordion', () => {
    it('should create an accordion with the correct properties', () => {
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Content 1') },
          { id: 'section2', title: 'Section 2', content: View.text('Content 2') }
        ],
        activeSection: 'section1',
        onChange: () => {},
        allowMultiple: false,
        variant: 'default',
        style: { width: '500px' },
        className: 'test-accordion',
        props: { 'data-test': 'test' }
      });

      expect(accordion.type).toBe('box');
      expect(accordion.style.width).toBe('500px');
      expect(accordion.className).toBe('test-accordion');
      expect(accordion.props?.['data-test']).toBe('test');
      expect(accordion.children).toHaveLength(2);
    });

    it('should handle single section correctly', () => {
      const onChange = jest.fn();
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Content 1') },
          { id: 'section2', title: 'Section 2', content: View.text('Content 2') }
        ],
        activeSection: 'section1',
        onChange,
        allowMultiple: false
      });

      // Simulate click on section 2
      const section2Header = accordion.children?.[1].children?.[0];
      if (section2Header?.events?.onClick) {
        section2Header.events.onClick(new MouseEvent('click'));
      }

      expect(onChange).toHaveBeenCalledWith('section2');
    });

    it('should handle multiple sections correctly', () => {
      const onChange = jest.fn();
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Content 1') },
          { id: 'section2', title: 'Section 2', content: View.text('Content 2') }
        ],
        activeSection: ['section1'],
        onChange,
        allowMultiple: true
      });

      // Simulate click on section 2
      const section2Header = accordion.children?.[1].children?.[0];
      if (section2Header?.events?.onClick) {
        section2Header.events.onClick(new MouseEvent('click'));
      }

      expect(onChange).toHaveBeenCalledWith(['section1', 'section2']);
    });
  });
}); 