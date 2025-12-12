# Raxol Roadmap

This document outlines planned features and enhancements for Raxol.

## Current Version: v2.0.1

### Released Features
- Multi-framework UI support (React, LiveView, HEEx, Raw)
- VT100/ANSI terminal emulation
- Cross-platform support (macOS, Linux, Windows)
- VIM navigation patterns
- Command parser with tab completion
- Fuzzy search functionality
- Virtual filesystem
- Cursor effects and animations
- Modular package architecture

## Upcoming Features

### v2.1.0 - Svelte Framework Support (Q1 2026)

**Goal**: Add Svelte-style reactive component patterns with compile-time optimization

**Features**:
- \`use Raxol.UI, framework: :svelte\` support
- Reactive state management with \`state(:name, value)\` macro
- Computed properties via \`reactive :name do ... end\`
- Two-way data binding
- Component lifecycle hooks (onMount, onDestroy, beforeUpdate, afterUpdate)
- Store pattern with derived values
- Compile-time optimizations for reactive dependencies

**Implementation**:
- \`Raxol.Svelte.Component\` module
- \`Raxol.Svelte.Store\` for reactive stores
- \`Raxol.Svelte.Reactive\` for reactive statements
- Component compiler to track dependencies
- Runtime for efficient updates

**Example**:
\`\`\`elixir
defmodule MyCounter do
  use Raxol.UI, framework: :svelte

  state(:count, 0)
  state(:step, 1)

  reactive :doubled do
    @count * 2
  end

  def render(assigns) do
    ~H"""
    <Box>
      <Text>Count: {@count}</Text>
      <Text>Doubled: {@doubled}</Text>
      <Button on_click={increment}>+</Button>
    </Box>
    """
  end
end
\`\`\`

### v2.2.0 - Enhanced Graphics (Q2 2026)

**Goal**: WebGL-style rendering capabilities in terminal

**Features**:
- Hardware-accelerated rendering via GPU
- Canvas API for custom graphics
- SVG-to-terminal conversion
- Image manipulation and filters
- Animation interpolation engine
- Particle effects system

**Use Cases**:
- Data visualizations and charts
- Terminal games with rich graphics
- Live dashboards with animations
- Interactive diagrams

### v2.3.0 - Multi-session Collaboration (Q3 2026)

**Goal**: Real-time shared terminal sessions

**Features**:
- CRDT-based state synchronization
- WebRTC peer-to-peer connections
- Session sharing and permissions
- Collaborative cursors
- User presence indicators
- Chat integration
- Session recording and playback

**Use Cases**:
- Pair programming in terminal
- Shared debugging sessions
- Remote system administration
- Live demonstrations

### v2.4.0 - Plugin Marketplace (Q4 2026)

**Goal**: Community-driven plugin ecosystem

**Features**:
- Plugin registry and discovery
- Version management
- Dependency resolution
- Plugin sandboxing and security
- Theme marketplace
- Component library sharing
- Plugin development toolkit

**Components**:
- Web interface for browsing plugins
- CLI tools for plugin management
- Plugin testing framework
- Documentation generator

### v3.0.0 - Mobile Terminal (Q1 2027)

**Goal**: iOS and Android terminal clients

**Features**:
- Native mobile apps
- Touch-optimized UI
- Mobile keyboard integration
- Cloud session sync
- Offline mode support
- Mobile-specific gestures
- Cross-device session handoff

**Platforms**:
- iOS (SwiftUI)
- Android (Compose)
- React Native (shared UI)

## Research & Exploration

### Under Consideration

- **AI Integration**: Natural language terminal commands, code suggestions
- **WebAssembly**: Browser-based terminal emulation
- **Voice Control**: Speech-to-command conversion
- **AR/VR**: Terminal in 3D space
- **Blockchain**: Decentralized session storage
- **Quantum**: Terminal for quantum computing interfaces

### Community Requests

Submit feature requests via [GitHub Issues](https://github.com/Hydepwns/raxol/issues) with the \`enhancement\` label.

## Contributing

Want to help implement these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Version Naming

- **Minor versions** (2.x.0): New frameworks, major features
- **Patch versions** (2.0.x): Bug fixes, performance improvements
- **Major versions** (3.0.0): Breaking API changes, architectural shifts

## Timeline

This roadmap is aspirational. Actual release dates may vary based on:
- Community contributions
- Prioritization changes
- Technical challenges
- Resource availability

Stay updated:
- GitHub Releases
- Discord community
- Twitter @raxol_terminal
- Monthly development blog

---

Last updated: December 2025
