defmodule RaxolPlugin do
  @moduledoc """
  Plugin system for Raxol terminal applications.

  Build extensible terminal UIs with a simple plugin behavior. Plugins define
  lifecycle callbacks for initialization, input handling, rendering, and cleanup.

  ## Quick Start

      defmodule MyPlugin do
        use Raxol.Plugin

        @impl true
        def init(config) do
          {:ok, %{config: config, count: 0}}
        end

        @impl true
        def handle_input(key, _buffer, state) do
          case key do
            "+" -> {:ok, %{state | count: state.count + 1}}
            "-" -> {:ok, %{state | count: state.count - 1}}
            _ -> {:ok, state}
          end
        end

        @impl true
        def render(buffer, state) do
          alias Raxol.Core.{Buffer, Box}

          buffer
          |> Box.draw_box(0, 0, 40, 10, :single)
          |> Buffer.write_at(5, 5, "Count: #{state.count}")
        end

        @impl true
        def cleanup(_state) do
          :ok
        end
      end

  ## Running Plugins

      # Standalone
      Raxol.Plugin.run(MyPlugin, %{})

      # With configuration
      config = %{width: 80, height: 24}
      Raxol.Plugin.run(MyPlugin, config)

  ## Modules

  - `Raxol.Plugin` - Plugin behavior and runner

  ## Documentation

  See the [Plugin Development Guide](https://hexdocs.pm/raxol_plugin/building-plugins.html)
  for comprehensive examples and best practices.
  """

  @doc """
  Returns the version of RaxolPlugin.
  """
  def version, do: unquote(Mix.Project.config()[:version])
end
