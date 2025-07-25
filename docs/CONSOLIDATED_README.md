---
title: Raxol Documentation Hub
description: Complete consolidated documentation for Raxol TUI library
date: 2025-07-25
author: Raxol Team
section: documentation
tags: [documentation, hub, guide, reference]
---

# Raxol Documentation Hub

Welcome to Raxol—a modern toolkit for building terminal user interfaces (TUIs) in Elixir.

## 🚀 Quick Start

1. **Installation**: Choose your preferred method
   - [Nix Development Environment](DEVELOPMENT.md#nix-setup) (Recommended)
   - [Manual Installation](DEVELOPMENT.md#manual-installation)

2. **First Application**: [Quick Start Guide](../examples/guides/01_getting_started/quick_start.md)

3. **Interactive Demos**: 
   ```bash
   mix run bin/demo.exs  # Interactive menu
   mix run bin/demo.exs form  # Specific demo
   ```

## 📚 Documentation Structure

### Core Documentation
- [Architecture](ARCHITECTURE.md) - System design and principles
- [Development Guide](DEVELOPMENT.md) - Setup, workflow, troubleshooting
- [Configuration](CONFIGURATION.md) - Settings and environment

### Component System
- [Component Guide](components/README.md) - Complete component reference
- [Component API](components/api/README.md) - API documentation
- [Style Guide](components/style_guide.md) - Styling patterns

### User Guides
- [Getting Started](../examples/guides/01_getting_started/) - Installation and first app
- [Core Concepts](../examples/guides/02_core_concepts/) - Terminal, events, theming
- [Component Reference](../examples/guides/03_component_reference/) - Detailed component docs
- [Extending Raxol](../examples/guides/04_extending_raxol/) - Plugins and extensions
- [Development & Testing](../examples/guides/05_development_and_testing/) - Testing patterns

### Examples & Snippets
- [Example Browser](../examples/snippets/README.md) - Interactive examples
- [Basic Examples](../examples/snippets/basic/) - Simple patterns
- [Advanced Examples](../examples/snippets/advanced/) - Complex implementations
- [Showcase](../examples/snippets/showcase/) - Feature demonstrations

## 🎯 Key Features

- **Terminal Emulator**: ANSI support, buffer management, cursor handling
- **Component Architecture**: Reusable UI components with state management
- **Plugin System**: Extensible architecture for custom features
- **Event System**: Keyboard, mouse, window resize, and custom events
- **Theme Support**: Customizable styling with color system integration
- **Performance**: < 1ms event processing, < 2ms screen updates

## 🔗 External Resources

- [GitHub Repository](https://github.com/Hydepwns/raxol)
- [HexDocs](https://hexdocs.pm/raxol/0.6.0)
- [Issue Tracker](https://github.com/Hydepwns/raxol/issues)
- [Changelog](../CHANGELOG.md)

---
*This consolidated README replaces the fragmented documentation across multiple files. See MIGRATION.md for details on moved content.*