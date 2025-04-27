---
title: Installation Guide
description: Comprehensive guide for installing Raxol Terminal Emulator
date: 2025-04-04
author: DROO AMOR
section: installation
tags: [installation, guide, setup]
---

# Raxol Installation Guide

To use Raxol in your Elixir project, add it to your list of dependencies in `mix.exs`.

## Adding the Dependency

Open your `mix.exs` file and add `raxol` to your `deps` function:

```elixir
def deps do
  [
    {:raxol, "~> 0.1.0"}
    # Or, for development, use the GitHub repository:
    # {:raxol, github: "Hydepwns/raxol"}
  ]
end
```

Replace `~> 0.1.0` with the desired version constraint. Using the GitHub repository is recommended if you need the latest development changes.

## Fetching Dependencies

After updating your `mix.exs`, run the following command in your terminal to fetch and install the dependency:

```bash
mix deps.get
```

This command downloads Raxol and its dependencies, making them available to your project.

## Next Steps

With Raxol installed, you can now start building your terminal application. See the [Getting Started Tutorial](guides/quick_start.md) for a step-by-step guide.
