defmodule Raxol.Plugins.MockPluginA do
  @moduledoc "Simple mock plugin for testing."
  use Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(_config) do
    Logger.debug("MockPluginA initialized.")
    {:ok, %{version: "1.0"}}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      # {namespace, name, function, arity}
      {:mock_a, :ping, :handle_ping, 1},
      {:mock_a, :get_version, :handle_get_version, 1}
    ]
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:ping, [_arg], state) do
    Logger.debug("MockPluginA handling ping.")
    {:ok, state, :pong_a}
  end

  def handle_command(:get_version, [_arg], state) do
     Logger.debug("MockPluginA handling get_version.")
    {:ok, state, state.version}
  end

  def handle_command(cmd, args, state) do
    Logger.warning("MockPluginA received unhandled command: #{inspect cmd} with args: #{inspect args}")
    {:error, :unhandled_command, state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def terminate(_reason, _state) do
    Logger.debug("MockPluginA terminated.")
    :ok
  end

  # Optional callbacks with default implementations
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def enable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def disable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def filter_event(event, state), do: {:ok, event, state}

  # Helper for reload testing
  def version, do: "1.0"

end
