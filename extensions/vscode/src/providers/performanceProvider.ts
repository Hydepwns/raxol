import * as vscode from 'vscode';
import * as path from 'path';

export class PerformanceTreeItem extends vscode.TreeItem {
  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public readonly type: 'file' | 'metric' | 'category',
    public readonly value?: string,
    public readonly filePath?: string
  ) {
    super(label, collapsibleState);
    
    if (filePath) {
      this.tooltip = `${label}: ${value || 'N/A'}`;
      this.command = {
        command: 'vscode.open',
        arguments: [vscode.Uri.file(filePath)],
        title: 'Open File'
      };
    }
    
    // Set icon based on type
    switch (type) {
      case 'file':
        this.iconPath = new vscode.ThemeIcon('file');
        break;
      case 'metric':
        this.iconPath = new vscode.ThemeIcon('dashboard');
        break;
      case 'category':
        this.iconPath = new vscode.ThemeIcon('folder');
        break;
    }
    
    // Add performance value if available
    if (value !== undefined) {
      this.description = value;
    }
  }
}

export class PerformanceProvider implements vscode.TreeDataProvider<PerformanceTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<PerformanceTreeItem | undefined | null | void> = new vscode.EventEmitter<PerformanceTreeItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<PerformanceTreeItem | undefined | null | void> = this._onDidChangeTreeData.event;
  
  private performanceData: Map<string, any> = new Map();

  constructor() {
    this.loadPerformanceData();
  }

  refresh(): void {
    this.loadPerformanceData();
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: PerformanceTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: PerformanceTreeItem): Thenable<PerformanceTreeItem[]> {
    if (!vscode.workspace.workspaceFolders) {
      vscode.window.showInformationMessage('No folder opened');
      return Promise.resolve([]);
    }

    if (!element) {
      // Root level - show performance categories
      return Promise.resolve([
        new PerformanceTreeItem(
          'Component Performance',
          vscode.TreeItemCollapsibleState.Expanded,
          'category'
        ),
        new PerformanceTreeItem(
          'Memory Usage',
          vscode.TreeItemCollapsibleState.Collapsed,
          'category'
        ),
        new PerformanceTreeItem(
          'Event Handling',
          vscode.TreeItemCollapsibleState.Collapsed,
          'category'
        )
      ]);
    } else if (element.label === 'Component Performance') {
      // Show component performance metrics
      return this.getComponentPerformanceItems();
    }

    return Promise.resolve([]);
  }

  private async getComponentPerformanceItems(): Promise<PerformanceTreeItem[]> {
    const items: PerformanceTreeItem[] = [];
    
    // This would be replaced with actual performance data in a real implementation
    // For now, we'll use mock data
    const mockPerformanceData = [
      { component: 'Dashboard', render: '12ms', update: '8ms', path: 'src/components/Dashboard.ts' },
      { component: 'Chart', render: '28ms', update: '15ms', path: 'src/components/Chart.ts' },
      { component: 'Table', render: '18ms', update: '10ms', path: 'src/components/Table.ts' }
    ];
    
    for (const data of mockPerformanceData) {
      items.push(
        new PerformanceTreeItem(
          data.component,
          vscode.TreeItemCollapsibleState.Collapsed,
          'file',
          `Render: ${data.render}, Update: ${data.update}`,
          data.path
        )
      );
    }
    
    return items;
  }
  
  private loadPerformanceData(): void {
    // In a real implementation, this would load performance data from project files
    // For now, we'll use mock data
    this.performanceData.clear();
    
    // Mock data
    this.performanceData.set('Dashboard', {
      renderTime: '12ms',
      updateTime: '8ms',
      memoryUsage: '2.4MB'
    });
    
    this.performanceData.set('Chart', {
      renderTime: '28ms',
      updateTime: '15ms',
      memoryUsage: '5.8MB'
    });
    
    this.performanceData.set('Table', {
      renderTime: '18ms',
      updateTime: '10ms',
      memoryUsage: '3.2MB'
    });
  }
} 