defmodule Raxol.Core.Runtime.Plugins.Registry do
  @moduledoc """
  Placeholder for the plugin registry.
  Manages information about loaded plugins.
  """

  require Logger

  # TODO: Implement state management (e.g., using GenServer or ETS)

  @doc "Creates a new, empty registry state."
  def new() do
    Logger.debug("[#{__MODULE__}] new registry created.")
    %{}
  end

  @doc "Placeholder for listing plugins."
  @spec list_plugins(map()) :: list({atom(), map()})
  def list_plugins(_registry_state) do
    Logger.debug("[#{__MODULE__}] list_plugins called.")
    # TODO: Return actual list of {plugin_id, metadata}
    []
  end
end
