import * as vscode from 'vscode';
import { ComponentProvider } from './providers/componentProvider';
import { PerformanceProvider } from './providers/performanceProvider';
import { registerCommands } from './commands';
import { ComponentPreviewer } from './features/componentPreviewer';
import { StateInspector } from './features/stateInspector';

export function activate(context: vscode.ExtensionContext) {
  console.log('Raxol extension is now active');

  // Register component provider
  const componentProvider = new ComponentProvider();
  vscode.window.registerTreeDataProvider('raxolComponents', componentProvider);

  // Register performance provider
  const performanceProvider = new PerformanceProvider();
  vscode.window.registerTreeDataProvider('raxolPerformance', performanceProvider);

  // Register commands
  registerCommands(context, { componentProvider, performanceProvider });

  // Register language features
  registerLanguageFeatures(context);
  
  // Register component previewer command
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.previewComponent', (fileUri) => {
      if (fileUri) {
        ComponentPreviewer.previewComponent(context, fileUri.fsPath);
      } else if (vscode.window.activeTextEditor) {
        ComponentPreviewer.previewComponent(context, vscode.window.activeTextEditor.document.uri.fsPath);
      }
    })
  );
  
  // Register state inspector command
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.openStateInspector', () => {
      StateInspector.createOrShow(context);
    })
  );
  
  // Register context menu for component files
  const componentFilePattern = '**/src/**/*Component*.{ts,tsx,js,jsx}';
  
  // Register file explorer context menu item
  context.subscriptions.push(
    vscode.commands.registerCommand('raxol.previewComponentFromExplorer', (fileUri) => {
      ComponentPreviewer.previewComponent(context, fileUri.fsPath);
    })
  );
  
  // Register editor context menu item
  const editorContextDisposable = vscode.languages.registerCodeLensProvider(
    { pattern: componentFilePattern },
    {
      provideCodeLenses(document, token) {
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
    }
  );
  
  context.subscriptions.push(editorContextDisposable);
}

function registerLanguageFeatures(context: vscode.ExtensionContext) {
  // Register code completion provider
  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider(
      [{ language: 'typescript' }, { language: 'javascript' }], 
      {
        provideCompletionItems(document, position, token, context) {
          const completionItems: vscode.CompletionItem[] = [];
          
          // Example completion item for Raxol component
          const componentCompletion = new vscode.CompletionItem('RaxolComponent', vscode.CompletionItemKind.Class);
          componentCompletion.insertText = new vscode.SnippetString(
            'class ${1:ComponentName} extends RaxolComponent {\n\tconstructor() {\n\t\tsuper();\n\t\t$0\n\t}\n\n\trender() {\n\t\treturn View.box({\n\t\t\tchildren: []\n\t\t});\n\t}\n}'
          );
          componentCompletion.documentation = new vscode.MarkdownString('Create a new Raxol component');
          completionItems.push(componentCompletion);
          
          return completionItems;
        }
      }
    )
  );

  // Register hover provider
  context.subscriptions.push(
    vscode.languages.registerHoverProvider(
      [{ language: 'typescript' }, { language: 'javascript' }],
      {
        provideHover(document, position, token) {
          const range = document.getWordRangeAtPosition(position);
          if (!range) {
            return;
          }
          
          const word = document.getText(range);
          
          // Provide hover info for Raxol components and APIs
          if (word === 'View' || word === 'RaxolComponent') {
            return new vscode.Hover(
              new vscode.MarkdownString(`**Raxol ${word}**\n\nPart of the Raxol framework for building terminal user interfaces.`)
            );
          }
        }
      }
    )
  );
}

export function deactivate() {
  console.log('Raxol extension is now deactivated');
} 