---
title: Quick Start Guide
description: Get started with Raxol Terminal Emulator quickly
date: 2023-04-04
author: Raxol Team
section: guides
tags: [quick start, guide, tutorial]
---

# Quick Start Guide

This guide will help you get started with Raxol Terminal Emulator quickly.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/raxol.git
   cd raxol
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Build the project:
   ```bash
   mix compile
   ```

## Basic Usage

### Starting the Terminal

```elixir
# Start the terminal emulator
iex -S mix run -e "Raxol.Terminal.Emulator.start()"
```

### Basic Terminal Operations

```elixir
# Create a new terminal emulator
terminal = Raxol.Terminal.Emulator.new(80, 24)

# Write text to the terminal
terminal = Raxol.Terminal.Emulator.write_char(terminal, "Hello, World!")

# Move the cursor
terminal = Raxol.Terminal.Emulator.move_cursor(terminal, 5, 5)

# Set text attributes
terminal = Raxol.Terminal.Emulator.set_attribute(terminal, :bold)
terminal = Raxol.Terminal.Emulator.set_attribute(terminal, :underline)
```

### Using Plugins

```elixir
# Load plugins
{:ok, terminal} = Raxol.Terminal.Emulator.load_plugin(terminal, Raxol.Plugins.HyperlinkPlugin)
{:ok, terminal} = Raxol.Terminal.Emulator.load_plugin(terminal, Raxol.Plugins.ImagePlugin)

# Enable/disable a plugin
{:ok, terminal} = Raxol.Terminal.Emulator.disable_plugin(terminal, "hyperlink")
{:ok, terminal} = Raxol.Terminal.Emulator.enable_plugin(terminal, "hyperlink")
```

## Next Steps

- Check out the [Installation Guide](../installation/Installation.md) for detailed installation instructions
- Explore the [Components Documentation](../components/README.md) to learn about available components
- Read the [Contributing Guide](../../CONTRIBUTING.md) to learn how to contribute to the project 