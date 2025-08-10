import * as vscode from 'vscode';

export class RaxolCompletionProvider implements vscode.CompletionItemProvider {

    public provideCompletionItems(
        document: vscode.TextDocument,
        position: vscode.Position,
        token: vscode.CancellationToken,
        context: vscode.CompletionContext
    ): vscode.ProviderResult<vscode.CompletionItem[] | vscode.CompletionList> {
        const lineText = document.lineAt(position).text;
        const textBeforeCursor = lineText.substring(0, position.character);

        // Component completions
        if (this.shouldProvideComponentCompletions(textBeforeCursor)) {
            return this.getComponentCompletions();
        }

        // Props completions
        if (this.shouldProvidePropsCompletions(textBeforeCursor)) {
            const componentName = this.extractComponentName(textBeforeCursor);
            return this.getPropsCompletions(componentName);
        }

        // Event handler completions
        if (this.shouldProvideEventCompletions(textBeforeCursor)) {
            return this.getEventCompletions();
        }

        // Style completions
        if (this.shouldProvideStyleCompletions(textBeforeCursor)) {
            return this.getStyleCompletions();
        }

        // Color completions
        if (this.shouldProvideColorCompletions(textBeforeCursor)) {
            return this.getColorCompletions();
        }

        // Raxol module completions
        if (this.shouldProvideRaxolModuleCompletions(textBeforeCursor)) {
            return this.getRaxolModuleCompletions();
        }

        return [];
    }

