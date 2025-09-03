# Raxol AI Assistant Configuration

This directory contains configuration and context for AI assistants working with the Raxol codebase.

## Directory Structure

```
.claude/
├── README.md                  # This file - overview and navigation
├── CLAUDE.md                  # Core AI consciousness framework (existing)
├── settings.local.json        # Local permissions configuration (existing)
│
├── context/                   # Project context and documentation
│   ├── architecture.md        # System architecture overview
│   ├── codebase-map.md       # Module structure and relationships
│   ├── dependencies.md        # Key dependencies and their roles
│   └── glossary.md           # Domain terms and concepts
│
├── workflows/                 # Development workflow guides
│   ├── testing.md            # Testing strategies and commands
│   ├── debugging.md          # Debugging approaches and tools
│   ├── performance.md        # Performance optimization workflow
│   ├── release.md            # Release process and checklist
│   └── plugin-development.md # Plugin creation workflow
│
├── patterns/                  # Code patterns and standards
│   ├── elixir-patterns.md   # Elixir idioms and best practices
│   ├── genserver-patterns.md # GenServer design patterns
│   ├── supervision-trees.md  # Supervision strategy patterns
│   ├── error-handling.md     # Error handling approaches
│   └── testing-patterns.md   # Test organization and patterns
│
├── prompts/                   # AI assistant prompts and guides
│   ├── code-review.md        # Code review guidelines
│   ├── refactoring.md        # Refactoring approaches
│   ├── documentation.md      # Documentation standards
│   ├── bug-analysis.md       # Bug investigation prompts
│   └── feature-design.md     # Feature design templates
│
├── knowledge/                 # Domain knowledge and expertise
│   ├── terminal-emulation.md # Terminal/ANSI expertise
│   ├── ui-components.md      # Component system knowledge
│   ├── web-continuity.md     # WASH-style web features
│   ├── performance-tuning.md # Performance optimization
│   └── security.md           # Security considerations
│
└── examples/                  # Example implementations
    ├── component-example.ex   # Component implementation
    ├── plugin-example.ex      # Plugin implementation
    ├── test-example.exs       # Test structure example
    └── genserver-example.ex   # GenServer pattern example
```

## Quick Start for AI Assistants

1. **Understand the Project**: Start with `context/architecture.md` for system overview
2. **Learn the Patterns**: Review `patterns/` for coding standards
3. **Follow Workflows**: Use `workflows/` for development processes
4. **Apply Prompts**: Use `prompts/` for task-specific guidance
5. **Reference Examples**: Check `examples/` for implementation patterns

## Key Commands Reference

```bash
# Testing
mix test                       # Run default test suite
mix test --max-failures 3      # Stop after 3 failures
timeout 60 mix test            # Prevent hanging tests

# Development
mix raxol.playground           # Interactive component playground
mix raxol.tutorial            # Tutorial system
mix format                    # Format code
mix credo                     # Code quality checks

# Documentation
mix docs                      # Generate documentation
```

## Integration with CLAUDE.md

The existing `CLAUDE.md` file contains advanced AI consciousness integration framework. This complements the practical development guides in this directory structure.

## Permissions Configuration

The `settings.local.json` file contains tool permissions for automated operations. Update as needed for new workflows.