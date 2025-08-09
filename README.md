# Raxol

[![CI](https://github.com/Hydepwns/raxol/workflows/CI/badge.svg)](https://github.com/Hydepwns/raxol/actions/workflows/ci.yml)
[![Codecov](https://codecov.io/gh/Hydepwns/raxol/branch/master/graph/badge.svg)](https://codecov.io/gh/Hydepwns/raxol)
[![Hex.pm](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/raxol)

A modern Elixir framework for building terminal-based applications with web capabilities. Raxol combines a powerful terminal emulator core with a component-based UI framework, real-time web interface, and extensible plugin system.

## What is Raxol?

Raxol is a **full-stack terminal application framework** that enables developers to build sophisticated terminal applications that can run both locally and be accessed through the web. It provides:

- **Advanced Terminal Emulator**: Full ANSI/VT100+ compliant terminal emulator with Sixel graphics, Unicode support, and comprehensive escape sequence handling
- **Component-Based TUI Framework**: React-style component system for building rich terminal user interfaces with lifecycle management, state handling, and reusable UI components
- **Real-Time Web Interface**: Phoenix LiveView-powered web terminal that provides browser-based access to terminal sessions with real-time collaboration features
- **Extensible Plugin Architecture**: Runtime plugin system for extending functionality with custom commands, integrations, and features
- **Enterprise Features**: Built-in authentication, session management, metrics, monitoring, and security features for production deployments

## Core Features

### Terminal Emulator Engine

- **Full ANSI/VT100+ Compliance**: Comprehensive escape sequence parsing and handling
- **Advanced Graphics**: Sixel graphics protocol, Unicode rendering, custom fonts
- **Mouse Support**: Complete mouse event handling with click, drag, selection, and reporting modes
- **Buffer Management**: Sophisticated multi-buffer system with main, alternate, and scrollback buffers
- **Input Processing**: Full keyboard, mouse, tab completion, and special key handling with modifiers
- **Modern Terminal Features**: Bracketed paste mode, column width switching (80/132), command history
- **Performance Optimized**: Efficient rendering with damage tracking and incremental updates

### Component-Based TUI Framework

- **Rich Component Library**: Pre-built components including buttons, inputs, tables, progress bars, modals, and more
- **Declarative UI**: Build interfaces using a familiar component-based approach
- **State Management**: Built-in state handling with lifecycle hooks (init, mount, update, render, unmount)
- **Layout Engine**: Flexible layout system with support for flex, grid, and absolute positioning
- **Event System**: Comprehensive event handling for keyboard, mouse, and custom events
- **Theming & Styling**: Full theming support with color schemes, styles, and customization

### Web Terminal Interface

- **Phoenix LiveView Integration**: Real-time, interactive terminal sessions in the browser
- **Collaborative Features**: Multi-user sessions with cursor tracking and shared state
- **Session Persistence**: Save and restore terminal sessions across connections
- **WebSocket Communication**: Low-latency bidirectional communication
- **Responsive Design**: Adaptive UI that works on desktop and mobile devices
- **Security**: Built-in authentication, authorization, and rate limiting

### Plugin & Extension System

- **Runtime Plugin Loading**: Load, unload, and reload plugins without restarting
- **Plugin Lifecycle Management**: Full lifecycle hooks for initialization, configuration, and cleanup
- **Command Registry**: Register custom commands that integrate with the terminal
- **Event Hooks**: Subscribe to system events and extend functionality
- **Dependency Management**: Automatic plugin dependency resolution and loading

### Development & Operations

- **Comprehensive Testing**: Unit, integration, and performance test frameworks
- **Metrics & Monitoring**: Built-in telemetry with Prometheus integration
- **Performance Profiling**: Tools for analyzing and optimizing performance
- **Configuration Management**: TOML-based configuration with validation and hot-reloading
- **Error Recovery**: Circuit breakers, supervision trees, and graceful degradation
- **Cloud Ready**: Support for distributed deployments and horizontal scaling

## Installation

See [Installation Guide](docs/DEVELOPMENT.md#quick-setup) for detailed setup instructions including:

- Nix development environment (recommended)
- Manual installation steps
- Dependency requirements

## Quick Start

### 1. Web-Based Terminal

Launch a web-accessible terminal with real-time collaboration:

```bash
# Start the server
mix phx.server

# Visit http://localhost:4000
# Create an account and start a terminal session
```

### 2. Building a TUI Application

Create rich terminal applications using the component framework:

```elixir
defmodule TodoApp do
  use Raxol.UI.Components.Base.Component

  def init(_props) do
    %{todos: [], input: ""}
  end

  def render(state, _context) do
    {:box, [border: :single, padding: 1],
      [
        {:text, [color: :cyan, bold: true], "Todo List"},
        {:input, [value: state.input, on_change: :update_input, on_submit: :add_todo]},
        {:list, [], 
          Enum.map(state.todos, fn todo ->
            {:row, [],
              [
                {:checkbox, [checked: todo.done, on_change: {:toggle, todo.id}]},
                {:text, [strikethrough: todo.done], todo.text}
              ]
            }
          end)
        }
      ]
    }
  end

  def handle_event({:change, :update_input, value}, state, _context) do
    {%{state | input: value}, []}
  end

  def handle_event({:submit, :add_todo}, state, _context) do
    new_todo = %{id: UUID.uuid4(), text: state.input, done: false}
    {%{state | todos: [new_todo | state.todos], input: ""}, []}
  end
end
```

### 3. Creating a Plugin

Extend Raxol with custom functionality:

```elixir
defmodule GitPlugin do
  use Raxol.Plugin

  def init(config) do
    {:ok, %{config: config}}
  end

  def commands do
    [
      {"git-status", &git_status/2, "Show git status in terminal"},
      {"git-log", &git_log/2, "Show formatted git log"}
    ]
  end

  defp git_status(_args, state) do
    output = System.cmd("git", ["status", "--porcelain"])
    {:ok, format_git_status(output), state}
  end
end

# Load the plugin
Raxol.Core.Runtime.Plugins.Manager.load_plugin_by_module(GitPlugin)
```

## Use Cases

### Development Tools

- **IDE Integration**: Build terminal-based development environments
- **CLI Applications**: Create sophisticated command-line tools with rich UIs
- **DevOps Dashboards**: Monitor and manage infrastructure through terminal interfaces
- **Code Editors**: Implement terminal-based text editors with syntax highlighting

### Business Applications

- **Admin Interfaces**: Build secure administrative tools accessible via terminal or web
- **Data Visualization**: Create real-time dashboards and monitoring tools
- **System Management**: Develop tools for server administration and monitoring
- **Workflow Automation**: Build interactive terminal-based automation tools

### Collaboration & Education

- **Remote Pair Programming**: Share terminal sessions for collaborative coding
- **Interactive Tutorials**: Create hands-on learning experiences in the terminal
- **Terminal Broadcasting**: Stream terminal sessions to multiple users
- **Code Reviews**: Conduct interactive code reviews in shared sessions

## Architecture

Raxol follows a layered, modular architecture designed for extensibility and performance:

```
┌─────────────────────────────────────────────────────────┐
│                    Applications                         │
│         (User TUI Apps, Plugins, Extensions)            │
├─────────────────────────────────────────────────────────┤
│                  UI Framework Layer                     │
│    (Components, Layouts, Themes, Event System)          │
├─────────────────────────────────────────────────────────┤
│                   Web Interface Layer                   │
│      (Phoenix LiveView, WebSockets, Auth, API)          │
├─────────────────────────────────────────────────────────┤
│                Terminal Emulator Core                   │
│   (ANSI Parser, Buffer Manager, Input Handler)          │
├─────────────────────────────────────────────────────────┤
│                  Platform Services                      │
│  (Plugins, Config, Metrics, Security, Persistence)      │
└─────────────────────────────────────────────────────────┘
```

### Key Design Principles

- **Separation of Concerns**: Each layer has clear responsibilities
- **Event-Driven**: Components communicate through events
- **Supervision Trees**: Fault-tolerant with OTP supervision
- **Performance First**: Optimized for high-throughput terminal operations
- **Extensible**: Plugin system allows extending any layer

## Performance

Raxol is designed for high performance and scalability:

- **Test Coverage**: 100% pass rate (1751/1751 tests passing)
- **Rendering Speed**: < 2ms average frame time for complex UIs
- **Input Latency**: < 1ms for local, < 5ms for web sessions
- **Throughput**: Handles 10,000+ operations/second per session
- **Memory Usage**: Efficient buffer management with configurable limits
- **Concurrent Users**: Tested with 100+ simultaneous sessions
- **Startup Time**: < 100ms to initialize a new terminal session
- **Production Ready**: Feature-complete with comprehensive VT100/ANSI compliance

## Getting Started

### Prerequisites

- Elixir 1.17+
- PostgreSQL (optional, for web features)
- Node.js (for asset compilation)

### Installation

Add Raxol to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:raxol, "~> 0.9.0"}
  ]
end
```

### Basic Terminal App

```elixir
# lib/my_app.ex
defmodule MyApp do
  use Raxol.Application

  def init(_args) do
    %{counter: 0}
  end

  def update({:key, "+"}, state) do
    %{state | counter: state.counter + 1}
  end

  def update({:key, "-"}, state) do
    %{state | counter: state.counter - 1}
  end

  def render(state) do
    {:box, [border: :double],
      {:center, [],
        {:text, [color: :green, bold: true], 
          "Counter: #{state.counter}"}
      }
    }
  end
end

# Run with: mix raxol.run --app MyApp
```

## What's New in v0.9.0

### Complete Terminal Feature Suite

- **🖱️ Mouse Handling**: Full mouse event system with click, drag, selection, and multiple reporting modes (X10, cell motion, SGR)
- **⌨️ Tab Completion**: Advanced completion system with cycling, callbacks, and built-in Elixir keyword support
- **📋 Bracketed Paste**: Secure paste mode that distinguishes typed vs pasted text (ESC[200~/ESC[201~)
- **📐 Column Width**: Dynamic 80/132 column switching with proper VT100 behavior (ESC[?3h/ESC[?3l)
- **🖼️ Sixel Graphics**: Complete implementation with parser, renderer, and graphics management
- **📚 Command History**: Multi-layer history system with persistence, navigation, and search

### Quality Assurance

- **✅ 100% Test Pass Rate**: 1751/1751 tests passing
- **🏭 Production Ready**: Feature-complete terminal framework
- **📋 VT100/ANSI Compliant**: Comprehensive escape sequence support
- **🔧 Zero Technical Debt**: All compilation warnings documented, all features implemented

## Why Raxol?

### For Terminal App Developers

- **Modern Development Experience**: Component-based UI development for the terminal
- **Cross-Platform**: Build once, run in terminal or web browser
- **Rich UI Components**: Pre-built, accessible components that just work
- **Type Safety**: Leverage Elixir's pattern matching and compile-time checks

### For Teams & Organizations

- **Secure Remote Access**: Built-in authentication and authorization
- **Collaboration Features**: Real-time session sharing and pair programming
- **Enterprise Ready**: Monitoring, metrics, and operational tooling included
- **Extensible**: Plugin system allows custom integrations and features

### For the Elixir Ecosystem

- **OTP Native**: Built on OTP principles with supervision trees and fault tolerance
- **Phoenix Integration**: Seamlessly integrates with existing Phoenix applications
- **Performance**: Leverages Elixir's concurrency model for high performance
- **Community Driven**: Open source with a focus on developer experience

## Documentation

Comprehensive documentation and guides:

- [Installation Guide](docs/DEVELOPMENT.md#quick-setup)
- [Component Reference](docs/components/README.md)
- [Terminal Emulator Guide](examples/guides/02_core_concepts/terminal_emulator.md)
- [Plugin Development](examples/guides/04_extending_raxol/plugin_development.md)
- [Enterprise Features](examples/guides/06_enterprise/README.md)
- [API Documentation](https://hexdocs.pm/raxol/0.9.0)
- [Example Applications](examples/)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/Hydepwns/raxol.git
cd raxol

# Install dependencies
mix deps.get

# Run tests
mix test

# Start development server
mix phx.server
```

## License

MIT License - see [LICENSE.md](LICENSE.md)

## Support

- [Documentation Hub](docs/CONSOLIDATED_README.md)
- [Hex.pm Package](https://hex.pm/packages/raxol)
