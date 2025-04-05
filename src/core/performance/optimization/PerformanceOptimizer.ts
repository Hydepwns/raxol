/**
 * PerformanceOptimizer.ts
 * 
 * Performance optimization recommendation system for the View rendering system.
 * Analyzes performance metrics and provides targeted optimization suggestions.
 */

import { ViewPerformance } from '../ViewPerformance';
import { AnimationPerformance } from '../animation/AnimationPerformance';
import { PerformanceMetrics } from '../ViewPerformance';
import { AnimationPerformanceMetrics } from '../animation/AnimationPerformance';
import { ComponentMetrics } from '../ViewPerformance';

export interface OptimizationRecommendation {
  category: 'memory' | 'rendering' | 'animation' | 'component';
  severity: 'low' | 'medium' | 'high';
  title: string;
  description: string;
  suggestions: string[];
  impact: string;
  codeExamples?: string[];
}

export interface ComponentPerformanceAnalysis {
  componentType: string;
  metrics: ComponentMetrics;
  recommendations: OptimizationRecommendation[];
  bottlenecks: string[];
}

export class PerformanceOptimizer {
  private static instance: PerformanceOptimizer;
  private viewPerformance: ViewPerformance;
  private animationPerformance: AnimationPerformance;

  private constructor() {
    this.viewPerformance = ViewPerformance.getInstance();
    this.animationPerformance = AnimationPerformance.getInstance();
  }

  static getInstance(): PerformanceOptimizer {
    if (!PerformanceOptimizer.instance) {
      PerformanceOptimizer.instance = new PerformanceOptimizer();
    }
    return PerformanceOptimizer.instance;
  }

  /**
   * Generate optimization recommendations based on current performance metrics
   */
  generateOptimizationRecommendations(): OptimizationRecommendation[] {
    const metrics = this.viewPerformance.getMetrics();
    const animationMetrics = this.animationPerformance.getMetrics();
    const recommendations: OptimizationRecommendation[] = [];

    // Analyze memory usage
    if (metrics.memory) {
      const memoryRecommendations = this.analyzeMemoryUsage(metrics.memory);
      recommendations.push(...memoryRecommendations);
    }

    // Analyze rendering performance
    const renderingRecommendations = this.analyzeRenderingPerformance(metrics.rendering);
    recommendations.push(...renderingRecommendations);

    // Analyze animation performance
    const animationRecommendations = this.analyzeAnimationPerformance(animationMetrics);
    recommendations.push(...animationRecommendations);

    // Analyze component performance
    const componentMetrics = this.viewPerformance.getAllComponentMetrics();
    for (const metric of componentMetrics) {
      const componentRecommendations = this.analyzeComponentPerformance(metric.type);
      recommendations.push(...componentRecommendations.recommendations);
    }

    return recommendations;
  }

