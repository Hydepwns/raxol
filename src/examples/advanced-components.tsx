/**
 * advanced-components.tsx
 * 
 * Example usage of advanced UI components and performance optimizations.
 */

// Import View components
import { View, ViewElement, ButtonOptions, ModalOptions } from '../core/renderer/view';

// Example data
const generateItems = (count: number) => {
  return Array.from({ length: count }, (_, i) => ({
    id: `item-${i}`,
    content: `Item ${i + 1}`
  }));
};

// Mock React hooks for demonstration
const useState = <T,>(initialState: T): [T, (newState: T | ((prev: T) => T)) => void] => {
  let state = initialState;
  const setState = (newState: T | ((prev: T) => T)) => {
    if (typeof newState === 'function') {
      state = (newState as (prev: T) => T)(state);
    } else {
      state = newState;
    }
    // In a real implementation, this would trigger a re-render
  };
  return [state, setState];
};

const useCallback = <T extends (...args: any[]) => any>(
  callback: T,
  deps: any[]
): T => {
  return callback;
};

const AdvancedComponentsExample = () => {
  const [items, setItems] = useState(generateItems(20));
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('tab1');
  const [activeSection, setActiveSection] = useState('section1');

  // Infinite scroll handlers
  const handleScroll = useCallback((scrollTop: number) => {
    console.log('Scrolled to:', scrollTop);
  }, []);

  const handleLoadMore = useCallback(() => {
    setItems(prevItems => [...prevItems, ...generateItems(10)]);
  }, []);

  // Drag and drop handlers
  const handleDragStart = useCallback((item: any, index: number) => {
    console.log('Started dragging:', item, index);
  }, []);

  const handleDragOver = useCallback((item: any, index: number) => {
    console.log('Dragging over:', item, index);
  }, []);

  const handleDrop = useCallback((item: any, sourceIndex: number, targetIndex: number) => {
    setItems(prevItems => {
      const newItems = [...prevItems];
      const [removed] = newItems.splice(sourceIndex, 1);
      newItems.splice(targetIndex, 0, removed);
      return newItems;
    });
  }, []);

  // Create the UI elements
  const renderInfiniteScroll = (): ViewElement => {
    return View.infiniteScroll({
      items: items.map(item => View.text(item.content)),
      itemHeight: 50,
      containerHeight: 400,
      overscan: 5,
      onScroll: handleScroll,
      onLoadMore: handleLoadMore,
      loadingThreshold: 0.8,
      loadingIndicator: View.text('Loading more items...')
    });
  };

  const renderModal = (): ViewElement => {
    const modalContent = View.box({
      style: {
        padding: 20
      },
      children: [
        View.text('This is a modal with advanced components'),
        View.button({
          content: 'Close',
          events: {
            onClick: () => setIsModalOpen(false)
          }
        })
      ]
    });

    return View.modal({
      title: 'Advanced Components Demo',
      isOpen: isModalOpen,
      onClose: () => setIsModalOpen(false),
      size: 'large',
      content: modalContent
    });
  };

  const renderTabs = (): ViewElement => {
    return View.tabs({
      tabs: [
        {
          id: 'tab1',
          label: 'Infinite Scroll',
          content: renderInfiniteScroll()
        },
        {
          id: 'tab2',
          label: 'Drag and Drop',
          content: View.dragAndDrop({
            items: items.map(item => View.text(item.content)),
            onDragStart: handleDragStart,
            onDragOver: handleDragOver,
            onDrop: handleDrop,
            onDragEnd: () => console.log('Drag ended'),
            draggableItemStyle: {
              padding: 10,
              margin: 5,
              border: 'single',
              borderRadius: 4,
              cursor: 'move'
            },
            dropTargetStyle: {
              border: 'double'
            }
          })
        }
      ],
      activeTab,
      onChange: setActiveTab
    });
  };

  const renderAccordion = (): ViewElement => {
    return View.accordion({
      sections: [
        {
          id: 'section1',
          title: 'Performance Optimizations',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.text('This section demonstrates performance optimizations'),
              View.button({
                content: 'Optimize Rendering',
                events: {
                  onClick: () => {
                    const elements = document.querySelectorAll('*');
                    View.optimizeRendering(Array.from(elements) as unknown as ViewElement[]);
                  }
                }
              }),
              View.button({
                content: 'Batch Updates',
                events: {
                  onClick: () => {
                    View.batchUpdates([
                      () => setItems(prev => [...prev, ...generateItems(5)]),
                      () => setActiveTab('tab1'),
                      () => setActiveSection('section1')
                    ]);
                  }
                }
              })
            ]
          })
        },
        {
          id: 'section2',
          title: 'Lazy Loading',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.lazyLoad({
                src: 'https://example.com/large-image.jpg',
                placeholder: View.text('Loading image...'),
                threshold: 0.5,
                onLoad: () => console.log('Image loaded'),
                onError: () => console.error('Failed to load image')
              })
            ]
          })
        }
      ],
      activeSection,
      onChange: setActiveSection
    });
  };

  // Main layout
  return View.box({
    style: {
      padding: 20,
      maxWidth: 800,
      margin: '0 auto'
    },
    children: [
      View.text('Advanced Components Demo', { style: { fontSize: 24, marginBottom: 20 } }),
      View.button({
        content: 'Open Modal',
        events: {
          onClick: () => setIsModalOpen(true)
        }
      }),
      renderTabs(),
      renderAccordion(),
      renderModal()
    ]
  });
};

export default AdvancedComponentsExample;