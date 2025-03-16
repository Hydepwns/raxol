# Raxol Examples

This directory contains examples to help you learn and explore Raxol's capabilities. The examples are organized into categories based on complexity and purpose.

## Directory Structure

- **[basic](./basic/)** - Simple examples demonstrating core concepts
- **[advanced](./advanced/)** - More complex examples showing advanced features
- **[showcase](./showcase/)** - Complete applications highlighting real-world use cases
- **[without-runtime](./without-runtime/)** - Examples showing how to use Raxol's low-level APIs

## Getting Started

If you're new to Raxol, start with the basic examples:

```
mix run examples/basic/counter.exs
```

## Running Examples

All examples can be run using Mix:

```
mix run examples/path/to/example.exs
```

## Creating Your Own

Use these examples as a starting point for your own applications. The basic structure for a Raxol application is:

```elixir
defmodule MyApp do
  use Raxol.App
  
  @impl true
  def init(_) do
    # Initial state
    %{}
  end
  
  @impl true
  def update(model, msg) do
    # Handle messages and update state
    model
  end
  
  @impl true
  def render(model) do
    # Render the UI
    use Raxol.View
    
    view do
      # UI elements
    end
  end
end

# Start the application
Raxol.run(MyApp)
``` 