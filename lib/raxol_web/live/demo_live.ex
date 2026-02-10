defmodule RaxolWeb.DemoLive do
  @moduledoc """
  LiveView page for the xterm.js terminal demo.
  """

  use RaxolWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    session_id = generate_session_id()

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:page_title, "Terminal Demo")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="demo-container">
      <header class="demo-header">
        <h1>Raxol Terminal Demo</h1>
        <p class="demo-subtitle">
          Interactive terminal emulation powered by Elixir
        </p>
      </header>

      <div class="terminal-wrapper">
        <div
          id="terminal"
          phx-hook="TerminalDemo"
          data-session-id={@session_id}
          phx-update="ignore"
        >
        </div>
      </div>

      <footer class="demo-footer">
        <p>
          Type <code>help</code> for available commands |
          <a href="https://github.com/raxol/raxol" target="_blank">GitHub</a> |
          <a href="https://hexdocs.pm/raxol" target="_blank">Docs</a>
        </p>
      </footer>
    </div>

    <style>
      .demo-container {
        display: flex;
        flex-direction: column;
        min-height: 100vh;
        background: #1a1b26;
        color: #a9b1d6;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }

      .demo-header {
        text-align: center;
        padding: 2rem 1rem 1rem;
      }

      .demo-header h1 {
        margin: 0;
        font-size: 2rem;
        font-weight: 600;
        color: #7aa2f7;
      }

      .demo-subtitle {
        margin: 0.5rem 0 0;
        color: #565f89;
        font-size: 1rem;
      }

      .terminal-wrapper {
        flex: 1;
        display: flex;
        justify-content: center;
        padding: 1rem;
      }

      #terminal {
        width: 100%;
        max-width: 900px;
        height: 500px;
        background: #1a1b26;
        border: 1px solid #3b4261;
        border-radius: 8px;
        overflow: hidden;
      }

      .demo-footer {
        text-align: center;
        padding: 1rem;
        color: #565f89;
        font-size: 0.875rem;
      }

      .demo-footer code {
        background: #24283b;
        padding: 0.2rem 0.4rem;
        border-radius: 4px;
        color: #bb9af7;
      }

      .demo-footer a {
        color: #7aa2f7;
        text-decoration: none;
      }

      .demo-footer a:hover {
        text-decoration: underline;
      }

      @media (max-width: 768px) {
        .demo-header h1 {
          font-size: 1.5rem;
        }

        #terminal {
          height: 400px;
        }
      }
    </style>
    """
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
