/**
 * VisualizationDemoApp.ts
 * 
 * A demo application that showcases the Raxol visualization components.
 */

import { runChartExamples } from './visualization/ChartExample';
import { runTreeMapExamples } from './visualization/TreeMapExample';

/**
 * Create navigation tabs for the demo app
 */
function createNavigation(): void {
  const navContainer = document.createElement('div');
  navContainer.style.display = 'flex';
  navContainer.style.borderBottom = '1px solid #ddd';
  navContainer.style.marginBottom = '20px';
  navContainer.style.padding = '0 20px';
  
  const tabs = [
    { id: 'charts', label: 'Charts', active: true },
    { id: 'treemap', label: 'TreeMap', active: false },
    { id: 'dashboard', label: 'Dashboard', active: false }
  ];
  
  tabs.forEach(tab => {
    const tabElement = document.createElement('div');
    tabElement.id = `tab-${tab.id}`;
    tabElement.className = 'nav-tab';
    tabElement.textContent = tab.label;
    tabElement.style.padding = '12px 20px';
    tabElement.style.cursor = 'pointer';
    tabElement.style.fontWeight = tab.active ? 'bold' : 'normal';
    tabElement.style.borderBottom = tab.active ? '3px solid #4285F4' : 'none';
    tabElement.style.color = tab.active ? '#4285F4' : '#333';
    
    tabElement.addEventListener('click', () => {
      // Set all tabs inactive
      document.querySelectorAll('.nav-tab').forEach(el => {
        (el as HTMLElement).style.fontWeight = 'normal';
        (el as HTMLElement).style.borderBottom = 'none';
        (el as HTMLElement).style.color = '#333';
      });
      
      // Set this tab active
      tabElement.style.fontWeight = 'bold';
      tabElement.style.borderBottom = '3px solid #4285F4';
      tabElement.style.color = '#4285F4';
      
      // Show corresponding content
      showContent(tab.id);
    });
    
    navContainer.appendChild(tabElement);
  });
  
  document.body.appendChild(navContainer);
}

/**
 * Create content containers for each tab
 */
function createContentContainers(): void {
  const ids = ['charts', 'treemap', 'dashboard'];
  
  ids.forEach(id => {
    const container = document.createElement('div');
    container.id = `content-${id}`;
    container.style.display = id === 'charts' ? 'block' : 'none';
    document.body.appendChild(container);
  });
}

/**
 * Show content for the selected tab
 */
function showContent(tabId: string): void {
  const containers = ['charts', 'treemap', 'dashboard'];
  
  containers.forEach(id => {
    const container = document.getElementById(`content-${id}`);
    if (container) {
      container.style.display = id === tabId ? 'block' : 'none';
      
      // Load content if not already loaded
      if (id === tabId && container.dataset.loaded !== 'true') {
        loadTabContent(id, container);
        container.dataset.loaded = 'true';
      }
    }
  });
}

/**
 * Load content for a specific tab
 */
function loadTabContent(tabId: string, container: HTMLElement): void {
  // Clear any existing content
  container.innerHTML = '';
  
  switch (tabId) {
    case 'charts':
      const chartsTitle = document.createElement('h1');
      chartsTitle.textContent = 'Raxol Charts Demo';
      chartsTitle.style.textAlign = 'center';
      chartsTitle.style.margin = '20px 0';
      container.appendChild(chartsTitle);
      
      // Load chart examples
      runChartExamples();
      break;
      
    case 'treemap':
      const treemapTitle = document.createElement('h1');
      treemapTitle.textContent = 'Raxol TreeMap Demo';
      treemapTitle.style.textAlign = 'center';
      treemapTitle.style.margin = '20px 0';
      container.appendChild(treemapTitle);
      
      // Load treemap examples
      runTreeMapExamples();
      break;
      
    case 'dashboard':
      const dashboardTitle = document.createElement('h1');
      dashboardTitle.textContent = 'Data Visualization Dashboard';
      dashboardTitle.style.textAlign = 'center';
      dashboardTitle.style.margin = '20px 0';
      container.appendChild(dashboardTitle);
      
      // Create a placeholder dashboard
      const dashboardContent = document.createElement('div');
      dashboardContent.innerHTML = `
        <div style="text-align: center; padding: 50px; color: #666; background: #f5f5f5; border-radius: 8px; margin: 20px;">
          <h2>Coming Soon</h2>
          <p>The integrated dashboard will be available in a future update.</p>
          <p>This will showcase how multiple visualization components can work together.</p>
        </div>
      `;
      container.appendChild(dashboardContent);
      break;
  }
}

/**
 * Create header for the demo app
 */
function createHeader(): void {
  const header = document.createElement('header');
  header.style.backgroundColor = '#f8f9fa';
  header.style.padding = '20px';
  header.style.textAlign = 'center';
  header.style.borderBottom = '1px solid #e0e0e0';
  
  const logo = document.createElement('h1');
  logo.textContent = 'Raxol Visualization';
  logo.style.margin = '0';
  logo.style.fontSize = '24px';
  logo.style.color = '#333';
  
  const description = document.createElement('p');
  description.textContent = 'A demonstration of the visualization components for the Raxol framework';
  description.style.margin = '10px 0 0 0';
  description.style.color = '#666';
  
  header.appendChild(logo);
  header.appendChild(description);
  document.body.appendChild(header);
}

/**
 * Create footer for the demo app
 */
function createFooter(): void {
  const footer = document.createElement('footer');
  footer.style.backgroundColor = '#f8f9fa';
  footer.style.padding = '20px';
  footer.style.textAlign = 'center';
  footer.style.borderTop = '1px solid #e0e0e0';
  footer.style.marginTop = '40px';
  
  const text = document.createElement('p');
  text.textContent = 'Raxol Framework - Data Visualization Components';
  text.style.margin = '0';
  text.style.color = '#666';
  
  footer.appendChild(text);
  document.body.appendChild(footer);
}

/**
 * Initialize styles for the demo app
 */
function initializeStyles(): void {
  // Reset body styles
  document.body.style.margin = '0';
  document.body.style.padding = '0';
  document.body.style.fontFamily = 'Arial, sans-serif';
  document.body.style.color = '#333';
  document.body.style.backgroundColor = '#fff';
  
  // Create a style element for global styles
  const styleElement = document.createElement('style');
  styleElement.textContent = `
    * {
      box-sizing: border-box;
    }
    
    .nav-tab:hover {
      background-color: #f5f5f5;
    }
  `;
  
  document.head.appendChild(styleElement);
}

/**
 * Run the visualization demo app
 */
export function runVisualizationDemoApp(): void {
  console.log('Starting Visualization Demo App');
  
  // Initialize basic styles
  initializeStyles();
  
  // Create app structure
  createHeader();
  createNavigation();
  createContentContainers();
  createFooter();
  
  // Load the default tab content
  const defaultContainer = document.getElementById('content-charts');
  if (defaultContainer) {
    loadTabContent('charts', defaultContainer);
    defaultContainer.dataset.loaded = 'true';
  }
  
  console.log('Visualization Demo App initialized');
} 