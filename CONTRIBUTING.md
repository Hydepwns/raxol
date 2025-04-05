# Contributing to Raxol

Thank you for your interest in contributing to Raxol! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Plugin Development](#plugin-development)
- [Quality Assurance](#quality-assurance)

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/raxol.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Install dependencies:
   ```bash
   mix deps.get
   npm install
   ```

## Development Workflow

1. Make your changes
2. Run tests: `mix test`
3. Run JavaScript tests: `npm test`
4. Run pre-commit checks: `npm run precommit`
5. Commit your changes with a descriptive commit message
6. Push to your fork
7. Create a pull request

## Pull Request Process

1. Update the README.md with details of changes if needed
2. Update the CHANGELOG.md with details of changes
3. Ensure all pre-commit checks pass
4. The PR will be merged once you have the sign-off of at least one maintainer

## Coding Standards

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Use [Credo](https://github.com/rrrene/credo) for static code analysis
- Format code with `mix format`
- Add type specifications to all public functions
- Follow the TypeScript style guide for JavaScript/TypeScript code

## Testing

- Write unit tests for all new features
- Ensure all tests pass before submitting a PR
- Maintain or improve test coverage (minimum 80%)
- For JavaScript components, follow the testing guidelines in `test/js/README.md`

## Documentation

- Document all public functions with [ExDoc](https://github.com/elixir-lang/ex_doc)
- Update documentation when adding or modifying features
- Follow the documentation format with required frontmatter
- Run documentation validation: `node scripts/docs/maintenance.js`
- Check for broken links in documentation: `npm run check:links`

## Plugin Development

- Follow the plugin development guide in `docs/plugins/development.md`
- Ensure plugins are properly tested
- Document plugin configuration options
- Follow the plugin API versioning guidelines

## Quality Assurance

Raxol uses a comprehensive set of pre-commit checks to ensure code quality. These checks are automated and run before each commit. The following checks are performed:

- Type Safety: Ensures that all code is type-safe.
- Documentation Consistency: Ensures that all documentation is consistent and up-to-date.
- Code Style: Ensures that all code follows the project's style guidelines.
- Broken Links: Checks for broken links in documentation.
- Test Coverage: Ensures that test coverage meets the required threshold.
- Performance: Validates that performance metrics meet the required standards.
- Accessibility: Ensures that the application meets accessibility standards.
- End-to-End Tests: Validates that all end-to-end tests pass.

### Running Pre-Commit Checks

To run the pre-commit checks manually, use the following command:

```bash
mix run scripts/pre_commit_check.exs
```

### Validation Scripts

The following validation scripts are available:

- `scripts/validate_performance.exs`: Validates performance metrics.
- `scripts/validate_accessibility.exs`: Validates accessibility standards.
- `scripts/validate_e2e.exs`: Validates end-to-end tests.

These scripts can be run individually using the following command:

```bash
mix run scripts/validate_<script_name>.exs
```

## Questions?

If you have any questions, please open an issue or reach out to the maintainers. 