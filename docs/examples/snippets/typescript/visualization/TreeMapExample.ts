/**
 * TreeMapExample.ts
 * 
 * Demonstrates how to use the Raxol TreeMap component for hierarchical data visualization
 */

import { TreeMap, TreeMapNode, TreeMapOptions } from '../../components/visualization/TreeMap';
import { startPerformanceMark, endPerformanceMark, startJankDetection } from '../../core/performance';

/**
 * Generate sample hierarchical data for the treemap
 */
function generateSampleData(): TreeMapNode {
  // File system example data
  return {
    id: 'root',
    name: 'File System',
    value: 0, // Will be calculated from children
    children: [
      {
        id: 'documents',
        name: 'Documents',
        value: 0,
        children: [
          {
            id: 'work',
            name: 'Work',
            value: 0,
            children: [
              { id: 'presentations', name: 'Presentations', value: 720 },
              { id: 'reports', name: 'Reports', value: 550 },
              { id: 'spreadsheets', name: 'Spreadsheets', value: 350 }
            ]
          },
          {
            id: 'personal',
            name: 'Personal',
            value: 0,
            children: [
              { id: 'photos', name: 'Photos', value: 1200 },
              { id: 'recipes', name: 'Recipes', value: 90 },
              { id: 'tax', name: 'Tax Documents', value: 200 }
            ]
          },
          { id: 'resume', name: 'Resume.docx', value: 2 }
        ]
      },
      {
        id: 'media',
        name: 'Media',
        value: 0,
        children: [
          { id: 'movies', name: 'Movies', value: 3200 },
          { id: 'music', name: 'Music', value: 1800 },
          { id: 'podcasts', name: 'Podcasts', value: 600 }
        ]
      },
      {
        id: 'applications',
        name: 'Applications',
        value: 0,
        children: [
          { id: 'development', name: 'Development', value: 1500 },
          { id: 'utilities', name: 'Utilities', value: 800 },
          { id: 'games', name: 'Games', value: 2800 }
        ]
      },
      {
        id: 'system',
        name: 'System',
        value: 1200
      }
    ]
  };
}

/**
 * Generate alternative dataset (market share by industry)
 */
function generateMarketShareData(): TreeMapNode {
  return {
    id: 'markets',
    name: 'Global Market Share by Industry',
    value: 0,
    children: [
      {
        id: 'tech',
        name: 'Technology',
        value: 0,
        children: [
          { id: 'hard', name: 'Hardware', value: 780, color: '#4285F4' },
          { id: 'soft', name: 'Software', value: 850, color: '#5E97F6' },
          { id: 'cloud', name: 'Cloud Services', value: 920, color: '#8AB4F8' },
          { id: 'semi', name: 'Semiconductors', value: 530, color: '#C6DAFC' }
        ]
      },
      {
        id: 'fin',
        name: 'Financial',
        value: 0,
        children: [
          { id: 'bank', name: 'Banking', value: 1100, color: '#EA4335' },
          { id: 'ins', name: 'Insurance', value: 680, color: '#EB786F' },
          { id: 'invest', name: 'Investment', value: 780, color: '#FCBCB8' }
        ]
      },
      {
        id: 'health',
        name: 'Healthcare',
        value: 0,
        children: [
          { id: 'pharma', name: 'Pharmaceuticals', value: 940, color: '#34A853' },
          { id: 'equip', name: 'Medical Equipment', value: 410, color: '#71C287' },
          { id: 'service', name: 'Health Services', value: 740, color: '#ACDBBD' }
        ]
      },
      {
        id: 'retail',
        name: 'Retail',
        value: 0,
        children: [
          { id: 'online', name: 'E-commerce', value: 720, color: '#FBBC05' },
          { id: 'brick', name: 'Brick & Mortar', value: 530, color: '#FCE19B' }
        ]
      },
      {
        id: 'energy',
        name: 'Energy',
        value: 0,
        children: [
          { id: 'oil', name: 'Oil & Gas', value: 810, color: '#FF6D01' },
          { id: 'renew', name: 'Renewable', value: 380, color: '#FFAD78' }
        ]
      }
    ]
  };
}

