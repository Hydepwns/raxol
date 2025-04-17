import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export class ComponentTreeItem extends vscode.TreeItem {
  constructor(
    public readonly label: string,
    public readonly collapsibleState: vscode.TreeItemCollapsibleState,
    public readonly filePath?: string
  ) {
    super(label, collapsibleState);
    
    if (filePath) {
      this.tooltip = filePath;
      this.command = {
        command: 'vscode.open',
        arguments: [vscode.Uri.file(filePath)],
        title: 'Open Component'
      };
      this.iconPath = new vscode.ThemeIcon('symbol-class');
    } else {
      this.iconPath = new vscode.ThemeIcon('folder');
    }
  }
}

export class ComponentProvider implements vscode.TreeDataProvider<ComponentTreeItem> {
  private _onDidChangeTreeData: vscode.EventEmitter<ComponentTreeItem | undefined | null | void> = new vscode.EventEmitter<ComponentTreeItem | undefined | null | void>();
  readonly onDidChangeTreeData: vscode.Event<ComponentTreeItem | undefined | null | void> = this._onDidChangeTreeData.event;

  constructor() {}

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: ComponentTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: ComponentTreeItem): Thenable<ComponentTreeItem[]> {
    if (!vscode.workspace.workspaceFolders) {
      vscode.window.showInformationMessage('No folder opened');
      return Promise.resolve([]);
    }

    if (!element) {
      return this.getRootComponents();
    }

    // If it's a folder element, find child components
    return Promise.resolve([]);
  }

  private async getRootComponents(): Promise<ComponentTreeItem[]> {
    const components: ComponentTreeItem[] = [];
    
    if (!vscode.workspace.workspaceFolders) {
      return components;
    }
    
    const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;
    
    // Look for component directories
    const srcPath = path.join(workspaceRoot, 'src', 'components');
    
    if (fs.existsSync(srcPath)) {
      // Find all component files
      try {
        const files = await vscode.workspace.findFiles(
          'src/components/**/*.{ts,tsx,js,jsx}',
          '**/node_modules/**'
        );
        
        for (const file of files) {
          const content = await fs.promises.readFile(file.fsPath, 'utf8');
          
          // Check if file contains a Raxol component
          if (content.includes('extends') && 
              (content.includes('RaxolComponent') || content.includes('Component'))) {
            
            const fileName = path.basename(file.fsPath);
            components.push(
              new ComponentTreeItem(
                fileName,
                vscode.TreeItemCollapsibleState.None,
                file.fsPath
              )
            );
          }
        }
      } catch (err) {
        console.error('Error finding components:', err);
      }
    }
    
    return components;
  }
} 