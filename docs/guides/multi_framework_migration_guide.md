# Multi-Framework Migration Guide

## Overview

This guide helps you migrate between different UI frameworks in Raxol applications, understand framework-specific patterns, and leverage Raxol's universal features across all supported frameworks.

## Supported Frameworks

Raxol supports five UI paradigms:

- **React**: Component-based with JSX-like syntax
- **Svelte**: Reactive components with minimal boilerplate
- **LiveView**: Server-side rendered with real-time updates
- **HEEx**: Phoenix's HTML templating with embedded Elixir
- **Raw**: Direct terminal control for maximum performance

## Migration Strategies

### 1. Gradual Migration (Recommended)

Migrate components incrementally while maintaining a working application:

```elixir
# Start with universal patterns
defmodule MyApp.Dashboard do
  # Support multiple frameworks during transition
  use Raxol.UI, framework: :react      # Current
  # use Raxol.UI, framework: :svelte   # Target
  
  def render(assigns) do
    case get_framework_mode() do
      :react -> render_react(assigns)
      :svelte -> render_svelte(assigns)
      _ -> render_universal(assigns)
    end
  end
end
```

### 2. Wrapper Components

Create compatibility layers for smooth transitions:

```elixir
defmodule MyApp.CompatButton do
  @moduledoc """
  Universal button that works across framework migrations.
  """
  
  use Raxol.UI, framework: :universal
  
  def compat_button(assigns) do
    # Normalize props across frameworks
    assigns = normalize_button_props(assigns)
    
    case current_framework() do
      :react -> MyApp.ReactComponents.button(assigns)
      :svelte -> MyApp.SvelteComponents.button(assigns)
      :liveview -> MyApp.LiveViewComponents.button(assigns)
      :heex -> MyApp.HeexComponents.button(assigns)
      :raw -> MyApp.RawComponents.button(assigns)
    end
  end
  
  defp normalize_button_props(assigns) do
    # Convert between different prop naming conventions
    assigns
    |> convert_react_props()
    |> convert_svelte_props()
    |> convert_liveview_props()
  end
end
```

## Framework-Specific Migration Patterns

### React → Svelte

**Component Structure Changes**

```elixir
# React (Before)
defmodule MyApp.ReactCounter do
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end
  
  def render(assigns) do
    ~H"""
    <div className="counter">
      <button onClick={() => setCount(count + 1)}>
        Count: {count}
      </button>
    </div>
    """
  end
end

# Svelte (After)  
defmodule MyApp.SvelteCounter do
  use Raxol.UI, framework: :svelte
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end
  
  def render(assigns) do
    ~H"""
    <script>
      let count = 0;
      
      function increment() {
        count += 1;
      }
    </script>
    
    <div class="counter">
      <button on:click={increment}>
        Count: {count}
      </button>
    </div>
    """
  end
end
```

**Event Handling Migration**

```elixir
# React patterns
def handle_react_events(assigns) do
  ~H"""
  <button onClick={() => handleClick()}>Click</button>
  <input onChange={(e) => handleChange(e.target.value)} />
  <form onSubmit={handleSubmit}>Submit</form>
  """
end

# Equivalent Svelte patterns
def handle_svelte_events(assigns) do
  ~H"""
  <button on:click={handleClick}>Click</button>
  <input on:input={(e) => handleChange(e.target.value)} />
  <form on:submit={handleSubmit}>Submit</form>
  """
end
```

### LiveView → HEEx

**Template Syntax Migration**

```elixir
# LiveView (Before)
defmodule MyApp.LiveViewForm do
  use Raxol.UI, framework: :liveview
  
  def render(assigns) do
    ~H"""
    <%= f = form_for @changeset, "#", phx_submit: "save" %>
      <%= label f, :name %>
      <%= text_input f, :name %>
      <%= error_tag f, :name %>
      
      <%= submit "Save", phx_disable_with: "Saving..." %>
    </form>
    """
  end
end

# HEEx (After)
defmodule MyApp.HeexForm do
  use Raxol.UI, framework: :heex
  
  def render(assigns) do
    ~H"""
    <.form for={@changeset} phx-submit="save">
      <.input field={@form[:name]} type="text" label="Name" />
      <.button phx-disable-with="Saving...">Save</.button>
    </.form>
    """
  end
end
```

**State Management Changes**

