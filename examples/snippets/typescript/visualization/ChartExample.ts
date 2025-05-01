/**
 * ChartExample.ts
 * 
 * Demonstrates how to use the Raxol Chart component for data visualization
 * with different chart types and accessibility features.
 */

import { Chart, ChartOptions, DataSeries, DataPoint } from '../../components/visualization/Chart';
import { 
  startPerformanceMark, 
  endPerformanceMark, 
  startJankDetection,
  createJankVisualizer
} from '../../core/performance';

/**
 * Generate sample data for the charts
 */
function generateSampleData(): {
  lineData: DataSeries[];
  barData: DataSeries[];
  pieData: DataSeries[];
  multiData: DataSeries[];
} {
  // Line chart data - temperature over time
  const lineData: DataSeries[] = [
    {
      name: 'Tokyo',
      data: [
        { x: 'Jan', y: 7 },
        { x: 'Feb', y: 8 },
        { x: 'Mar', y: 12 },
        { x: 'Apr', y: 18 },
        { x: 'May', y: 22 },
        { x: 'Jun', y: 26 },
        { x: 'Jul', y: 29 },
        { x: 'Aug', y: 30 },
        { x: 'Sep', y: 26 },
        { x: 'Oct', y: 20 },
        { x: 'Nov', y: 14 },
        { x: 'Dec', y: 9 }
      ]
    },
    {
      name: 'London',
      data: [
        { x: 'Jan', y: 4 },
        { x: 'Feb', y: 4 },
        { x: 'Mar', y: 7 },
        { x: 'Apr', y: 10 },
        { x: 'May', y: 13 },
        { x: 'Jun', y: 17 },
        { x: 'Jul', y: 19 },
        { x: 'Aug', y: 18 },
        { x: 'Sep', y: 15 },
        { x: 'Oct', y: 12 },
        { x: 'Nov', y: 7 },
        { x: 'Dec', y: 5 }
      ]
    }
  ];
  
  // Bar chart data - website visits by device
  const barData: DataSeries[] = [
    {
      name: 'Desktop',
      data: [
        { x: 'Q1', y: 45 },
        { x: 'Q2', y: 50 },
        { x: 'Q3', y: 42 },
        { x: 'Q4', y: 48 }
      ]
    },
    {
      name: 'Mobile',
      data: [
        { x: 'Q1', y: 35 },
        { x: 'Q2', y: 40 },
        { x: 'Q3', y: 50 },
        { x: 'Q4', y: 55 }
      ]
    },
    {
      name: 'Tablet',
      data: [
        { x: 'Q1', y: 20 },
        { x: 'Q2', y: 18 },
        { x: 'Q3', y: 15 },
        { x: 'Q4', y: 12 }
      ]
    }
  ];
  
  // Pie chart data - market share
  const pieData: DataSeries[] = [
    {
      name: 'Market Share',
      data: [
        { x: 'Chrome', y: 64, color: '#4285F4' },
        { x: 'Firefox', y: 12, color: '#FF9800' },
        { x: 'Safari', y: 10, color: '#34A853' },
        { x: 'Edge', y: 8, color: '#4A90E2' },
        { x: 'Opera', y: 2, color: '#EA4335' },
        { x: 'Other', y: 4, color: '#607D8B' }
      ]
    }
  ];
  
  // Multiple series with mixed types
  const multiData: DataSeries[] = [
    {
      name: 'Revenue',
      type: 'bar',
      data: [
        { x: 'Jan', y: 50 },
        { x: 'Feb', y: 55 },
        { x: 'Mar', y: 70 },
        { x: 'Apr', y: 65 },
        { x: 'May', y: 90 },
        { x: 'Jun', y: 100 }
      ]
    },
    {
      name: 'Expenses',
      type: 'bar',
      data: [
        { x: 'Jan', y: 40 },
        { x: 'Feb', y: 45 },
        { x: 'Mar', y: 50 },
        { x: 'Apr', y: 55 },
        { x: 'May', y: 60 },
        { x: 'Jun', y: 70 }
      ]
    },
    {
      name: 'Profit',
      type: 'line',
      data: [
        { x: 'Jan', y: 10 },
        { x: 'Feb', y: 10 },
        { x: 'Mar', y: 20 },
        { x: 'Apr', y: 10 },
        { x: 'May', y: 30 },
        { x: 'Jun', y: 30 }
      ]
    }
  ];
  
  return { lineData, barData, pieData, multiData };
}

/**
 * Create and set up chart containers
 */
