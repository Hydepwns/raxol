# Contributing to the Raxol VS Code Extension

Thank you for your interest in contributing to the Raxol VS Code Extension! This document provides guidelines and instructions for contributing.

## Development Setup

1. Clone the repository
2. Run `npm install` to install dependencies
3. Run `npm run watch` to start the TypeScript compiler in watch mode

## Extension Structure

- `src/extension.ts`: Main extension entry point
- `src/providers/`: Tree data providers for VS Code views
- `src/commands.ts`: Command implementations
- `resources/`: Icons and other resources

## Adding New Features

When adding new features to the extension, please follow these guidelines:

1. Create a separate branch for your feature
2. Add appropriate tests for your changes
3. Update documentation to reflect the new features
4. Submit a pull request with a clear description of the changes

## Feature Priorities

We are currently focusing on:

1. Improving the component explorer with better visualization
2. Enhancing the performance analysis tools
3. Expanding intelligent code assistance capabilities
4. Adding support for more VS Code integrations

## Testing

- Run `npm test` to execute the extension tests
- Ensure that your changes don't break existing functionality
- Add new tests as needed for new features

## Documentation

Please update the following documentation when adding features:

- README.md: Update features and usage instructions
- CHANGELOG.md: Document changes in the appropriate section
- Inline documentation: Add comments to explain complex code

## Submitting Changes

1. Push your changes to your fork
2. Submit a pull request against the main repository
3. Include a clear description of the changes
4. Reference any related issues

## Code Style

- Follow the TypeScript style guidelines
- Use camelCase for variables and functions
- Use PascalCase for classes and interfaces
- Use proper JSDoc comments for documentation

## Communication

- Report bugs and request features through GitHub issues
- Ask questions in the community Discord server
- Discuss major changes in GitHub discussions before implementation

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License). 