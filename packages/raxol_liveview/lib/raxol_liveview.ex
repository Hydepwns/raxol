defmodule RaxolLiveView do
  @moduledoc """
  Phoenix LiveView integration for Raxol terminal buffers.

  Renders terminal UIs in web browsers with real-time updates,
  keyboard/mouse event translation, and themeable CSS.

  ## Modules

    * `Raxol.LiveView.TerminalBridge` -- buffer-to-HTML conversion with
      run-length encoding, diff highlighting, and inline/class style output.
    * `Raxol.LiveView.InputAdapter` -- translates browser keydown events
      into `Raxol.Core.Events.Event` structs.
    * `Raxol.LiveView.TEALive` -- a Phoenix LiveView that hosts a TEA app
      (requires `phoenix_live_view`).
    * `Raxol.LiveView.TerminalComponent` -- a Phoenix LiveComponent that
      renders a buffer with theme support (requires `phoenix_live_view`).
    * `Raxol.LiveView.Themes` -- built-in color themes and CSS custom
      property generation.

  ## Quick start

      defmodule MyAppWeb.TerminalLive do
        use MyAppWeb, :live_view
        alias Raxol.LiveView.TerminalBridge

        def mount(_params, _session, socket) do
          buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
          {:ok, assign(socket, buffer: buffer)}
        end

        def render(assigns) do
          ~H\"\"\"
          <div class="terminal-container">
            <%= raw(TerminalBridge.buffer_to_html(@buffer, theme: :synthwave84)) %>
          </div>
          \"\"\"
        end
      end

  ## CSS

  Include the bundled stylesheet for base terminal styles and named color
  classes. Call `css_path/0` to get the filesystem path.
  """

  @doc """
  Returns the version of RaxolLiveView.
  """
  @spec version() :: String.t()
  def version, do: unquote(Mix.Project.config()[:version])

  @doc """
  Returns the absolute filesystem path to the bundled CSS stylesheet.

  Copy or symlink this file into your Phoenix static assets to use
  the pre-built terminal styles.

  ## Example

      # In a Mix task or setup script
      File.cp!(RaxolLiveView.css_path(), "priv/static/css/raxol_terminal.css")
  """
  @spec css_path() :: String.t()
  def css_path do
    Path.join(:code.priv_dir(:raxol_liveview), "static/raxol_terminal.css")
  end
end
