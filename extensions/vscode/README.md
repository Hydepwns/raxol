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

### Robust Backend Communication

The extension features improved backend communication with:

- **Smart Output Classification**: Automatically detects and handles different types of output (JSON messages, logs, make output, errors)
- **Make Output Filtering**: Gracefully handles make build output like "Nothing to be done for 'all'"
- **Enhanced Error Handling**: Better error recovery and debugging capabilities
- **Buffer Management**: Prevents memory issues with large output streams
- **JSON Validation**: Validates JSON before parsing to prevent parsing errors

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

- `raxol.enableIntelligentAssistance`: Enable/disable AI-powered code assistance
- `raxol.performanceMetricsEnabled`: Enable/disable real-time performance metrics
- `raxol.componentTemplatesPath`: Path to custom component templates

## Troubleshooting

### Backend Communication Issues

The extension now includes improved error handling for backend communication:

1. **Make Output Errors**: If you see "make: Nothing to be done for 'all'" messages, these are now handled gracefully and won't cause parsing errors.

2. **JSON Parsing Errors**: The extension validates JSON before parsing and provides better error messages for debugging.

3. **Buffer Overflow**: Large output streams are automatically managed to prevent memory issues.

4. **Output Classification**: Different types of output (logs, errors, make output) are automatically classified and handled appropriately.

### Debugging

To enable debug logging:

1. Open VS Code settings
2. Search for "Raxol Backend"
3. Enable debug mode to see detailed communication logs

### Common Issues

- **"Error on parsing output"**: This usually indicates non-JSON output from the backend. The extension now handles this gracefully.
- **Backend not starting**: Check that your Raxol project is properly configured and `mix` is available in your PATH.
- **Memory issues**: The extension now includes buffer management to prevent memory overflow.

## Development

### Building the Extension

1. Clone the repository
2. Run `npm install`
3. Run `npm run watch` for development or `npm run compile` for production

### Testing

Run `npm test` to execute the extension tests.

### Backend Communication Protocol

The extension communicates with the Raxol backend using a JSON-based protocol:

- **JSON Messages**: Wrapped in `RAXOL-JSON-BEGIN` and `RAXOL-JSON-END` markers
- **Log Output**: Plain text output is automatically classified and displayed
- **Make Output**: Build system output is filtered and handled specially
- **Error Output**: Error patterns are detected and logged appropriately

## Roadmap

- Language server implementation for advanced type checking
- Visual component editor
- State flow visualization
- Integration with Raxol CLI tools

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

For licensing information, see the [License](../../LICENSE.md).
