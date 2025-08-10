/**
 * advanced-components-examples.tsx
 * 
 * Additional examples for advanced UI components and performance optimizations.
 */

// Import View components
import { View } from '../core/renderer/view';
import { ViewElement } from '../core/renderer/types';

// Example data
const generateItems = (count: number) => {
  return Array.from({ length: count }, (_, i) => ({
    id: `item-${i}`,
    content: `Item ${i + 1}`,
    description: `This is a description for item ${i + 1}`
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

// Example 1: Advanced Modal with Form
const AdvancedModalExample = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: ''
  });

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = () => {
    console.log('Form submitted:', formData);
    setIsModalOpen(false);
  };

  const renderForm = (): ViewElement => {
    return View.box({
      style: {
        padding: 20,
        display: 'flex' as const,
        flexDirection: 'column' as const,
        gap: 10
      },
      children: [
        View.text('Contact Form', { style: { fontSize: 18, marginBottom: 10 } }),
        View.box({
          style: {
            display: 'flex' as const,
            flexDirection: 'column' as const,
            gap: 5
          },
          children: [
            View.text('Name:'),
            View.box({
              style: {
                border: '1px solid #ccc',
                borderRadius: 4,
                padding: 8
              },
              content: formData.name,
              events: {
                onInput: (e: any) => handleInputChange('name', e.target.value)
              }
            })
          ]
        }),
        View.box({
          style: {
            display: 'flex' as const,
            flexDirection: 'column' as const,
            gap: 5
          },
          children: [
            View.text('Email:'),
            View.box({
              style: {
                border: '1px solid #ccc',
                borderRadius: 4,
                padding: 8
              },
              content: formData.email,
              events: {
                onInput: (e: any) => handleInputChange('email', e.target.value)
              }
            })
          ]
        }),
        View.box({
          style: {
            display: 'flex' as const,
            flexDirection: 'column' as const,
            gap: 5
          },
          children: [
            View.text('Message:'),
            View.box({
              style: {
                border: '1px solid #ccc',
                borderRadius: 4,
                padding: 8,
                minHeight: 100
              },
              content: formData.message,
              events: {
                onInput: (e: any) => handleInputChange('message', e.target.value)
              }
            })
          ]
        }),
        View.box({
          style: {
            display: 'flex' as const,
            justifyContent: 'flex-end' as const,
            gap: 10,
            marginTop: 10
          },
          children: [
            View.button({
              content: 'Cancel',
              events: {
                onClick: () => setIsModalOpen(false)
              }
            }),
            View.button({
              content: 'Submit',
              events: {
                onClick: handleSubmit
              }
            })
          ]
        })
      ]
    });
  };

  const renderModal = (): ViewElement => {
    return View.modal({
      title: 'Contact Form',
      isOpen: isModalOpen,
      onClose: () => setIsModalOpen(false),
      size: 'medium',
      content: renderForm()
    });
  };

  return View.box({
    style: {
      padding: 20
    },
    children: [
      View.text('Advanced Modal Example', { style: { fontSize: 24, marginBottom: 20 } }),
      View.button({
        content: 'Open Contact Form',
        events: {
          onClick: () => setIsModalOpen(true)
        }
      }),
      renderModal()
    ]
  });
};

// Example 2: Advanced Accordion with Nested Content
const AdvancedAccordionExample = () => {
  const [activeSection, setActiveSection] = useState<string | string[]>(['section1']);

  const renderAccordion = (): ViewElement => {
    return View.accordion({
      sections: [
        {
          id: 'section1',
          title: 'Getting Started',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.text('Welcome to the advanced accordion example!', { style: { marginBottom: 10 } }),
              View.text('This section demonstrates how to create rich content within accordion sections.'),
              View.box({
                style: {
                  marginTop: 10,
                  padding: 10,
                  backgroundColor: '#f5f5f5',
                  borderRadius: 4
                },
                children: [
                  View.text('Tip: You can include any View elements inside accordion sections.')
                ]
              })
            ]
          })
        },
        {
          id: 'section2',
          title: 'Advanced Features',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.text('Advanced Features', { style: { fontSize: 18, marginBottom: 10 } }),
              View.box({
                style: {
                  display: 'grid' as const,
                  gridTemplateColumns: '1fr 1fr',
                  gap: 10
                },
                children: [
                  View.box({
                    style: {
                      padding: 10,
                      border: '1px solid #ddd',
                      borderRadius: 4
                    },
                    children: [
                      View.text('Feature 1', { style: { fontWeight: 'bold' } }),
                      View.text('Description of feature 1')
                    ]
                  }),
                  View.box({
                    style: {
                      padding: 10,
                      border: '1px solid #ddd',
                      borderRadius: 4
                    },
                    children: [
                      View.text('Feature 2', { style: { fontWeight: 'bold' } }),
                      View.text('Description of feature 2')
                    ]
                  })
                ]
              })
            ]
          })
        },
        {
          id: 'section3',
          title: 'Performance Tips',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.text('Performance Tips', { style: { fontSize: 18, marginBottom: 10 } }),
              View.box({
                style: {
                  display: 'flex' as const,
                  flexDirection: 'column' as const,
                  gap: 10
                },
                children: [
                  View.box({
                    style: {
                      padding: 10,
                      border: '1px solid #ddd',
                      borderRadius: 4
                    },
                    children: [
                      View.text('Tip 1: Use lazy loading for images', { style: { fontWeight: 'bold' } }),
                      View.text('Only load images when they are about to enter the viewport.')
                    ]
                  }),
                  View.box({
                    style: {
                      padding: 10,
                      border: '1px solid #ddd',
                      borderRadius: 4
                    },
                    children: [
                      View.text('Tip 2: Batch updates', { style: { fontWeight: 'bold' } }),
                      View.text('Group multiple state updates together to reduce renders.')
                    ]
                  })
                ]
              })
            ]
          })
        }
      ],
      activeSection,
      onChange: setActiveSection,
      allowMultiple: true
    });
  };

  return View.box({
    style: {
      padding: 20
    },
    children: [
      View.text('Advanced Accordion Example', { style: { fontSize: 24, marginBottom: 20 } }),
      renderAccordion()
    ]
  });
};