  /**
   * Analyze performance of a specific component type
   */
  analyzeComponentPerformance(componentType: string): ComponentPerformanceAnalysis {
    const metrics = this.viewPerformance.getComponentMetrics(componentType);
    if (!metrics) {
      throw new Error(`No metrics found for component type: ${componentType}`);
    }

    const recommendations: OptimizationRecommendation[] = [];
    const bottlenecks: string[] = [];

    // Analyze render time
    if (metrics.renderTime > 16) { // More than one frame at 60fps
      bottlenecks.push('High render time');
      recommendations.push({
        category: 'component',
        severity: metrics.renderTime > 32 ? 'high' : 'medium',
        title: 'Optimize Component Render Time',
        description: `Component "${componentType}" takes ${metrics.renderTime}ms to render, which may cause frame drops.`,
        suggestions: [
          'Consider using React.memo or useMemo for expensive computations',
          'Break down complex components into smaller ones',
          'Move expensive calculations outside the render cycle',
          'Use virtualization for long lists'
        ],
        impact: 'Improving render time will lead to smoother animations and better user experience.',
        codeExamples: [
          `// Before
const ExpensiveComponent = () => {
  const result = expensiveCalculation(props.data);
  return <div>{result}</div>;
};

// After
const ExpensiveComponent = React.memo(({ data }) => {
  const result = useMemo(() => expensiveCalculation(data), [data]);
  return <div>{result}</div>;
});`
        ]
      });
    }

    // Analyze update frequency
    if (metrics.updateCount > 10) {
      bottlenecks.push('High update frequency');
      recommendations.push({
        category: 'component',
        severity: metrics.updateCount > 20 ? 'high' : 'medium',
        title: 'Reduce Component Update Frequency',
        description: `Component "${componentType}" is updating ${metrics.updateCount} times, which may indicate unnecessary re-renders.`,
        suggestions: [
          'Use shouldComponentUpdate or React.memo to prevent unnecessary updates',
          'Implement debouncing for frequent updates',
          'Move state updates to a more appropriate level in the component tree',
          'Consider using useCallback for event handlers'
        ],
        impact: 'Reducing update frequency will improve performance and reduce CPU usage.',
        codeExamples: [
          `// Before
const Component = () => {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const interval = setInterval(() => setCount(c => c + 1), 100);
    return () => clearInterval(interval);
  }, []);
  return <div>{count}</div>;
};

// After
const Component = React.memo(() => {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const interval = setInterval(() => {
      setCount(c => {
        if (c % 10 === 0) return c + 10;
        return c;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, []);
  return <div>{count}</div>;
});`
        ]
      });
    }

    // Analyze child count
    if (metrics.childCount > 100) {
      bottlenecks.push('Large number of children');
      recommendations.push({
        category: 'component',
        severity: metrics.childCount > 500 ? 'high' : 'medium',
        title: 'Optimize Large Component Tree',
        description: `Component "${componentType}" has ${metrics.childCount} children, which may impact performance.`,
        suggestions: [
          'Use virtualization for long lists',
          'Implement pagination or infinite scroll',
          'Break down into smaller components',
          'Consider using a virtual DOM diffing optimization'
        ],
        impact: 'Reducing the number of children will improve render performance and reduce memory usage.',
        codeExamples: [
          `// Before
const List = ({ items }) => (
  <div>
    {items.map(item => (
      <ListItem key={item.id} {...item} />
    ))}
  </div>
);

// After
import { VirtualList } from 'virtual-list';

const List = ({ items }) => (
  <VirtualList
    height={400}
    itemCount={items.length}
    itemSize={50}
    width={300}
  >
    {({ index, style }) => (
      <ListItem
        key={items[index].id}
        {...items[index]}
        style={style}
      />
    )}
  </VirtualList>
);`
        ]
      });
    }

    return {
      componentType,
      metrics,
      recommendations,
      bottlenecks
    };
  }

  /**
   * Analyze memory usage and generate recommendations
   */
  private analyzeMemoryUsage(memory: NonNullable<PerformanceMetrics['memory']>): OptimizationRecommendation[] {
    const recommendations: OptimizationRecommendation[] = [];
    const usedPercent = (memory.usedJSHeapSize / memory.totalJSHeapSize) * 100;

    if (usedPercent > 80) {
      recommendations.push({
        category: 'memory',
        severity: 'high',
        title: 'Critical Memory Usage',
        description: `Memory usage is at ${usedPercent.toFixed(1)}% of available heap.`,
        suggestions: [
          'Implement memory cleanup in component unmount',
          'Use WeakMap/WeakSet for object references',
          'Avoid storing large data in component state',
          'Implement pagination or lazy loading for large datasets'
        ],
        impact: 'High memory usage can lead to browser crashes and poor performance.',
        codeExamples: [
          `// Before
class Component extends React.Component {
  state = {
    largeData: []
  };
  componentDidMount() {
    this.setState({ largeData: fetchLargeDataset() });
  }
}

// After
class Component extends React.Component {
  state = {
    page: 1,
    data: []
  };
  componentDidMount() {
    this.loadPage(1);
  }
  loadPage = async (page) => {
    const newData = await fetchPage(page);
    this.setState(prev => ({
      data: [...prev.data, ...newData],
      page
    }));
  };
  componentWillUnmount() {
    // Cleanup any subscriptions or large data
    this.setState({ data: [] });
  }
}`
        ]
      });
    }

    return recommendations;
  }

