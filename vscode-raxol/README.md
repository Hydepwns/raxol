# Raxol VSCode Extension

Advanced development support for the Raxol terminal UI framework. This extension provides comprehensive tooling for building, debugging, and testing Raxol applications directly within VSCode.

## Features

### 🎨 Rich Language Support
- **Syntax highlighting** for Raxol components and templates
- **Code snippets** for common patterns and components
- **Auto-completion** for components, props, and events
- **Go-to-definition** for components and functions
- **Hover documentation** with detailed component information

### 🔍 Component Development
- **Live component preview** with real-time updates
- **Component explorer** tree view showing all project components
- **Interactive playground** integration
- **Code generation** for new components
- **Property validation** and type checking

### 🖥️ Integrated Terminal Tools
- **Built-in REPL** for testing components
- **Mix task integration** (playground, tutorial, tests)
- **Project scaffolding** with templates
- **Hot reloading** during development

### 🧪 Testing & Debugging
- **Test runner integration** with CodeLens actions
- **Component testing** templates and helpers
- **Error highlighting** and diagnostics
- **Performance monitoring** integration

## Installation

1. Install from the VSCode Marketplace
2. Open a Raxol project or create a new one
3. The extension will automatically activate and provide language support

## Getting Started

### Create a New Raxol Project

1. Open Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
2. Run `Raxol: New Project`
3. Choose a location and enter project name
4. The extension will create a complete project structure

### Create Components

1. Right-click in the Explorer
2. Select `Raxol: New Component`
3. Choose component type and enter name
4. The extension generates boilerplate code

### Preview Components

1. Open a component file
2. Use `Cmd+Shift+P` (`Ctrl+Shift+P`) to preview
3. Or click the "👁️ Preview" CodeLens action
4. See live updates in the preview panel

## Commands

| Command | Description | Shortcut |
|---------|-------------|----------|
| `Raxol: Start Playground` | Launch component playground | |
| `Raxol: Start Tutorial` | Interactive tutorial | |
| `Raxol: Preview Component` | Preview current component | `Cmd+Shift+P` |
| `Raxol: New Project` | Create new Raxol project | |
| `Raxol: New Component` | Create new component | |
| `Raxol: Open REPL` | Start Raxol REPL | `Cmd+Shift+R` |
| `Raxol: Run Tests` | Run project tests | |

## Component Snippets

The extension includes rich snippets for rapid development:

- `defcomponent` - Full component template
- `rtext` - Text component
- `rbutton` - Button component
- `rinput` - Input component
- `rbox` - Box layout
- `rflex` - Flex layout
- `revent` - Event handler
- `rtest` - Component test

## Configuration

Configure the extension through VSCode settings:

```json
{
  "raxol.enablePreview": true,
  "raxol.previewTheme": "default",
  "raxol.autoStartREPL": false,
  "raxol.mixPath": "mix",
  "raxol.enableCodeLens": true,
  "raxol.enableIntelliSense": true
}
```

## Project Structure

When creating new projects, the extension generates:

```
my_raxol_app/
├── lib/
│   ├── my_raxol_app.ex          # Main application
│   ├── my_raxol_app/
│   │   ├── application.ex        # Application supervisor
│   │   └── components/           # Component modules
│   │       └── hello_world.ex    # Example component
├── test/                         # Test files
├── config/                       # Configuration
├── mix.exs                       # Project definition
└── README.md
```

## Component Development Workflow

1. **Create** components using snippets or templates
2. **Preview** components in real-time
3. **Test** using integrated test runner
4. **Debug** with REPL and error diagnostics
5. **Deploy** using Mix tasks

## Advanced Features

### Component Explorer

The Component Explorer shows:
- All components organized by type
- Component descriptions and props
- Quick actions (preview, test, documentation)
- Dependency relationships

### Live Preview

The preview panel provides:
- Real-time component rendering
- Theme switching
- Property editors
- Error reporting

### IntelliSense

Smart completions for:
- Component names and modules
- Properties and their types
- Event handlers
- Style attributes
- ANSI colors

## Troubleshooting

### Extension Not Activating
- Ensure you have a `mix.exs` file in your workspace
- Check that Elixir and Mix are installed
- Restart VSCode and check the Output panel

### Preview Not Working
- Verify Raxol dependency in `mix.exs`
- Run `mix deps.get` to install dependencies
- Check that Mix path is configured correctly

### REPL Issues
- Ensure Mix environment is set up
- Check terminal permissions
- Verify Elixir installation

## Contributing

This extension is part of the Raxol project. Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

- [Documentation](https://raxol.dev/docs)
- [GitHub Issues](https://github.com/raxol-team/vscode-raxol/issues)
- [Community Discord](https://discord.gg/raxol)

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Happy coding with Raxol! 🎨✨**