# Contributing to Raxol

Thank you for your interest in contributing to Raxol! We welcome contributions from the community and are grateful for any help you can provide.

## Table of Contents
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Contributions](#making-contributions)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Community](#community)

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/raxol.git
   cd raxol
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/Hydepwns/raxol.git
   ```

## Development Setup

### Prerequisites
- Elixir 1.14 or later
- Erlang/OTP 25 or later
- Node.js 16+ (for VSCode extension development)
- Git

### Initial Setup
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests to verify setup
mix test

# Start the interactive playground
mix raxol.playground

# Run the tutorial system
mix raxol.tutorial
```

### Development Tools
- **Formatter**: Run `mix format` before committing
- **Dialyzer**: Run `mix dialyzer` for static analysis
- **Documentation**: Run `mix docs` to generate documentation
- **Coverage**: Run `mix test --cover` for test coverage

## Making Contributions

### Types of Contributions

#### Bug Fixes
- Check existing issues for duplicates
- Create a new issue if none exists
- Reference the issue in your PR

#### Features
- Discuss major features in an issue first
- Break large features into smaller PRs
- Update documentation and tests

#### Documentation
- Fix typos and clarify existing docs
- Add examples and guides
- Improve API documentation

#### Tests
- Add tests for uncovered code
- Improve test reliability
- Add property-based tests

### Development Workflow

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write clean, idiomatic Elixir code
   - Follow existing patterns and conventions
   - Add tests for new functionality

3. **Test your changes**:
   ```bash
   # Run all tests
   mix test
   
   # Run specific test file
   mix test test/path/to/test.exs
   
   # Run with coverage
   mix test --cover
   ```

4. **Format your code**:
   ```bash
   mix format
   ```

## Code Style

### Elixir Guidelines
- Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Use descriptive variable and function names
- Keep functions small and focused
- Document public functions with `@doc`
- Add type specs with `@spec`

### Project Conventions
- Prefix private functions with underscore for internal modules
- Use consistent error handling patterns
- Follow existing module organization
- Maintain backwards compatibility when possible

### Example Code Style
```elixir
defmodule Raxol.Example do
  @moduledoc """
  Example module demonstrating code style.
  """

  @type option :: {:timeout, timeout()} | {:retries, non_neg_integer()}

  @doc """
  Performs an example operation.
  
  ## Options
  
    * `:timeout` - Maximum time in milliseconds (default: 5000)
    * `:retries` - Number of retry attempts (default: 3)
    
  ## Examples
  
      iex> Example.perform(:test, timeout: 1000)
      {:ok, :result}
  """
  @spec perform(atom(), [option()]) :: {:ok, term()} | {:error, term()}
  def perform(operation, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    retries = Keyword.get(opts, :retries, 3)
    
    do_perform(operation, timeout, retries)
  end
  
  defp do_perform(operation, timeout, retries) do
    # Implementation
    {:ok, :result}
  end
end
```

## Testing

### Test Guidelines
- Write tests for all new functionality
- Maintain existing test coverage (>95%)
- Use descriptive test names
- Test edge cases and error conditions
- Mock external dependencies appropriately

### Running Tests
```bash
# Run all tests
mix test

# Run with specific seed for reproducibility
mix test --seed 12345

# Run only specific tags
mix test --only integration

# Exclude slow tests
mix test --exclude slow

# Run with coverage
mix test --cover
```

### Test Organization
```elixir
defmodule Raxol.ExampleTest do
  use ExUnit.Case
  
  describe "perform/2" do
    test "returns success with valid input" do
      assert {:ok, _} = Example.perform(:test)
    end
    
    test "handles timeout option" do
      assert {:ok, _} = Example.perform(:test, timeout: 100)
    end
    
    test "returns error on invalid operation" do
      assert {:error, :invalid_operation} = Example.perform(:invalid)
    end
  end
end
```

## Documentation

### Documentation Standards
- Document all public APIs
- Include examples in documentation
- Keep documentation up-to-date with code changes
- Use proper markdown formatting

### Building Documentation
```bash
# Generate documentation
mix docs

# Open in browser
open doc/index.html
```

## Submitting Changes

### Pull Request Process

1. **Update your fork**:
   ```bash
   git fetch upstream
   git rebase upstream/master
   ```

2. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request**:
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changes you made and why
   - Include screenshots for UI changes
   - Ensure all CI checks pass

### PR Title Format
```
type: Brief description

- Detailed change 1
- Detailed change 2

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Review Process
- PRs require at least one review
- Address review feedback promptly
- Keep PRs focused and reasonable in size
- Be patient and respectful

## Community

### Communication Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code contributions and reviews

### Code of Conduct
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Assume good intentions

### Getting Help
- Check existing documentation first
- Search issues for similar problems
- Ask clear, specific questions
- Provide context and examples

## Recognition

Contributors will be recognized in:
- The project README
- Release notes
- Special thanks in documentation

Thank you for contributing to Raxol! Your efforts help make this project better for everyone.