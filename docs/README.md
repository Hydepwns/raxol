---
title: Raxol Library Documentation
description: Documentation for using the Raxol TUI library in Elixir projects
date: 2025-05-10
author: DROO AMOR
section: overview
tags: [documentation, overview, library, tui, elixir]
---

## Raxol Documentation

Welcome to the main documentation index for Raxol, a terminal application toolkit for Elixir.

## Project Status

As of May 10, 2025:

- Test suite: 49 doctests, 1528 tests, 279 failures, 17 invalid, 21 skipped
- Recent improvements: See [CHANGELOG.md](/CHANGELOG.md) for details

## Key Sections

- **[Architecture](ARCHITECTURE.md):** Overview of the Raxol system architecture.
- **[UI Components & Layout](../docs/guides/03_components_and_layout/components/README.md):** Documentation for built-in UI components and the layout system.
- **Examples:** Explore runnable demos and snippets in the top-level `examples/` directory.
- **[CHANGELOG](../CHANGELOG.md):** Log of changes between versions.

## Navigating the Docs

Use the links above to explore different topics. Start with the Installation and Getting Started guides if you are new to Raxol. Check the `ARCHITECTURE.md` for a high-level overview.

## Performance Requirements

Raxol enforces strict performance requirements through automated testing:

- Event processing: < 1ms average, < 2ms 95th percentile
- Screen updates: < 2ms average, < 5ms 95th percentile
- Concurrent operations: < 5ms average, < 10ms 95th percentile

See [Performance Testing](/docs/testing/performance_testing.md) for details.
