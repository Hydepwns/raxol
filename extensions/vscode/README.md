# Raxol VS Code Extension

A VS Code extension for the Raxol framework, providing tools for enhanced productivity, performance analysis, and intelligent assistance.

## Features

### Component Explorer

View all Raxol components in your project via the dedicated Explorer view. Quickly navigate to component files and understand the component structure of your application.

### Performance Analysis

Analyze the performance of your Raxol components with detailed metrics:
- Rendering time
- Memory usage
- Event handler efficiency
- Update performance

### AI-Assisted Development

This extension integrates with Raxol's AI features to provide:
- Code completion and suggestions
- Performance optimization recommendations
- Refactoring assistance
- Best practice guidelines

### Commands

- **Raxol: Create New Component** - Generate a new Raxol component with proper structure
- **Raxol: Analyze Performance** - Analyze the current file for performance issues
- **Raxol: Optimize Component** - Get optimization suggestions for the current component

## Getting Started

1. Install the extension from the VS Code marketplace
2. Open a Raxol project
3. Access Raxol tools from the activity bar

## Requirements

- VS Code 1.60.0 or higher
- Raxol framework installed in your project

## Extension Settings

This extension contributes the following settings:

* `raxol.enableIntelligentAssistance`: Enable/disable AI-powered code assistance
* `raxol.performanceMetricsEnabled`: Enable/disable real-time performance metrics
* `raxol.componentTemplatesPath`: Path to custom component templates

## Development

### Building the Extension

1. Clone the repository
2. Run `npm install`
3. Run `npm run watch` for development or `npm run compile` for production

### Testing

Run `npm test` to execute the extension tests.

## Roadmap

- Language server implementation for advanced type checking
- Visual component editor
- State flow visualization
- Integration with Raxol CLI tools

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

For licensing information, see the [License](../../LICENSE.md). 