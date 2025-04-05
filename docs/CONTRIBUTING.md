---
title: Contributing to Raxol
description: Guidelines for contributing to the Raxol terminal emulator framework
date: 2023-04-04
author: Raxol Team
section: guides
tags: [contributing, guidelines, development]
---

# Contributing to Raxol

Thank you for your interest in contributing to Raxol! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](../CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/raxol.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `mix test`
6. Commit your changes: `git commit -am 'Add some feature'`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Submit a pull request

## Development Environment

### Prerequisites

- Elixir 1.12 or later
- Erlang/OTP 24 or later
- Node.js 14 or later (for frontend components)

### Setup

1. Install dependencies:
   ```
   mix deps.get
   npm install
   ```

2. Run tests:
   ```
   mix test
   ```

3. Start the development server:
   ```
   mix phx.server
   ```

## Project Structure

- `lib/raxol/terminal/` - Core terminal emulator components
- `lib/raxol_web/` - Web interface components
- `test/` - Test files
- `docs/` - Documentation
- `scripts/` - Utility scripts

## Coding Standards

- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Use proper type specifications
- Document all public functions
- Write tests for all new features
- Keep functions small and focused
- Use meaningful variable and function names

## Testing

- Write unit tests for each module
- Create integration tests for component interactions
- Include performance tests for critical operations
- Test edge cases and error conditions
- Maintain test coverage above 80%

## Documentation

- Use ExDoc for documentation
- Include examples in documentation
- Document all public functions
- Add type specifications
- Keep README up to date

## Pull Request Process

1. Update the README.md with details of changes if needed
2. Update the CHANGELOG.md with a note describing your changes
3. The PR will be merged once you have the sign-off of at least one maintainer

## Reporting Bugs

- Use the GitHub issue tracker
- Describe the bug in detail
- Include steps to reproduce
- Provide expected and actual behavior
- Include system information

## Feature Requests

- Use the GitHub issue tracker
- Describe the feature in detail
- Explain why this feature would be useful
- Provide examples of how it would be used

## Questions and Discussions

- Use the GitHub Discussions feature
- Join our community chat
- Ask questions in the issue tracker

## License

By contributing to Raxol, you agree that your contributions will be licensed under the project's license. 