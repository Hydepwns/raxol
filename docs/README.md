---
title: Raxol Library Documentation
description: Documentation for using the Raxol TUI library in Elixir projects
date: 2025-05-10
author: DROO AMOR
section: overview
tags: [documentation, overview, library, tui, elixir]
---

# 📚 Raxol Documentation

Welcome! This is your starting point for all things Raxol—a modern, feature-rich toolkit for building sophisticated terminal user interfaces (TUIs) in Elixir. Raxol provides a comprehensive set of components, styling options, and event handling for creating interactive terminal applications with rich text formatting, keyboard input handling, and dynamic UI updates.

## 📈 Project Status (2025-06-29)

- **Test suite:** Enhanced with improved coverage and reliability
- **Recent improvements:** Major terminal system refactoring, core enhancements, and UI updates
- **Code quality:** Consistent formatting and improved maintainability
- **Documentation:** Updated with comprehensive guides and API references

## 🗂️ Key Sections

- [Architecture](ARCHITECTURE.md): System overview and design principles.
- [UI Components & Layout Guide](../examples/guides/03_components_and_layout/components/README.md): Built-in components and layout system.
- [Examples](../examples/): Runnable demos and code snippets.
- [CHANGELOG](../CHANGELOG.md): Version history and updates.

## Subsystems

- [Terminal](../lib/raxol/terminal/README.md): Low-level terminal I/O and buffer management
- [Core](../lib/raxol/core/README.md): Application lifecycle and state management
- [Plugins](../lib/raxol/plugins/README.md): Extensible plugin architecture
- [Style](../lib/raxol/style/README.md): Rich text formatting and styling system
- [UI](../lib/raxol/ui/README.md): Component system and layout management
- [AI](../lib/raxol/ai/README.md): AI-powered features and enhancements
- [Animation](../lib/raxol/animation/README.md): Dynamic UI animations and transitions

## 📦 Static Assets

All static assets (JavaScript, CSS, images, etc.) located in the `priv/static/@static` directory.

- If you need to add or update frontend assets, use the `@static` folder.
- The asset pipeline (npm, bundlers, etc.) should be run from `priv/static/@static`.
- References to static files in templates and code should use the `/@static/` path prefix.

> **Note:** This replaces the previous `assets` folder. Update any custom scripts or documentation accordingly.

## 🧭 How to Navigate

- New to Raxol? Start with the Installation and Getting Started guides.
- For a high-level overview, see [Architecture](ARCHITECTURE.md).
- Explore the links above for in-depth guides and references.

## 🚦 Performance Requirements

Raxol is built for speed and reliability. Automated tests enforce strict performance standards:

- **Event processing:** < 1ms average, < 2ms (95th percentile)
- **Screen updates:** < 2ms average, < 5ms (95th percentile)
- **Concurrent operations:** < 5ms average, < 10ms (95th percentile)

Happy hacking!
