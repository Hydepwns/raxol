# `Raxol.Core.Runtime.Plugins.PluginEventProcessor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_event_processor.ex#L1)

Handles event processing and filtering through plugins.

This module provides a pipeline for processing events through all enabled plugins.
Events flow through plugins in load order, and any plugin can:

- Modify the event (return `{:ok, modified_event}`)
- Pass it through unchanged (return `{:ok, event}`)
- Stop propagation (return `:halt`)
- Handle errors gracefully

## Plugin Ordering

Plugins are processed in the following order:

1. By explicit priority (if defined in plugin metadata)
2. By load order (plugins loaded first process events first)
3. By dependency order (dependent plugins process after their dependencies)

## Event Filtering

Plugins implementing the `filter_event/2` callback can modify or stop events:

    def filter_event(event, state) do
      case event do
        %{type: :sensitive} -> :halt  # Stop propagation
        %{type: :modifiable} -> {:ok, Map.put(event, :processed, true)}
        _ -> {:ok, event}  # Pass through unchanged
      end
    end

## Error Handling

Plugin errors are logged but don't stop event propagation to other plugins.
A crashed plugin is skipped, and the event continues to the next plugin.

# `filter_event`

```elixir
@spec filter_event(term(), map(), map(), map(), [atom()]) ::
  {:ok, term()} | :halt | {:error, term()}
```

Filters an event through all enabled plugins.

Unlike `process_event_through_plugins/7`, this function focuses on event
modification and can halt propagation. Plugins should implement `filter_event/2`.

## Parameters

  * `event` - The event to filter
  * `plugins` - Map of plugin_id => module
  * `metadata` - Plugin metadata (must include `:enabled` status)
  * `plugin_states` - Map of plugin_id => state
  * `load_order` - List of plugin IDs in processing order

## Returns

  * `{:ok, filtered_event}` - Event after all filters applied
  * `:halt` - Event propagation was stopped by a plugin
  * `{:error, reason}` - An error occurred

## Example

    case filter_event(event, plugins, metadata, states, load_order) do
      {:ok, event} -> dispatch_event(event)
      :halt -> :ok  # Event was consumed
      {:error, reason} -> log_error(reason)
    end

# `filter_through_plugin`

```elixir
@spec filter_through_plugin(atom(), term(), map(), map(), map()) ::
  {:ok, term()} | :halt | {:error, term()}
```

Filters an event through a single plugin with isolation.

Uses PluginSupervisor for crash isolation.

# `get_dependency_ordered_plugins`

```elixir
@spec get_dependency_ordered_plugins([atom()], map()) :: [atom()]
```

Gets the effective load order considering dependencies.

Ensures that plugins are processed after their dependencies.

# `process_event_through_plugins`

Processes an event through all enabled plugins in load order.

# `process_plugin_event`

Processes an event for a specific plugin.

# `sort_plugins_by_priority`

```elixir
@spec sort_plugins_by_priority([atom()], map()) :: [atom()]
```

Sorts plugins by priority for event processing.

Plugins with explicit priority in metadata are sorted first (lower = higher priority).
Plugins without priority retain their load order.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
