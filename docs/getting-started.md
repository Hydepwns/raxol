# Getting Started with Raxol

Terminal framework for Elixir supporting multiple UI patterns.

## Table of Contents
- [Installation](#installation)
- [Your First Terminal App](#your-first-terminal-app)
- [Understanding Components](#understanding-components)
- [Adding Interactivity](#adding-interactivity)
- [Working with State](#working-with-state)
- [Styling and Theming](#styling-and-theming)
- [Web Interface](#web-interface)
- [Plugin System](#plugin-system)
- [Next Steps](#next-steps)

## Installation

### Prerequisites

Raxol requires:
- **Elixir** 1.15.7 or later  
- **Erlang/OTP** 26.0 or later
- **Node.js** 20+ (for web interface)

### Using Nix (Development)

```bash
# Clone the repository
git clone https://github.com/Hydepwns/raxol.git
cd raxol

# Enter the development environment
nix-shell

# Install dependencies and setup
mix deps.get
git submodule update --init --recursive
mix setup
```

Nix provides Erlang, Elixir, PostgreSQL, and build tools.

### Using Mix (Production)

Add to `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.9.0"}
  ]
end
```

Then fetch the dependency:

```bash
mix deps.get
mix deps.compile
```

### Try It Now

```bash
# Interactive tutorial (5 minutes)
mix raxol.tutorial

# Component playground
mix raxol.playground

# Run tests
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
```

## Your First Terminal App

Let's create a simple "Hello, Terminal!" application that showcases Raxol's component system.

### 1. Create a New Project

```bash
mix new my_terminal_app
cd my_terminal_app
```

### 2. Create Your First Component

Create `lib/my_terminal_app/hello_component.ex`:

```elixir
defmodule MyTerminalApp.HelloComponent do
  use Raxol.Component
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box padding={2} border="rounded" borderColor="green">
      <Text color="cyan" bold>
        Hello, <%= @name %>!
      </Text>
      <Text color="gray" marginTop={1}>
        Welcome to Raxol - The Terminal Framework
      </Text>
    </Box>
    """
  end
end
```

### 3. Create the Main Application

Create `lib/my_terminal_app/app.ex`:

```elixir
defmodule MyTerminalApp.App do
  use Raxol.Core.Runtime.Application
  import Raxol.LiveView, only: [assign: 2, assign: 3]
  
  @impl true
  def mount(_params, socket) do
    {:ok, assign(socket, name: "Terminal Developer")}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Screen>
      <MyTerminalApp.HelloComponent name={@name} />
    </Screen>
    """
  end
end
```

### 4. Run Your Application

```bash
mix raxol.run --app MyTerminalApp.App
```

Application created successfully.

## Understanding Components

Component-based architecture. Choose your framework style:

### Framework Options

```elixir
# React-Style Components
defmodule MyApp do
  use Raxol.Component
  
  def render(assigns) do
    ~H"""
    <Box padding={2}>
      <Text color="green" bold>Hello, Raxol!</Text>
      <Button on_click={@on_click}>Click me!</Button>
    </Box>
    """
  end
end

# Svelte-Style Components  
defmodule MyApp do
  use Raxol.Svelte.Component
  
  state :count, 0
  reactive :doubled, do: @count * 2
  
  def render(assigns) do
    ~H"""
    <Box padding={2} use:tooltip="Reactive component">
      <Text>Count: {@count} Doubled: {@doubled}</Text>
      <Button on_click={&increment/0} in:scale>+1</Button>
    </Box>
    """
  end
end

# LiveView-Style Components
defmodule MyApp do
  use Raxol.LiveView
  import Raxol.LiveView, only: [assign: 2, assign: 3]
  
  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end
  
  def render(assigns) do
    ~H"""
    <Box padding={2}>
      <Text>Count: {@count}</Text>
      <Button phx-click="increment">+1</Button>
    </Box>
    """
  end
end
```

### Built-in Components

Built-in components:
- **Layout**: `<Box>`, `<Grid>`, `<Stack>`, `<Spacer>`
- **Text**: `<Text>`, `<Heading>`, `<Code>`, `<Link>`
- **Input**: `<TextInput>`, `<TextArea>`, `<Select>`, `<Checkbox>`, `<RadioGroup>`
- **Display**: `<Table>`, `<List>`, `<ProgressBar>`, `<Spinner>`, `<Chart>`

## Adding Interactivity

Event handling:

### Counter Example

```elixir
defmodule Counter do
  use Raxol.Component
  import Raxol.LiveView, only: [assign: 2, assign: 3, update: 3]
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end
  
  @impl true
  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
  
  @impl true
  def handle_event("decrement", _params, socket) do
    {:noreply, update(socket, :count, &(&1 - 1))}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Text size="large">Count: <%= @count %></Text>
      <Stack direction="horizontal" spacing={2}>
        <Button onClick="increment" variant="primary">
          Increment
        </Button>
        <Button onClick="decrement" variant="secondary">
          Decrement
        </Button>
      </Stack>
    </Box>
    """
  end
end
```

### Keyboard Shortcuts

Register keyboard shortcuts with `register_shortcuts/2`:

```elixir
def mount(socket) do
  {:ok,
   socket
   |> assign(message: "Press a key...")
   |> register_shortcuts([
     {"ctrl+s", "save"},
     {"ctrl+q", "quit"}
   ])}
end
```

## Working with State

### Local Component State

```elixir
defmodule TodoList do
  use Raxol.Component
  import Raxol.LiveView, only: [assign: 2, assign: 3, update: 3]
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, todos: [], input: "")}
  end
  
  @impl true
  def handle_event("add_todo", %{"value" => text}, socket) do
    todo = %{id: System.unique_integer(), text: text, done: false}
    {:noreply, socket |> update(:todos, &[todo | &1]) |> assign(input: "")}
  end
  
  @impl true
  def handle_event("toggle_todo", %{"id" => id}, socket) do
    todos = Enum.map(socket.assigns.todos, fn todo ->
      if todo.id == id do
        %{todo | done: !todo.done}
      else
        todo
      end
    end)
    {:noreply, assign(socket, todos: todos)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Heading>Todo List</Heading>
      <TextInput value={@input} onSubmit="add_todo" placeholder="Add a todo..." />
      <List>
        <%= for todo <- @todos do %>
          <ListItem>
            <Checkbox checked={todo.done} onChange={"toggle_todo", todo.id} />
            <Text strikethrough={todo.done}><%= todo.text %></Text>
          </ListItem>
        <% end %>
      </List>
    </Box>
    """
  end
end
```

### Global State with PubSub

```elixir
defmodule GlobalStateExample do
  use Raxol.Component
  import Raxol.LiveView, only: [assign: 2, assign: 3]
  
  @impl true
  def mount(socket) do
    Raxol.PubSub.subscribe("user:updated")
    {:ok, assign(socket, user: nil)}
  end
  
  @impl true
  def handle_info({:user_updated, user}, socket) do
    {:noreply, assign(socket, user: user)}
  end
  
  @impl true
  def handle_event("update_user", %{"name" => name}, socket) do
    user = %{name: name, updated_at: DateTime.utc_now()}
    Raxol.PubSub.broadcast("user:updated", {:user_updated, user})
    {:noreply, socket}
  end
end
```

## Styling and Theming

Raxol supports rich styling options:

### Colors and Styles
- **Colors**: 24-bit true color support
- **Text Styles**: Bold, italic, underline, strikethrough  
- **Borders**: Single, double, rounded, custom
- **Themes**: Predefined and custom themes

### Example Themed Application

```elixir
defmodule ThemedApp do
  use Raxol.Core.Runtime.Application
  
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

## Web Interface

Access terminal applications through web browser with session continuity.

### Enable Web Access

Update your `config/config.exs`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base",
  render_errors: [view: MyAppWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

config :raxol,
  terminal: [
    scrollback_lines: 1000,
    default_width: 80,
    default_height: 24
  ]
```

Add web dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    {:raxol, "~> 0.9.0"},
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},
    {:plug_cowboy, "~> 2.5"}
  ]
end
```

Start the web server:

```bash
mix phx.server
# Visit http://localhost:4000
```

Features:
- Real-time synchronization
- Multiple user support
- Persistent sessions
- Keyboard and mouse support

## Plugin System

Plugin system:

```elixir
defmodule MyApp.StatsPlugin do
  use Raxol.Plugin

  def init(config) do
    {:ok, %{config: config, start_time: DateTime.utc_now()}}
  end

  def commands do
    [
      {"stats", &show_stats/2, "Show application statistics"},
      {"export", &export_data/2, "Export data to JSON"}
    ]
  end

  defp show_stats(_args, state) do
    {:ok, app_state} = Raxol.Core.Runtime.get_app_state()
    
    stats = """
    Application Statistics:
    ----------------------
    Session started: #{state.start_time}
    Memory usage: #{:erlang.memory(:total) |> div(1024)} KB
    """
    
    {:ok, stats, state}
  end

  defp export_data(_args, state) do
    {:ok, app_state} = Raxol.Core.Runtime.get_app_state()
    json = Jason.encode!(app_state, pretty: true)
    File.write!("export.json", json)
    
    {:ok, "Data exported to export.json", state}
  end
end

# Load the plugin
Raxol.Core.Runtime.Plugins.Manager.load_plugin_by_module(MyApp.StatsPlugin)
```

## Next Steps

Advanced topics:

### Interactive Examples
```bash
mix raxol.examples showcase  # Component showcase
mix raxol.examples todo      # Todo application  
mix raxol.examples dashboard # Dashboard demo
```

### Development Tools
- Enable hot reloading with `config :raxol, hot_reload: true`
- Press `F12` to open DevTools (component inspector, state viewer, profiler)
- Use `mix format` to format your code
- Run `mix credo` for style checks

### Advanced Features
- **Sixel Graphics**: Display images in terminal
- **Animation**: Smooth transitions and effects (60 FPS engine)
- **Virtual Scrolling**: Handle large datasets efficiently  
- **Hot Reloading**: Live code updates during development
- **GPU Acceleration**: Hardware-accelerated rendering pipeline

### Performance
- Parser: 3.3μs/operation
- Memory: 2.8MB per session
- Startup: <10ms
- Render: 1.3μs

### Learn More
- [Component API Reference](./api-reference.md)
- [Web Interface Guide](WEB_INTERFACE_GUIDE.md) 
- [Plugin Development Guide](PLUGIN_SYSTEM_GUIDE.md)
- [Architecture Documentation](ARCHITECTURE.md)
- [Performance Tuning Guide](PERFORMANCE_TUNING_GUIDE.md)

### Community
- [GitHub Discussions](https://github.com/Hydepwns/raxol/discussions)
- [Issue Tracker](https://github.com/Hydepwns/raxol/issues)
- [Development Guide](../DEVELOPMENT.md)

## Troubleshooting

**Terminal rendering**: Set `export TERM=xterm-256color`
**Component updates**: Ensure handlers return `{:noreply, socket}`
**Performance**: Use `Raxol.Profile.start()` for profiling
**Permissions**: Use `chmod +x /path/to/raxol`

See [Troubleshooting Guide](./TROUBLESHOOTING.md) for detailed help.

---

Ready to build terminal applications with Raxol.