/**
 * Calculate total values for parent nodes based on children
 * This ensures the treemap sizes are based on leaf node values
 */
function calculateNodeValues(node: TreeMapNode): number {
  if (!node.children || node.children.length === 0) {
    return node.value;
  }
  
  let totalValue = 0;
  for (const child of node.children) {
    totalValue += calculateNodeValues(child);
  }
  
  node.value = totalValue;
  return totalValue;
}

/**
 * Create and set up treemap containers
 */
function createContainers(): {
  fileSystemContainer: HTMLElement;
  marketShareContainer: HTMLElement;
  controlsContainer: HTMLElement;
} {
  // Main container
  const mainContainer = document.createElement('div');
  mainContainer.style.fontFamily = 'Arial, sans-serif';
  mainContainer.style.padding = '20px';
  mainContainer.style.display = 'flex';
  mainContainer.style.flexDirection = 'column';
  mainContainer.style.gap = '20px';
  
  // Page title
  const title = document.createElement('h1');
  title.textContent = 'Raxol TreeMap Component Example';
  title.style.textAlign = 'center';
  title.style.margin = '0 0 20px 0';
  
  // TreeMaps container
  const treemapsContainer = document.createElement('div');
  treemapsContainer.style.display = 'grid';
  treemapsContainer.style.gridTemplateColumns = 'repeat(2, 1fr)';
  treemapsContainer.style.gap = '20px';
  
  // Create individual treemap containers
  const fileSystemContainer = document.createElement('div');
  fileSystemContainer.style.height = '400px';
  fileSystemContainer.style.border = '1px solid #ddd';
  fileSystemContainer.style.borderRadius = '4px';
  fileSystemContainer.style.overflow = 'hidden';
  
  const marketShareContainer = document.createElement('div');
  marketShareContainer.style.height = '400px';
  marketShareContainer.style.border = '1px solid #ddd';
  marketShareContainer.style.borderRadius = '4px';
  marketShareContainer.style.overflow = 'hidden';
  
  // Controls container
  const controlsContainer = document.createElement('div');
  controlsContainer.style.padding = '15px';
  controlsContainer.style.backgroundColor = '#f5f5f5';
  controlsContainer.style.borderRadius = '4px';
  
  // Add to main container
  treemapsContainer.appendChild(fileSystemContainer);
  treemapsContainer.appendChild(marketShareContainer);
  
  mainContainer.appendChild(title);
  mainContainer.appendChild(treemapsContainer);
  mainContainer.appendChild(controlsContainer);
  
  // Add to document
  document.body.appendChild(mainContainer);
  
  return {
    fileSystemContainer,
    marketShareContainer,
    controlsContainer
  };
}

/**
 * Create controls for manipulating the treemap
 */
