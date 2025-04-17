"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RaxolPanelManager = void 0;
const vscode = require("vscode");
// import * as path from 'path'; // Unused
const fs = require("fs"); // Import the 'fs' module
const backendManager_1 = require("./backendManager");
/**
 * Manages the Raxol Terminal webview panel.
 */
class RaxolPanelManager {
    static createOrShow(context) {
        const column = vscode.window.activeTextEditor
            ? vscode.window.activeTextEditor.viewColumn
            : undefined;
        if (RaxolPanelManager.currentPanel) {
            RaxolPanelManager.currentPanel.panel.reveal(column);
            return;
        }
        const panel = vscode.window.createWebviewPanel('raxolTerminal', 'Raxol Terminal', column || vscode.ViewColumn.One, {
            enableScripts: true,
            retainContextWhenHidden: true,
            localResourceRoots: [
                vscode.Uri.joinPath(context.extensionUri, 'media') // For potential future CSS/JS
            ],
        });
        RaxolPanelManager.currentPanel = new RaxolPanelManager(panel, context);
    }
    constructor(panel, context) {
        this.disposables = [];
        this.panel = panel;
        this.extensionContext = context;
        // Create and manage the backend process
        this.backendManager = new backendManager_1.BackendManager(context);
        // Set initial HTML content by loading from file
        this.updateWebviewContent(); // Use a new method to load/update content
        // Set up listeners
        this.setupListeners();
        // Start the backend process
        this.backendManager.start();
    }
    setupListeners() {
        // Listen for when the panel is disposed
        this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
        // Handle messages from the webview
        this.panel.webview.onDidReceiveMessage((message) => {
            console.log("[PanelManager] Received from webview:", message);
            this.handleWebviewMessage(message);
        }, null, this.disposables);
        // Handle messages from the backend manager
        this.backendManager.on('message', (message) => {
            // Forward backend messages to the webview
            console.log("[PanelManager] Forwarding to webview:", message);
            this.panel.webview.postMessage(message);
        });
        // Handle status updates from the backend manager
        this.backendManager.on('status', (status) => {
            let statusText = 'Unknown Status';
            let isError = false;
            switch (status) {
                case 'connecting':
                    statusText = 'Connecting to backend...';
                    // Send initialize message once backend process is spawned
                    this.sendInitializeMessage();
                    break;
                case 'connected': // We'll infer this from receiving 'initialized'
                    // Status is handled by 'initialized' and 'ui_update' messages
                    return; // Don't send a generic 'connected' status update
                case 'stopped':
                    statusText = 'Backend stopped.';
                    break;
                case 'crashed':
                    statusText = 'Backend crashed unexpectedly.';
                    isError = true;
                    break;
                case 'error':
                    statusText = 'Backend connection error.';
                    isError = true;
                    break;
            }
            // Send status update message to webview
            this.panel.webview.postMessage({ type: 'status_update', payload: { text: statusText, isError: isError } });
        });
        // Handle raw stdout/stderr for debugging
        this.backendManager.on('stdout_data', (data) => {
            console.log("Backend stdout:", data);
        });
        this.backendManager.on('stderr_data', (data) => {
            console.error("Backend stderr:", data);
        });
    }
    handleWebviewMessage(message) {
        switch (message.command) {
            case 'userInput':
                this.backendManager.sendMessage({ type: 'user_input', payload: message.payload });
                break;
            case 'resize':
                this.backendManager.sendMessage({ type: 'resize_panel', payload: message.payload });
                break;
            // Add other commands as needed
            default:
                console.warn('Received unknown command from webview:', message.command);
        }
    }
    sendInitializeMessage() {
        const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '.';
        // TODO: Get actual panel dimensions if possible
        const initialWidth = 80;
        const initialHeight = 24;
        const extensionVersion = this.extensionContext.extension.packageJSON.version;
        this.backendManager.sendMessage({
            type: 'initialize',
            payload: {
                workspaceRoot,
                initialWidth,
                initialHeight,
                extensionVersion
            }
        });
    }
    /**
     * Loads the base HTML from the file, injects resource URIs and nonce, and sets it on the webview.
     */
    updateWebviewContent() {
        const webview = this.panel.webview;
        const extensionUri = this.extensionContext.extensionUri;
        // Construct URIs for resources
        const scriptPathOnDisk = vscode.Uri.joinPath(extensionUri, 'media', 'main.js');
        const scriptUri = webview.asWebviewUri(scriptPathOnDisk);
        const stylePathOnDisk = vscode.Uri.joinPath(extensionUri, 'media', 'styles.css');
        const styleUri = webview.asWebviewUri(stylePathOnDisk);
        // Path to the HTML file
        const htmlPathOnDisk = vscode.Uri.joinPath(extensionUri, 'media', 'index.html');
        // Use a nonce to only allow specific scripts to be run
        const nonce = getNonce();
        try {
            // Read the HTML file content
            let htmlContent = fs.readFileSync(htmlPathOnDisk.fsPath, 'utf8');
            // Replace placeholders with actual URIs and nonce
            htmlContent = htmlContent.replace(/{{styleUri}}/g, styleUri.toString());
            htmlContent = htmlContent.replace(/{{scriptUri}}/g, scriptUri.toString());
            htmlContent = htmlContent.replace(/{{nonce}}/g, nonce);
            // Replace CSP source placeholder
            htmlContent = htmlContent.replace(/{{webview.cspSource}}/g, webview.cspSource);
            // Set the final HTML content
            webview.html = htmlContent;
            console.log("Webview HTML updated from file.");
        }
        catch (error) {
            console.error('Error loading webview HTML:', error);
            webview.html = `<html><body>Error loading webview content. Please check logs.</body></html>`;
        }
    }
    dispose() {
        RaxolPanelManager.currentPanel = undefined;
        // Stop the backend process
        this.backendManager.stop();
        // Clean up resources
        this.panel.dispose();
        while (this.disposables.length) {
            const x = this.disposables.pop();
            if (x) {
                x.dispose();
            }
        }
    }
}
exports.RaxolPanelManager = RaxolPanelManager;
// Helper function to generate a nonce
function getNonce() {
    let text = '';
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    for (let i = 0; i < 32; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
}
//# sourceMappingURL=raxolPanelManager.js.map