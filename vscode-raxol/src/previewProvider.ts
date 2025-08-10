import * as vscode from 'vscode';
import * as path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class RaxolPreviewProvider implements vscode.WebviewViewProvider {
    public static readonly viewType = 'raxolPreview';
    private _view?: vscode.WebviewView;

    constructor(private readonly _extensionContext: vscode.ExtensionContext) {}

    public resolveWebviewView(
        webviewView: vscode.WebviewView,
        context: vscode.WebviewViewResolveContext,
        _token: vscode.CancellationToken
    ) {
        this._view = webviewView;

        webviewView.webview.options = {
            enableScripts: true,
            localResourceRoots: [this._extensionContext.extensionUri]
        };

        webviewView.webview.html = this._getHtmlForWebview(webviewView.webview);

        webviewView.webview.onDidReceiveMessage(
            message => {
                switch (message.command) {
                    case 'refresh':
                        this.refreshPreview();
                        break;
                    case 'changeTheme':
                        this.changeTheme(message.theme);
                        break;
                }
            },
            undefined,
            this._extensionContext.subscriptions
        );
    }

    public async previewComponent(uri: vscode.Uri) {
        if (!this._view) {
            vscode.window.showErrorMessage('Preview panel not available');
            return;
        }

        const componentContent = await this.extractComponentFromFile(uri);
        if (componentContent) {
            const preview = await this.generatePreview(componentContent);
            this._view.webview.postMessage({
                command: 'updatePreview',
                content: preview
            });
        }
    }

    private async extractComponentFromFile(uri: vscode.Uri): Promise<string | null> {
        try {
            const document = await vscode.workspace.openTextDocument(uri);
            const content = document.getText();
            
            // Look for Raxol component patterns
            const componentMatch = content.match(/defmodule\s+([^\\s]+)\s+do[\\s\\S]*?use\\s+Raxol\\.Component[\\s\\S]*?def\\s+render[\\s\\S]*?end/);
            
            if (componentMatch) {
                return componentMatch[0];
            }
            
            return null;
        } catch (error) {
            console.error('Error extracting component:', error);
            return null;
        }
    }

    private async generatePreview(componentContent: string): Promise<string> {
        try {
            const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
            if (!workspaceFolder) {
                return '<div class="error">No workspace folder found</div>';
            }

            // Create a temporary file with the component
            const tempFilePath = path.join(workspaceFolder.uri.fsPath, 'tmp_preview_component.ex');
            await vscode.workspace.fs.writeFile(
                vscode.Uri.file(tempFilePath),
                Buffer.from(componentContent)
            );

            // Use mix to compile and preview the component
            const { stdout, stderr } = await execAsync(
                'mix raxol.playground --preview --component-file tmp_preview_component.ex',
                { cwd: workspaceFolder.uri.fsPath }
            );

            // Clean up temp file
            try {
                await vscode.workspace.fs.delete(vscode.Uri.file(tempFilePath));
            } catch (error) {
                // Ignore cleanup errors
            }

            if (stderr) {
                return `<div class="error">Preview Error: ${this.escapeHtml(stderr)}</div>`;
            }

            return this.formatPreviewOutput(stdout);
        } catch (error) {
            return `<div class="error">Failed to generate preview: ${this.escapeHtml(error instanceof Error ? error.message : String(error))}</div>`;
        }
    }

    private formatPreviewOutput(output: string): string {
        // Convert ANSI escape codes to HTML
        const ansiMap: { [key: string]: string } = {
            '\\x1b[0m': '</span>',
            '\\x1b[1m': '<span class="bold">',
            '\\x1b[3m': '<span class="italic">',
            '\\x1b[4m': '<span class="underline">',
            '\\x1b[30m': '<span class="color-black">',
            '\\x1b[31m': '<span class="color-red">',
            '\\x1b[32m': '<span class="color-green">',
            '\\x1b[33m': '<span class="color-yellow">',
            '\\x1b[34m': '<span class="color-blue">',
            '\\x1b[35m': '<span class="color-magenta">',
            '\\x1b[36m': '<span class="color-cyan">',
            '\\x1b[37m': '<span class="color-white">',
        };

        let htmlOutput = this.escapeHtml(output);
        
        Object.keys(ansiMap).forEach(ansi => {
            const htmlTag = ansiMap[ansi];
            htmlOutput = htmlOutput.replace(new RegExp(ansi.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'g'), htmlTag);
        });

        return `<pre class="preview-content">${htmlOutput}</pre>`;
    }

    private escapeHtml(unsafe: string): string {
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    private async refreshPreview() {
        const editor = vscode.window.activeTextEditor;
        if (editor) {
            await this.previewComponent(editor.document.uri);
        }
    }

    private async changeTheme(theme: string) {
        const config = vscode.workspace.getConfiguration('raxol');
        await config.update('previewTheme', theme, vscode.ConfigurationTarget.Workspace);
        await this.refreshPreview();
    }

    private _getHtmlForWebview(webview: vscode.Webview): string {
        const codiconsUri = webview.asWebviewUri(
            vscode.Uri.joinPath(this._extensionContext.extensionUri, 'node_modules', '@vscode/codicons', 'dist', 'codicon.css')
        );

        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="${codiconsUri}" rel="stylesheet" />
    <title>Raxol Component Preview</title>
    <style>
        body {
            font-family: var(--vscode-font-family);
            font-size: var(--vscode-font-size);
            color: var(--vscode-foreground);
            background: var(--vscode-editor-background);
            margin: 0;
            padding: 16px;
        }
        
        .toolbar {
            display: flex;
            gap: 8px;
            margin-bottom: 16px;
            padding-bottom: 8px;
            border-bottom: 1px solid var(--vscode-panel-border);
        }
        
        .toolbar button {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        
        .toolbar button:hover {
            background: var(--vscode-button-hoverBackground);
        }
        
        .toolbar select {
            background: var(--vscode-dropdown-background);
            color: var(--vscode-dropdown-foreground);
            border: 1px solid var(--vscode-dropdown-border);
            padding: 4px 8px;
            border-radius: 4px;
        }
        
        .preview-container {
            background: var(--vscode-editor-background);
            border: 1px solid var(--vscode-panel-border);
            border-radius: 4px;
            overflow: auto;
            max-height: 600px;
        }
        
        .preview-content {
            font-family: 'Courier New', Courier, monospace;
            white-space: pre-wrap;
            margin: 0;
            padding: 16px;
            background: #000;
            color: #fff;
        }
        
        .error {
            color: var(--vscode-errorForeground);
            background: var(--vscode-inputValidation-errorBackground);
            padding: 8px;
            border-radius: 4px;
            margin: 8px 0;
        }
        
        .loading {
            color: var(--vscode-descriptionForeground);
            font-style: italic;
            text-align: center;
            padding: 32px;
        }
        
        /* ANSI color classes */
        .color-black { color: #000; }
        .color-red { color: #f44336; }
        .color-green { color: #4caf50; }
        .color-yellow { color: #ffeb3b; }
        .color-blue { color: #2196f3; }
        .color-magenta { color: #e91e63; }
        .color-cyan { color: #00bcd4; }
        .color-white { color: #fff; }
        .bold { font-weight: bold; }
        .italic { font-style: italic; }
        .underline { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="toolbar">
        <button onclick="refreshPreview()">
            <i class="codicon codicon-refresh"></i> Refresh
        </button>
        <select onchange="changeTheme(this.value)">
            <option value="default">Default Theme</option>
            <option value="dark">Dark Theme</option>
            <option value="light">Light Theme</option>
        </select>
    </div>
    
    <div class="preview-container">
        <div class="loading">Select a Raxol component to preview</div>
    </div>

    <script>
        const vscode = acquireVsCodeApi();

        function refreshPreview() {
            vscode.postMessage({ command: 'refresh' });
        }

        function changeTheme(theme) {
            vscode.postMessage({ command: 'changeTheme', theme: theme });
        }

        window.addEventListener('message', event => {
            const message = event.data;
            switch (message.command) {
                case 'updatePreview':
                    document.querySelector('.preview-container').innerHTML = message.content;
                    break;
            }
        });
    </script>
</body>
</html>`;
    }
}