/**
 * State Inspector Feature
 *
 * This feature allows for real-time inspection of Raxol component state.
 * It provides a WebView-based panel that can display and track state changes.
 */

import * as vscode from 'vscode';
import * as path from 'path';

/**
 * State inspector panel manager
 */
export class StateInspector {
  /**
   * Current inspector panel
   */
  private static currentPanel: StateInspector | undefined;

  /**
   * VS Code webview panel
   */
  private readonly panel: vscode.WebviewPanel;

  /**
   * Disposables for cleanup
   */
  private disposables: vscode.Disposable[] = [];

  /**
   * State history
   */
  private stateHistory: { timestamp: number; state: any }[] = [];

  /**
   * The maximum number of state entries to keep
   */
  private readonly maxHistoryEntries = 50;

  /**
   * Create and show the inspector panel
   */
  public static createOrShow(context: vscode.ExtensionContext): void {
    const column = vscode.window.activeTextEditor
      ? vscode.ViewColumn.Beside
      : undefined;

    // If we already have a panel, show it
    if (StateInspector.currentPanel) {
      StateInspector.currentPanel.panel.reveal(column);
      return;
    }

    // Otherwise, create a new panel
    const panel = vscode.window.createWebviewPanel(
      'raxolStateInspector',
      'Raxol State Inspector',
      column || vscode.ViewColumn.Three,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [
          vscode.Uri.file(path.join(context.extensionPath, 'media')),
          vscode.Uri.file(path.join(context.extensionPath, 'node_modules'))
        ]
      }
    );

