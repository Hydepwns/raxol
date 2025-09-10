# Raxol Naming Conventions

This document outlines the standardized naming conventions used throughout the Raxol codebase, established during Sprint 22-23 refactoring efforts.

## Module Naming

### General Pattern
All modules follow the pattern: `<domain>_<function>.ex`

### Examples

#### ✅ Correct Naming
- `lib/raxol/terminal/cursor/cursor_manager.ex` → `Raxol.Terminal.Cursor.CursorManager`
- `lib/raxol/core/events/event_manager.ex` → `Raxol.Core.Events.EventManager`
- `lib/raxol/terminal/buffer/buffer_server.ex` → `Raxol.Terminal.Buffer.BufferServer`

#### ❌ Previous Naming (Fixed)
- `lib/raxol/terminal/cursor/manager.ex` → `Raxol.Terminal.Cursor.Manager`
- `lib/raxol/core/events/manager.ex` → `Raxol.Core.Events.Manager`
- `lib/raxol/terminal/buffer/server.ex` → `Raxol.Terminal.Buffer.Server`

## Specific Naming Rules

### 1. Managers
- **Pattern**: `<domain>_manager.ex`
- **Module**: `<Domain>Manager`

Examples:
- `cursor_manager.ex` → `CursorManager`
- `color_manager.ex` → `ColorManager`
- `plugin_manager.ex` → `PluginManager`

### 2. Servers (GenServer processes)
- **Pattern**: `<domain>_server.ex`
- **Module**: `<Domain>Server`

Examples:
- `buffer_server.ex` → `BufferServer`
- `emulator_server.ex` → `EmulatorServer`
- `accessibility_server.ex` → `AccessibilityServer`

### 3. Handlers
- **Pattern**: `<domain>_handler.ex` (singular)
- **Module**: `<Domain>Handler`

Examples:
- `cursor_handler.ex` → `CursorHandler`
- `events_handler.ex` → `EventsHandler`
- `device_handler.ex` → `DeviceHandler`

**Note**: Previously used `handlers` (plural) - now standardized to singular.

### 4. Core Modules
- **Pattern**: `<domain>_<core_function>.ex`
- **Module**: `<Domain><CoreFunction>`

Examples:
- `terminal_core.ex` → `TerminalCore`
- `renderer_core.ex` → `RendererCore`
- `cloud_core.ex` → `CloudCore`

### 5. State Modules
- **Pattern**: `<domain>_state.ex`
- **Module**: `<Domain>State`

Examples:
- `emulator_state.ex` → `EmulatorState`
- `parser_state.ex` → `ParserState`
- `terminal_state.ex` → `TerminalState`

### 6. Configuration Modules
- **Pattern**: `<domain>_config.ex`
- **Module**: `<Domain>Config`

Examples:
- `terminal_config.ex` → `TerminalConfig`
- `cloud_config.ex` → `CloudConfig`
- `raxol_config.ex` → `RaxolConfig`

### 7. Validators
- **Pattern**: `<domain>_validation.ex`
- **Module**: `<Domain>Validation`

Examples:
- `view_validation.ex` → `ViewValidation`
- `config_validation.ex` → `ConfigValidation`
- `lifecycle_validation.ex` → `LifecycleValidation`

## Directory Structure Alignment

### Nested Module Names
When modules are nested deeply, the filename should reflect the full context:

```
lib/raxol/terminal/graphics/kitty/
├── kitty_protocol.ex      → Raxol.Terminal.Graphics.Kitty.KittyProtocol
├── kitty_renderer.ex      → Raxol.Terminal.Graphics.Kitty.KittyRenderer
└── kitty_config.ex        → Raxol.Terminal.Graphics.Kitty.KittyConfig
```

### Avoiding Generic Names
Avoid generic names like:
- `manager.ex` → Use `<domain>_manager.ex`
- `server.ex` → Use `<domain>_server.ex`
- `handler.ex` → Use `<domain>_handler.ex`
- `core.ex` → Use `<domain>_core.ex`

## Benefits of This Convention

1. **No Name Conflicts**: Every filename is unique across the codebase
2. **Clear Context**: Purpose is immediately clear from filename
3. **IDE Navigation**: Better autocomplete and file navigation
4. **Grep/Search**: Easier to find specific functionality
5. **Consistency**: Uniform pattern across all modules

## Migration Status

✅ **Completed**: All 154+ duplicate filenames resolved in Sprint 22-23
✅ **Verified**: Zero compilation warnings from naming conflicts
✅ **Tested**: All module references updated and tests passing

## Implementation Notes

- All existing alias statements updated to reflect new module names
- Import statements maintained backward compatibility where possible  
- Test files follow same naming convention in `test/` directory
- Documentation updated to reflect new module names

---

**Last Updated**: 2025-09-10  
**Sprint**: 26 (Technical Debt Cleanup)