"use strict";
/**
 * Component Previewer Feature
 *
 * This feature allows for real-time preview of Raxol components directly in VS Code.
 * It provides a WebView-based preview panel that can render components with mock props.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.ComponentPreviewer = void 0;
const vscode = require("vscode");
const path = require("path");
const fs = require("fs");
/**
 * Component preview panel manager
 */
class ComponentPreviewer {
    /**
     * Create and show the preview panel
     */
    static createOrShow(extensionContext) {
        const column = vscode.window.activeTextEditor
            ? vscode.window.activeTextEditor.viewColumn
            : undefined;
        // If we already have a panel, show it
        if (ComponentPreviewer.currentPanel) {
            ComponentPreviewer.currentPanel.reveal(column);
            return;
        }
        // Otherwise, create a new panel
        const panel = vscode.window.createWebviewPanel('raxolComponentPreview', 'Raxol Component Preview', column || vscode.ViewColumn.Two, {
            enableScripts: true,
            retainContextWhenHidden: true,
            localResourceRoots: [
                vscode.Uri.file(path.join(extensionContext.extensionPath, 'media')),
                vscode.Uri.file(path.join(extensionContext.extensionPath, 'node_modules'))
            ]
        });
        ComponentPreviewer.currentPanel = panel;
    }
    /**
     * Preview a specific component file
     */
    static previewComponent(extensionContext, filePath) {
        ComponentPreviewer.createOrShow(extensionContext);
        if (ComponentPreviewer.currentPanel) {
            ComponentPreviewer.currentPanel.webview.postMessage({ command: 'getInitialData', filePath });
        }
    }
    /**
     * Constructor
     */
    constructor(panel, extensionContext) {
        this.panel = panel;
        // Set the webview's initial html content
        this.updateHtml();
        // Listen for when the panel is disposed
        this.panel.onDidDispose(() => this.dispose(), null, extensionContext.subscriptions);
        // Update the content based on view changes
        this.panel.onDidChangeViewState(() => {
            if (this.panel.visible) {
                this.updateHtml();
            }
        }, null, extensionContext.subscriptions);
        // Handle messages from the webview
        this.panel.webview.onDidReceiveMessage(message => {
            switch (message.command) {
                case 'alert':
                    vscode.window.showErrorMessage(message.text);
                    return;
                case 'refresh':
                    this.update();
                    return;
                case 'updateProps':
                    this.updateHtml(message.props);
                    return;
                case 'getInitialData':
                    this.update(message.filePath);
                    return;
            }
        }, undefined, extensionContext.subscriptions);
    }
    /**
     * Update the preview for a specific file
     */
    update(filePath) {
        if (filePath) {
            this.componentFile = filePath;
        }
        // Update the panel title if we have a component file
        if (this.componentFile) {
            const fileName = path.basename(this.componentFile);
            this.panel.title = `Preview: ${fileName}`;
        }
        this.updateHtml();
    }
    /**
     * Update the HTML content of the preview
     */
    updateHtml(props) {
        if (!this.componentFile) {
            this.panel.webview.html = this.getPlaceholderHtml();
            return;
        }
        try {
            // Read the component file
            const fileContent = fs.readFileSync(this.componentFile, 'utf8');
            // Extract component class name
            const componentMatch = fileContent.match(/class\s+([^\s]+)\s+extends\s+RaxolComponent/);
            const componentName = componentMatch ? componentMatch[1] : 'UnknownComponent';
            // Extract props interface
            const propsMatch = fileContent.match(/interface\s+([^\s]+Props)\s*\{([^}]+)\}/);
            const propsInterface = propsMatch ? { name: propsMatch[1], content: propsMatch[2] } : null;
            // Generate mock props based on props interface
            const mockProps = props || this.generateMockProps(propsInterface?.content);
            // Update the webview content
            this.panel.webview.html = this.getWebviewContent(componentName, mockProps);
        }
        catch (error) {
            this.panel.webview.html = this.getErrorHtml(error);
        }
    }
    /**
     * Generate simple placeholder HTML
     */
    getPlaceholderHtml() {
        return `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Raxol Component Preview</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            color: #333;
          }
          .placeholder {
            text-align: center;
            padding: 40px;
            border: 1px dashed #ccc;
            border-radius: 4px;
          }
        </style>
      </head>
      <body>
        <div class="placeholder">
          <h2>No Component Selected</h2>
          <p>Open a Raxol component file and use the context menu to preview it.</p>
        </div>
      </body>
      </html>
    `;
    }
    /**
     * Generate HTML content for an error
     */
    getErrorHtml(error) {
        return `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Raxol Component Preview - Error</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            color: #333;
          }
          .error {
            padding: 20px;
            background-color: #ffebee;
            border: 1px solid #f44336;
            border-radius: 4px;
          }
          .error-message {
            color: #f44336;
            font-weight: bold;
          }
          pre {
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            overflow: auto;
          }
        </style>
      </head>
      <body>
        <div class="error">
          <h2 class="error-message">Error Loading Component</h2>
          <p>${error.message}</p>
          <pre>${error.stack}</pre>
        </div>
      </body>
      </html>
    `;
    }
    /**
     * Generate mock props based on a props interface
     */
    generateMockProps(propsInterface) {
        if (!propsInterface) {
            return {};
        }
        const mockProps = {};
        // Extract property definitions
        const propRegex = /(\w+)(\??):\s*([^;]+);/g;
        let match;
        while ((match = propRegex.exec(propsInterface)) !== null) {
            const [_, propName, optional, propType] = match;
            // Skip optional props half the time to simulate variation
            if (optional && Math.random() > 0.5) {
                continue;
            }
            // Generate mock value based on type
            if (propType.includes('string')) {
                mockProps[propName] = `Sample ${propName}`;
            }
            else if (propType.includes('number')) {
                mockProps[propName] = Math.floor(Math.random() * 100);
            }
            else if (propType.includes('boolean')) {
                mockProps[propName] = Math.random() > 0.5;
            }
            else if (propType.includes('[]') || propType.includes('Array')) {
                mockProps[propName] = [1, 2, 3].map(i => `Item ${i}`);
            }
            else if (propType.includes('{') || propType.includes('object')) {
                mockProps[propName] = { id: 1, name: 'Sample Object' };
            }
            else if (propType.includes('Function') || propType.includes('=>')) {
                mockProps[propName] = () => console.log(`${propName} called`);
            }
        }
        return mockProps;
    }
    /**
     * Generate the HTML content for the webview
     */
    getWebviewContent(componentName, mockProps) {
        const mockPropsJson = JSON.stringify(mockProps, (_key, value) => {
            if (typeof value === 'function') {
                return '[Function]';
            }
            return value;
        }, 2);
        return `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Raxol Component Preview: ${componentName}</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            height: 100vh;
            overflow: hidden;
          }
          .preview-container {
            flex: 1;
            display: flex;
            flex-direction: column;
            overflow: hidden;
          }
          .toolbar {
            background-color: #f5f5f5;
            border-bottom: 1px solid #ddd;
            padding: 10px;
            display: flex;
            align-items: center;
          }
          .preview-area {
            flex: 1;
            padding: 20px;
            overflow: auto;
            background-color: #fff;
          }
          .props-panel {
            width: 300px;
            border-left: 1px solid #ddd;
            padding: 10px;
            overflow: auto;
            background-color: #f9f9f9;
          }
          .props-title {
            margin-top: 0;
            padding-bottom: 8px;
            border-bottom: 1px solid #ddd;
          }
          .component-name {
            font-weight: bold;
            margin-right: 10px;
          }
          .preview-shell {
            border: 1px dashed #ddd;
            padding: 20px;
            border-radius: 4px;
            margin-bottom: 20px;
          }
          button {
            background-color: #007acc;
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 2px;
            cursor: pointer;
            margin-left: 10px;
          }
          button:hover {
            background-color: #005999;
          }
          .props-editor {
            width: 100%;
            height: 300px;
            font-family: monospace;
            border: 1px solid #ddd;
            padding: 8px;
            margin-top: 10px;
          }
        </style>
      </head>
      <body>
        <div class="preview-container">
          <div class="toolbar">
            <span class="component-name">${componentName}</span>
            <button id="refreshBtn">Refresh</button>
            <button id="togglePropsBtn">Toggle Props Panel</button>
          </div>
          <div class="preview-area">
            <div class="preview-shell">
              <div id="component-preview">
                <!-- Component preview will be rendered here -->
                <p>Component would render here in a real implementation.</p>
                <p>This is a visual placeholder for ${componentName}.</p>
              </div>
            </div>
          </div>
        </div>
        <div class="props-panel" id="props-panel">
          <h3 class="props-title">Component Props</h3>
          <p>Edit the props below and click "Apply" to update the preview:</p>
          <textarea id="props-editor" class="props-editor">${mockPropsJson}</textarea>
          <button id="applyPropsBtn">Apply Props</button>
        </div>

        <script>
          const vscode = acquireVsCodeApi();

          // Handle refresh button
          document.getElementById('refreshBtn').addEventListener('click', () => {
            vscode.postMessage({ command: 'refresh' });
          });

          // Handle props panel toggle
          document.getElementById('togglePropsBtn').addEventListener('click', () => {
            const panel = document.getElementById('props-panel');
            panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
          });

          // Handle apply props button
          document.getElementById('applyPropsBtn').addEventListener('click', () => {
            try {
              const propsText = document.getElementById('props-editor').value;
              const props = JSON.parse(propsText);
              vscode.postMessage({
                command: 'updateProps',
                props: props
              });
            } catch (error) {
              vscode.postMessage({
                command: 'alert',
                text: 'Invalid JSON: ' + error.message
              });
            }
          });
        </script>
      </body>
      </html>
    `;
    }
    /**
     * Dispose of resources
     */
    dispose() {
        ComponentPreviewer.currentPanel = undefined;
        // Clean up resources
        this.panel.dispose();
    }
}
exports.ComponentPreviewer = ComponentPreviewer;
//# sourceMappingURL=componentPreviewer.js.map