    StateInspector.currentPanel = new StateInspector(panel);
  }

  /**
   * Constructor
   */
  private constructor(panel: vscode.WebviewPanel) {
    this.panel = panel;

    // Set the webview's initial html content
    this.updateContent();

    // Listen for when the panel is disposed
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);

    // Handle messages from the webview
    this.panel.webview.onDidReceiveMessage(
      message => {
        switch (message.command) {
          case 'clearHistory':
            this.clearHistory();
            return;
          case 'filterState':
            this.updateContent(message.filter);
            return;
          case 'exportState':
            this.exportStateHistory();
            return;
        }
      },
      null,
      this.disposables
    );
  }

  /**
   * Add a new state entry to the history
   */
  public addState(state: any): void {
    // Create a new state entry
    const entry = {
      timestamp: Date.now(),
      state: JSON.parse(JSON.stringify(state)) // Deep clone to avoid reference issues
    };

    // Add to history
    this.stateHistory.unshift(entry);

    // Trim history if needed
    if (this.stateHistory.length > this.maxHistoryEntries) {
      this.stateHistory = this.stateHistory.slice(0, this.maxHistoryEntries);
    }

    // Update the panel
    this.updateContent();
  }

  /**
   * Clear the state history
   */
  private clearHistory(): void {
    this.stateHistory = [];
    this.updateContent();
  }

  /**
   * Export state history to a JSON file
   */
  private async exportStateHistory(): Promise<void> {
    try {
      // Get save location from user
      const uri = await vscode.window.showSaveDialog({
        defaultUri: vscode.Uri.file('state-history.json'),
        filters: {
          'JSON Files': ['json']
        }
      });

      if (uri) {
        // Convert state history to JSON
        const stateJson = JSON.stringify(this.stateHistory, null, 2);

        // Write to file using VS Code API
        await vscode.workspace.fs.writeFile(uri, Buffer.from(stateJson, 'utf8'));

        vscode.window.showInformationMessage('State history exported successfully');
      }
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to export state history: ${(error as Error).message}`);
    }
  }

  /**
   * Update the panel content
   */
  private updateContent(filter?: string): void {
    // Apply filter if provided
    const filteredHistory = filter
      ? this.stateHistory.filter(entry =>
          JSON.stringify(entry.state).toLowerCase().includes(filter.toLowerCase())
        )
      : this.stateHistory;

    this.panel.webview.html = this.getWebviewContent(filteredHistory, filter);
  }

  /**
   * Generate the HTML content for the webview
   */
  private getWebviewContent(stateHistory: { timestamp: number; state: any }[], filter?: string): string {
    const historyJson = JSON.stringify(stateHistory);

    return `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Raxol State Inspector</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            color: #333;
            display: flex;
            flex-direction: column;
            height: 100vh;
            overflow: hidden;
          }
          .toolbar {
            background-color: #f5f5f5;
            border-bottom: 1px solid #ddd;
            padding: 10px;
            display: flex;
            align-items: center;
          }
          .main-content {
            display: flex;
            flex: 1;
            overflow: hidden;
          }
          .history-list {
            width: 250px;
            border-right: 1px solid #ddd;
            overflow-y: auto;
            background-color: #f9f9f9;
          }
          .state-viewer {
            flex: 1;
            padding: 10px;
            overflow: auto;
          }
          .history-item {
            padding: 8px 12px;
            border-bottom: 1px solid #eee;
            cursor: pointer;
          }
          .history-item:hover {
            background-color: #e9e9e9;
          }
          .history-item.selected {
            background-color: #007acc;
            color: white;
          }
          .timestamp {
            font-size: 0.8em;
            color: #666;
          }
          .selected .timestamp {
            color: #ddd;
          }
          .placeholder {
            text-align: center;
            padding: 20px;
            color: #999;
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
          input[type="text"] {
            padding: 6px;
            border: 1px solid #ddd;
            border-radius: 2px;
            flex: 1;
            max-width: 300px;
          }
          pre {
            margin: 0;
            white-space: pre-wrap;
          }
          .json-key {
            color: #881391;
          }
          .json-string {
            color: #1c6b48;
          }
          .json-number {
            color: #1a1aa6;
          }
          .json-boolean {
            color: #1a1aa6;
          }
          .json-null {
            color: #5a5a5a;
          }
        </style>
      </head>
      <body>
        <div class="toolbar">
          <input
            type="text"
            id="filterInput"
            placeholder="Filter state..."
            value="${filter || ''}"
          >
          <button id="clearBtn">Clear History</button>
          <button id="exportBtn">Export</button>
        </div>
        <div class="main-content">
          <div class="history-list" id="historyList">
            ${this.renderHistoryList(stateHistory)}
          </div>
          <div class="state-viewer" id="stateViewer">
            <div class="placeholder">Select a state entry to view details</div>
          </div>
        </div>

        <script>
          const vscode = acquireVsCodeApi();
          const stateHistory = ${historyJson};
          let selectedIndex = -1;

          // Initialize the UI
          function initialize() {
            // Set up filter input
            document.getElementById('filterInput').addEventListener('input', (e) => {
              vscode.postMessage({
                command: 'filterState',
                filter: e.target.value
              });
            });

            // Set up clear button
            document.getElementById('clearBtn').addEventListener('click', () => {
              vscode.postMessage({ command: 'clearHistory' });
            });

            // Set up export button
            document.getElementById('exportBtn').addEventListener('click', () => {
              vscode.postMessage({ command: 'exportState' });
            });

            // Set up history item selection
            const historyItems = document.querySelectorAll('.history-item');
            historyItems.forEach((item, index) => {
              item.addEventListener('click', () => {
                selectHistoryItem(index);
              });
            });

            // Select the first item if available
            if (historyItems.length > 0) {
              selectHistoryItem(0);
            }
          }

          // Format JSON with syntax highlighting
          function formatJson(json) {
            if (typeof json !== 'string') {
              json = JSON.stringify(json, null, 2);
            }

            return json.replace(/("(\\\\u[a-zA-Z0-9]{4}|\\\\[^u]|[^\\\\"])*"(\\s*:)?|\\b(true|false|null)\\b|-?\\d+(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?)/g, function (match) {
              let cls = 'json-number';
              if (/^"/.test(match)) {
                if (/:$/.test(match)) {
                  cls = 'json-key';
                } else {
                  cls = 'json-string';
                }
              } else if (/true|false/.test(match)) {
                cls = 'json-boolean';
              } else if (/null/.test(match)) {
                cls = 'json-null';
              }
              return '<span class="' + cls + '">' + match + '</span>';
            });
          }

          // Select a history item
          function selectHistoryItem(index) {
            // Remove selection from previous item
            if (selectedIndex !== -1) {
              const previousItem = document.getElementById('history-item-' + selectedIndex);
              if (previousItem) {
                previousItem.classList.remove('selected');
              }
            }

            selectedIndex = index;

            // Add selection to new item
            const selectedItem = document.getElementById('history-item-' + index);
            if (selectedItem) {
              selectedItem.classList.add('selected');

              // Show state details
              const stateViewer = document.getElementById('stateViewer');
              const stateData = stateHistory[index].state;
              const formattedJson = formatJson(JSON.stringify(stateData, null, 2));

              stateViewer.innerHTML = '<pre>' + formattedJson + '</pre>';
            }
          }

          // Initialize when the document is ready
          document.addEventListener('DOMContentLoaded', initialize);

          // Call initialize immediately as well (in case DOMContentLoaded already fired)
          initialize();
        </script>
      </body>
      </html>
    `;
  }

  /**
   * Render the history list
   */
  private renderHistoryList(stateHistory: { timestamp: number; state: any }[]): string {
    if (stateHistory.length === 0) {
      return '<div class="placeholder">No state changes recorded yet</div>';
    }

    return stateHistory.map((entry, index) => {
      const date = new Date(entry.timestamp);
      const timeString = date.toLocaleTimeString();

      return `
        <div class="history-item" id="history-item-${index}">
          <div>State Update #${stateHistory.length - index}</div>
          <div class="timestamp">${timeString}</div>
        </div>
      `;
    }).join('');
  }

  /**
   * Dispose of resources
   */
  private dispose(): void {
    StateInspector.currentPanel = undefined;

    // Clean up resources
    this.panel.dispose();

    while (this.disposables.length) {
      const disposable = this.disposables.pop();
      if (disposable) {
        disposable.dispose();
      }
    }
  }
}
