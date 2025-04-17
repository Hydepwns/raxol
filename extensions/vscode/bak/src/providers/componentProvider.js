"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ComponentProvider = exports.ComponentTreeItem = void 0;
const vscode = require("vscode");
const path = require("path");
const fs = require("fs");
class ComponentTreeItem extends vscode.TreeItem {
    constructor(label, collapsibleState, filePath) {
        super(label, collapsibleState);
        this.label = label;
        this.collapsibleState = collapsibleState;
        this.filePath = filePath;
        if (filePath) {
            this.tooltip = filePath;
            this.command = {
                command: 'vscode.open',
                arguments: [vscode.Uri.file(filePath)],
                title: 'Open Component'
            };
            this.iconPath = new vscode.ThemeIcon('symbol-class');
        }
        else {
            this.iconPath = new vscode.ThemeIcon('folder');
        }
    }
}
exports.ComponentTreeItem = ComponentTreeItem;
class ComponentProvider {
    constructor() {
        this._onDidChangeTreeData = new vscode.EventEmitter();
        this.onDidChangeTreeData = this._onDidChangeTreeData.event;
    }
    refresh() {
        this._onDidChangeTreeData.fire();
    }
    getTreeItem(element) {
        return element;
    }
    getChildren(element) {
        if (!vscode.workspace.workspaceFolders) {
            vscode.window.showInformationMessage('No folder opened');
            return Promise.resolve([]);
        }
        if (!element) {
            return this.getRootComponents();
        }
        // If it's a folder element, find child components
        return Promise.resolve([]);
    }
    async getRootComponents() {
        const components = [];
        if (!vscode.workspace.workspaceFolders) {
            return components;
        }
        const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;
        // Look for component directories
        const srcPath = path.join(workspaceRoot, 'src', 'components');
        if (fs.existsSync(srcPath)) {
            // Find all component files
            try {
                const files = await vscode.workspace.findFiles('src/components/**/*.{ts,tsx,js,jsx}', '**/node_modules/**');
                for (const file of files) {
                    const content = await fs.promises.readFile(file.fsPath, 'utf8');
                    // Check if file contains a Raxol component
                    if (content.includes('extends') &&
                        (content.includes('RaxolComponent') || content.includes('Component'))) {
                        const fileName = path.basename(file.fsPath);
                        components.push(new ComponentTreeItem(fileName, vscode.TreeItemCollapsibleState.None, file.fsPath));
                    }
                }
            }
            catch (err) {
                console.error('Error finding components:', err);
            }
        }
        return components;
    }
}
exports.ComponentProvider = ComponentProvider;
//# sourceMappingURL=componentProvider.js.map