```elixir
# LiveView: Server-side state
def handle_event("update", params, socket) do
  # State lives on server
  socket = assign(socket, :value, params["value"])
  {:noreply, socket}
end

# HEEx: Client-side with server sync
def handle_event("update", params, socket) do
  # Immediate client update, sync to server
  socket = 
    socket
    |> assign(:value, params["value"])
    |> push_event("sync_state", %{value: params["value"]})
    
  {:noreply, socket}
end
```

### Any Framework → Raw

**Direct Terminal Control**

```elixir
# Framework-based (Before)
defmodule MyApp.FrameworkProgress do
  use Raxol.UI, framework: :react
  
  def render(assigns) do
    ~H"""
    <div className="progress-bar">
      <div 
        className="progress-fill"
        style={{width: `${progress}%`}}
      />
    </div>
    """
  end
end

# Raw Terminal (After)
defmodule MyApp.RawProgress do
  use Raxol.UI, framework: :raw
  
  def render(assigns) do
    progress = assigns.progress || 0
    width = assigns.width || 50
    
    filled_chars = round(width * progress / 100)
    empty_chars = width - filled_chars
    
    bar = String.duplicate("█", filled_chars) <> String.duplicate("░", empty_chars)
    
    """
    #{bar} #{progress}%
    """
  end
end
```

## Universal Patterns

### Framework-Agnostic Components

```elixir
defmodule MyApp.UniversalModal do
  @moduledoc """
  Modal component that works across all frameworks.
  """
  
  # Import all framework support
  use Raxol.UI, framework: [:react, :svelte, :liveview, :heex, :raw]
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  def universal_modal(assigns) do
    assigns = 
      assigns
      |> assign_new(:show, fn -> false end)
      |> assign_new(:title, fn -> "Modal" end)
      |> assign_new(:closable, fn -> true end)
      |> assign(:framework, detect_framework(assigns))
    
    case assigns.framework do
      :react -> modal_react(assigns)
      :svelte -> modal_svelte(assigns)  
      :liveview -> modal_liveview(assigns)
      :heex -> modal_heex(assigns)
      :raw -> modal_raw(assigns)
    end
  end
  
  # React implementation
  defp modal_react(assigns) do
    ~H"""
    {show && (
      <div className="modal-overlay" onClick={closable ? onClose : null}>
        <div className="modal-content" onClick={(e) => e.stopPropagation()}>
          <div className="modal-header">
            <h2>{title}</h2>
            {closable && <button onClick={onClose}>×</button>}
          </div>
          <div className="modal-body">
            {children}
          </div>
        </div>
      </div>
    )}
    """
  end
  
  # Svelte implementation
  defp modal_svelte(assigns) do
    ~H"""
    {#if show}
      <div class="modal-overlay" on:click={closable ? onClose : null}>
        <div class="modal-content" on:click|stopPropagation>
          <div class="modal-header">
            <h2>{title}</h2>
            {#if closable}
              <button on:click={onClose}>×</button>
            {/if}
          </div>
          <div class="modal-body">
            <slot />
          </div>
        </div>
      </div>
    {/if}
    """
  end
  
  # LiveView implementation
  defp modal_liveview(assigns) do
    ~H"""
    <%= if @show do %>
      <div 
        class="modal-overlay" 
        phx-click={@closable && "close_modal"}
        phx-target={@myself}
      >
        <div class="modal-content" phx-click-away="close_modal">
          <div class="modal-header">
            <h2><%= @title %></h2>
            <%= if @closable do %>
              <button phx-click="close_modal" phx-target={@myself}>×</button>
            <% end %>
          </div>
          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
  
  # Raw terminal implementation
  defp modal_raw(assigns) do
    if assigns.show do
      title = assigns.title || "Modal"
      content = assigns.inner_block || ""
      
      # Create terminal modal using ANSI sequences
      """
      \e[2J\e[H
      ┌─────────────────────────────────────┐
      │ #{title} #{if assigns.closable, do: "                [×]", else: ""} │
      ├─────────────────────────────────────┤
      │ #{content}                          │
      └─────────────────────────────────────┘
      """
    else
      ""
    end
  end
end
```

### Shared State Management

