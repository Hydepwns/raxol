# Building Applications with Raxol

This tutorial covers best practices for building production-ready terminal applications with Raxol v1.1.0.

## Table of Contents

- [Application Architecture](#application-architecture)
- [The Elm Architecture (TEA) in Raxol](#the-elm-architecture-tea-in-raxol)
- [Error Handling Patterns](#error-handling-patterns)
- [State Management](#state-management)
- [Performance Best Practices](#performance-best-practices)
- [Testing Strategies](#testing-strategies)
- [Deployment](#deployment)

---

## Application Architecture

Raxol applications follow The Elm Architecture (TEA) pattern, providing predictable state management and clean separation of concerns.

### Core Structure

Every Raxol application implements three essential functions:

```elixir
defmodule MyApp do
  @behaviour Raxol.Core.Runtime.Application
  
  # Initialize application state
  def init(opts) do
    {initial_state, initial_effects}
  end
  
  # Handle events and update state
  def update(state, event) do
    {new_state, effects}
  end
  
  # Render UI based on current state
  def render(state) do
    view_tree
  end
end
```

### Project Structure

Organize your Raxol application with this recommended structure:

```
lib/my_app/
├── application.ex          # Main application module
├── components/             # Reusable UI components
│   ├── button.ex
│   ├── form.ex
│   └── table.ex
├── models/                 # Domain models and business logic
│   ├── user.ex
│   └── session.ex
├── views/                  # View layer organization
│   ├── dashboard.ex
│   ├── settings.ex
│   └── login.ex
├── services/              # External service integrations
│   ├── database.ex
│   └── api_client.ex
└── utils/                 # Utility modules
    ├── helpers.ex
    └── validators.ex
```

---

## The Elm Architecture (TEA) in Raxol

### State Management

Keep your application state normalized and immutable:

```elixir
defmodule MyApp.State do
  defstruct [
    :user,
    :current_view,
    :loading,
    :error,
    :ui_state
  ]
  
  def init do
    %__MODULE__{
      user: nil,
      current_view: :login,
      loading: false,
      error: nil,
      ui_state: %{}
    }
  end
end
```

### Event Handling

Define clear event types for your application:

```elixir
defmodule MyApp.Events do
  defstruct [:type, :data, :metadata]
  
  # User events
  def login(credentials), do: %__MODULE__{type: :login, data: credentials}
  def logout, do: %__MODULE__{type: :logout}
  
  # Navigation events  
  def navigate_to(view), do: %__MODULE__{type: :navigate, data: view}
  
  # UI events
  def toggle_sidebar, do: %__MODULE__{type: :toggle_sidebar}
end
```

### Update Function Patterns

Use pattern matching for clean event handling:

```elixir
def update(state, %{type: :login, data: credentials}) do
  case authenticate_user(credentials) do
    {:ok, user} ->
      {%{state | user: user, current_view: :dashboard}, []}
    {:error, reason} ->
      {%{state | error: reason}, []}
  end
end

def update(state, %{type: :navigate, data: view}) do
  {%{state | current_view: view, error: nil}, []}
end

def update(state, %{type: :toggle_sidebar}) do
  ui_state = Map.update(state.ui_state, :sidebar_open, true, &(!&1))
  {%{state | ui_state: ui_state}, []}
end
```

---

## Error Handling Patterns

Raxol v1.1.0 provides comprehensive error handling with functional patterns.

### Using Result Types

Always use `Raxol.Core.ErrorHandling` for potentially failing operations:

```elixir
alias Raxol.Core.ErrorHandling, as: EH

def load_user_data(user_id) do
  EH.safe_call(fn ->
    user_id
    |> fetch_user_from_db()
    |> load_user_preferences()
    |> load_user_sessions()
  end)
  |> EH.map(&format_user_data/1)
  |> EH.unwrap_or(%{error: "Failed to load user"})
end
```

### Pipeline Error Handling

Use `with` statements for complex pipelines:

```elixir
def process_form_submission(form_data) do
  with {:ok, validated} <- validate_form(form_data),
       {:ok, user} <- create_user(validated),
       {:ok, session} <- create_session(user),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, %{user: user, session: session}}
  else
    {:error, :validation, errors} -> {:error, :form_invalid, errors}
    {:error, :user_exists} -> {:error, :duplicate_user}
    {:error, reason} -> {:error, :processing_failed, reason}
  end
end
```

### Error Recovery

Implement graceful degradation:

```elixir
def load_dashboard_data(user) do
  # Load essential data with fallbacks
  stats = load_user_stats(user) |> EH.unwrap_or(%{})
  notifications = load_notifications(user) |> EH.unwrap_or([])
  
  # Load optional data that can fail
  recent_activity = EH.safe_call(fn -> 
    load_recent_activity(user) 
  end) |> EH.unwrap_or([])
  
  %{
    stats: stats,
    notifications: notifications, 
    recent_activity: recent_activity
  }
end
```

---

## State Management

### Component State vs Application State

Distinguish between local component state and global application state:

```elixir
# Application-level state
defmodule MyApp.AppState do
  defstruct [:user, :route, :global_notifications]
end

# Component-level state
defmodule MyApp.Components.FormState do
  defstruct [:fields, :errors, :dirty, :submitting]
  
  def update_field(state, field, value) do
    fields = Map.put(state.fields, field, value)
    %{state | fields: fields, dirty: true}
  end
end
```

### State Composition

Compose complex state from smaller modules:

```elixir
defmodule MyApp.State do
  defstruct [
    :app,           # Global app state
    :ui,            # UI-specific state  
    :data,          # Business data
    :cache          # Performance cache
  ]
  
  def init(opts) do
    %__MODULE__{
      app: MyApp.AppState.init(opts),
      ui: MyApp.UIState.init(),
      data: MyApp.DataState.init(),
      cache: MyApp.Cache.init()
    }
  end
end
```

---

## Performance Best Practices

### Efficient Rendering

Use memoization for expensive renders:

```elixir
defmodule MyApp.Views.Dashboard do
  use Raxol.Core.Performance.Memoization
  
  @memoize_opts [ttl: 1000, key: &cache_key/1]
  def render_dashboard(state) do
    # Expensive dashboard rendering
    build_complex_layout(state)
  end
  
  defp cache_key(state) do
    # Create cache key from relevant state
    "dashboard:#{state.user.id}:#{state.data.version}"
  end
end
```

### Lazy Loading

Implement lazy loading for large datasets:

```elixir
def render_table(%{data: %{items: items, loading: loading}} = state) do
  Raxol.UI.Table.new()
  |> Raxol.UI.Table.items(items)
  |> Raxol.UI.Table.virtual_scroll(true)
  |> Raxol.UI.Table.on_scroll_end(:load_more)
  |> Raxol.UI.Table.loading(loading)
end

def update(state, %{type: :load_more}) do
  case load_next_page(state.data.page + 1) do
    {:ok, new_items} ->
      data = %{state.data | 
        items: state.data.items ++ new_items,
        page: state.data.page + 1
      }
      {%{state | data: data}, []}
    {:error, _} ->
      {state, []}
  end
end
```

### Memory Management

Use efficient data structures:

```elixir
# Use ETS for large datasets
defmodule MyApp.DataCache do
  def init do
    :ets.new(:app_cache, [:named_table, :public, read_concurrency: true])
  end
  
  def get(key) do
    case :ets.lookup(:app_cache, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end
  
  def put(key, value) do
    :ets.insert(:app_cache, {key, value})
    :ok
  end
end
```

---

## Testing Strategies

### Unit Testing

Test pure functions and business logic:

```elixir
defmodule MyApp.ModelsTest do
  use ExUnit.Case
  
  alias MyApp.Models.User
  
  test "validates user data correctly" do
    valid_data = %{name: "John", email: "john@example.com"}
    assert {:ok, user} = User.create(valid_data)
    assert user.name == "John"
  end
  
  test "rejects invalid email" do
    invalid_data = %{name: "John", email: "invalid"}
    assert {:error, :invalid_email} = User.create(invalid_data)
  end
end
```

### Integration Testing

Test the TEA cycle:

```elixir
defmodule MyApp.AppTest do
  use ExUnit.Case
  
  test "login flow updates state correctly" do
    {initial_state, _} = MyApp.init([])
    
    event = MyApp.Events.login(%{email: "test@example.com", password: "pass"})
    {new_state, effects} = MyApp.update(initial_state, event)
    
    assert new_state.user != nil
    assert new_state.current_view == :dashboard
    assert effects == []
  end
end
```

### Property Testing

Use property-based testing for complex logic:

```elixir
defmodule MyApp.PropertyTest do
  use ExUnit.Case
  use PropCheck
  
  property "state transitions are always valid" do
    forall {initial_state, event} <- {state_generator(), event_generator()} do
      {new_state, _effects} = MyApp.update(initial_state, event)
      valid_state?(new_state)
    end
  end
end
```

---

## Deployment

### Configuration Management

Use runtime configuration:

```elixir
# config/runtime.exs
import Config

config :my_app,
  database_url: System.get_env("DATABASE_URL"),
  api_key: System.get_env("API_KEY"),
  log_level: System.get_env("LOG_LEVEL", "info") |> String.to_atom()
```

### Release Configuration

Create releases with mix:

```elixir
# mix.exs
def project do
  [
    app: :my_app,
    version: "1.0.0",
    elixir: "~> 1.17",
    start_permanent: Mix.env() == :prod,
    releases: releases()
  ]
end

defp releases do
  [
    my_app: [
      include_executables_for: [:unix],
      applications: [runtime_tools: :permanent]
    ]
  ]
end
```

### Docker Deployment

Example Dockerfile:

```dockerfile
FROM elixir:1.17-alpine AS builder

WORKDIR /app
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only=prod
RUN mix deps.compile

COPY lib lib
COPY priv priv
RUN mix compile
RUN mix release

FROM alpine:3.18 AS runner
RUN apk add --no-cache libstdc++ openssl ncurses
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/my_app ./
EXPOSE 4000
CMD ["./bin/my_app", "start"]
```

### Monitoring

Set up telemetry for production monitoring:

```elixir
defmodule MyApp.Telemetry do
  def setup do
    :telemetry.attach_many(
      "my_app-telemetry",
      [
        [:my_app, :user, :login],
        [:my_app, :error, :occurred]
      ],
      &handle_event/4,
      nil
    )
  end
  
  def handle_event([:my_app, :user, :login], measurements, metadata, _) do
    # Log successful login
    Logger.info("User login", user_id: metadata.user_id)
  end
end
```

---

## Best Practices Summary

1. **Follow TEA**: Keep init, update, and render functions pure
2. **Use Result types**: Leverage `Raxol.Core.ErrorHandling` for all potentially failing operations
3. **Normalize state**: Keep application state flat and composable
4. **Test thoroughly**: Unit test business logic, integration test TEA cycles
5. **Optimize early**: Use memoization and lazy loading for performance
6. **Plan for failure**: Implement graceful degradation and error recovery
7. **Monitor production**: Set up telemetry and logging for production insights

---

*This tutorial is part of Raxol v1.1.0 documentation. For more information, see the [API Reference](../API_REFERENCE.md) and [Error Handling Guide](../ERROR_HANDLING_GUIDE.md).*