// Example 3: Advanced Tabs with Dynamic Content
const AdvancedTabsExample = () => {
  const [activeTab, setActiveTab] = useState('tab1');
  const [items, setItems] = useState(generateItems(10));

  const handleLoadMore = () => {
    setItems(prevItems => [...prevItems, ...generateItems(5)]);
  };

  const renderInfiniteScroll = (): ViewElement => {
    return View.infiniteScroll({
      items: items.map(item => 
        View.box({
          style: {
            padding: 10,
            border: '1px solid #ddd',
            borderRadius: 4,
            marginBottom: 10
          },
          children: [
            View.text(item.content, { style: { fontWeight: 'bold' } }),
            View.text(item.description, { style: { fontSize: 14, color: '#666' } })
          ]
        })
      ),
      itemHeight: 80,
      containerHeight: 400,
      overscan: 5,
      onLoadMore: handleLoadMore,
      loadingThreshold: 0.8,
      loadingIndicator: View.text('Loading more items...')
    });
  };

  const renderDragAndDrop = (): ViewElement => {
    return View.dragAndDrop({
      items: items.map(item => 
        View.box({
          style: {
            padding: 10,
            border: '1px solid #ddd',
            borderRadius: 4,
            marginBottom: 10
          },
          children: [
            View.text(item.content, { style: { fontWeight: 'bold' } }),
            View.text(item.description, { style: { fontSize: 14, color: '#666' } })
          ]
        })
      ),
      onDragStart: (item, index) => console.log('Started dragging:', item, index),
      onDragOver: (item, index) => console.log('Dragging over:', item, index),
      onDrop: (item, sourceIndex, targetIndex) => {
        setItems(prevItems => {
          const newItems = [...prevItems];
          const [removed] = newItems.splice(sourceIndex, 1);
          newItems.splice(targetIndex, 0, removed);
          return newItems;
        });
      },
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
          content: renderDragAndDrop()
        },
        {
          id: 'tab3',
          label: 'Lazy Loading',
          content: View.box({
            style: {
              padding: 20
            },
            children: [
              View.text('Lazy Loading Example', { style: { fontSize: 18, marginBottom: 10 } }),
              View.lazyLoad({
                src: 'https://example.com/large-image.jpg',
                placeholder: View.text('Loading image...'),
                threshold: 0.5,
                onLoad: () => console.log('Image loaded'),
                onError: (error) => console.error('Failed to load image:', error)
              })
            ]
          })
        }
      ],
      activeTab,
      onChange: setActiveTab
    });
  };

  return View.box({
    style: {
      padding: 20
    },
    children: [
      View.text('Advanced Tabs Example', { style: { fontSize: 24, marginBottom: 20 } }),
      renderTabs()
    ]
  });
};

// Export all examples
export {
  AdvancedModalExample,
  AdvancedAccordionExample,
  AdvancedTabsExample
}; 