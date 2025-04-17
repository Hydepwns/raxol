"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PerformanceProvider = exports.PerformanceTreeItem = void 0;
const vscode = require("vscode");
// import * as path from 'path'; // Unused
// import { EventEmitter } from 'events'; // Unused
class PerformanceTreeItem extends vscode.TreeItem {
    constructor(label, collapsibleState, type, value, filePath) {
        super(label, collapsibleState);
        this.label = label;
        this.collapsibleState = collapsibleState;
        this.type = type;
        this.value = value;
        this.filePath = filePath;
        if (filePath) {
            this.tooltip = `${label}: ${value || 'N/A'}`;
            this.command = {
                command: 'vscode.open',
                arguments: [vscode.Uri.file(filePath)],
                title: 'Open File'
            };
        }
        // Set icon based on type
        switch (type) {
            case 'file':
                this.iconPath = new vscode.ThemeIcon('file');
                break;
            case 'metric':
                this.iconPath = new vscode.ThemeIcon('dashboard');
                break;
            case 'category':
                this.iconPath = new vscode.ThemeIcon('folder');
                break;
        }
        // Add performance value if available
        if (value !== undefined) {
            this.description = value;
        }
    }
}
exports.PerformanceTreeItem = PerformanceTreeItem;
class PerformanceProvider {
    constructor() {
        this._onDidChangeTreeData = new vscode.EventEmitter();
        this.onDidChangeTreeData = this._onDidChangeTreeData.event;
        this.performanceData = new Map();
        this.loadPerformanceData();
    }
    refresh() {
        this.loadPerformanceData();
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
            // Root level - show performance categories
            return Promise.resolve([
                new PerformanceTreeItem('Component Performance', vscode.TreeItemCollapsibleState.Expanded, 'category'),
                new PerformanceTreeItem('Memory Usage', vscode.TreeItemCollapsibleState.Collapsed, 'category'),
                new PerformanceTreeItem('Event Handling', vscode.TreeItemCollapsibleState.Collapsed, 'category')
            ]);
        }
        else if (element.label === 'Component Performance') {
            // Show component performance metrics
            return this.getComponentPerformanceItems();
        }
        return Promise.resolve([]);
    }
    async getComponentPerformanceItems() {
        const items = [];
        // This would be replaced with actual performance data in a real implementation
        // For now, we'll use mock data
        const mockPerformanceData = [
            { component: 'Dashboard', render: '12ms', update: '8ms', path: 'src/components/Dashboard.ts' },
            { component: 'Chart', render: '28ms', update: '15ms', path: 'src/components/Chart.ts' },
            { component: 'Table', render: '18ms', update: '10ms', path: 'src/components/Table.ts' }
        ];
        for (const data of mockPerformanceData) {
            items.push(new PerformanceTreeItem(data.component, vscode.TreeItemCollapsibleState.Collapsed, 'file', `Render: ${data.render}, Update: ${data.update}`, data.path));
        }
        return items;
    }
    loadPerformanceData() {
        // In a real implementation, this would load performance data from project files
        // For now, we'll use mock data
        this.performanceData.clear();
        // Mock data
        this.performanceData.set('Dashboard', {
            renderTime: '12ms',
            updateTime: '8ms',
            memoryUsage: '2.4MB'
        });
        this.performanceData.set('Chart', {
            renderTime: '28ms',
            updateTime: '15ms',
            memoryUsage: '5.8MB'
        });
        this.performanceData.set('Table', {
            renderTime: '18ms',
            updateTime: '10ms',
            memoryUsage: '3.2MB'
        });
    }
}
exports.PerformanceProvider = PerformanceProvider;
//# sourceMappingURL=performanceProvider.js.map