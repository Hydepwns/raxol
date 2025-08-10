import * as vscode from 'vscode';

export class RaxolCodeLensProvider implements vscode.CodeLensProvider {
    
    public provideCodeLenses(document: vscode.TextDocument): vscode.CodeLens[] | Thenable<vscode.CodeLens[]> {
        const codeLenses: vscode.CodeLens[] = [];
        const text = document.getText();

        // Find Raxol component definitions
        const componentMatches = this.findComponentDefinitions(text);
        
        for (const match of componentMatches) {
            const range = document.lineAt(match.line).range;
            
            // Preview command
            const previewLens = new vscode.CodeLens(range, {
                title: '👁️ Preview',
                command: 'raxol.preview',
                arguments: [document.uri]
            });
            
            // Test command (if test file doesn't exist)
            const testLens = new vscode.CodeLens(range, {
                title: '🧪 Create Test',
                command: 'raxol.createTest',
                arguments: [document.uri, match.componentName]
            });
            
            // Documentation command
            const docsLens = new vscode.CodeLens(range, {
                title: '📖 Generate Docs',
                command: 'raxol.generateDocs',
                arguments: [document.uri, match.componentName]
            });

            codeLenses.push(previewLens, testLens, docsLens);
        }

        // Find render functions
        const renderMatches = this.findRenderFunctions(text);
        
        for (const match of renderMatches) {
            const range = document.lineAt(match.line).range;
            
            const previewLens = new vscode.CodeLens(range, {
                title: '▶️ Run Component',
                command: 'raxol.runComponent',
                arguments: [document.uri, match.line]
            });
            
            codeLenses.push(previewLens);
        }

        // Find test functions
        const testMatches = this.findTestFunctions(text);
        
        for (const match of testMatches) {
            const range = document.lineAt(match.line).range;
            
            const runTestLens = new vscode.CodeLens(range, {
                title: '🏃 Run Test',
                command: 'raxol.runSingleTest',
                arguments: [document.uri, match.testName]
            });
            
            codeLenses.push(runTestLens);
        }

        return codeLenses;
    }

    private findComponentDefinitions(text: string): ComponentMatch[] {
        const matches: ComponentMatch[] = [];
        const lines = text.split('\\n');
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for component module definitions
            const componentMatch = line.match(/defmodule\\s+([^\\s]+)\\s+do/);
            if (componentMatch) {
                // Check if this is a Raxol component by looking ahead
                const isRaxolComponent = this.isRaxolComponent(lines, i);
                if (isRaxolComponent) {
                    const moduleName = componentMatch[1];
                    const componentName = this.extractComponentName(moduleName);
                    
                    matches.push({
                        line: i,
                        componentName,
                        moduleName
                    });
                }
            }
        }
        
        return matches;
    }

    private findRenderFunctions(text: string): RenderMatch[] {
        const matches: RenderMatch[] = [];
        const lines = text.split('\\n');
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for render function definitions
            if (line.match(/def\\s+render\\s*\\(/)) {
                matches.push({ line: i });
            }
        }
        
        return matches;
    }

    private findTestFunctions(text: string): TestMatch[] {
        const matches: TestMatch[] = [];
        const lines = text.split('\\n');
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            
            // Look for test definitions
            const testMatch = line.match(/test\\s+["\']([^"']+)["\']/) || line.match(/test\\s+["\']([^"']+)["\']/);
            if (testMatch) {
                matches.push({
                    line: i,
                    testName: testMatch[1]
                });
            }
        }
        
        return matches;
    }

    private isRaxolComponent(lines: string[], startLine: number): boolean {
        // Look for "use Raxol.Component" in the next few lines
        for (let i = startLine; i < Math.min(startLine + 10, lines.length); i++) {
            if (lines[i].includes('use Raxol.Component')) {
                return true;
            }
        }
        return false;
    }

    private extractComponentName(moduleName: string): string {
        const parts = moduleName.split('.');
        return parts[parts.length - 1];
    }
}

interface ComponentMatch {
    line: number;
    componentName: string;
    moduleName: string;
}

interface RenderMatch {
    line: number;
}

interface TestMatch {
    line: number;
    testName: string;
}