    private shouldProvideComponentCompletions(textBeforeCursor: string): boolean {
        return /\\b[A-Z][a-zA-Z]*$/.test(textBeforeCursor) || 
               textBeforeCursor.endsWith('Raxol.UI.') ||
               /\\.render\\s*\\($/.test(textBeforeCursor);
    }

    private shouldProvidePropsCompletions(textBeforeCursor: string): boolean {
        return /\\w+\\.render\\s*\\([^)]*[,:]?\\s*$/.test(textBeforeCursor) ||
               /%\\{[^}]*[,:]?\\s*$/.test(textBeforeCursor) ||
               /Map\\.get\\s*\\(\\s*props\\s*,\\s*:$/.test(textBeforeCursor);
    }

    private shouldProvideEventCompletions(textBeforeCursor: string): boolean {
        return /on_\\w*$/.test(textBeforeCursor);
    }

    private shouldProvideStyleCompletions(textBeforeCursor: string): boolean {
        return /style:\\s*%\\{[^}]*$/.test(textBeforeCursor) ||
               /%\\{[^}]*(?:color|background|bold|italic|underline):?\\s*$/.test(textBeforeCursor);
    }

    private shouldProvideColorCompletions(textBeforeCursor: string): boolean {
        return /(?:color|background):\\s*:?$/.test(textBeforeCursor) ||
               /IO\\.ANSI\\.\\w*$/.test(textBeforeCursor);
    }

    private shouldProvideRaxolModuleCompletions(textBeforeCursor: string): boolean {
        return textBeforeCursor.endsWith('Raxol.') ||
               textBeforeCursor.endsWith('use Raxol.');
    }

    private extractComponentName(textBeforeCursor: string): string {
        const match = textBeforeCursor.match(/(\\w+)\\.render/);
        return match ? match[1] : '';
    }

    private getComponentCompletions(): vscode.CompletionItem[] {
        const components = [
            // Text Components
            { name: 'Text', description: 'Display text content', props: ['content', 'style'] },
            { name: 'Heading', description: 'Display heading text', props: ['content', 'level', 'style'] },
            { name: 'Label', description: 'Display label text', props: ['text', 'required', 'style'] },
            
            // Input Components
            { name: 'TextInput', description: 'Text input field', props: ['value', 'placeholder', 'width', 'disabled'] },
            { name: 'TextArea', description: 'Multi-line text input', props: ['value', 'placeholder', 'rows', 'cols'] },
            { name: 'Select', description: 'Dropdown selection', props: ['options', 'selected', 'placeholder'] },
            
            // Interactive Components
            { name: 'Button', description: 'Clickable button', props: ['label', 'variant', 'disabled', 'on_click'] },
            { name: 'Checkbox', description: 'Checkbox input', props: ['label', 'checked', 'disabled', 'on_change'] },
            { name: 'RadioGroup', description: 'Radio button group', props: ['options', 'selected', 'on_change'] },
            { name: 'Toggle', description: 'Toggle switch', props: ['label', 'enabled', 'on_change'] },
            
            // Layout Components
            { name: 'Box', description: 'Container with border', props: ['width', 'height', 'border', 'title'] },
            { name: 'Flex', description: 'Flexible layout container', props: ['direction', 'gap', 'align', 'justify'] },
            { name: 'Grid', description: 'Grid layout container', props: ['columns', 'rows', 'gap'] },
            { name: 'Tabs', description: 'Tabbed interface', props: ['tabs', 'active_tab'] },
            
            // Data Display
            { name: 'Table', description: 'Data table', props: ['headers', 'rows', 'border'] },
            { name: 'List', description: 'List of items', props: ['items', 'ordered', 'marker'] },
            { name: 'ProgressBar', description: 'Progress indicator', props: ['value', 'max', 'width', 'show_percentage'] },
            { name: 'Spinner', description: 'Loading spinner', props: ['text', 'style'] },
            
            // Special Components
            { name: 'Modal', description: 'Modal dialog', props: ['title', 'visible', 'width', 'height'] },
            { name: 'Tooltip', description: 'Tooltip popup', props: ['text', 'position', 'visible'] }
        ];

        return components.map(comp => {
            const item = new vscode.CompletionItem(comp.name, vscode.CompletionItemKind.Class);
            item.detail = `Raxol Component: ${comp.description}`;
            item.documentation = new vscode.MarkdownString(
                `**${comp.name}** - ${comp.description}\\n\\n` +
                `**Props:** ${comp.props.join(', ')}\\n\\n` +
                `**Example:**\\n\`\`\`elixir\\n${comp.name}.render(${comp.props.slice(0, 2).map(p => `${p}: value`).join(', ')})\\n\`\`\``
            );
            item.insertText = new vscode.SnippetString(
                `${comp.name}.render(\\n  \${1:${comp.props[0] || 'prop'}: \${2:value}}\\n)`
            );
            return item;
        });
    }

    private getPropsCompletions(componentName: string): vscode.CompletionItem[] {
        const propsByComponent: { [key: string]: string[] } = {
            'Text': ['content', 'style'],
            'Heading': ['content', 'level', 'style'],
            'Label': ['text', 'required', 'style'],
            'TextInput': ['value', 'placeholder', 'width', 'disabled', 'on_change'],
            'TextArea': ['value', 'placeholder', 'rows', 'cols', 'on_change'],
            'Select': ['options', 'selected', 'placeholder', 'on_change'],
            'Button': ['label', 'variant', 'disabled', 'on_click'],
            'Checkbox': ['label', 'checked', 'disabled', 'on_change'],
            'RadioGroup': ['options', 'selected', 'on_change'],
            'Toggle': ['label', 'enabled', 'on_change'],
            'Box': ['width', 'height', 'border', 'title', 'padding'],
            'Flex': ['direction', 'gap', 'align', 'justify', 'children'],
            'Grid': ['columns', 'rows', 'gap', 'children'],
            'Tabs': ['tabs', 'active_tab', 'on_change'],
            'Table': ['headers', 'rows', 'border'],
            'List': ['items', 'ordered', 'marker'],
            'ProgressBar': ['value', 'max', 'width', 'show_percentage'],
            'Spinner': ['text', 'style'],
            'Modal': ['title', 'visible', 'width', 'height', 'on_close'],
            'Tooltip': ['text', 'position', 'visible']
        };

        const props = propsByComponent[componentName] || [];
        
        return props.map(prop => {
            const item = new vscode.CompletionItem(prop, vscode.CompletionItemKind.Property);
            item.detail = `${componentName} property`;
            item.insertText = `${prop}: `;
            return item;
        });
    }

    private getEventCompletions(): vscode.CompletionItem[] {
        const events = [
            'on_click', 'on_change', 'on_input', 'on_focus', 'on_blur',
            'on_submit', 'on_reset', 'on_load', 'on_error',
            'on_key', 'on_keydown', 'on_keyup', 'on_keypress',
            'on_mouse', 'on_mousedown', 'on_mouseup', 'on_mousemove',
            'on_mouseenter', 'on_mouseleave',
            'on_drag', 'on_drop', 'on_scroll', 'on_resize',
            'on_mount', 'on_unmount', 'on_update', 'on_render'
        ];

        return events.map(event => {
            const item = new vscode.CompletionItem(event, vscode.CompletionItemKind.Event);
            item.detail = 'Raxol event handler';
            item.insertText = `${event}: &handle_${event.replace('on_', '')}/1`;
            return item;
        });
    }

    private getStyleCompletions(): vscode.CompletionItem[] {
        const styleProps = [
            'color', 'background', 'bold', 'italic', 'underline', 'strikethrough',
            'blink', 'reverse', 'bright', 'dim', 'hidden', 'protected',
            'crossedout', 'faint', 'doubly_underlined'
        ];

        return styleProps.map(prop => {
            const item = new vscode.CompletionItem(prop, vscode.CompletionItemKind.Property);
            item.detail = 'Style property';
            
            if (prop === 'color' || prop === 'background') {
                item.insertText = `${prop}: :\${1:white}`;
            } else {
                item.insertText = `${prop}: \${1:true}`;
            }
            
            return item;
        });
    }

    private getColorCompletions(): vscode.CompletionItem[] {
        const colors = [
            'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
            'light_black', 'light_red', 'light_green', 'light_yellow',
            'light_blue', 'light_magenta', 'light_cyan', 'light_white', 'default'
        ];

        return colors.map(color => {
            const item = new vscode.CompletionItem(color, vscode.CompletionItemKind.Color);
            item.detail = 'ANSI color';
            item.insertText = `:${color}`;
            return item;
        });
    }

    private getRaxolModuleCompletions(): vscode.CompletionItem[] {
        const modules = [
            { name: 'Component', description: 'Base component functionality' },
            { name: 'Terminal', description: 'Terminal application framework' },
            { name: 'UI', description: 'UI component library' },
            { name: 'ANSI', description: 'ANSI escape sequence utilities' },
            { name: 'Event', description: 'Event handling system' },
            { name: 'State', description: 'State management utilities' },
            { name: 'Style', description: 'Styling utilities' },
            { name: 'Layout', description: 'Layout management' }
        ];

        return modules.map(mod => {
            const item = new vscode.CompletionItem(mod.name, vscode.CompletionItemKind.Module);
            item.detail = mod.description;
            return item;
        });
    }
}