# Getting Started with Raxol

Welcome to Raxol! This guide will help you get up and running with the most advanced terminal framework in Elixir in just 5 minutes.

## Table of Contents
- [Installation](#installation)
- [Your First Terminal App](#your-first-terminal-app)
- [Understanding Components](#understanding-components)
- [Adding Interactivity](#adding-interactivity)
- [Working with State](#working-with-state)
- [Next Steps](#next-steps)

## Installation

### Prerequisites
- Elixir 1.15.7 or later
- Erlang/OTP 26.0 or later
- Node.js 20+ (for web interface)

### Add Raxol to Your Project

Add Raxol to your `mix.exs` dependencies:

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

## Your First Terminal App

Let's create a simple "Hello, Terminal!" application:

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
        Hello, <%= @name %>! 👋
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
  use Raxol.Application
  
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

Congratulations! You've created your first Raxol terminal application! 🎉

## Understanding Components

Raxol uses a component-based architecture similar to React or Phoenix LiveView. Components are the building blocks of your terminal UI.

### Basic Component Structure

```elixir
defmodule MyComponent do
  use Raxol.Component
  
  # Optional: Define props with types
  prop :title, :string, required: true
  prop :count, :integer, default: 0
  
  # Lifecycle callbacks
  @impl true
  def mount(socket) do
    {:ok, assign(socket, internal_state: "initialized")}
  end
  
  @impl true
  def update(assigns, socket) do
    # Called when props change
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Text><%= @title %>: <%= @count %></Text>
    </Box>
    """
  end
end
```

### Built-in Components

Raxol provides a rich set of pre-built components:

#### Layout Components
- `<Box>` - Container with padding, margin, and borders
- `<Grid>` - Grid layout system
- `<Stack>` - Vertical or horizontal stacking
- `<Spacer>` - Flexible spacing

#### Text Components
- `<Text>` - Styled text with colors and formatting
- `<Heading>` - Headers with levels (h1-h6)
- `<Code>` - Code blocks with syntax highlighting
- `<Link>` - Clickable links

#### Input Components
- `<TextInput>` - Single-line text input
- `<TextArea>` - Multi-line text input
- `<Select>` - Dropdown selection
- `<Checkbox>` - Checkbox input
- `<RadioGroup>` - Radio button group

#### Display Components
- `<Table>` - Data tables
- `<List>` - Ordered/unordered lists
- `<ProgressBar>` - Progress indicators
- `<Spinner>` - Loading spinners
- `<Chart>` - Data visualization

## Adding Interactivity

Make your applications interactive with event handling:

### Counter Example

```elixir
defmodule Counter do
  use Raxol.Component
  
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

```elixir
defmodule ShortcutExample do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    {:ok, 
     socket
     |> assign(message: "Press a key...")
     |> register_shortcuts([
       {"ctrl+s", "save"},
       {"ctrl+q", "quit"},
       {"?", "help"}
     ])}
  end
  
  @impl true
  def handle_event("save", _, socket) do
    {:noreply, assign(socket, message: "Saving...")}
  end
  
  @impl true
  def handle_event("quit", _, socket) do
    Raxol.quit()
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("help", _, socket) do
    {:noreply, assign(socket, message: "Help: Ctrl+S to save, Ctrl+Q to quit")}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Text><%= @message %></Text>
    </Box>
    """
  end
end
```

## Working with State

Raxol provides powerful state management capabilities:

### Local Component State

```elixir
defmodule TodoList do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    {:ok, 
     socket
     |> assign(todos: [])
     |> assign(input: "")}
  end
  
  @impl true
  def handle_event("add_todo", %{"value" => text}, socket) do
    todo = %{id: System.unique_integer(), text: text, done: false}
    {:noreply, 
     socket
     |> update(:todos, &[todo | &1])
     |> assign(input: "")}
  end
  
  @impl true
  def handle_event("toggle_todo", %{"id" => id}, socket) do
    todos = Enum.map(socket.assigns.todos, fn todo ->
      if todo.id == id, do: %{todo | done: !todo.done}, else: todo
    end)
    {:noreply, assign(socket, todos: todos)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Heading>Todo List</Heading>
      <TextInput 
        value={@input} 
        onSubmit="add_todo"
        placeholder="Add a todo..." 
      />
      <List marginTop={2}>
        <%= for todo <- @todos do %>
          <ListItem>
            <Checkbox 
              checked={todo.done} 
              onChange="toggle_todo"
              params={%{id: todo.id}}
            >
              <Text strikethrough={todo.done}>
                <%= todo.text %>
              </Text>
            </Checkbox>
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
  
  @impl true
  def mount(socket) do
    # Subscribe to global events
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
    # Broadcast to all subscribers
    Raxol.PubSub.broadcast("user:updated", {:user_updated, user})
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <%= if @user do %>
        <Text>Current User: <%= @user.name %></Text>
        <Text color="gray">Updated: <%= @user.updated_at %></Text>
      <% else %>
        <Text>No user logged in</Text>
      <% end %>
    </Box>
    """
  end
end
```

## Next Steps

Now that you've learned the basics, explore these advanced topics:

### 📚 Learn More
- [Component API Reference](./API_REFERENCE.md) - Complete component documentation
- [Plugin Development](./PLUGIN_SYSTEM_GUIDE.md) - Extend Raxol with plugins
- [Web Interface](./WEB_INTERFACE_GUIDE.md) - Deploy terminal apps to the web
- [Architecture Documentation](./ARCHITECTURE.md) - System design and patterns

### 🎮 Interactive Examples
Run the interactive examples to see Raxol in action:

```bash
# Component showcase
mix raxol.examples showcase

# Todo application
mix raxol.examples todo

# Dashboard demo
mix raxol.examples dashboard

# Text editor
mix raxol.examples editor
```

### 🛠️ Development Tools

#### Hot Reloading
Enable hot reloading for rapid development:

```elixir
# config/dev.exs
config :raxol,
  hot_reload: true,
  reload_paths: ["lib"]
```

#### DevTools
Press `F12` in any Raxol app to open the developer tools:
- Component inspector
- State viewer
- Performance profiler
- Event logger

### 🤝 Community
- [GitHub Discussions](https://github.com/hydepwns/raxol/discussions) - Ask questions
- [Discord Server](https://discord.gg/raxol) - Chat with the community
- [Twitter](https://twitter.com/raxol_terminal) - Updates and tips

## Troubleshooting

### Common Issues

#### Terminal doesn't render correctly
- Ensure your terminal supports 256 colors: `echo $TERM`
- Try setting: `export TERM=xterm-256color`

#### Components not updating
- Check that you're returning `{:noreply, socket}` from event handlers
- Verify props are being passed correctly
- Use `IO.inspect(assigns)` to debug state

#### Performance issues
- Use `Raxol.Profile.start()` to identify bottlenecks
- Implement `shouldComponentUpdate/2` for expensive renders
- Consider virtual scrolling for large lists

For more help, see our [Troubleshooting Guide](./TROUBLESHOOTING.md).

---

🎉 **You're ready to build amazing terminal applications with Raxol!**

Remember: The terminal is your canvas, and Raxol is your paintbrush. Create something beautiful! 🎨