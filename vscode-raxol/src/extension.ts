import * as vscode from 'vscode';
import { RaxolPreviewProvider } from './previewProvider';
import { RaxolComponentsProvider } from './componentsProvider';
import { RaxolTerminalManager } from './terminalManager';
import { RaxolProjectManager } from './projectManager';
import { RaxolCodeLensProvider } from './codeLensProvider';
import { RaxolCompletionProvider } from './completionProvider';
import { RaxolDefinitionProvider } from './definitionProvider';
import { RaxolHoverProvider } from './hoverProvider';

let raxolTerminal: RaxolTerminalManager;
let previewProvider: RaxolPreviewProvider;
let componentsProvider: RaxolComponentsProvider;
let projectManager: RaxolProjectManager;

export function activate(context: vscode.ExtensionContext) {
    console.log('Raxol extension is now active');

    // Initialize providers
    raxolTerminal = new RaxolTerminalManager();
    previewProvider = new RaxolPreviewProvider(context);
    componentsProvider = new RaxolComponentsProvider();
    projectManager = new RaxolProjectManager();

    // Register webview provider for component preview
    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider(
            'raxolPreview',
            previewProvider,
            {
                webviewOptions: {
                    retainContextWhenHidden: true
                }
            }
        )
    );

    // Register tree data provider for components
    const componentsTree = vscode.window.createTreeView('raxolComponents', {
        treeDataProvider: componentsProvider,
        showCollapseAll: true
    });
    context.subscriptions.push(componentsTree);

    // Register language features
    const elixirSelector = { scheme: 'file', language: 'elixir' };
    const raxolSelector = { scheme: 'file', language: 'raxol' };

    // CodeLens provider
    context.subscriptions.push(
        vscode.languages.registerCodeLensProvider(
            elixirSelector,
            new RaxolCodeLensProvider()
        )
    );

    // Completion provider
    context.subscriptions.push(
        vscode.languages.registerCompletionItemProvider(
            elixirSelector,
            new RaxolCompletionProvider(),
            '.', ':', '@'
        ),
        vscode.languages.registerCompletionItemProvider(
            raxolSelector,
            new RaxolCompletionProvider(),
            '.', ':', '@'
        )
    );

    // Definition provider
    context.subscriptions.push(
        vscode.languages.registerDefinitionProvider(
            elixirSelector,
            new RaxolDefinitionProvider()
        ),
        vscode.languages.registerDefinitionProvider(
            raxolSelector,
            new RaxolDefinitionProvider()
        )
    );

    // Hover provider
    context.subscriptions.push(
        vscode.languages.registerHoverProvider(
            elixirSelector,
            new RaxolHoverProvider()
        ),
        vscode.languages.registerHoverProvider(
            raxolSelector,
            new RaxolHoverProvider()
        )
    );

    // Register commands
    registerCommands(context);

    // Auto-start REPL if enabled
    const config = vscode.workspace.getConfiguration('raxol');
    if (config.get('autoStartREPL')) {
        vscode.commands.executeCommand('raxol.openREPL');
    }

    // Watch for Raxol project files
    const watcher = vscode.workspace.createFileSystemWatcher('**/mix.exs');
    watcher.onDidCreate(() => {
        componentsProvider.refresh();
    });
    watcher.onDidChange(() => {
        componentsProvider.refresh();
    });
    context.subscriptions.push(watcher);
}

function registerCommands(context: vscode.ExtensionContext) {
    // Component playground command
    const startPlaygroundCommand = vscode.commands.registerCommand('raxol.startPlayground', () => {
        raxolTerminal.startPlayground();
    });

    // Interactive tutorial command
    const startTutorialCommand = vscode.commands.registerCommand('raxol.startTutorial', () => {
        raxolTerminal.startTutorial();
    });

    // Component preview command
    const previewCommand = vscode.commands.registerCommand('raxol.preview', () => {
        const editor = vscode.window.activeTextEditor;
        if (editor) {
            previewProvider.previewComponent(editor.document.uri);
        }
    });

    // New project command
    const newProjectCommand = vscode.commands.registerCommand('raxol.newProject', async () => {
        await projectManager.createNewProject();
    });

    // New component command
    const newComponentCommand = vscode.commands.registerCommand('raxol.newComponent', async (uri?: vscode.Uri) => {
        const targetFolder = uri || (vscode.workspace.workspaceFolders?.[0]?.uri);
        if (targetFolder) {
            await projectManager.createNewComponent(targetFolder);
        }
    });

    // Run tests command
    const runTestsCommand = vscode.commands.registerCommand('raxol.runTests', () => {
        raxolTerminal.runTests();
    });

    // Open REPL command
    const openREPLCommand = vscode.commands.registerCommand('raxol.openREPL', () => {
        raxolTerminal.openREPL();
    });

    // Show documentation command
    const showDocumentationCommand = vscode.commands.registerCommand('raxol.showDocumentation', () => {
        vscode.env.openExternal(vscode.Uri.parse('https://raxol.dev/docs'));
    });

    // Refresh components command
    const refreshComponentsCommand = vscode.commands.registerCommand('raxol.refreshComponents', () => {
        componentsProvider.refresh();
    });

    // Format component command
    const formatComponentCommand = vscode.commands.registerCommand('raxol.formatComponent', async () => {
        const editor = vscode.window.activeTextEditor;
        if (editor && editor.document.languageId === 'elixir') {
            await raxolTerminal.formatFile(editor.document.uri.fsPath);
        }
    });

    // Add all commands to subscriptions
    context.subscriptions.push(
        startPlaygroundCommand,
        startTutorialCommand,
        previewCommand,
        newProjectCommand,
        newComponentCommand,
        runTestsCommand,
        openREPLCommand,
        showDocumentationCommand,
        refreshComponentsCommand,
        formatComponentCommand
    );
}

export function deactivate() {
    if (raxolTerminal) {
        raxolTerminal.dispose();
    }
}