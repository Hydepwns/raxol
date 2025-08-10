import * as vscode from 'vscode';

export class RaxolHoverProvider implements vscode.HoverProvider {

    public provideHover(
        document: vscode.TextDocument,
        position: vscode.Position,
        token: vscode.CancellationToken
    ): vscode.ProviderResult<vscode.Hover> {
        const wordRange = document.getWordRangeAtPosition(position);
        if (!wordRange) {
            return null;
        }

        const word = document.getText(wordRange);
        const line = document.lineAt(position).text;

        // Component hover information
        if (this.isComponentReference(line, word)) {
            return this.getComponentHover(word);
        }

        // Props hover information
        if (this.isPropReference(line, word)) {
            const componentName = this.extractComponentName(line);
            return this.getPropHover(word, componentName);
        }

        // Event hover information
        if (this.isEventReference(line, word)) {
            return this.getEventHover(word);
        }

        // Style property hover
        if (this.isStyleProperty(line, word)) {
            return this.getStyleHover(word);
        }

        // Color hover information
        if (this.isColorReference(line, word)) {
            return this.getColorHover(word);
        }

        // Raxol module hover
        if (this.isRaxolModule(line, word)) {
            return this.getRaxolModuleHover(word);
        }

        return null;
    }

    private isComponentReference(line: string, word: string): boolean {
        return new RegExp(`\\\\b${word}\\\\.render\\\\s*\\\\(`).test(line);
    }

    private isPropReference(line: string, word: string): boolean {
        return /\\w+\\.render\\s*\\([^)]*/.test(line) && 
               new RegExp(`\\\\b${word}:\\\\s*`).test(line);
    }

    private isEventReference(line: string, word: string): boolean {
        return word.startsWith('on_') && line.includes(`${word}:`);
    }

