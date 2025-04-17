import * as vscode from "vscode";
import * as fs from "fs";
import { BackendManager } from "./BackendManager";

interface WebviewMessage {
  command: string;
  payload?: any;
}

interface BackendMessage {
  type: string;
  payload: any;
}

/**
 * Manages the Raxol Terminal webview panel.
 */
export class RaxolPanelManager {
  public static currentPanel: RaxolPanelManager | undefined;
  private readonly panel: vscode.WebviewPanel;
  private readonly extensionContext: vscode.ExtensionContext;
  private readonly backendManager: BackendManager;
  private disposables: vscode.Disposable[] = [];

  public static createOrShow(context: vscode.ExtensionContext): void {
    const column = vscode.window.activeTextEditor
      ? vscode.window.activeTextEditor.viewColumn
      : undefined;

    if (RaxolPanelManager.currentPanel) {
      RaxolPanelManager.currentPanel.panel.reveal(column);
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      "raxolTerminal",
      "Raxol Terminal",
      column || vscode.ViewColumn.One,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [
          vscode.Uri.joinPath(context.extensionUri, "media"),
        ],
      }
    );

    RaxolPanelManager.currentPanel = new RaxolPanelManager(panel, context);
  }

  private constructor(
    panel: vscode.WebviewPanel,
    context: vscode.ExtensionContext
  ) {
    this.panel = panel;
    this.extensionContext = context;

    // Create and manage the backend process
    this.backendManager = new BackendManager(context);

    // Set initial HTML content
    this.updateWebviewContent();

    // Set up listeners
    this.setupListeners();

    // Start the backend process
    this.backendManager.start();
  }

  private setupListeners(): void {
    // Listen for when the panel is disposed
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);

    // Handle messages from the webview
    this.panel.webview.onDidReceiveMessage(
      (message: WebviewMessage) => {
        console.log("[PanelManager] Received from webview:", message);
        this.handleWebviewMessage(message);
      },
      null,
      this.disposables
    );

    // Handle messages from the backend manager
    this.backendManager.on("message", (message: BackendMessage) => {
      // Forward backend messages to the webview
      console.log("[PanelManager] Forwarding to webview:", message);
      this.panel.webview.postMessage(message);
    });

    // Handle status updates from the backend manager
    this.backendManager.on("status", (status: string) => {
      let statusText = "Unknown Status";
      let isError = false;
      switch (status) {
        case "connecting":
          statusText = "Connecting to backend...";
          // Send initialize message once backend process is spawned
          this.sendInitializeMessage();
          break;
        case "connected":
          return; // Don't send a generic 'connected' status update
        case "stopped":
          statusText = "Backend stopped.";
          break;
        case "crashed":
          statusText = "Backend crashed unexpectedly.";
          isError = true;
          break;
        case "error":
          statusText = "Backend connection error.";
          isError = true;
          break;
      }
      // Send status update message to webview
      this.panel.webview.postMessage({
        type: "status_update",
        payload: { text: statusText, isError: isError },
      });
    });

    // Handle raw stdout/stderr for debugging
    this.backendManager.on("stdout_data", (data: string) => {
      console.log("Backend stdout:", data);
    });
    this.backendManager.on("stderr_data", (data: string) => {
      console.error("Backend stderr:", data);
    });
  }

  private handleWebviewMessage(message: WebviewMessage): void {
    switch (message.command) {
      case "userInput":
        this.backendManager.sendMessage({
          type: "user_input",
          payload: message.payload,
        });
        break;
      case "resize":
        this.backendManager.sendMessage({
          type: "resize_panel",
          payload: message.payload,
        });
        break;
      default:
        console.warn("Received unknown command from webview:", message.command);
    }
  }

  private sendInitializeMessage(): void {
    const workspaceRoot =
      vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? ".";
    const initialWidth = 80;
    const initialHeight = 24;
    const extensionVersion =
      this.extensionContext.extension.packageJSON.version;

    this.backendManager.sendMessage({
      type: "initialize",
      payload: {
        workspaceRoot,
        initialWidth,
        initialHeight,
        extensionVersion,
      },
    });
  }

  /**
   * Loads the base HTML from the file, injects resource URIs and nonce, and sets it on the webview.
   */
  private updateWebviewContent(): void {
    const webview = this.panel.webview;
    const extensionUri = this.extensionContext.extensionUri;

    // Construct URIs for resources
    const scriptPathOnDisk = vscode.Uri.joinPath(
      extensionUri,
      "media",
      "main.js"
    );
    const scriptUri = webview.asWebviewUri(scriptPathOnDisk);

    const stylePathOnDisk = vscode.Uri.joinPath(
      extensionUri,
      "media",
      "styles.css"
    );
    const styleUri = webview.asWebviewUri(stylePathOnDisk);

    // Path to the HTML file
    const htmlPathOnDisk = vscode.Uri.joinPath(
      extensionUri,
      "media",
      "index.html"
    );

    // Use a nonce to only allow specific scripts to be run
    const nonce = getNonce();

    try {
      // Read the HTML file content
      let htmlContent = fs.readFileSync(htmlPathOnDisk.fsPath, "utf8");

      // Replace placeholders with actual URIs and nonce
      htmlContent = htmlContent.replace(/{{styleUri}}/g, styleUri.toString());
      htmlContent = htmlContent.replace(/{{scriptUri}}/g, scriptUri.toString());
      htmlContent = htmlContent.replace(/{{nonce}}/g, nonce);
      // Replace CSP source placeholder
      htmlContent = htmlContent.replace(
        /{{webview.cspSource}}/g,
        webview.cspSource
      );

      // Set the final HTML content
      webview.html = htmlContent;
      console.log("Webview HTML updated from file.");
    } catch (error) {
      console.error("Error loading webview HTML:", error);
      webview.html = `<html><body>Error loading webview content. Please check logs.</body></html>`;
    }
  }

  public dispose(): void {
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

// Helper function to generate a nonce
function getNonce() {
  let text = "";
  const possible =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (let i = 0; i < 32; i++) {
    text += possible.charAt(Math.floor(Math.random() * possible.length));
  }
  return text;
}