```elixir
defmodule MyApp.SharedState do
  @moduledoc """
  Framework-agnostic state management.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    {:ok, %{subscribers: [], state: %{}}}
  end
  
  # Subscribe to state changes (works for all frameworks)
  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end
  
  # Update state and notify all frameworks
  def update_state(key, value) do
    GenServer.cast(__MODULE__, {:update, key, value})
  end
  
  def handle_call({:subscribe, pid}, _from, state) do
    subscribers = [pid | state.subscribers]
    {:reply, :ok, %{state | subscribers: subscribers}}
  end
  
  def handle_cast({:update, key, value}, state) do
    new_state = Map.put(state.state, key, value)
    
    # Notify all framework components
    for subscriber <- state.subscribers do
      send(subscriber, {:state_update, key, value})
    end
    
    {:noreply, %{state | state: new_state}}
  end
end
```

## Migration Tools and Utilities

### Automated Migration Script

```elixir
defmodule Mix.Tasks.Raxol.Migrate do
  @moduledoc """
  Automated framework migration utility.
  """
  
  use Mix.Task
  
  @shortdoc "Migrate between Raxol frameworks"
  
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, 
      switches: [
        from: :string,
        to: :string,
        path: :string,
        dry_run: :boolean
      ]
    )
    
    from_framework = Keyword.get(opts, :from) || raise "Must specify --from framework"
    to_framework = Keyword.get(opts, :to) || raise "Must specify --to framework"
    path = Keyword.get(opts, :path, "lib/")
    dry_run = Keyword.get(opts, :dry_run, false)
    
    migrate_framework(from_framework, to_framework, path, dry_run)
  end
  
  defp migrate_framework(from, to, path, dry_run) do
    files = find_framework_files(path, from)
    
    IO.puts("Found #{length(files)} #{from} files to migrate to #{to}")
    
    for file <- files do
      migrate_file(file, from, to, dry_run)
    end
    
    unless dry_run do
      IO.puts("Migration completed! Run tests to verify functionality.")
    end
  end
  
  defp migrate_file(file_path, from, to, dry_run) do
    content = File.read!(file_path)
    migrated_content = transform_content(content, from, to)
    
    if dry_run do
      IO.puts("Would migrate: #{file_path}")
      show_diff(content, migrated_content)
    else
      File.write!(file_path, migrated_content)
      IO.puts("Migrated: #{file_path}")
    end
  end
  
  defp transform_content(content, :react, :svelte) do
    content
    |> String.replace("use Raxol.UI, framework: :react", "use Raxol.UI, framework: :svelte")
    |> transform_react_to_svelte_syntax()
    |> transform_event_handlers(:react, :svelte)
    |> transform_conditional_rendering(:react, :svelte)
  end
  
  defp transform_react_to_svelte_syntax(content) do
    content
    |> String.replace(~r/className=/, "class=")
    |> String.replace(~r/onClick=/, "on:click=")
    |> String.replace(~r/onChange=/, "on:change=")
    |> String.replace(~r/{(\w+)}/), "{$1}")
    |> String.replace(~r/{(.*?) && (.*?)}/, "{#if $1}$2{/if}")
  end
  
  defp show_diff(original, migrated) do
    # Show a simple diff of changes
    IO.puts("\n--- Original")
    IO.puts("+++ Migrated")
    
    original_lines = String.split(original, "\n")
    migrated_lines = String.split(migrated, "\n")
    
    for {orig, mig, idx} <- Enum.zip([original_lines, migrated_lines, 1..length(original_lines)]) do
      if orig != mig do
        IO.puts("#{idx}: - #{orig}")
        IO.puts("#{idx}: + #{mig}")
      end
    end
  end
end
```

### Migration Testing

