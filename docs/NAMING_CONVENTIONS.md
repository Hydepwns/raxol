# Raxol Naming Conventions

This document outlines the naming conventions used throughout the Raxol codebase to ensure consistency and maintainability.

## Module Naming

### Singular vs Plural

**Rule**: Module names should always be singular.

**Correct**:
- `Raxol.Terminal.Commands.WindowHandler`
- `Raxol.Terminal.Events.Handler`
- `Raxol.Terminal.Buffer.Helper`

**Incorrect**:
- `Raxol.Terminal.Commands.WindowHandlers`
- `Raxol.Terminal.Events.Handlers`
- `Raxol.Terminal.Buffer.Helpers`

### GenServer Module Naming

We use two primary patterns for GenServer modules:

#### Manager
Use `Manager` suffix for stateful processes that manage resources, state, or coordinate multiple components.

**Characteristics**:
- Maintains state across the application lifecycle
- Manages resources (connections, buffers, caches, etc.)
- Coordinates multiple child processes or components
- Typically singleton processes

**Examples**:
- `Raxol.Terminal.WindowManager` - Manages window state and operations
- `Raxol.Terminal.ConfigManager` - Manages configuration state
- `Raxol.Terminal.Cursor.Manager` - Manages cursor position and state
- `Raxol.Terminal.Buffer.Manager` - Manages terminal buffer state

#### Server
Use `Server` suffix for stateless service processes that provide functionality without managing resources.

**Characteristics**:
- Provides services or functionality
- May cache data but doesn't own resources
- Can have multiple instances
- Focus on processing rather than state management

**Examples**:
- `Raxol.Core.Accessibility.Server` - Provides accessibility services
- `Raxol.Animation.StateServer` - Serves animation state queries
- `Raxol.Cloud.EdgeComputing.Server` - Provides edge computing services

### Configuration Modules

**Rule**: Use `Config` not `Configuration` for brevity and consistency.

**Correct**: `Raxol.Terminal.Config`
**Incorrect**: `Raxol.Terminal.Configuration`

### Handler Modules

**Rule**: Use singular `Handler` suffix.

**Correct**: `Raxol.Terminal.Commands.CursorHandler`
**Incorrect**: `Raxol.Terminal.Commands.CursorHandlers`

### Helper Modules

**Rule**: Use singular `Helper` suffix.

**Correct**: `Raxol.Terminal.Buffer.Helper`
**Incorrect**: `Raxol.Terminal.Buffer.Helpers`

### Implementation Modules

**Rule**: Use `Impl` suffix for implementation modules (shorter than `Implementation`).

**Examples**:
- `Raxol.Terminal.Buffer.BehaviourImpl`
- `Raxol.System.InteractionImpl`

## File Naming

### Source Files
- Use snake_case for all file names
- Match the module name in snake_case

**Examples**:
- `window_handler.ex` for `WindowHandler` module
- `config_manager.ex` for `ConfigManager` module

### Test Files
- Test files should end with `_test.exs`
- Test helper modules in `lib/raxol/test/` use `.ex` extension
- Test support files in `test/support/` use `.exs` extension

## Function Naming

### Public Functions
- Use snake_case
- Be descriptive but concise
- Use verb_noun pattern where appropriate

**Examples**:
- `handle_window_resize/2`
- `get_cursor_position/1`
- `update_config/2`

### Private Functions
- Same as public functions
- Consider prefixing with `do_` for internal implementation functions

**Examples**:
- `do_merge_opts/2`
- `do_validate/1`

## Variable Naming

### General Variables
- Use snake_case
- Be descriptive
- Avoid single letters except for common conventions (i, x, y, etc.)

### Module Attributes
- Use snake_case with @ prefix
- Use SCREAMING_SNAKE_CASE for constants (though this is rare in Elixir)

**Examples**:
- `@default_timeout`
- `@max_retries`

## Test Naming

### Test Descriptions
- Use descriptive strings that explain what is being tested
- Start with the function name being tested when appropriate

**Examples**:
```elixir
test "handle_window_resize/2 updates dimensions correctly"
test "get_cursor_position/1 returns current position"
```

## Directory Structure

### Source Directories
- Use snake_case for directory names
- Match the module namespace structure

**Examples**:
```
lib/
  raxol/
    terminal/
      commands/
        csi_handler/
      buffer/
      cursor/
```

### Test Directories
- Mirror the source directory structure
- Test helpers go in `lib/raxol/test/`
- Test support files go in `test/support/`

## Consistency Guidelines

1. **Be Consistent**: If a pattern exists, follow it
2. **Singular Over Plural**: Always prefer singular module names
3. **Brevity When Clear**: Use shorter forms when meaning is clear (Config vs Configuration)
4. **Descriptive When Needed**: Don't sacrifice clarity for brevity
5. **Follow Elixir Conventions**: When in doubt, follow standard Elixir/Phoenix conventions

## Migration Notes

When refactoring existing code to match these conventions:

1. Create compatibility aliases for one version cycle
2. Mark old names as deprecated
3. Update documentation
4. Provide migration scripts when possible

## Version History

- v1.0 (2025-01): Initial naming conventions
- v2.0 (2025-09): Standardized Handler/Helper to singular, Config naming