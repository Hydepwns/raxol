# Raxol Examples

This directory contains examples showcasing Raxol's features.

**Note:** Many examples demonstrate specific UI components. Check the comments at the top of the example file (e.g., `progress_bar_test.exs`) which often link to the corresponding component module in `lib/raxol/ui/components/` or similar paths.

## Directory Structure

- **/basic/** - Core concepts (`Counter`, `MultipleViews`, `Rendering`, `Subscriptions`, `TableFeatures`).
- **/advanced/** - Async operations, custom components (`Commands`, `DocumentationBrowser`, `Editor`, `Snake`).
- **/display/** - Visual display components (`ProgressBar`).
- **/interactive/** - User interaction, events (`FormValidation`, `EventHandling`).
- **/layout/** - Layout strategies (`Dashboard`, `AdvancedLayout`).
- **/showcase/** - More complete applications (`ComponentShowcase`, `ArchitectureDemo`, `ProgressBarDemo`).
- **/without-runtime/** - Using low-level APIs (`HelloWorld`, `Clock`, `EventViewer`).

## Getting Started

If you're new to Raxol, start with the basic examples:

```elixir
mix run examples/basic/counter.exs | cat
# Add " | cat " to prevent interference with your current terminal
```

## Running Examples

Run any example using `mix run`:

```elixir
mix run examples/showcase/component_showcase.exs | cat
# Add " | cat " to prevent interference with your current terminal
```

## Creating Your Own

Use these examples as a starting point. A simple application using the `Raxol.Component` behaviour looks like this:

```elixir
defmodule MyApp do
  use Raxol.Component
  alias Raxol.View.Elements # Optional if only using <.elements>

  @impl Raxol.Component
  def mount(_params, _session, socket) do
    # Initialize state in assigns
    {:ok, assign(socket, :message, "Hello from Raxol!")}
  end

  @impl Raxol.Component
  def handle_event("some_event", _payload, socket) do
    # Handle user events
    {:noreply, assign(socket, :message, "Event handled!")}
  end

  @impl Raxol.Component
  def render(assigns) do
    # Render UI using the ~V sigil and component syntax
    ~V"""
    <.panel title="My App">
      <.text>{assigns.message}</.text>
      <.button rax-click="some_event">Click Me</.button>
    </.panel>
    """
  end
end

# Start the application (Assuming a `Raxol.run/1` function exists)
# Raxol.run(MyApp)
# Or potentially integrate with a host application (e.g., Phoenix)
```