```elixir
defmodule MyApp.MigrationTest do
  @moduledoc """
  Tests to verify framework migrations work correctly.
  """
  
  use ExUnit.Case
  
  describe "framework migration" do
    test "component renders identically across frameworks" do
      # Test data
      assigns = %{title: "Test", count: 42, items: ["a", "b", "c"]}
      
      # Render in each framework
      react_result = MyApp.ReactComponent.render(assigns)
      svelte_result = MyApp.SvelteComponent.render(assigns) 
      liveview_result = MyApp.LiveViewComponent.render(assigns)
      heex_result = MyApp.HeexComponent.render(assigns)
      
      # Normalize for comparison (remove framework-specific syntax)
      react_normalized = normalize_output(react_result)
      svelte_normalized = normalize_output(svelte_result)
      liveview_normalized = normalize_output(liveview_result)
      heex_normalized = normalize_output(heex_result)
      
      # Verify all frameworks produce equivalent output
      assert react_normalized == svelte_normalized
      assert svelte_normalized == liveview_normalized  
      assert liveview_normalized == heex_normalized
    end
    
    test "event handling works across frameworks" do
      # Test that events are handled correctly after migration
      for framework <- [:react, :svelte, :liveview, :heex] do
        {:ok, component} = start_component(MyApp.UniversalButton, framework)
        
        # Simulate click event
        result = send_event(component, "click", %{})
        
        assert {:ok, _new_state} = result
      end
    end
    
    test "state management is preserved during migration" do
      original_state = %{count: 5, items: ["x", "y"]}
      
      # Migrate component state
      migrated_state = MyApp.StateMigrator.migrate_state(
        original_state,
        from: :react,
        to: :svelte
      )
      
      # Verify state structure is preserved
      assert migrated_state.count == original_state.count
      assert migrated_state.items == original_state.items
    end
  end
  
  defp normalize_output(html) do
    html
    |> String.replace(~r/class(?:Name)?=/, "class=")
    |> String.replace(~r/on:?(\w+)=/, "on$1=")
    |> String.replace(~r/phx-(\w+)=/, "phx$1=")
    |> String.trim()
  end
end
```

## Performance Considerations

### Framework Performance Characteristics

| Framework | Startup Time | Memory Usage | Render Speed | Bundle Size | Best For |
|-----------|--------------|--------------|-------------|-------------|----------|
| React     | Medium       | Medium       | Fast        | Large       | Complex UIs |
| Svelte    | Fast         | Low          | Very Fast   | Small       | Performance-critical |
| LiveView  | Fast         | Low          | Medium      | Minimal     | Real-time apps |
| HEEx      | Very Fast    | Very Low     | Fast        | None        | Static content |
| Raw       | Instant      | Minimal      | Instant     | None        | Terminal apps |

### Optimization During Migration

```elixir
defmodule MyApp.PerformanceOptimizer do
  @moduledoc """
  Optimize components during framework migration.
  """
  
  def optimize_for_framework(component, target_framework) do
    case target_framework do
      :svelte ->
        # Leverage Svelte's compile-time optimizations
        optimize_for_svelte(component)
        
      :raw ->
        # Minimize rendering overhead for terminal
        optimize_for_raw(component)
        
      :liveview ->
        # Optimize for server-side rendering
        optimize_for_liveview(component)
        
      _ ->
        component
    end
  end
  
  defp optimize_for_svelte(component) do
    # Use Svelte's reactive declarations
    component
    |> add_reactive_declarations()
    |> minimize_dom_updates()
    |> leverage_svelte_stores()
  end
  
  defp optimize_for_raw(component) do
    # Minimize terminal escape sequences
    component
    |> cache_ansi_sequences()
    |> batch_terminal_writes()
    |> reduce_cursor_movements()
  end
  
  defp optimize_for_liveview(component) do
    # Optimize for server-side performance
    component
    |> use_stream_for_large_lists()
    |> minimize_socket_assigns()
    |> batch_updates()
  end
end
```

## Common Migration Pitfalls

### 1. State Management Differences

```elixir
# ❌ Don't assume state works the same way
defmodule BadMigration do
  # This won't work when migrating from LiveView to React
  def handle_event("update", params, socket) do
    # LiveView: state on server
    {:noreply, assign(socket, :value, params["value"])}
  end
end

# ✅ Use framework-agnostic state patterns
defmodule GoodMigration do
  def update_value(new_value) do
    case current_framework() do
      :liveview -> 
        # Server-side update
        {:noreply, assign(socket, :value, new_value)}
      :react -> 
        # Client-side update
        {:ok, %{state | value: new_value}}
      _ ->
        # Generic state update
        MyApp.SharedState.update_state(:value, new_value)
    end
  end
end
```

### 2. Event Handler Differences

```elixir
# ❌ Framework-specific event syntax
def bad_event_handling(assigns) do
  case assigns.framework do
    :react ->
      ~H"<button onClick={handleClick}>Click</button>"
    :svelte ->
      ~H"<button on:click={handleClick}>Click</button>"
  end
end

# ✅ Universal event handling
def good_event_handling(assigns) do
  ~H"""
  <button 
    {@click_handler}
    class="universal-button"
  >
    Click
  </button>
  """
end

defp click_handler(framework) do
  case framework do
    :react -> [onClick: "handleClick"]
    :svelte -> ["on:click": "handleClick"]  
    :liveview -> ["phx-click": "handleClick"]
    _ -> []
  end
end
```

