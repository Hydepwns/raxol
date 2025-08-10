# Change Log

All notable changes to the Raxol VSCode extension will be documented in this file.

## [1.0.0] - 2024-01-15

### Added
- Initial release of Raxol VSCode extension
- Rich syntax highlighting for Raxol components
- Comprehensive code snippets for rapid development
- Live component preview with real-time updates
- Component explorer tree view
- Integrated playground and tutorial access
- IntelliSense for components, props, and events
- Go-to-definition support for components and functions
- Hover documentation with detailed component information
- Project scaffolding with templates
- REPL integration for interactive development
- Test runner integration with CodeLens actions
- Mix task integration (playground, tutorial, tests)
- Support for multiple themes in preview
- Error diagnostics and syntax validation
- Auto-completion for ANSI colors and styles

### Features
- **Language Support**: Full Elixir + Raxol syntax highlighting
- **Component Development**: Live preview, explorer, and scaffolding
- **Terminal Integration**: Built-in REPL and Mix task support
- **Testing**: Integrated test runner and component test templates
- **Documentation**: Hover info and go-to-definition
- **Project Management**: New project creation and component generation

### Supported File Types
- `.ex` - Elixir files with Raxol components
- `.exs` - Elixir script files
- `.rx` - Raxol template files (experimental)
- `.raxol` - Raxol component files (experimental)

### Commands Available
- `Raxol: Start Playground` - Launch interactive component playground
- `Raxol: Start Tutorial` - Start the interactive tutorial
- `Raxol: Preview Component` - Live preview of current component
- `Raxol: New Project` - Create new Raxol project with scaffolding
- `Raxol: New Component` - Generate new component from templates
- `Raxol: Open REPL` - Start integrated Elixir REPL
- `Raxol: Run Tests` - Execute project tests
- `Raxol: Show Documentation` - Open Raxol documentation

### Configuration Options
- `raxol.enablePreview` - Enable/disable component preview
- `raxol.previewTheme` - Default theme for previews
- `raxol.autoStartREPL` - Auto-start REPL on project open
- `raxol.mixPath` - Path to Mix executable
- `raxol.enableCodeLens` - Enable CodeLens actions
- `raxol.enableIntelliSense` - Enable IntelliSense features

## [Unreleased]

### Planned Features
- Debugging support with breakpoints
- Performance profiling integration
- Component dependency graph visualization
- Advanced theming and customization
- Web-based preview mode
- Component marketplace integration
- Git hooks for component validation
- Advanced refactoring tools
- Component performance analysis
- Accessibility checking tools