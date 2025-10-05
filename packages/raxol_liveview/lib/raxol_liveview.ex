defmodule RaxolLiveView do
  @moduledoc """
  Phoenix LiveView integration for Raxol terminal buffers.

  RaxolLiveView enables rendering terminal UIs in web browsers with:

  - Real-time buffer updates
  - Keyboard and mouse event handling
  - 5 built-in themes (Nord, Dracula, Solarized, Monokai)
  - 60fps rendering performance
  - Responsive and accessible

  ## Quick Start

      # In your LiveView
      defmodule MyAppWeb.TerminalLive do
        use MyAppWeb, :live_view
        alias Raxol.Core.{Buffer, Box}

        def mount(_params, _session, socket) do
          buffer = Buffer.create_blank_buffer(80, 24)
          buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)

          {:ok, assign(socket, buffer: buffer)}
        end

        def render(assigns) do
          ~H\"\"\"
          <.live_component
            module={Raxol.LiveView.TerminalComponent}
            id="terminal"
            buffer={@buffer}
            theme={:nord}
          />
          \"\"\"
        end
      end

  ## Modules

  - `Raxol.LiveView.TerminalBridge` - Buffer to HTML conversion
  - `Raxol.LiveView.TerminalComponent` - Phoenix LiveComponent

  ## Themes

  Built-in themes: `:nord`, `:dracula`, `:solarized_dark`, `:solarized_light`, `:monokai`

  ## Documentation

  See the [LiveView Integration Cookbook](https://hexdocs.pm/raxol_liveview/liveview-integration.html)
  for comprehensive examples.
  """

  @doc """
  Returns the version of RaxolLiveView.
  """
  def version, do: unquote(Mix.Project.config()[:version])
end
