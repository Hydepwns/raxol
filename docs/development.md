# Development Guide

## Setup

1. Install dependencies:

   ```bash
   mix deps.get
   mix deps.compile
   ```

2. Setup the database:

   ```bash
   mix ecto.setup
   ```

3. Run tests:
   ```bash
   mix test
   ```

## Architecture

Raxol is built with a modular architecture that separates concerns into distinct layers:

- Core: Base functionality and utilities
- Components: Reusable UI components
- Terminal: Terminal emulation and rendering
- Web: Phoenix-based web interface

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Code Style

We follow the standard Elixir formatting guidelines. Run `mix format` before committing.
