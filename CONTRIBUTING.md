# Contributing to Raxol

Contributions welcome. Guidelines below.

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

1. Fork repository
2. Clone locally: `git clone https://github.com/YOUR_USERNAME/raxol.git`
3. Add upstream: `git remote add upstream https://github.com/Hydepwns/raxol.git`

## Development Setup

### Prerequisites
- Elixir 1.17.3
- Erlang/OTP 27.0
- Node.js 20+ (for VSCode extension development)
- PostgreSQL 15+
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
- Format: `mix format`
- Analysis: `mix dialyzer`
- Docs: `mix docs`
- Coverage: `mix test --cover`

## Making Contributions

### Types of Contributions

#### Bug Fixes
- Check for duplicate issues
- Create new issue if needed
- Reference issue in PR

#### Features
- Discuss in issue first
- Break into smaller PRs
- Update docs and tests

#### Documentation
- Fix typos, clarify content
- Add examples and guides
- Improve API docs

#### Tests
- Cover new code
- Improve reliability
- Add property-based tests

### Development Workflow

1. Create branch: `git checkout -b feature/name`
2. Make changes: clean Elixir code, follow patterns, add tests
3. Test: `mix test` or `mix test --cover`
4. Format: `mix format`

## Code Style

### Elixir Guidelines
- Follow [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- Descriptive names
- Small, focused functions
- Document with `@doc`
- Add `@spec` type specs

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
- Test new functionality
- Maintain >95% coverage
- Descriptive test names
- Test edge cases
- Mock external dependencies

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

1. Update: `git fetch upstream && git rebase upstream/master`
2. Push: `git push origin feature/name`
3. Create PR:
   - Clear title
   - Reference issues
   - Describe changes
   - Include screenshots for UI
   - Ensure CI passes

### PR Title Format
```
type: Brief description

- Detailed change 1
- Detailed change 2

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Review Process
- Requires one review
- Address feedback promptly
- Keep PRs focused
- Be respectful

## Community

### Communication
- Issues: bugs, features
- Discussions: questions, ideas
- PRs: code contributions

### Code of Conduct
- Respectful and inclusive
- Welcome newcomers
- Constructive feedback
- Assume good intentions

### Getting Help
- Check documentation
- Search existing issues
- Ask specific questions
- Provide context

## Recognition

Contributors recognized in:
- Project README
- Release notes
- Documentation

Thank you for contributing to Raxol.