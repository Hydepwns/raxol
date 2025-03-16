# Raxol

## ⚠️ WARNING: ALPHA RELEASE ⚠️

⚠️ This is an **alpha release** of Raxol. The API is unstable and subject to significant changes without notice. Features may be incomplete, contain bugs, or behave unexpectedly. Use in production environments is strongly discouraged.

---

Raxol strives to be a comprehensive terminal UI framework, written in Elixir.

## How Raxol Works

Raxol implements The Elm Architecture (TEA), a simple yet powerful pattern for building interactive applications:

```txt
┌───────────────┐     ┌─────────────┐     ┌──────────────┐
│   MODEL       │────▶│   UPDATE    │────▶│    VIEW     │
│ (State Data)  │     │ (Logic)     │     │ (Rendering) │
└───────────────┘     └─────────────┘     └──────────────┘
        ▲                                          │
        │                                          │
        │                                          │
        │           ┌─────────────┐                │
        └───────────│   EVENTS    │◀───────────────┘
                    │ (Messages)  │
                    └─────────────┘
```

### Component Hierarchy

Raxol organizes components in a hierarchical tree structure:

```txt
         App (Root)
        /    |     \
       /     |      \
   Panel   Panel    Panel
   /  \      |      /  \
  /    \     |     /    \
Label Button Row  Input Button
             / \
            /   \
       Column   Column
         |        |
      Button    Button
```

### Event Processing Flow

```elixir
┌────────────┐    ┌───────────┐    ┌────────────┐    ┌────────────┐
│ User Input │───▶│ Event     │───▶│ Update     │───▶│ State     │
│ (Keyboard) │    │ Dispatcher│    │ Function   │    │ Change    │
└────────────┘    └───────────┘    └────────────┘    └────────────┘
                                                          │
┌────────────┐    ┌───────────┐    ┌────────────┐          │
│ Rendered   │◀───│ View      │◀───│ Component │◀─────────┘
│ UI         │    │ Function  │    │ Tree      │
└────────────┘    └───────────┘    └────────────┘
```

## Features

- **The Elm Architecture (TEA)** - Model-Update-View pattern for state management
- **Component System** - Pre-built, customizable UI components
- **Styling System** - Declarative styling with a CSS-like interface
- **Focus Management** - Keyboard navigation between interactive elements
- **Accessibility Features** - Screen reader support and keyboard navigation

## Installation

Add `raxol` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.1.0"}
  ]
end
```

## Basic Usage

```elixir
defmodule CounterExample do
  use Raxol.App
  
  @impl true
  def init(_) do
    %{count: 0}
  end
  
  @impl true
  def update(model, msg) do
    case msg do
      :increment -> %{model | count: model.count + 1}
      :decrement -> %{model | count: model.count - 1}
      _ -> model
    end
  end
  
  @impl true
  def render(model) do
    use Raxol.View
    
    view do
      panel title: "Counter Example" do
        row do
          column size: 12 do
            label content: "Count: #{model.count}"
          end
        end
        
        row do
          column size: 6 do
            button label: "Increment", on_click: :increment
          end
          column size: 6 do
            button label: "Decrement", on_click: :decrement
          end
        end
      end
    end
  end
end
```

To run your application:

```elixir
Raxol.run(CounterExample)
```

## Exploring Raxol

Beyond the basic usage with Mix, there are several ways to explore and demonstrate Raxol's capabilities:

### Running Examples

```bash
# Using Mix
mix run examples/basic/counter.exs

# Using Elixir directly
elixir examples/basic/counter.exs

# Running the integrated demo
elixir bin/demo.exs
```

### Testing and Validation

```bash
# Run the test suite
mix test

# Validate performance
elixir scripts/validate_performance.exs

# Run platform-specific tests
elixir scripts/run_platform_tests.exs
```

### Compilation and Distribution

```bash
# Standard compilation
mix compile

# Create a release
mix release
```

For more detailed documentation and examples, explore the `docs` directory and the `examples` folder which contains applications of varying complexity to showcase Raxol's features.

## Styling

Raxol provides a declarative styling system:

```elixir
import Raxol.Style

# Create a style
button_style = style([
  color: :blue,
  background: :white,
  padding: [1, 2],
  border: :rounded,
  width: 20,
  align: :center
])

# Apply style to content
styled_button = render(button_style, "Click Me")
```

## Advanced Components

Raxol includes a growing library of pre-built components:

```elixir
alias Raxol.Components.Button

Button.new("Save Changes", 
  on_click: :save_clicked,
  style: :primary,
  icon: :check
)
```

## Documentation

For more detailed documentation, see the `docs` directory or run `mix docs` to generate the full documentation.
