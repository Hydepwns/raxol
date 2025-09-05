# Raxol Codebase Map

## Directory Structure Overview

```
raxol/
├── lib/                      # Main application code
│   ├── raxol/               # Core Raxol modules
│   ├── raxol_web/           # Phoenix web interface
│   └── termbox2_nif/        # Native terminal interface
├── test/                     # Test suites
├── config/                   # Configuration files
├── docs/                     # Documentation
├── bench/                    # Benchmarks
├── demos/                    # Demo recordings
├── scripts/                  # Development scripts
└── vscode-raxol/            # VSCode extension

```

## Core Module Structure

### `lib/raxol/` - Main Application Modules

#### Terminal Subsystem (`lib/raxol/terminal/`)
Core terminal emulation functionality:

```
terminal/
├── emulator/                 # Terminal emulator implementation
│   ├── core.ex              # Core emulator logic
│   ├── state.ex             # Emulator state management
│   ├── input.ex             # Input processing
│   └── output.ex            # Output handling
├── buffer/                   # Buffer management
│   ├── manager.ex           # Buffer operations
│   ├── cell.ex              # Cell structure
│   ├── scrollback.ex        # History management
│   └── damage.ex            # Damage tracking
├── ansi/                     # ANSI/VT100 support
│   ├── parser.ex            # Sequence parser
│   ├── sequences.ex         # Sequence definitions
│   ├── sgr_processor.ex     # SGR handling
│   └── sixel_graphics.ex    # Sixel support
└── cursor/                   # Cursor management
    ├── manager.ex           # Cursor operations
    └── style.ex             # Cursor styling
```

#### UI Framework (`lib/raxol/ui/`)
Component-based UI system:

```
ui/
├── components/               # UI components
│   ├── button.ex
│   ├── input.ex
│   ├── list.ex
│   └── modal.ex
├── layouts/                  # Layout engines
│   ├── flex.ex
│   ├── grid.ex
│   └── absolute.ex
├── themes/                   # Theme system
│   ├── default.ex
│   ├── dark.ex
│   └── manager.ex
└── renderer/                 # Rendering engine
    ├── view.ex
    └── buffer.ex
```

#### Core Services (`lib/raxol/core/`)
Foundational services:

```
core/
├── runtime/                  # Runtime management
│   ├── application.ex       # App lifecycle
│   ├── component_manager.ex # Component management
│   ├── events/              # Event system
│   └── plugins/             # Plugin infrastructure
├── performance/              # Performance monitoring
│   ├── monitor.ex
│   ├── profiler.ex
│   └── metrics.ex
├── accessibility/            # Accessibility features
│   ├── screen_reader.ex
│   ├── keyboard_nav.ex
│   └── announcements.ex
└── config/                   # Configuration
    ├── manager.ex
    └── schema.ex
```

#### Plugin System (`lib/raxol/plugins/`)
Extensibility framework:

```
plugins/
├── manager.ex                # Plugin lifecycle
├── loader.ex                 # Dynamic loading
├── registry.ex               # Plugin registry
├── lifecycle.ex              # Lifecycle hooks
└── builtin/                  # Built-in plugins
    ├── clipboard_plugin.ex
    ├── search_plugin.ex
    └── theme_plugin.ex
```

### `lib/raxol_web/` - Web Interface

Phoenix LiveView implementation:

```
raxol_web/
├── live/                     # LiveView modules
│   ├── terminal_live.ex     # Terminal LiveView
│   ├── playground_live.ex   # Component playground
│   └── tutorial_live.ex     # Tutorial system
├── channels/                 # WebSocket channels
│   ├── terminal_channel.ex
│   └── sync_channel.ex
├── controllers/              # HTTP controllers
├── views/                    # View modules
└── templates/                # HTML templates
```

### `test/` - Test Organization

```
test/
├── raxol/                    # Unit tests (mirrors lib/raxol/)
│   ├── terminal/
│   ├── ui/
│   ├── core/
│   └── plugins/
├── raxol_web/                # Web interface tests
├── integration/              # Integration tests
├── performance/              # Performance benchmarks
├── support/                  # Test helpers
│   ├── mocks/               # Mock modules
│   ├── fixtures/            # Test fixtures
│   └── helpers/             # Test utilities
└── platform_specific/        # Platform-specific tests
```

## Key Files and Their Purposes

### Configuration Files
- `mix.exs` - Project definition and dependencies
- `config/config.exs` - Base configuration
- `config/runtime.exs` - Runtime configuration
- `config/test.exs` - Test environment config

### Entry Points
- `lib/raxol/application.ex` - OTP application start
- `lib/raxol_web/endpoint.ex` - Phoenix endpoint
- `lib/raxol/runtime/supervisor.ex` - Main supervisor

### Core Interfaces
- `lib/raxol/component.ex` - Component behavior
- `lib/raxol/plugin.ex` - Plugin behavior
- `lib/raxol/terminal/emulator_behaviour.ex` - Emulator interface

## Module Relationships

### Dependency Flow
```
User Apps
    ↓
Components → Runtime → Terminal Core
    ↓          ↓           ↓
Themes    Events     Buffer/Parser
    ↓          ↓           ↓
Renderer  Plugins    Platform Services
```

### Communication Patterns

#### Synchronous Calls
- Buffer operations
- State queries
- Configuration access

#### Asynchronous Messages
- Event dispatch
- Plugin notifications
- Render updates

#### PubSub Topics
- `terminal:*` - Terminal events
- `component:*` - Component updates
- `plugin:*` - Plugin notifications

## Code Organization Principles

### Module Naming
- Descriptive, hierarchical names
- Behavior suffixes (`_behaviour`)
- Implementation suffixes (`_impl`)
- Test suffixes (`_test`)

### File Structure
- One module per file
- Behaviors separate from implementations
- Tests mirror source structure
- Helpers in support modules

### Dependency Rules
- Core modules no external deps
- Web modules depend on core
- Plugins isolated dependencies
- Tests can mock anything

## Important Patterns

### GenServer Usage
- State management
- Process isolation
- Supervised processes
- Call/cast patterns

### Supervision Trees
- Restart strategies
- Child specifications
- Dynamic supervisors
- Process registration

### Event Handling
- Event bubbling
- Handler registration
- Priority ordering
- Async dispatch

### Plugin Architecture
- Behavior definitions
- Dynamic loading
- Hook registration
- Dependency resolution

## Development Areas

### Active Development
- `lib/raxol/ai/` - AI features
- `lib/raxol/cloud/` - Cloud integration
- `lib/raxol/enterprise/` - Enterprise features

### Experimental
- `lib/raxol/experimental/` - New features
- `bench/` - Performance experiments
- `demos/` - Demo applications

### Deprecated
- None currently (clean codebase)

## Navigation Tips

### Finding Code
1. Start with module name search
2. Check behavior definitions
3. Look for test files
4. Review documentation

### Understanding Flow
1. Start at application.ex
2. Follow supervisor tree
3. Trace message flow
4. Check event handlers

### Making Changes
1. Find existing patterns
2. Check test coverage
3. Update documentation
4. Run benchmarks