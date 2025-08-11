# Getting Started with Raxol

---
id: getting_started
title: Getting Started with Raxol
difficulty: beginner
estimated_time: 15
tags: [basics, introduction, setup]
prerequisites: []
---

## Welcome to Raxol!

Raxol is a powerful terminal framework for Elixir that provides React-style components, advanced terminal emulation, and enterprise features. This tutorial will guide you through the basics of using Raxol.

### Step 1: Understanding Raxol Architecture
---
step_id: architecture_overview
title: Understanding the Architecture
---

Raxol is built with a modular architecture consisting of:

- **Terminal Emulator**: Handles ANSI escape sequences and terminal state
- **Component System**: React-style components for building UIs
- **Event System**: Manages keyboard, mouse, and custom events
- **Rendering Pipeline**: Efficient rendering with caching and optimization

#### Example Code

```elixir
# Creating a simple Raxol application
defmodule MyApp do
  use Raxol.Application
  
  def init(_args) do
    {:ok, %{counter: 0}}
  end
  
  def render(state) do
    Raxol.UI.view do
      Raxol.UI.text("Counter: #{state.counter}")
      Raxol.UI.button("Increment", on_click: :increment)
    end
  end
  
  def handle_event(:increment, state) do
    {:ok, %{state | counter: state.counter + 1}}
  end
end
```

#### Exercise

Create a simple counter application that displays a number and allows incrementing/decrementing it.

#### Hints
- Use `Raxol.Core.Renderer.View.Components.button/2` for interactive buttons
- Handle events with `handle_event/2`
- Update state immutably

### Step 2: Working with Components
---
step_id: components_basics
title: Working with Components
---

Raxol provides a rich set of built-in components:

- **Text Components**: `text`, `label`, `heading`
- **Input Components**: `text_input`, `text_area`, `select`
- **Layout Components**: `box`, `flex`, `grid`
- **Interactive Components**: `button`, `checkbox`, `radio`

#### Example Code

```elixir
defmodule TodoList do
  use Raxol.Component
  
  def init(_props) do
    {:ok, %{todos: [], input: ""}}
  end
  
  def render(state, _props) do
    Raxol.UI.box(border: :single) do
      Raxol.UI.heading("Todo List", level: 1)
      
      Raxol.UI.text_input(
        value: state.input,
        on_change: {:update_input, :value},
        on_submit: :add_todo
      )
      
      Raxol.UI.list(state.todos, fn todo ->
        Raxol.UI.text("• #{todo}")
      end)
    end
  end
  
  def handle_event({:update_input, value}, state) do
    {:ok, %{state | input: value}}
  end
  
  def handle_event(:add_todo, state) do
    todos = state.todos ++ [state.input]
    {:ok, %{state | todos: todos, input: ""}}
  end
end
```

#### Exercise

Build a todo list component that allows adding, removing, and marking items as complete.

#### Hints
- Use `Raxol.UI.Components.Button` for interactive elements
- Store todos as a list of maps with `text` and `completed` fields
- Use `Raxol.UI.Components.TextInput` for form inputs

### Step 3: Handling User Input
---
step_id: user_input
title: Handling User Input
---

Raxol provides comprehensive input handling:

- **Keyboard Events**: Key presses, shortcuts, modifiers
- **Mouse Events**: Clicks, drags, scrolling
- **Text Input**: With validation and formatting
- **Focus Management**: Tab navigation and focus control

#### Example Code

```elixir
defmodule SearchBox do
  use Raxol.Component
  
  def init(_props) do
    {:ok, %{
      query: "",
      results: [],
      selected_index: 0
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.text_input(
        value: state.query,
        placeholder: "Search...",
        on_change: {:update_query, :value},
        on_key_down: :handle_key
      )
      
      if length(state.results) > 0 do
        Raxol.UI.list_with_selection(
          state.results,
          state.selected_index,
          fn result, selected ->
            style = if selected, do: [background: :blue], else: []
            Raxol.UI.text(result, style: style)
          end
        )
      end
    end
  end
  
  def handle_event({:update_query, value}, state) do
    results = search_items(value)
    {:ok, %{state | query: value, results: results, selected_index: 0}}
  end
  
  def handle_event({:handle_key, %{key: :arrow_down}}, state) do
    max_index = length(state.results) - 1
    new_index = min(state.selected_index + 1, max_index)
    {:ok, %{state | selected_index: new_index}}
  end
  
  def handle_event({:handle_key, %{key: :arrow_up}}, state) do
    new_index = max(state.selected_index - 1, 0)
    {:ok, %{state | selected_index: new_index}}
  end
  
  def handle_event({:handle_key, %{key: :enter}}, state) do
    selected_item = Enum.at(state.results, state.selected_index)
    # Handle selection
    {:ok, state}
  end
  
  defp search_items(query) do
    # Implement search logic
    ["Result 1", "Result 2", "Result 3"]
  end
end
```

