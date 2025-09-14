import * as vscode from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
  // Register Raxol commands
  registerCommands(context);
  
  // Start LSP server if enabled
  const config = vscode.workspace.getConfiguration('raxol');
  if (config.get('lsp.enabled')) {
    startLanguageServer(context);
  }

  // Set up file watchers for Raxol-specific files
  setupFileWatchers(context);
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}

function registerCommands(context: vscode.ExtensionContext) {
  // Start/Restart LSP Server
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.startLSP', () => {
      startLanguageServer(context);
      vscode.window.showInformationMessage('Raxol LSP Server started');
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.restartLSP', () => {
      if (client) {
        client.stop().then(() => {
          startLanguageServer(context);
          vscode.window.showInformationMessage('Raxol LSP Server restarted');
        });
      }
    })
  );

  // Generate Component
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.generateComponent', async (uri) => {
      const componentName = await vscode.window.showInputBox({
        prompt: 'Enter component name',
        placeHolder: 'MyComponent'
      });

      if (componentName) {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (workspaceFolder) {
          const terminal = vscode.window.createTerminal('Raxol Generator');
          terminal.sendText(`cd "${workspaceFolder.uri.fsPath}"`);
          terminal.sendText(`mix raxol.gen.component ${componentName}`);
          terminal.show();
        }
      }
    })
  );

  // Open Component Playground
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.openPlayground', () => {
      const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
      if (workspaceFolder) {
        const terminal = vscode.window.createTerminal('Raxol Playground');
        terminal.sendText(`cd "${workspaceFolder.uri.fsPath}"`);
        terminal.sendText('mix raxol.playground');
        terminal.show();
      }
    })
  );
}

function startLanguageServer(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('raxol');
  const lspPath = config.get<string>('lsp.path', 'mix');
  const lspArgs = config.get<string[]>('lsp.args', ['raxol.lsp', '--stdio']);

  const serverOptions: ServerOptions = {
    run: { command: lspPath, args: lspArgs, transport: TransportKind.stdio },
    debug: { command: lspPath, args: lspArgs, transport: TransportKind.stdio }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: 'file', language: 'elixir' },
      { scheme: 'file', language: 'eex' },
      { scheme: 'file', language: 'heex' }
    ],
    synchronize: {
      fileEvents: [
        vscode.workspace.createFileSystemWatcher('**/*.ex'),
        vscode.workspace.createFileSystemWatcher('**/*.exs'),
        vscode.workspace.createFileSystemWatcher('**/*.eex'),
        vscode.workspace.createFileSystemWatcher('**/*.heex'),
        vscode.workspace.createFileSystemWatcher('**/mix.exs'),
        vscode.workspace.createFileSystemWatcher('**/.raxol.exs')
      ]
    },
    initializationOptions: {
      raxol: {
        version: '1.0.0',
        features: {
          completion: config.get('completion.enabled'),
          diagnostics: config.get('diagnostics.enabled')
        }
      }
    }
  };

  client = new LanguageClient(
    'raxolLanguageServer',
    'Raxol Language Server',
    serverOptions,
    clientOptions
  );

  // Start the client and server
  client.start().then(() => {
    console.log('Raxol Language Server started');
    
    // Register additional client capabilities
    registerClientCapabilities();
  });
}

function registerClientCapabilities() {
  // Handle custom LSP notifications from Raxol server
  client.onNotification('raxol/componentValidation', (params) => {
    // Handle component validation results
    console.log('Component validation:', params);
  });

  client.onNotification('raxol/frameworkDetected', (params) => {
    // Handle framework detection
    vscode.window.showInformationMessage(
      `Raxol detected ${params.framework} framework`
    );
  });
}

function setupFileWatchers(context: vscode.ExtensionContext) {
  // Watch for new Raxol component files
  const componentWatcher = vscode.workspace.createFileSystemWatcher(
    '**/lib/**/components/**/*.ex'
  );

  componentWatcher.onDidCreate((uri) => {
    // Automatically add component boilerplate if file is empty
    vscode.workspace.openTextDocument(uri).then((doc) => {
      if (doc.getText().trim() === '') {
        suggestComponentTemplate(doc);
      }
    });
  });

  context.subscriptions.push(componentWatcher);

  // Watch for .raxol.exs configuration changes
  const configWatcher = vscode.workspace.createFileSystemWatcher('**/.raxol.exs');
  
  configWatcher.onDidChange(() => {
    // Restart LSP server when configuration changes
    if (client) {
      vscode.commands.executeCommand('raxol.restartLSP');
    }
  });

  context.subscriptions.push(configWatcher);
}

async function suggestComponentTemplate(document: vscode.TextDocument) {
  const action = await vscode.window.showInformationMessage(
    'Generate Raxol component boilerplate?',
    'Yes', 'No'
  );

  if (action === 'Yes') {
    const fileName = document.fileName.split('/').pop()?.replace('.ex', '') || 'Component';
    const componentName = pascalCase(fileName);
    
    const template = generateComponentTemplate(componentName);
    
    const edit = new vscode.WorkspaceEdit();
    edit.insert(document.uri, new vscode.Position(0, 0), template);
    vscode.workspace.applyEdit(edit);
  }
}

function generateComponentTemplate(componentName: string): string {
  return `defmodule ${componentName} do
  @moduledoc """
  ${componentName} component.
  """

  use Raxol.UI.Components.Base.Component

  def init(props) do
    Map.merge(%{}, props)
  end

  def mount(state) do
    {state, []}
  end

  def update(message, state) do
    # Handle component messages here
    state
  end

  def render(state, context) do
    # Render component UI here
    text("${componentName}")
  end

  def handle_event(event, state, context) do
    # Handle UI events here
    {state, []}
  end
end
`;
}

function pascalCase(str: string): string {
  return str
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join('');
}