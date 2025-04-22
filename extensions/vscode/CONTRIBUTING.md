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

## General Development Best Practices

Based on experience developing Raxol, we've established the following best practices:

### Component Testing Approach

- Create dedicated testing helpers per component type
- Implement mock components for integration testing
- Use stub implementations for visual testing
- Make testing helpers easily reusable
- Structure tests into logical units (unit, integration, visual)
- Implement comprehensive test coverage for all component states
- Ensure tests verify both appearance and behavior

### Component API Design

- Ensure consistent event handling patterns
- Support both disabled and active states
- Implement proper state transitions
- Provide style customization options
- Follow consistent naming conventions
- Maintain backward compatibility when possible
- Ensure proper theme integration
- Document component APIs thoroughly

### Layout and Grid Systems

- Support multiple naming conventions for better flexibility
- Implement proper validation and error handling
- Add detailed logging for debugging
- Use fallback values for missing configuration
- Ensure responsive behavior in different environments
- Provide clear error messages for invalid configurations
- Test layout systems with various widget sizes and configurations

### Performance Optimization

- Implement caching for expensive calculations
- Benchmark critical rendering paths
- Profile memory usage for large datasets
- Optimize render loops for efficiency
- Implement incremental updates when possible
- Minimize DOM operations in browser contexts
- Use efficient algorithms for data transformations

### Cross-platform Compatibility

- Test on multiple operating systems
- Implement platform-specific fallbacks
- Handle environment-specific initialization
- Use feature detection rather than platform detection
- Provide consistent error handling across platforms
- Document platform-specific limitations

### Code Organization

- Maintain clear separation of concerns
- Use consistent module organization
- Follow established naming conventions
- Keep related functionality together
- Create reusable utilities for common tasks
- Document module interfaces and responsibilities
- Use clear and descriptive variable/function names

### Development Workflow

- Verify changes in both VS Code and native terminal environments
- Run comprehensive test suites before submitting changes
- Use local CI testing with Act before pushing to GitHub
- Document significant changes in CHANGELOG.md
- Follow the established commit message format
- Create focused pull requests with clear descriptions
- Review code changes for consistency and quality