#### Exercise

Create a searchable dropdown component with keyboard navigation.

#### Hints
- Use arrow keys for navigation
- Implement fuzzy search for filtering
- Handle Enter key for selection

### Step 4: Styling and Theming
---
step_id: styling_theming
title: Styling and Theming
---

Raxol supports rich styling options:

- **Colors**: 24-bit true color support
- **Text Styles**: Bold, italic, underline, strikethrough
- **Borders**: Single, double, rounded, custom
- **Themes**: Predefined and custom themes

#### Example Code

```elixir
defmodule ThemedApp do
  use Raxol.Application
  
  def init(_args) do
    {:ok, %{theme: :dark}}
  end
  
  def render(state) do
    theme = get_theme(state.theme)
    
    Raxol.UI.themed(theme) do
      Raxol.UI.box(
        border: :rounded,
        padding: 2,
        style: [background: theme.background]
      ) do
        Raxol.UI.heading(
          "Themed Application",
          style: [color: theme.primary, bold: true]
        )
        
        Raxol.UI.text(
          "This app supports multiple themes",
          style: [color: theme.text]
        )
        
        Raxol.UI.button(
          "Toggle Theme",
          on_click: :toggle_theme,
          style: [
            background: theme.accent,
            color: theme.background
          ]
        )
      end
    end
  end
  
  def handle_event(:toggle_theme, state) do
    new_theme = if state.theme == :dark, do: :light, else: :dark
    {:ok, %{state | theme: new_theme}}
  end
  
  defp get_theme(:dark) do
    %{
      background: "#1e1e1e",
      text: "#d4d4d4",
      primary: "#569cd6",
      accent: "#c586c0"
    }
  end
  
  defp get_theme(:light) do
    %{
      background: "#ffffff",
      text: "#000000",
      primary: "#0066cc",
      accent: "#663399"
    }
  end
end
```

#### Exercise

Create a theme switcher that supports at least 3 different color schemes.

#### Hints
- Store theme configuration in a separate module
- Use CSS color names or hex values
- Apply theme to all child components

### Step 5: Advanced Features
---
step_id: advanced_features
title: Advanced Features
---

Explore Raxol's advanced capabilities:

- **Sixel Graphics**: Display images in terminal
- **Animation**: Smooth transitions and effects
- **Virtual Scrolling**: Handle large datasets
- **Hot Reloading**: Live code updates

#### Example Code

```elixir
defmodule AnimatedDashboard do
  use Raxol.Component
  
  def init(_props) do
    # Start animation timer
    :timer.send_interval(100, self(), :tick)
    
    {:ok, %{
      progress: 0,
      direction: 1,
      data: generate_data()
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.heading("Animated Dashboard")
      
      # Animated progress bar
      Raxol.UI.progress_bar(
        value: state.progress,
        max: 100,
        style: [color: progress_color(state.progress)]
      )
      
      # Live data visualization
      Raxol.UI.chart(
        type: :line,
        data: state.data,
        animated: true
      )
      
      # Sixel image display (if supported)
      if Raxol.Terminal.supports_sixel?() do
        Raxol.UI.image("logo.png", width: 20, height: 10)
      end
    end
  end
  
  def handle_info(:tick, state) do
    new_progress = state.progress + state.direction * 5
    
    {progress, direction} = 
      cond do
        new_progress >= 100 -> {100, -1}
        new_progress <= 0 -> {0, 1}
        true -> {new_progress, state.direction}
      end
    
    {:ok, %{state | progress: progress, direction: direction}}
  end
  
  defp progress_color(progress) do
    cond do
      progress < 33 -> :red
      progress < 66 -> :yellow
      true -> :green
    end
  end
  
  defp generate_data do
    for i <- 1..10, do: {i, :rand.uniform(100)}
  end
end
```

#### Exercise

Build an animated loading spinner with customizable styles.

#### Hints
- Use Unicode characters for spinner frames
- Implement smooth rotation animation
- Allow customizing speed and colors

### Congratulations!

You've completed the Getting Started tutorial! You now understand:

- ✓ Raxol's architecture and components
- ✓ Building interactive UIs
- ✓ Handling user input
- ✓ Styling and theming
- ✓ Advanced features

## Next Steps

- Explore the [Component Catalog](component_catalog.md)
- Learn about [Terminal Emulation](03_terminal_emulation.md)
- Build a [Real-World Application](building_apps.md)