### 3. Template Syntax Confusion

```elixir
# ❌ Mixed template syntaxes
def confusing_template(assigns) do
  ~H"""
  <!-- This mixes React and Svelte syntax -->
  {#if show}
    <div className="content">{content}</div>
  {/if}
  """
end

# ✅ Consistent template patterns
def clean_template(assigns) do
  ~H"""
  <%= if @show do %>
    <div class="content"><%= @content %></div>
  <% end %>
  """
end
```

## Migration Checklist

### Pre-Migration

- [ ] **Audit Current Framework Usage**
  - [ ] Identify all framework-specific patterns
  - [ ] Document custom components and their dependencies
  - [ ] List third-party framework libraries used
  - [ ] Map state management patterns

- [ ] **Prepare Migration Environment**  
  - [ ] Set up testing environment for target framework
  - [ ] Create backup of current codebase
  - [ ] Install target framework dependencies
  - [ ] Configure build tools for new framework

### During Migration

- [ ] **Component Migration**
  - [ ] Start with leaf components (no dependencies)
  - [ ] Update component declarations and imports
  - [ ] Transform template syntax
  - [ ] Adapt event handling patterns
  - [ ] Update state management

- [ ] **Testing and Validation**
  - [ ] Run automated migration tests
  - [ ] Verify visual consistency
  - [ ] Test interaction patterns
  - [ ] Performance regression testing
  - [ ] Accessibility compliance check

### Post-Migration

- [ ] **Cleanup and Optimization**
  - [ ] Remove old framework dependencies  
  - [ ] Optimize for new framework strengths
  - [ ] Update documentation and examples
  - [ ] Train team on new patterns

- [ ] **Monitoring and Maintenance**
  - [ ] Monitor performance metrics
  - [ ] Watch for framework-specific issues
  - [ ] Update migration guide with lessons learned
  - [ ] Plan future framework evaluations

## Advanced Migration Scenarios

### Gradual Component Replacement

```elixir
defmodule MyApp.HybridRenderer do
  @moduledoc """
  Support multiple frameworks during gradual migration.
  """
  
  def render_component(component_name, assigns, opts \\ []) do
    # Check if new framework version exists
    new_framework = Keyword.get(opts, :target_framework, :svelte)
    fallback_framework = Keyword.get(opts, :fallback_framework, :react)
    
    case component_exists?(component_name, new_framework) do
      true ->
        render_in_framework(component_name, assigns, new_framework)
      false ->
        # Fall back to old framework during migration
        render_in_framework(component_name, assigns, fallback_framework)
    end
  end
  
  defp component_exists?(component_name, framework) do
    module_name = build_component_module(component_name, framework)
    Code.ensure_loaded?(module_name)
  end
  
  defp render_in_framework(component_name, assigns, framework) do
    module_name = build_component_module(component_name, framework)
    apply(module_name, :render, [assigns])
  end
end
```

### A/B Testing Framework Performance

```elixir
defmodule MyApp.FrameworkABTest do
  @moduledoc """
  A/B test different frameworks for performance comparison.
  """
  
  def render_with_ab_test(component, assigns, user_id) do
    framework = select_framework_for_user(user_id)
    
    start_time = System.monotonic_time(:microsecond)
    result = render_in_framework(component, assigns, framework)
    end_time = System.monotonic_time(:microsecond)
    
    # Log performance metrics
    log_performance_metric(%{
      user_id: user_id,
      component: component,
      framework: framework,
      render_time: end_time - start_time,
      timestamp: System.system_time(:second)
    })
    
    result
  end
  
  defp select_framework_for_user(user_id) do
    # Deterministic framework selection for consistent user experience
    hash = :crypto.hash(:md5, "#{user_id}")
    case rem(:binary.decode_unsigned(hash), 2) do
      0 -> :react    # Control group
      1 -> :svelte   # Test group
    end
  end
end
```

## Further Resources

- [Raxol Framework Documentation](../frameworks/README.md)
- [Performance Comparison Benchmarks](../../bench/framework_comparison.exs)
- [Migration Testing Guide](./migration_testing.md)
- [Framework-Specific Best Practices](./framework_best_practices.md)
- [Component Compatibility Matrix](./compatibility_matrix.md)

---

*This guide is updated with each major framework migration. Contribute your migration experiences and patterns to help the community.*