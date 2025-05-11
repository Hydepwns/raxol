---
title: Raxol Library Documentation
description: Documentation for using the Raxol TUI library in Elixir projects
date: 2025-05-10
author: DROO AMOR
section: overview
tags: [documentation, overview, library, tui, elixir]
---

# 📚 Raxol Documentation

Welcome! This is your starting point for all things Raxol—a powerful toolkit for building interactive terminal (TUI) applications in Elixir.

## 📈 Project Status

- **Test suite:** 49 doctests, 1528 tests, 279 failures, 17 invalid, 21 skipped
- **Recent improvements:** See the [CHANGELOG](../CHANGELOG.md) for details.

## 🗂️ Key Sections

- [Architecture](ARCHITECTURE.md): System overview and design principles.
- [UI Components & Layout](../docs/guides/03_components_and_layout/components/README.md): Built-in components and layout system.
- [Examples](../examples/): Runnable demos and code snippets.
- [CHANGELOG](../CHANGELOG.md): Version history and updates.

## 🧭 How to Navigate

- New to Raxol? Start with the Installation and Getting Started guides.
- For a high-level overview, see [Architecture](ARCHITECTURE.md).
- Explore the links above for in-depth guides and references.

## 🚦 Performance Requirements

Raxol is built for speed and reliability. Automated tests enforce strict performance standards:

- **Event processing:** < 1ms average, < 2ms (95th percentile)
- **Screen updates:** < 2ms average, < 5ms (95th percentile)
- **Concurrent operations:** < 5ms average, < 10ms (95th percentile)

See the [Performance Testing Guide](/docs/testing/performance_testing.md) for more details.

Happy hacking!
