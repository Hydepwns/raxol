defmodule Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour do
  @moduledoc """
  Defines the behaviour for plugin event filtering.

  This behaviour is responsible for:
  - Filtering events through registered plugin filters
  - Managing event modifications
  - Handling event halting
  - Coordinating event propagation
  """

  @doc """
  Filters an event through registered plugin filters.
  Returns the filtered event or :halt if the event should be stopped.
  """
  @callback filter_event(
              plugin_manager_state :: map(),
              event :: term()
            ) :: {:ok, term()} | :halt | {:error, any()}

  @doc """
  Gets a list of enabled plugins in load order.
  """
  @callback get_enabled_plugins(state :: map()) :: list(String.t())

  @doc """
  Applies a single plugin's filter to the event.
  """
  @callback apply_plugin_filter(
              plugin_id :: String.t(),
              event :: term(),
              state :: map()
            ) :: {:ok, term()} | :halt | {:error, any()}

  @doc """
  Handles event filtering errors.
  """
  @callback handle_filter_error(
              plugin_id :: String.t(),
              error :: any(),
              event :: term()
            ) :: {:ok, term()} | :halt | {:error, any()}

  @doc """
  Updates the event filter state.
  """
  @callback update_filter_state(
              state :: map(),
              new_state :: map()
            ) :: map()
end