function createChartContainers(): {
  lineContainer: HTMLElement;
  barContainer: HTMLElement;
  pieContainer: HTMLElement;
  performanceContainer: HTMLElement;
} {
  // Create container for overall layout
  const mainContainer = document.createElement('div');
  mainContainer.style.fontFamily = 'Arial, sans-serif';
  mainContainer.style.padding = '20px';
  mainContainer.style.display = 'flex';
  mainContainer.style.flexDirection = 'column';
  mainContainer.style.gap = '20px';
  
  // Page title
  const title = document.createElement('h1');
  title.textContent = 'Raxol Chart Component Examples';
  title.style.textAlign = 'center';
  title.style.margin = '0 0 20px 0';
  
  // Charts container
  const chartsContainer = document.createElement('div');
  chartsContainer.style.display = 'grid';
  chartsContainer.style.gridTemplateColumns = 'repeat(2, 1fr)';
  chartsContainer.style.gap = '20px';
  
  // Create individual chart containers
  const lineContainer = document.createElement('div');
  lineContainer.style.height = '300px';
  lineContainer.style.border = '1px solid #ddd';
  lineContainer.style.borderRadius = '4px';
  lineContainer.style.padding = '10px';
  
  const barContainer = document.createElement('div');
  barContainer.style.height = '300px';
  barContainer.style.border = '1px solid #ddd';
  barContainer.style.borderRadius = '4px';
  barContainer.style.padding = '10px';
  
  const pieContainer = document.createElement('div');
  pieContainer.style.height = '300px';
  pieContainer.style.border = '1px solid #ddd';
  pieContainer.style.borderRadius = '4px';
  pieContainer.style.padding = '10px';
  
  const performanceContainer = document.createElement('div');
  performanceContainer.style.height = '300px';
  performanceContainer.style.border = '1px solid #ddd';
  performanceContainer.style.borderRadius = '4px';
  performanceContainer.style.padding = '10px';
  
  // Add containers to the grid
  chartsContainer.appendChild(lineContainer);
  chartsContainer.appendChild(barContainer);
  chartsContainer.appendChild(pieContainer);
  chartsContainer.appendChild(performanceContainer);
  
  // Build page
  mainContainer.appendChild(title);
  mainContainer.appendChild(chartsContainer);
  
  // Controls section
  const controlsSection = document.createElement('div');
  controlsSection.style.marginTop = '20px';
  controlsSection.style.padding = '15px';
  controlsSection.style.backgroundColor = '#f5f5f5';
  controlsSection.style.borderRadius = '4px';
  
  const controlsTitle = document.createElement('h2');
  controlsTitle.textContent = 'Chart Controls';
  controlsTitle.style.marginTop = '0';
  
  const buttonContainer = document.createElement('div');
  buttonContainer.style.display = 'flex';
  buttonContainer.style.gap = '10px';
  buttonContainer.style.flexWrap = 'wrap';
  
  // Add buttons for various actions
  const actions = [
    { text: 'Add Data Point', id: 'add-data' },
    { text: 'Remove Data Point', id: 'remove-data' },
    { text: 'Toggle Series', id: 'toggle-series' },
    { text: 'Change Colors', id: 'change-colors' },
    { text: 'Toggle Dark Mode', id: 'toggle-theme' },
    { text: 'Download Chart', id: 'download-chart' }
  ];
  
  actions.forEach(action => {
    const button = document.createElement('button');
    button.textContent = action.text;
    button.id = action.id;
    button.style.padding = '8px 16px';
    button.style.borderRadius = '4px';
    button.style.border = '1px solid #ccc';
    button.style.backgroundColor = '#fff';
    button.style.cursor = 'pointer';
    
    buttonContainer.appendChild(button);
  });
  
  // Add controls to page
  controlsSection.appendChild(controlsTitle);
  controlsSection.appendChild(buttonContainer);
  mainContainer.appendChild(controlsSection);
  
  // Add Jank Visualizer for performance monitoring
  const jankTitle = document.createElement('h2');
  jankTitle.textContent = 'Performance Monitoring';
  jankTitle.style.textAlign = 'center';
  jankTitle.style.marginTop = '20px';
  
  const jankContainer = document.createElement('div');
  jankContainer.id = 'jank-visualizer';
  jankContainer.style.height = '200px';
  jankContainer.style.border = '1px solid #ddd';
  jankContainer.style.borderRadius = '4px';
  jankContainer.style.marginTop = '10px';
  
  mainContainer.appendChild(jankTitle);
  mainContainer.appendChild(jankContainer);
  
  // Add to document
  document.body.appendChild(mainContainer);
  
  return { lineContainer, barContainer, pieContainer, performanceContainer };
}