    private isStyleProperty(line: string, word: string): boolean {
        return /style:\\s*%\\{/.test(line) && 
               new RegExp(`\\\\b${word}:\\\\s*`).test(line);
    }

    private isColorReference(line: string, word: string): boolean {
        return /:(?:color|background)/.test(line) && 
               new RegExp(`:${word}`).test(line);
    }

    private isRaxolModule(line: string, word: string): boolean {
        return line.includes(`Raxol.${word}`) || 
               (line.includes('use Raxol.') && line.includes(word));
    }

    private extractComponentName(line: string): string {
        const match = line.match(/(\\w+)\\.render/);
        return match ? match[1] : '';
    }

    private getComponentHover(componentName: string): vscode.Hover | null {
        const componentInfo = this.getComponentInfo(componentName);
        if (!componentInfo) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.isTrusted = true;

        markdown.appendMarkdown(`**${componentName}** - ${componentInfo.description}\\n\\n`);
        
        if (componentInfo.props.length > 0) {
            markdown.appendMarkdown(`**Props:**\\n`);
            componentInfo.props.forEach(prop => {
                markdown.appendMarkdown(`- \`${prop.name}\` _(${prop.type})_: ${prop.description}\\n`);
            });
        }

        if (componentInfo.example) {
            markdown.appendMarkdown(`\\n**Example:**\\n`);
            markdown.appendCodeblock(componentInfo.example, 'elixir');
        }

        return new vscode.Hover(markdown);
    }

    private getPropHover(propName: string, componentName: string): vscode.Hover | null {
        const componentInfo = this.getComponentInfo(componentName);
        if (!componentInfo) {
            return null;
        }

        const prop = componentInfo.props.find(p => p.name === propName);
        if (!prop) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.appendMarkdown(`**${propName}** _(${prop.type})_\\n\\n`);
        markdown.appendMarkdown(prop.description);

        if (prop.default !== undefined) {
            markdown.appendMarkdown(`\\n\\n**Default:** \`${prop.default}\``);
        }

        if (prop.example) {
            markdown.appendMarkdown(`\\n\\n**Example:** \`${prop.example}\``);
        }

        return new vscode.Hover(markdown);
    }

    private getEventHover(eventName: string): vscode.Hover | null {
        const eventInfo = this.getEventInfo(eventName);
        if (!eventInfo) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.appendMarkdown(`**${eventName}** - ${eventInfo.description}\\n\\n`);
        
        if (eventInfo.params) {
            markdown.appendMarkdown(`**Parameters:** ${eventInfo.params}\\n\\n`);
        }

        markdown.appendMarkdown(`**Example:**\\n`);
        markdown.appendCodeblock(eventInfo.example, 'elixir');

        return new vscode.Hover(markdown);
    }

    private getStyleHover(styleProp: string): vscode.Hover | null {
        const styleInfo = this.getStyleInfo(styleProp);
        if (!styleInfo) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.appendMarkdown(`**${styleProp}** _(${styleInfo.type})_ - ${styleInfo.description}\\n\\n`);
        
        if (styleInfo.values) {
            markdown.appendMarkdown(`**Possible values:** ${styleInfo.values.join(', ')}\\n\\n`);
        }

        markdown.appendMarkdown(`**Example:** \`${styleProp}: ${styleInfo.example}\``);

        return new vscode.Hover(markdown);
    }

    private getColorHover(colorName: string): vscode.Hover | null {
        const colors: { [key: string]: string } = {
            'black': '#000000',
            'red': '#FF0000',
            'green': '#00FF00',
            'yellow': '#FFFF00',
            'blue': '#0000FF',
            'magenta': '#FF00FF',
            'cyan': '#00FFFF',
            'white': '#FFFFFF',
            'light_black': '#808080',
            'light_red': '#FF8080',
            'light_green': '#80FF80',
            'light_yellow': '#FFFF80',
            'light_blue': '#8080FF',
            'light_magenta': '#FF80FF',
            'light_cyan': '#80FFFF',
            'light_white': '#FFFFFF'
        };

        const hexColor = colors[colorName];
        if (!hexColor) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.appendMarkdown(`**${colorName}** - ANSI color\\n\\n`);
        markdown.appendMarkdown(`**Hex value:** \`${hexColor}\``);

        return new vscode.Hover(markdown);
    }

    private getRaxolModuleHover(moduleName: string): vscode.Hover | null {
        const moduleInfo = this.getRaxolModuleInfo(moduleName);
        if (!moduleInfo) {
            return null;
        }

        const markdown = new vscode.MarkdownString();
        markdown.appendMarkdown(`**Raxol.${moduleName}** - ${moduleInfo.description}\\n\\n`);
        
        if (moduleInfo.functions && moduleInfo.functions.length > 0) {
            markdown.appendMarkdown(`**Key functions:**\\n`);
            moduleInfo.functions.slice(0, 5).forEach(func => {
                markdown.appendMarkdown(`- \`${func}\`\\n`);
            });
        }

        return new vscode.Hover(markdown);
    }

    private getComponentInfo(componentName: string) {
        const components: { [key: string]: any } = {
            'Text': {
                description: 'Display text content with styling',
                props: [
                    { name: 'content', type: 'string', description: 'Text content to display' },
                    { name: 'style', type: 'map', description: 'Text styling options', default: '%{}' }
                ],
                example: 'Text.render(content: "Hello World", style: %{color: :green, bold: true})'
            },
            'Button': {
                description: 'Interactive button component',
                props: [
                    { name: 'label', type: 'string', description: 'Button text label' },
                    { name: 'variant', type: 'atom', description: 'Button style variant', default: ':primary', example: ':primary | :secondary | :danger' },
                    { name: 'disabled', type: 'boolean', description: 'Whether button is disabled', default: 'false' },
                    { name: 'on_click', type: 'function', description: 'Click event handler' }
                ],
                example: 'Button.render(label: "Click me", variant: :primary, on_click: &handle_click/1)'
            },
            'TextInput': {
                description: 'Text input field component',
                props: [
                    { name: 'value', type: 'string', description: 'Current input value' },
                    { name: 'placeholder', type: 'string', description: 'Placeholder text' },
                    { name: 'width', type: 'integer', description: 'Input width in characters', default: '20' },
                    { name: 'disabled', type: 'boolean', description: 'Whether input is disabled', default: 'false' }
                ],
                example: 'TextInput.render(value: state.text, placeholder: "Enter text...", width: 30)'
            },
            'Box': {
                description: 'Container component with border',
                props: [
                    { name: 'width', type: 'integer', description: 'Box width' },
                    { name: 'height', type: 'integer', description: 'Box height' },
                    { name: 'border', type: 'atom', description: 'Border style', default: ':single', example: ':single | :double | :rounded' },
                    { name: 'title', type: 'string', description: 'Optional title for the box' }
                ],
                example: 'Box.render(width: 40, height: 10, border: :double, title: "My Box")'
            }
        };

        return components[componentName];
    }

    private getEventInfo(eventName: string) {
        const events: { [key: string]: any } = {
            'on_click': {
                description: 'Triggered when the component is clicked',
                params: 'event_data',
                example: 'on_click: &handle_click/1'
            },
            'on_change': {
                description: 'Triggered when the component value changes',
                params: 'new_value',
                example: 'on_change: &handle_change/1'
            },
            'on_input': {
                description: 'Triggered on input events (keystrokes, etc.)',
                params: 'input_data',
                example: 'on_input: &handle_input/1'
            },
            'on_focus': {
                description: 'Triggered when component gains focus',
                params: 'focus_event',
                example: 'on_focus: &handle_focus/1'
            },
            'on_blur': {
                description: 'Triggered when component loses focus',
                params: 'blur_event',
                example: 'on_blur: &handle_blur/1'
            }
        };

        return events[eventName];
    }

    private getStyleInfo(styleProp: string) {
        const styles: { [key: string]: any } = {
            'color': {
                type: 'atom',
                description: 'Text color',
                values: [':black', ':red', ':green', ':yellow', ':blue', ':magenta', ':cyan', ':white'],
                example: ':green'
            },
            'background': {
                type: 'atom', 
                description: 'Background color',
                values: [':black', ':red', ':green', ':yellow', ':blue', ':magenta', ':cyan', ':white'],
                example: ':blue'
            },
            'bold': {
                type: 'boolean',
                description: 'Makes text bold',
                example: 'true'
            },
            'italic': {
                type: 'boolean',
                description: 'Makes text italic',
                example: 'true'
            },
            'underline': {
                type: 'boolean',
                description: 'Underlines text',
                example: 'true'
            }
        };

        return styles[styleProp];
    }

    private getRaxolModuleInfo(moduleName: string) {
        const modules: { [key: string]: any } = {
            'Component': {
                description: 'Base functionality for Raxol components',
                functions: ['render/2', 'init/1', 'update/2', 'handle_event/3']
            },
            'Terminal': {
                description: 'Terminal application framework',
                functions: ['start_link/2', 'init/1', 'render/1', 'handle_event/3']
            },
            'UI': {
                description: 'Collection of UI components',
                functions: ['Text', 'Button', 'TextInput', 'Box', 'Flex']
            },
            'ANSI': {
                description: 'ANSI escape sequence utilities',
                functions: ['reset/0', 'color/1', 'background/1', 'bold/0', 'italic/0']
            }
        };

        return modules[moduleName];
    }
}