/**
 * advanced-components.test.ts
 * 
 * Tests for advanced UI components.
 */

import { View } from '../view';
import { ViewElement, ViewStyle } from '../types';

// Mock performance API
const mockPerformance = {
  now: jest.fn().mockReturnValue(0),
  timing: {
    navigationStart: 0,
    fetchStart: 0,
    domainLookupStart: 0,
    domainLookupEnd: 0,
    connectStart: 0,
    connectEnd: 0,
    requestStart: 0,
    responseStart: 0,
    responseEnd: 0,
    domLoading: 0,
    domInteractive: 0,
    domContentLoadedEventStart: 0,
    domContentLoadedEventEnd: 0,
    domComplete: 0,
    loadEventStart: 0,
    loadEventEnd: 0
  }
};

// Mock global performance object
global.performance = mockPerformance as any;

describe('Advanced Components', () => {
  describe('Modal', () => {
    it('should create a modal with the correct properties', () => {
      const onClose = jest.fn();
      const modal = View.modal({
        title: 'Test Modal',
        isOpen: true,
        onClose,
        content: View.text('Modal content')
      });

      expect(modal.type).toBe('modal');
      expect(modal.props?.title).toBe('Test Modal');
      expect(modal.props?.isOpen).toBe(true);
      expect(modal.props?.onClose).toBe(onClose);
      expect(modal.children?.[0].content).toBe('Modal content');
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const modal = View.modal({
        title: 'Test Modal',
        isOpen: true,
        onClose: jest.fn(),
        content: View.text('Modal content'),
        events: {
          onClick
        }
      });

      expect(modal.events?.onClick).toBe(onClick);
    });
  });

  describe('Tabs', () => {
    it('should create tabs with the correct properties', () => {
      const onChange = jest.fn();
      const tabs = View.tabs({
        tabs: [
          { id: 'tab1', label: 'Tab 1', content: View.text('Tab 1 content') },
          { id: 'tab2', label: 'Tab 2', content: View.text('Tab 2 content') }
        ],
        activeTab: 'tab1',
        onChange
      });

      expect(tabs.type).toBe('tabs');
      expect(tabs.props?.tabs).toHaveLength(2);
      expect(tabs.props?.activeTab).toBe('tab1');
      expect(tabs.props?.onChange).toBe(onChange);
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const tabs = View.tabs({
        tabs: [
          { id: 'tab1', label: 'Tab 1', content: View.text('Tab 1 content') },
          { id: 'tab2', label: 'Tab 2', content: View.text('Tab 2 content') }
        ],
        activeTab: 'tab1',
        onChange: jest.fn(),
        events: {
          onClick
        }
      });

      expect(tabs.events?.onClick).toBe(onClick);
    });
  });

  describe('Accordion', () => {
    it('should create an accordion with the correct properties', () => {
      const onChange = jest.fn();
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Section 1 content') },
          { id: 'section2', title: 'Section 2', content: View.text('Section 2 content') }
        ],
        activeSection: 'section1',
        onChange
      });

      expect(accordion.type).toBe('accordion');
      expect(accordion.props?.sections).toHaveLength(2);
      expect(accordion.props?.activeSection).toBe('section1');
      expect(accordion.props?.onChange).toBe(onChange);
    });

    it('should handle multiple sections correctly', () => {
      const onChange = jest.fn();
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Section 1 content') },
          { id: 'section2', title: 'Section 2', content: View.text('Section 2 content') }
        ],
        activeSection: ['section1', 'section2'],
        allowMultiple: true,
        onChange
      });

      expect(accordion.type).toBe('accordion');
      expect(accordion.props?.sections).toHaveLength(2);
      expect(accordion.props?.activeSection).toEqual(['section1', 'section2']);
      expect(accordion.props?.allowMultiple).toBe(true);
      expect(accordion.props?.onChange).toBe(onChange);
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const accordion = View.accordion({
        sections: [
          { id: 'section1', title: 'Section 1', content: View.text('Section 1 content') },
          { id: 'section2', title: 'Section 2', content: View.text('Section 2 content') }
        ],
        activeSection: 'section1',
        onChange: jest.fn(),
        events: {
          onClick
        }
      });

      expect(accordion.events?.onClick).toBe(onClick);
    });
  });

  describe('InfiniteScroll', () => {
    it('should create an infinite scroll with the correct properties', () => {
      const onScroll = jest.fn();
      const onLoadMore = jest.fn();
      const items = [View.text('Item 1'), View.text('Item 2')];
      
      const infiniteScroll = View.infiniteScroll({
        items,
        itemHeight: 50,
        containerHeight: 400,
        overscan: 5,
        onScroll,
        onLoadMore,
        loadingThreshold: 0.8,
        loadingIndicator: View.text('Loading more items...')
      });

      expect(infiniteScroll.type).toBe('infiniteScroll');
      expect(infiniteScroll.props?.items).toEqual(items);
      expect(infiniteScroll.props?.itemHeight).toBe(50);
      expect(infiniteScroll.props?.containerHeight).toBe(400);
      expect(infiniteScroll.props?.overscan).toBe(5);
      expect(infiniteScroll.props?.onScroll).toBe(onScroll);
      expect(infiniteScroll.props?.onLoadMore).toBe(onLoadMore);
      expect(infiniteScroll.props?.loadingThreshold).toBe(0.8);
      expect((infiniteScroll.props?.loadingIndicator as ViewElement).content).toBe('Loading more items...');
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const infiniteScroll = View.infiniteScroll({
        items: [View.text('Item 1'), View.text('Item 2')],
        itemHeight: 50,
        containerHeight: 400,
        onScroll: jest.fn(),
        onLoadMore: jest.fn(),
        events: {
          onClick
        }
      });

      expect(infiniteScroll.events?.onClick).toBe(onClick);
    });
  });

  describe('LazyLoad', () => {
    it('should create a lazy load with the correct properties', () => {
      const onLoad = jest.fn();
      const onError = jest.fn();
      
      const lazyLoad = View.lazyLoad({
        src: 'test.jpg',
        placeholder: View.text('Loading...'),
        threshold: 0.5,
        onLoad,
        onError
      });

      expect(lazyLoad.type).toBe('div');
      expect(lazyLoad.children?.[0].style?.backgroundImage).toBe('url(test.jpg)');
      expect(lazyLoad.props?.threshold).toBe(0.5);
      expect(lazyLoad.props?.onLoad).toBe(onLoad);
      expect(lazyLoad.props?.onError).toBe(onError);
    });

    it('should handle events correctly', () => {
      const onCustomEvent = jest.fn();
      const lazyLoad = View.lazyLoad({
        src: 'test.jpg',
        placeholder: View.text('Loading...'),
        onLoad: jest.fn(),
        onError: jest.fn(),
        events: {
          onCustomEvent
        }
      });

      expect(lazyLoad.events?.onCustomEvent).toBe(onCustomEvent);
    });
  });

  describe('DragAndDrop', () => {
    it('should create a drag and drop with the correct properties', () => {
      const onDragStart = jest.fn();
      const onDragOver = jest.fn();
      const onDrop = jest.fn();
      const onDragEnd = jest.fn();
      const items = [View.text('Item 1'), View.text('Item 2')];
      
      const dragAndDrop = View.dragAndDrop({
        items,
        onDragStart,
        onDragOver,
        onDrop,
        onDragEnd,
        draggableItemStyle: { border: '1px solid #ddd' as ViewStyle['border'] },
        dropTargetStyle: { border: '2px solid #000' as ViewStyle['border'] }
      });

      expect(dragAndDrop.type).toBe('div');
      expect(dragAndDrop.children).toHaveLength(2);
      expect(dragAndDrop.props?.onDragStart).toBe(onDragStart);
      expect(dragAndDrop.props?.onDragOver).toBe(onDragOver);
      expect(dragAndDrop.props?.onDrop).toBe(onDrop);
      expect(dragAndDrop.props?.onDragEnd).toBe(onDragEnd);
      expect(dragAndDrop.props?.draggableItemStyle).toEqual({ border: '1px solid #ddd' });
      expect(dragAndDrop.props?.dropTargetStyle).toEqual({ border: '2px solid #000' });
    });

    it('should handle events correctly', () => {
      const onClick = jest.fn();
      const dragAndDrop = View.dragAndDrop({
        items: [View.text('Item 1'), View.text('Item 2')],
        onDragStart: jest.fn(),
        onDragOver: jest.fn(),
        onDrop: jest.fn(),
        onDragEnd: jest.fn(),
        events: {
          onClick
        }
      });

      expect(dragAndDrop.events?.onClick).toBe(onClick);
    });
  });
}); 