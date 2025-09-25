defmodule Raxol.Core.Runtime.Plugins.PluginEventFilter.Behaviour do
  @moduledoc """
  Behavior for plugin event filtering.
  """

  @doc """
  Filters an event through the plugin system.
  Returns {:ok, event} for modified/passed-through events,
  :halt to stop event propagation, or {:error, reason} on error.
  """
  @callback filter_event(event :: term(), plugin_state :: term()) ::
              {:ok, term()} | :halt | {:error, term()}

  @doc """
  Initializes the event filter for a plugin.
  """
  @callback init_filter(opts :: keyword()) :: {:ok, term()} | {:error, term()}

  @doc """
  Terminates the event filter for a plugin.
  """
  @callback terminate_filter(state :: term()) :: :ok
end
