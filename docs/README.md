---
title: Raxol Documentation
description: Complete guide to the Raxol TUI library
date: 2025-01-27
author: Raxol Team
section: overview
tags: [documentation, overview, library, tui, elixir]
---

# 📚 Raxol Documentation

Welcome to Raxol—a modern toolkit for building terminal user interfaces (TUIs) in Elixir.

## 🚀 Quick Start

1. **Setup**: [Development Guide](DEVELOPMENT.md) - Get started with Nix
2. **First App**: [Quick Start](../examples/guides/01_getting_started/quick_start.md)
3. **Examples**: [Sample Applications](../examples/)

## 📖 Core Documentation

### Development

- [Development Guide](DEVELOPMENT.md) - Setup, workflow, troubleshooting
- [Architecture](ARCHITECTURE.md) - System design and principles
- [Configuration](CONFIGURATION.md) - Settings and environment

## 🎯 Key Features

- **Terminal Emulator**: ANSI support, buffer management, cursor handling
- **Component Architecture**: Reusable UI components with state management
- **Event System**: Keyboard, mouse, window resize, and custom events
- **Theme Support**: Customizable styling with color system integration
- **Performance**: < 1ms event processing, < 2ms screen updates

## 📦 Installation

```bash
# Using Nix (recommended)
git clone https://github.com/Hydepwns/raxol.git
cd raxol
nix-shell
mix deps.get
mix setup

# Or add to your project
def deps do
  [{:raxol, "~> 0.5.0"}]
end
```

## 🔗 Resources

- [GitHub](https://github.com/Hydepwns/raxol)
- [Issues](https://github.com/Hydepwns/raxol/issues)
- [CHANGELOG](../CHANGELOG.md)