/**
 * Create a line chart
 */
function createLineChart(container: HTMLElement, data: DataSeries[]): Chart {
  const options: ChartOptions = {
    type: 'line',
    title: 'Monthly Average Temperature',
    subtitle: 'Tokyo vs London',
    series: data,
    xAxis: {
      title: 'Month',
      gridLines: true
    },
    yAxis: {
      title: 'Temperature (°C)',
      min: 0,
      gridLines: true
    },
    accessibility: {
      description: 'Line chart showing monthly average temperatures for Tokyo and London throughout the year.',
      keyboardNavigation: true,
      announceDataPoints: true
    },
    events: {
      pointClick: (point, series, indices) => {
        console.log(`Clicked on ${series.name}, ${point.x}: ${point.y}°C`);
      }
    }
  };
  
  return new Chart(container, options);
}

/**
 * Create a bar chart
 */
function createBarChart(container: HTMLElement, data: DataSeries[]): Chart {
  const options: ChartOptions = {
    type: 'bar',
    title: 'Website Visits by Device',
    subtitle: 'Quarterly breakdown',
    series: data,
    xAxis: {
      title: 'Quarter',
      gridLines: false
    },
    yAxis: {
      title: 'Percentage (%)',
      min: 0,
      max: 100,
      gridLines: true
    },
    legend: {
      position: 'bottom'
    },
    accessibility: {
      description: 'Bar chart showing website visits by device type (Desktop, Mobile, Tablet) for each quarter.',
      keyboardNavigation: true,
      announceDataPoints: true
    },
    plotOptions: {
      bar: {
        groupPadding: 0.1,
        pointPadding: 0.05
      }
    }
  };
  
  return new Chart(container, options);
}

/**
 * Create a pie chart
 */
function createPieChart(container: HTMLElement, data: DataSeries[]): Chart {
  const options: ChartOptions = {
    type: 'pie',
    title: 'Browser Market Share',
    series: data,
    legend: {
      position: 'right'
    },
    tooltip: {
      enabled: true,
      format: (point) => `${point.x}: ${point.y}%`
    },
    accessibility: {
      description: 'Pie chart showing browser market share distribution between Chrome, Firefox, Safari, Edge, Opera and others.',
      keyboardNavigation: true,
      announceDataPoints: true
    },
    plotOptions: {
      pie: {
        innerRadius: 0,
        dataLabels: {
          enabled: true
        }
      }
    }
  };
  
  return new Chart(container, options);
}

/**
 * Create a performance test chart with many data points
 */
function createPerformanceTestChart(container: HTMLElement): Chart {
  startPerformanceMark('generate-performance-data');
  
  // Generate a larger dataset to test performance
  const performanceData: DataSeries[] = [];
  
  // Create a series with 1000 data points
  const largeDataPoints: DataPoint[] = [];
  for (let i = 0; i < 1000; i++) {
    const x = i;
    const y = 100 + 50 * Math.sin(i / 20) + 20 * Math.sin(i / 7) + 10 * Math.random();
    largeDataPoints.push({ x, y });
  }
  
  performanceData.push({
    name: 'Performance Test',
    data: largeDataPoints
  });
  
  endPerformanceMark('generate-performance-data');
  
  const options: ChartOptions = {
    type: 'line',
    title: 'Performance Test - 1000 Data Points',
    series: performanceData,
    xAxis: {
      title: 'Index',
      gridLines: false
    },
    yAxis: {
      title: 'Value',
      gridLines: true
    },
    accessibility: {
      description: 'Line chart with 1000 data points to test rendering performance.',
      keyboardNavigation: false
    },
    tooltip: {
      enabled: true
    },
    animation: {
      duration: 0 // Disable animation for performance
    }
  };
  
  return new Chart(container, options);
}

/**
 * Set up event handlers
 */
