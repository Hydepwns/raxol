import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { ComponentProvider } from './providers/componentProvider';
import { PerformanceProvider } from './providers/performanceProvider';

interface Providers {
  componentProvider: ComponentProvider;
  performanceProvider: PerformanceProvider;
}

export function registerCommands(context: vscode.ExtensionContext, providers: Providers): void {
  // Command: Create new component
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.newComponent', async () => {
      const componentName = await vscode.window.showInputBox({
        prompt: 'Enter component name',
        placeHolder: 'ComponentName'
      });

      if (!componentName) {
        return; // User cancelled
      }

      // Create component
      createComponent(componentName);

      // Refresh component explorer
      providers.componentProvider.refresh();
    })
  );

  // Command: Analyze performance
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.analyze', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('No active editor');
        return;
      }

      // Show mock analysis for now
      showPerformanceAnalysis(editor.document);

      // Refresh performance view
      providers.performanceProvider.refresh();
    })
  );

  // Command: Optimize component
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.optimize', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('No active editor');
        return;
      }

      // Show optimization suggestions
      showOptimizationSuggestions(editor.document);
    })
  );
}

async function createComponent(componentName: string): Promise<void> {
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (!workspaceFolders) {
    vscode.window.showErrorMessage('No workspace folder open');
    return;
  }

  const workspaceRoot = workspaceFolders[0].uri.fsPath;
  const componentsDir = path.join(workspaceRoot, 'src', 'components');

  // Ensure components directory exists
  if (!fs.existsSync(componentsDir)) {
    fs.mkdirSync(componentsDir, { recursive: true });
  }

  const componentPath = path.join(componentsDir, `${componentName}.ts`);

  // Check if component already exists
  if (fs.existsSync(componentPath)) {
    vscode.window.showErrorMessage(`Component ${componentName} already exists`);
    return;
  }

  // Create component file
  const componentContent = `/**
 * ${componentName}.ts
 *
 * A Raxol component for [description]
 */

import { RaxolComponent } from '../../core/component';
import { View } from '../../core/view';

export class ${componentName} extends RaxolComponent {
  constructor() {
    super();

    // Initialize component state
    this.state = {
      // Add your state properties here
    };
  }

  /**
   * Renders the component
   */
  render() {
    return View.box({
      children: [
        View.text('${componentName} Component')
      ]
    });
  }
}
`;

  fs.writeFileSync(componentPath, componentContent);

  // Open the new component file
  const document = await vscode.workspace.openTextDocument(componentPath);
  await vscode.window.showTextDocument(document);

  vscode.window.showInformationMessage(`Component ${componentName} created`);
}

function showPerformanceAnalysis(document: vscode.TextDocument): void {
  // This would be replaced with actual analysis in a real implementation
  const panel = vscode.window.createWebviewPanel(
    'raxolPerformance',
    'Performance Analysis',
    vscode.ViewColumn.Beside,
    {}
  );

  const fileName = path.basename(document.fileName);

  panel.webview.html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Performance Analysis</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 15px; }
        .metric { margin-bottom: 15px; }
        .metric-name { font-weight: bold; }
        .metric-value { font-size: 1.2em; }
        .good { color: green; }
        .warning { color: orange; }
        .critical { color: red; }
      </style>
    </head>
    <body>
      <h1>Performance Analysis: ${fileName}</h1>

      <div class="metric">
        <div class="metric-name">Render Time</div>
        <div class="metric-value warning">22ms</div>
        <div class="metric-desc">Component re-renders might be optimized</div>
      </div>

      <div class="metric">
        <div class="metric-name">Memory Usage</div>
        <div class="metric-value good">4.2MB</div>
        <div class="metric-desc">Memory usage is within acceptable range</div>
      </div>

      <div class="metric">
        <div class="metric-name">Event Handlers</div>
        <div class="metric-value warning">8 handlers found</div>
        <div class="metric-desc">Consider consolidating event handlers</div>
      </div>

      <h2>Recommendations</h2>
      <ul>
        <li>Use memoization for expensive calculations</li>
        <li>Optimize renderText function on line 24</li>
        <li>Consider using a pooling system for frequently created objects</li>
      </ul>
    </body>
    </html>
  `;
}

function showOptimizationSuggestions(document: vscode.TextDocument): void {
  const fileName = path.basename(document.fileName);

  // In a real implementation, this would analyze the code and provide suggestions
  const suggestionsPanel = vscode.window.createWebviewPanel(
    'raxolOptimizations',
    'Optimization Suggestions',
    vscode.ViewColumn.Beside,
    {}
  );

  suggestionsPanel.webview.html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Optimization Suggestions</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 15px; }
        .suggestion { margin-bottom: 20px; border-left: 4px solid #007bff; padding-left: 15px; }
        .suggestion-title { font-weight: bold; margin-bottom: 5px; }
        .suggestion-desc { margin-bottom: 10px; }
        .code { background-color: #f5f5f5; padding: 10px; font-family: monospace; border-radius: 4px; }
        .before { border-left: 2px solid red; }
        .after { border-left: 2px solid green; }
      </style>
    </head>
    <body>
      <h1>Optimization Suggestions: ${fileName}</h1>

      <div class="suggestion">
        <div class="suggestion-title">Use Memoization for Expensive Calculations</div>
        <div class="suggestion-desc">
          The calculation in <code>calculateTotal</code> is performed on every render.
          Consider memoizing this value to improve performance.
        </div>
        <div class="code before">
          <div>// Before</div>
          <pre>calculateTotal() {
  return this.items.reduce((sum, item) => sum + item.value, 0);
}</pre>
        </div>
        <div class="code after">
          <div>// After</div>
          <pre>calculateTotal() {
  if (this.cachedTotal && !this.isDirty) {
    return this.cachedTotal;
  }

  this.cachedTotal = this.items.reduce(
    (sum, item) => sum + item.value, 0
  );
  this.isDirty = false;
  return this.cachedTotal;
}</pre>
        </div>
      </div>

      <div class="suggestion">
        <div class="suggestion-title">Optimize Event Handling</div>
        <div class="suggestion-desc">
          Multiple redundant event handlers are created.
          Consider consolidating or using event delegation.
        </div>
        <div class="code before">
          <div>// Before</div>
          <pre>render() {
  return View.box({
    children: this.items.map(item =>
      View.box({
        onClick: () => this.handleItemClick(item),
        children: [View.text(item.name)]
      })
    )
  });
}</pre>
        </div>
        <div class="code after">
          <div>// After</div>
          <pre>render() {
  return View.box({
    onClick: (e) => this.handleItemClick(e),
    children: this.items.map(item =>
      View.box({
        data: { itemId: item.id },
        children: [View.text(item.name)]
      })
    )
  });
}</pre>
        </div>
      </div>
    </body>
    </html>
  `;
}