  /**
   * Analyze rendering performance and generate recommendations
   */
  private analyzeRenderingPerformance(rendering: PerformanceMetrics['rendering']): OptimizationRecommendation[] {
    const recommendations: OptimizationRecommendation[] = [];

    // Check render time
    if (rendering.renderTime > 16) {
      recommendations.push({
        category: 'rendering',
        severity: rendering.renderTime > 32 ? 'high' : 'medium',
        title: 'Optimize Render Performance',
        description: `Render time is ${rendering.renderTime}ms, which may cause frame drops.`,
        suggestions: [
          'Use React.memo for pure components',
          'Implement shouldComponentUpdate',
          'Use useMemo for expensive calculations',
          'Consider using a virtual DOM diffing optimization'
        ],
        impact: 'Improving render time will lead to smoother animations and better user experience.',
        codeExamples: [
          `// Before
const Component = ({ data }) => {
  const processed = expensiveProcessing(data);
  return <div>{processed}</div>;
};

// After
const Component = React.memo(({ data }) => {
  const processed = useMemo(() => expensiveProcessing(data), [data]);
  return <div>{processed}</div>;
});`
        ]
      });
    }

    // Check layout time
    if (rendering.layoutTime > 8) {
      recommendations.push({
        category: 'rendering',
        severity: rendering.layoutTime > 16 ? 'high' : 'medium',
        title: 'Optimize Layout Performance',
        description: `Layout time is ${rendering.layoutTime}ms, which may cause layout thrashing.`,
        suggestions: [
          'Batch DOM reads and writes',
          'Use CSS transform instead of position changes',
          'Avoid forced synchronous layouts',
          'Use will-change for elements that will animate'
        ],
        impact: 'Reducing layout time will improve rendering performance and reduce jank.',
        codeExamples: [
          `// Before
const updateLayout = () => {
  const element = document.getElementById('my-element');
  const height = element.offsetHeight;
  element.style.height = (height * 2) + 'px';
  const width = element.offsetWidth;
  element.style.width = (width * 2) + 'px';
};

// After
const updateLayout = () => {
  const element = document.getElementById('my-element');
  const height = element.offsetHeight;
  const width = element.offsetWidth;
  requestAnimationFrame(() => {
    element.style.height = (height * 2) + 'px';
    element.style.width = (width * 2) + 'px';
  });
};`
        ]
      });
    }

    return recommendations;
  }

  /**
   * Analyze animation performance and generate recommendations
   */
  private analyzeAnimationPerformance(metrics: AnimationPerformanceMetrics): OptimizationRecommendation[] {
    const recommendations: OptimizationRecommendation[] = [];

    // Check frame rate
    if (metrics.averageFrameRate < 55) {
      recommendations.push({
        category: 'animation',
        severity: metrics.averageFrameRate < 45 ? 'high' : 'medium',
        title: 'Optimize Animation Performance',
        description: `Average frame rate is ${metrics.averageFrameRate.toFixed(1)} FPS, which may cause stuttering.`,
        suggestions: [
          'Use CSS transforms instead of position changes',
          'Implement requestAnimationFrame for smooth animations',
          'Use will-change for elements that will animate',
          'Consider reducing animation complexity'
        ],
        impact: 'Improving animation performance will lead to smoother visual effects and better user experience.',
        codeExamples: [
          `// Before
const animate = () => {
  element.style.left = (parseInt(element.style.left) + 1) + 'px';
  setTimeout(animate, 16);
};

// After
const animate = () => {
  requestAnimationFrame(() => {
    element.style.transform = \`translateX(\${position}px)\`;
    position += 1;
    if (position < target) animate();
  });
};`
        ]
      });
    }

    // Check frame drop rate
    if (metrics.frameDropRate > 1) {
      recommendations.push({
        category: 'animation',
        severity: metrics.frameDropRate > 5 ? 'high' : 'medium',
        title: 'Reduce Frame Drops',
        description: `Frame drop rate is ${metrics.frameDropRate.toFixed(1)}%, which may cause stuttering.`,
        suggestions: [
          'Use CSS transforms for animations',
          'Implement frame skipping for complex animations',
          'Reduce animation complexity',
          'Use hardware acceleration when possible'
        ],
        impact: 'Reducing frame drops will improve animation smoothness and user experience.',
        codeExamples: [
          `// Before
.element {
  animation: move 1s linear infinite;
}

// After
.element {
  transform: translateZ(0);
  will-change: transform;
  animation: move 1s linear infinite;
}`
        ]
      });
    }

    return recommendations;
  }
} 