function createControls(
  controlsContainer: HTMLElement, 
  fileSystemTreemap: TreeMap, 
  marketShareTreemap: TreeMap
): void {
  // Controls title
  const controlsTitle = document.createElement('h2');
  controlsTitle.textContent = 'TreeMap Controls';
  controlsTitle.style.marginTop = '0';
  
  // Button container
  const buttonContainer = document.createElement('div');
  buttonContainer.style.display = 'flex';
  buttonContainer.style.gap = '10px';
  buttonContainer.style.flexWrap = 'wrap';
  buttonContainer.style.marginBottom = '15px';
  
  // Add buttons for various actions
  const actions = [
    { text: 'Toggle Labels', id: 'toggle-labels' },
    { text: 'Change Colors', id: 'change-colors' },
    { text: 'Toggle Dark Mode', id: 'toggle-theme' },
    { text: 'Increase Padding', id: 'increase-padding' },
    { text: 'Decrease Padding', id: 'decrease-padding' }
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
  
  // Selected node info
  const infoContainer = document.createElement('div');
  infoContainer.style.marginTop = '15px';
  infoContainer.style.padding = '10px';
  infoContainer.style.border = '1px solid #ddd';
  infoContainer.style.borderRadius = '4px';
  infoContainer.style.backgroundColor = '#fff';
  
  const infoTitle = document.createElement('h3');
  infoTitle.textContent = 'Selected Node';
  infoTitle.style.margin = '0 0 10px 0';
  
  const infoContent = document.createElement('div');
  infoContent.id = 'selected-node-info';
  infoContent.textContent = 'No node selected';
  
  infoContainer.appendChild(infoTitle);
  infoContainer.appendChild(infoContent);
  
  // Add everything to controls container
  controlsContainer.appendChild(controlsTitle);
  controlsContainer.appendChild(buttonContainer);
  controlsContainer.appendChild(infoContainer);
  
  // Set up event handlers
  setupControlEvents(fileSystemTreemap, marketShareTreemap);
}

/**
 * Set up event handlers for controls
 */
function setupControlEvents(fileSystemTreemap: TreeMap, marketShareTreemap: TreeMap): void {
  const toggleLabelsBtn = document.getElementById('toggle-labels');
  const changeColorsBtn = document.getElementById('change-colors');
  const toggleThemeBtn = document.getElementById('toggle-theme');
  const increasePaddingBtn = document.getElementById('increase-padding');
  const decreasePaddingBtn = document.getElementById('decrease-padding');
  
  let showLabels = true;
  let isDarkMode = false;
  let currentPadding = 2;
  
  // Toggle labels
  toggleLabelsBtn?.addEventListener('click', () => {
    showLabels = !showLabels;
    
    fileSystemTreemap.updateOptions({ showLabels });
    marketShareTreemap.updateOptions({ showLabels });
  });
  
  // Change colors
  changeColorsBtn?.addEventListener('click', () => {
    const colorSchemes = [
      [
        '#4285F4', '#EA4335', '#FBBC05', '#34A853', 
        '#FF6D01', '#46BDC6', '#7BAAF7', '#F07B72'
      ],
      [
        '#3949AB', '#D81B60', '#00897B', '#7CB342', 
        '#FFA000', '#5E35B1', '#039BE5', '#C62828'
      ],
      [
        '#1565C0', '#6A1B9A', '#2E7D32', '#EF6C00', 
        '#283593', '#4527A0', '#00695C', '#AD1457'
      ]
    ];
    
    // Rotate through color schemes
    const currentColors = fileSystemTreemap.getColors();
    let nextSchemeIndex = 0;
    
    if (currentColors.length > 0) {
      // Find current scheme
      for (let i = 0; i < colorSchemes.length; i++) {
        if (currentColors[0] === colorSchemes[i][0]) {
          nextSchemeIndex = (i + 1) % colorSchemes.length;
          break;
        }
      }
    }
    
    fileSystemTreemap.updateOptions({ colors: colorSchemes[nextSchemeIndex] });
  });
  
  // Toggle dark mode
  toggleThemeBtn?.addEventListener('click', () => {
    isDarkMode = !isDarkMode;
    
    document.body.style.backgroundColor = isDarkMode ? '#1a1a1a' : '#ffffff';
    document.body.style.color = isDarkMode ? '#e0e0e0' : '#333333';
    
    const controls = document.querySelector('div') as HTMLElement;
    if (controls) {
      controls.style.backgroundColor = isDarkMode ? '#333333' : '#f5f5f5';
    }
    
    const info = document.getElementById('selected-node-info')?.parentElement as HTMLElement;
    if (info) {
      info.style.backgroundColor = isDarkMode ? '#333333' : '#ffffff';
      info.style.borderColor = isDarkMode ? '#555555' : '#dddddd';
    }
  });
  
  // Increase padding
  increasePaddingBtn?.addEventListener('click', () => {
    currentPadding = Math.min(currentPadding + 1, 10);
    
    fileSystemTreemap.updateOptions({ padding: currentPadding });
    marketShareTreemap.updateOptions({ padding: currentPadding });
  });
  
  // Decrease padding
  decreasePaddingBtn?.addEventListener('click', () => {
    currentPadding = Math.max(currentPadding - 1, 0);
    
    fileSystemTreemap.updateOptions({ padding: currentPadding });
    marketShareTreemap.updateOptions({ padding: currentPadding });
  });
}

/**
 * Create file system treemap
 */
function createFileSystemTreemap(container: HTMLElement): TreeMap {
  // Get data and calculate values
  const data = generateSampleData();
  calculateNodeValues(data);
  
  const options: TreeMapOptions = {
    root: data,
    title: 'File System Storage (MB)',
    showLabels: true,
    padding: 2,
    tooltip: {
      enabled: true,
      formatter: (node) => {
        return `
          <div style="font-weight: bold;">${node.name}</div>
          <div>Size: ${node.value} MB</div>
          ${node.children ? `<div>Items: ${node.children.length}</div>` : ''}
        `;
      }
    },
    accessibility: {
      description: 'Treemap showing file system storage usage by category and file type',
      keyboardNavigation: true
    },
    events: {
      nodeClick: (node) => {
        updateSelectedNodeInfo(node);
        
        // Alert for demo purposes
        alert(`Clicked on "${node.name}" (${node.value} MB)`);
      }
    }
  };
  
  return new TreeMap(container, options);
}

/**
 * Create market share treemap
 */
function createMarketShareTreemap(container: HTMLElement): TreeMap {
  // Get data and calculate values
  const data = generateMarketShareData();
  calculateNodeValues(data);
  
  const options: TreeMapOptions = {
    root: data,
    title: 'Market Share by Industry (Billions)',
    showLabels: true,
    padding: 2,
    tooltip: {
      enabled: true,
      formatter: (node) => {
        return `
          <div style="font-weight: bold;">${node.name}</div>
          <div>Market Size: $${node.value}B</div>
          ${node.children ? `<div>Sectors: ${node.children.length}</div>` : ''}
        `;
      }
    },
    accessibility: {
      description: 'Treemap showing market share by industry sector and sub-sector',
      keyboardNavigation: true
    },
    events: {
      nodeHover: (node) => {
        if (node) {
          updateSelectedNodeInfo(node);
        }
      }
    }
  };
  
  return new TreeMap(container, options);
}

/**
 * Update selected node information in the UI
 */
function updateSelectedNodeInfo(node: TreeMapNode | null): void {
  const infoElement = document.getElementById('selected-node-info');
  if (!infoElement) return;
  
  if (!node) {
    infoElement.textContent = 'No node selected';
    return;
  }
  
  const hasChildren = node.children && node.children.length > 0;
  
  infoElement.innerHTML = `
    <div><strong>Name:</strong> ${node.name}</div>
    <div><strong>Value:</strong> ${node.value}</div>
    <div><strong>ID:</strong> ${node.id}</div>
    ${hasChildren ? `<div><strong>Children:</strong> ${node.children!.length}</div>` : ''}
  `;
}

/**
 * Main function to run the treemap examples
 */
export function runTreeMapExamples(): void {
  startPerformanceMark('treemap-examples-init');
  
  // Start jank detection
  startJankDetection();
  
  // Create containers
  const { fileSystemContainer, marketShareContainer, controlsContainer } = createContainers();
  
  // Create treemaps
  const fileSystemTreemap = createFileSystemTreemap(fileSystemContainer);
  const marketShareTreemap = createMarketShareTreemap(marketShareContainer);
  
  // Create controls
  createControls(controlsContainer, fileSystemTreemap, marketShareTreemap);
  
  // Handle window resize
  window.addEventListener('resize', () => {
    fileSystemTreemap.resize();
    marketShareTreemap.resize();
  });
  
  endPerformanceMark('treemap-examples-init');
  
  console.log('TreeMap examples initialized successfully');
} 