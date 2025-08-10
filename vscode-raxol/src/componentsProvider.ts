import * as vscode from 'vscode';
import * as path from 'path';

export class RaxolComponentsProvider implements vscode.TreeDataProvider<ComponentItem> {
    private _onDidChangeTreeData: vscode.EventEmitter<ComponentItem | undefined | null | void> = new vscode.EventEmitter<ComponentItem | undefined | null | void>();
    readonly onDidChangeTreeData: vscode.Event<ComponentItem | undefined | null | void> = this._onDidChangeTreeData.event;

    private components: ComponentItem[] = [];

    constructor() {
        this.refresh();
    }

    refresh(): void {
        this.loadComponents();
        this._onDidChangeTreeData.fire();
    }

    getTreeItem(element: ComponentItem): vscode.TreeItem {
        return element;
    }

    getChildren(element?: ComponentItem): Thenable<ComponentItem[]> {
        if (!element) {
            return Promise.resolve(this.components);
        }

        if (element.children) {
            return Promise.resolve(element.children);
        }

        return Promise.resolve([]);
    }

    private async loadComponents(): Promise<void> {
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (!workspaceFolder) {
            this.components = [];
            return;
        }

        try {
            const components = await this.findRaxolComponents(workspaceFolder.uri);
            this.components = this.organizeComponents(components);
        } catch (error) {
            console.error('Error loading Raxol components:', error);
            this.components = [];
        }
    }

    private async findRaxolComponents(rootUri: vscode.Uri): Promise<RaxolComponent[]> {
        const components: RaxolComponent[] = [];
        const pattern = new vscode.RelativePattern(rootUri, '**/*.ex');
        const files = await vscode.workspace.findFiles(pattern, '**/deps/**');

        for (const file of files) {
            try {
                const document = await vscode.workspace.openTextDocument(file);
                const content = document.getText();

                // Look for Raxol components
                const componentMatches = content.match(/defmodule\\s+([^\\s]+)\\s+do[\\s\\S]*?use\\s+Raxol\\.Component/g);
                
                if (componentMatches) {
                    for (const match of componentMatches) {
                        const moduleMatch = match.match(/defmodule\\s+([^\\s]+)/);
                        if (moduleMatch) {
                            const moduleName = moduleMatch[1];
                            const component: RaxolComponent = {
                                name: this.extractComponentName(moduleName),
                                module: moduleName,
                                file: file,
                                type: this.detectComponentType(content),
                                description: this.extractDescription(content),
                                props: this.extractProps(content)
                            };
                            components.push(component);
                        }
                    }
                }
            } catch (error) {
                console.warn(`Error processing file ${file.fsPath}:`, error);
            }
        }

        return components;
    }

    private extractComponentName(moduleName: string): string {
        const parts = moduleName.split('.');
        return parts[parts.length - 1];
    }

    private detectComponentType(content: string): ComponentType {
        if (content.includes('use GenServer')) {
            return 'genserver';
        }
        if (content.includes('def init(')) {
            return 'stateful';
        }
        if (content.includes('children') || content.includes('slot')) {
            return 'layout';
        }
        if (content.includes('on_click') || content.includes('on_change') || content.includes('handle_event')) {
            return 'interactive';
        }
        return 'basic';
    }

    private extractDescription(content: string): string {
        const docMatch = content.match(/@moduledoc\\s+"""([\\s\\S]*?)"""/);
        if (docMatch) {
            return docMatch[1].trim().split('\\n')[0] || 'Raxol component';
        }
        return 'Raxol component';
    }

    private extractProps(content: string): string[] {
        const props: string[] = [];
        
        // Look for Map.get(props, :prop_name) patterns
        const propMatches = content.match(/Map\.get\(props,\s*:([a-zA-Z_][a-zA-Z0-9_]*)/g);
        if (propMatches) {
            propMatches.forEach(match => {
                const propMatch = match.match(/:([a-zA-Z_][a-zA-Z0-9_]*)/);
                if (propMatch && !props.includes(propMatch[1])) {
                    props.push(propMatch[1]);
                }
            });
        }

        return props;
    }

    private organizeComponents(components: RaxolComponent[]): ComponentItem[] {
        const categories = new Map<ComponentType, RaxolComponent[]>();

        // Group components by type
        components.forEach(component => {
            if (!categories.has(component.type)) {
                categories.set(component.type, []);
            }
            categories.get(component.type)!.push(component);
        });

        // Create category nodes
        const categoryItems: ComponentItem[] = [];

        categories.forEach((comps, type) => {
            const categoryItem = new ComponentItem(
                this.getCategoryLabel(type),
                vscode.TreeItemCollapsibleState.Expanded,
                'category',
                undefined,
                this.getCategoryIcon(type)
            );

            categoryItem.children = comps.map(comp => 
                new ComponentItem(
                    comp.name,
                    vscode.TreeItemCollapsibleState.None,
                    'component',
                    comp,
                    'symbol-class'
                )
            );

            categoryItems.push(categoryItem);
        });

        return categoryItems.sort((a, b) => a.label.localeCompare(b.label));
    }

    private getCategoryLabel(type: ComponentType): string {
        switch (type) {
            case 'basic': return 'Basic Components';
            case 'stateful': return 'Stateful Components';
            case 'interactive': return 'Interactive Components';
            case 'layout': return 'Layout Components';
            case 'genserver': return 'GenServer Components';
            default: return 'Components';
        }
    }

    private getCategoryIcon(type: ComponentType): string {
        switch (type) {
            case 'basic': return 'symbol-interface';
            case 'stateful': return 'symbol-variable';
            case 'interactive': return 'symbol-event';
            case 'layout': return 'symbol-namespace';
            case 'genserver': return 'symbol-module';
            default: return 'symbol-class';
        }
    }
}

class ComponentItem extends vscode.TreeItem {
    constructor(
        public readonly label: string,
        public readonly collapsibleState: vscode.TreeItemCollapsibleState,
        public readonly type: 'category' | 'component',
        public readonly component?: RaxolComponent,
        iconName?: string
    ) {
        super(label, collapsibleState);
        
        if (iconName) {
            this.iconPath = new vscode.ThemeIcon(iconName);
        }

        if (type === 'component' && component) {
            this.tooltip = `${component.module}\\n${component.description}`;
            this.description = component.description;
            
            // Add context value for commands
            this.contextValue = 'raxolComponent';
            
            // Make component items clickable
            this.command = {
                command: 'raxol.preview',
                title: 'Preview Component',
                arguments: [component.file]
            };
        }
    }

    public children?: ComponentItem[];
}

interface RaxolComponent {
    name: string;
    module: string;
    file: vscode.Uri;
    type: ComponentType;
    description: string;
    props: string[];
}

type ComponentType = 'basic' | 'stateful' | 'interactive' | 'layout' | 'genserver';