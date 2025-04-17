"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = require("vscode");
const componentProvider_1 = require("./providers/componentProvider");
const performanceProvider_1 = require("./providers/performanceProvider");
const commands_1 = require("./commands");
const componentPreviewer_1 = require("./features/componentPreviewer");
const stateInspector_1 = require("./features/stateInspector");
const raxolPanelManager_1 = require("./raxolPanelManager");
function activate(context) {
    console.log('Raxol extension is now active');
    // Register component provider
    const componentProvider = new componentProvider_1.ComponentProvider();
    vscode.window.registerTreeDataProvider('raxolComponents', componentProvider);
    // Register performance provider
    const performanceProvider = new performanceProvider_1.PerformanceProvider();
    vscode.window.registerTreeDataProvider('raxolPerformance', performanceProvider);
    // Register commands
    (0, commands_1.registerCommands)(context, { componentProvider, performanceProvider });
    // Register language features
    registerLanguageFeatures(context);
    // Register command to show the Raxol Terminal panel
    context.subscriptions.push(vscode.commands.registerCommand('raxol.showTerminal', () => {
        raxolPanelManager_1.RaxolPanelManager.createOrShow(context);
    }));
    // Register component previewer command
    context.subscriptions.push(vscode.commands.registerCommand('raxol.previewComponent', (fileUri) => {
        if (fileUri) {
            componentPreviewer_1.ComponentPreviewer.previewComponent(context, fileUri.fsPath);
        }
        else if (vscode.window.activeTextEditor) {
            componentPreviewer_1.ComponentPreviewer.previewComponent(context, vscode.window.activeTextEditor.document.uri.fsPath);
        }
    }));
    // Register state inspector command
    context.subscriptions.push(vscode.commands.registerCommand('raxol.openStateInspector', () => {
        stateInspector_1.StateInspector.createOrShow(context);
    }));
    // Register context menu for component files
    const componentFilePattern = '**/src/**/*Component*.{ts,tsx,js,jsx}';
    // Register file explorer context menu item
    context.subscriptions.push(vscode.commands.registerCommand('raxol.previewComponentFromExplorer', (fileUri) => {
        componentPreviewer_1.ComponentPreviewer.previewComponent(context, fileUri.fsPath);
    }));
    // Register editor context menu item
    const editorContextDisposable = vscode.languages.registerCodeLensProvider({ pattern: componentFilePattern }, {
        provideCodeLenses(document) {
            const componentMatch = /class\s+([^\s]+)\s+extends\s+RaxolComponent/.exec(document.getText());
            if (!componentMatch) {
                return [];
            }
            const range = new vscode.Range(0, 0, 0, 0);
            const codeLens = new vscode.CodeLens(range, {
                title: 'Preview Component',
                command: 'raxol.previewComponent',
                arguments: [document.uri]
            });
            return [codeLens];
        }
    });
    context.subscriptions.push(editorContextDisposable);
    // Ensure the panel manager is disposed if it exists when the extension deactivates
    // Note: The RaxolPanelManager constructor already adds its own dispose logic
    // to context.subscriptions via the BackendManager, so this explicit check
    // might be redundant IF the panel is always created via the command.
    // However, keeping it doesn't hurt and covers potential future instantiation methods.
    context.subscriptions.push({
        dispose: () => {
            raxolPanelManager_1.RaxolPanelManager.currentPanel?.dispose();
        }
    });
}
function registerLanguageFeatures(context) {
    // Register code completion provider
    context.subscriptions.push(vscode.languages.registerCompletionItemProvider([{ language: 'typescript' }, { language: 'javascript' }], {
        provideCompletionItems() {
            const completionItems = [];
            // Example completion item for Raxol component
            const componentCompletion = new vscode.CompletionItem('RaxolComponent', vscode.CompletionItemKind.Class);
            componentCompletion.insertText = new vscode.SnippetString('class ${1:ComponentName} extends RaxolComponent {\n\tconstructor() {\n\t\tsuper();\n\t\t$0\n\t}\n\n\trender() {\n\t\treturn View.box({\n\t\t\tchildren: []\n\t\t});\n\t}\n}');
            componentCompletion.documentation = new vscode.MarkdownString('Create a new Raxol component');
            completionItems.push(componentCompletion);
            return completionItems;
        }
    }));
    // Register hover provider
    context.subscriptions.push(vscode.languages.registerHoverProvider([{ language: 'typescript' }, { language: 'javascript' }], {
        provideHover(document, position) {
            const range = document.getWordRangeAtPosition(position);
            if (!range) {
                return;
            }
            const word = document.getText(range);
            // Provide hover info for Raxol components and APIs
            if (word === 'View' || word === 'RaxolComponent') {
                return new vscode.Hover(new vscode.MarkdownString(`**Raxol ${word}**\n\nPart of the Raxol framework for building terminal user interfaces.`));
            }
            return undefined;
        }
    }));
}
function deactivate() {
    console.log('Raxol extension is now deactivated');
}
//# sourceMappingURL=extension.js.map