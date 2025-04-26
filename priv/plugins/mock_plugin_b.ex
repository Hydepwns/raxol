defmodule Raxol.Plugins.MockPluginB do
  @moduledoc "Simple mock plugin for testing dependencies."
  use Raxol.Core.Runtime.Plugins.Plugin

  # Define metadata for dependency check
  @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider
  def get_metadata, do: %{id: "mock_plugin_b", name: :mock_plugin_b, version: "1.0", dependencies: ["mock_plugin_a"]}

  require Logger

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(_config) do
    Logger.debug("MockPluginB initialized.")
    {:ok, %{}}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      {:mock_b, :hello, :handle_hello, 1}
    ]
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:hello, [name], state) do
    Logger.debug("MockPluginB handling hello.")
    # Example of potentially calling another plugin (though not directly tested here)
    # Manager.dispatch_command({:mock_a, :ping, nil})
    {:ok, state, "Hello from B, #{name}!"}
  end

  def handle_command(cmd, args, state) do
    Logger.warning("MockPluginB received unhandled command: #{inspect cmd} with args: #{inspect args}")
    {:error, :unhandled_command, state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def terminate(_reason, _state) do
    Logger.debug("MockPluginB terminated.")
    :ok
  end

  # Optional callbacks
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def enable(state), do: {:ok, state}
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def disable(state), do: {:ok, state}
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def filter_event(event, state), do: {:ok, event, state}

end
