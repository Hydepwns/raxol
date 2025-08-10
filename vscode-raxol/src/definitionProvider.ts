import * as vscode from 'vscode';

export class RaxolDefinitionProvider implements vscode.DefinitionProvider {

    public async provideDefinition(
        document: vscode.TextDocument,
        position: vscode.Position,
        token: vscode.CancellationToken
    ): Promise<vscode.Definition | vscode.LocationLink[] | null> {
        const wordRange = document.getWordRangeAtPosition(position);
        if (!wordRange) {
            return null;
        }

        const word = document.getText(wordRange);
        const line = document.lineAt(position).text;

        // Component module references
        if (this.isComponentReference(line, word)) {
            const definition = await this.findComponentDefinition(word);
            if (definition) {
                return definition;
            }
        }

        // Function calls within components
        if (this.isFunctionCall(line, word)) {
            const definition = await this.findFunctionDefinition(document, word);
            if (definition) {
                return definition;
            }
        }

        // Raxol module references
        if (this.isRaxolModuleReference(line, word)) {
            return this.getRaxolModuleDefinition(word);
        }

        // Event handler references
        if (this.isEventHandlerReference(line, word)) {
            const definition = await this.findEventHandlerDefinition(document, word);
            if (definition) {
                return definition;
            }
        }

        return null;
    }

    private isComponentReference(line: string, word: string): boolean {
        // Check if it's a component render call
        return new RegExp(`\\\\b${word}\\\\.render\\\\s*\\\\(`).test(line) ||
               // Or aliased component
               new RegExp(`alias.*${word}`).test(line);
    }

    private isFunctionCall(line: string, word: string): boolean {
        return new RegExp(`\\\\b${word}\\\\s*\\\\(`).test(line);
    }

    private isRaxolModuleReference(line: string, word: string): boolean {
        return line.includes(`Raxol.${word}`) || 
               (line.includes('use Raxol.') && line.includes(word));
    }

    private isEventHandlerReference(line: string, word: string): boolean {
        return /&\w+\/\d+/.test(line) && line.includes(word);
    }

    private async findComponentDefinition(componentName: string): Promise<vscode.Location | null> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            return null;
        }

        // Search for component definition
        const pattern = new vscode.RelativePattern(workspaceFolder, '**/*.ex');
        const files = await vscode.workspace.findFiles(pattern, '**/deps/**');

        for (const file of files) {
            try {
                const document = await vscode.workspace.openTextDocument(file);
                const content = document.getText();
                const lines = content.split('\n');

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    
                    // Look for module definition that ends with the component name
                    const moduleMatch = line.match(/defmodule\\s+([^\\s]+)\\s+do/);
                    if (moduleMatch) {
                        const moduleName = moduleMatch[1];
                        const moduleNameParts = moduleName.split('.');
                        const lastPart = moduleNameParts[moduleNameParts.length - 1];
                        
                        if (lastPart === componentName) {
                            // Check if it's a Raxol component
                            const isRaxolComponent = this.checkIsRaxolComponent(lines, i);
                            if (isRaxolComponent) {
                                const position = new vscode.Position(i, line.indexOf('defmodule'));
                                return new vscode.Location(file, position);
                            }
                        }
                    }
                }
            } catch (error) {
                console.warn(`Error searching file ${file.fsPath}:`, error);
            }
        }

        return null;
    }

    private checkIsRaxolComponent(lines: string[], startLine: number): boolean {
        // Look for "use Raxol.Component" in the next few lines
        for (let i = startLine; i < Math.min(startLine + 10, lines.length); i++) {
            if (lines[i].includes('use Raxol.Component')) {
                return true;
            }
        }
        return false;
    }

    private async findFunctionDefinition(document: vscode.TextDocument, functionName: string): Promise<vscode.Location | null> {
        const content = document.getText();
        const lines = content.split('\n');

        // First, search in the current document
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for function definitions
            const funcMatch = line.match(new RegExp(`def\\\\s+${functionName}\\\\s*\\\\(`));
            if (funcMatch) {
                const position = new vscode.Position(i, line.indexOf('def'));
                return new vscode.Location(document.uri, position);
            }
            
            // Look for private function definitions
            const privFuncMatch = line.match(new RegExp(`defp\\\\s+${functionName}\\\\s*\\\\(`));
            if (privFuncMatch) {
                const position = new vscode.Position(i, line.indexOf('defp'));
                return new vscode.Location(document.uri, position);
            }
        }

        // If not found in current document, search workspace
        return await this.searchWorkspaceForFunction(functionName);
    }

    private async searchWorkspaceForFunction(functionName: string): Promise<vscode.Location | null> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            return null;
        }

        const pattern = new vscode.RelativePattern(workspaceFolder, '**/*.ex');
        const files = await vscode.workspace.findFiles(pattern, '**/deps/**');

        for (const file of files) {
            try {
                const document = await vscode.workspace.openTextDocument(file);
                const content = document.getText();
                const lines = content.split('\n');

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    
                    const funcMatch = line.match(new RegExp(`def\\\\s+${functionName}\\\\s*\\\\(`));
                    if (funcMatch) {
                        const position = new vscode.Position(i, line.indexOf('def'));
                        return new vscode.Location(file, position);
                    }
                }
            } catch (error) {
                console.warn(`Error searching file ${file.fsPath}:`, error);
            }
        }

        return null;
    }

    private getRaxolModuleDefinition(moduleName: string): vscode.Location | null {
        // For now, return null - in a real implementation, this would point to
        // the actual Raxol module definitions, potentially in the hex package
        return null;
    }

    private async findEventHandlerDefinition(document: vscode.TextDocument, handlerName: string): Promise<vscode.Location | null> {
        const content = document.getText();
        const lines = content.split('\n');

        // Extract the actual function name from the handler reference
        const functionName = handlerName.replace(/^handle_/, '').replace(/\/\d+$/, '');

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for handle_event definitions
            if (line.includes(`def handle_event(`) && line.includes(functionName)) {
                const position = new vscode.Position(i, line.indexOf('def'));
                return new vscode.Location(document.uri, position);
            }
            
            // Look for the actual handler function
            const handlerMatch = line.match(new RegExp(`def\\\\s+${handlerName}\\\\s*\\\\(`));
            if (handlerMatch) {
                const position = new vscode.Position(i, line.indexOf('def'));
                return new vscode.Location(document.uri, position);
            }
        }

        return null;
    }
}