function setupEventHandlers(
  lineChart: Chart, 
  barChart: Chart, 
  pieChart: Chart, 
  performanceChart: Chart
): void {
  const addDataButton = document.getElementById('add-data');
  const removeDataButton = document.getElementById('remove-data');
  const toggleSeriesButton = document.getElementById('toggle-series');
  const changeColorsButton = document.getElementById('change-colors');
  const toggleThemeButton = document.getElementById('toggle-theme');
  const downloadButton = document.getElementById('download-chart');
  
  let isDarkMode = false;
  
  // Add data point
  addDataButton?.addEventListener('click', () => {
    // Clone current data
    const currentData = JSON.parse(JSON.stringify(
      lineChart.getSeriesData()
    ));
    
    // Add new point to both series
    currentData[0].data.push({
      x: `New ${currentData[0].data.length + 1}`,
      y: Math.floor(5 + Math.random() * 25)
    });
    
    currentData[1].data.push({
      x: `New ${currentData[1].data.length + 1}`,
      y: Math.floor(3 + Math.random() * 20)
    });
    
    // Update chart
    lineChart.updateData(currentData);
  });
  
  // Remove data point
  removeDataButton?.addEventListener('click', () => {
    // Clone current data
    const currentData = JSON.parse(JSON.stringify(
      lineChart.getSeriesData()
    ));
    
    // Remove last point from both series
    if (currentData[0].data.length > 1) {
      currentData[0].data.pop();
      currentData[1].data.pop();
      
      // Update chart
      lineChart.updateData(currentData);
    }
  });
  
  // Toggle series visibility
  toggleSeriesButton?.addEventListener('click', () => {
    // Clone current data
    const currentData = JSON.parse(JSON.stringify(
      barChart.getSeriesData()
    ));
    
    // Toggle visibility of second series
    currentData[1].visible = !currentData[1].visible;
    
    // Update chart
    barChart.updateData(currentData);
  });
  
  // Change colors
  changeColorsButton?.addEventListener('click', () => {
    // Toggle between two color schemes
    const colorScheme1 = ['#4285F4', '#EA4335', '#FBBC05', '#34A853', '#FF6D01', '#46BDC6'];
    const colorScheme2 = ['#3949AB', '#D81B60', '#00897B', '#7CB342', '#FFA000', '#5E35B1'];
    
    const currentColors = pieChart.getColors();
    pieChart.updateOptions({
      colors: currentColors?.[0] === colorScheme1[0] ? colorScheme2 : colorScheme1
    });
  });
  
  // Toggle dark/light theme
  toggleThemeButton?.addEventListener('click', () => {
    isDarkMode = !isDarkMode;
    
    const lightTheme = {
      backgroundColor: '#ffffff',
      textColor: '#333333',
      gridColor: '#e0e0e0'
    };
    
    const darkTheme = {
      backgroundColor: '#2a2a2a',
      textColor: '#e0e0e0',
      gridColor: '#444444'
    };
    
    const theme = isDarkMode ? darkTheme : lightTheme;
    
    // Update all charts
    [lineChart, barChart, pieChart, performanceChart].forEach(chart => {
      chart.updateOptions({
        backgroundColor: theme.backgroundColor,
        xAxis: {
          ...chart.getAxisOptions('x'),
          gridColor: theme.gridColor
        },
        yAxis: {
          ...chart.getAxisOptions('y'),
          gridColor: theme.gridColor
        }
      });
    });
    
    // Update page theme
    document.body.style.backgroundColor = isDarkMode ? '#1a1a1a' : '#ffffff';
    document.body.style.color = isDarkMode ? '#e0e0e0' : '#333333';
  });
  
  // Download chart
  downloadButton?.addEventListener('click', () => {
    lineChart.download('temperature-chart.png');
  });
}

/**
 * Main function to run the chart examples
 */
export function runChartExamples(): void {
  startPerformanceMark('chart-examples-init');
  
  // Start jank detection
  startJankDetection();
  
  // Create containers
  const { lineContainer, barContainer, pieContainer, performanceContainer } = createChartContainers();
  
  // Generate sample data
  const { lineData, barData, pieData } = generateSampleData();
  
  // Create charts
  const lineChart = createLineChart(lineContainer, lineData);
  const barChart = createBarChart(barContainer, barData);
  const pieChart = createPieChart(pieContainer, pieData);
  
  // Create performance test chart (with many data points)
  const performanceChart = createPerformanceTestChart(performanceContainer);
  
  // Set up event handlers
  setupEventHandlers(lineChart, barChart, pieChart, performanceChart);
  
  // Create jank visualizer
  const jankContainer = document.getElementById('jank-visualizer');
  if (jankContainer) {
    createJankVisualizer(jankContainer, {
      updateInterval: 200,
      styles: {
        backgroundColor: '#f5f5f5',
        textColor: '#333',
        gridColor: '#ccc',
        frameBarColor: '#4CAF50',
        jankBarColors: {
          minor: '#FFC107',
          moderate: '#FF9800',
          severe: '#F44336'
        }
      }
    });
  }
  
  endPerformanceMark('chart-examples-init');
  
  console.log('Chart examples initialized successfully');
} 