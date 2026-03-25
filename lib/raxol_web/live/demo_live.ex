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
        <h1>raxol</h1>
        <p class="demo-subtitle">
          terminal UI framework for Elixir
        </p>
      </header>

      <div class="terminal-wrapper">
        <div class="terminal-window">
          <div class="terminal-titlebar">
            <div class="terminal-buttons">
              <span class="terminal-btn close"></span>
              <span class="terminal-btn minimize"></span>
              <span class="terminal-btn maximize"></span>
            </div>
            <span class="terminal-title">raxol@demo</span>
            <div class="terminal-spacer"></div>
          </div>
          <div
            id="terminal"
            phx-hook="TerminalDemo"
            data-session-id={@session_id}
            phx-update="ignore"
          >
          </div>
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
      * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }

      html, body {
        margin: 0;
        padding: 0;
        background: #0d0e14;
        overflow-x: hidden;
      }

      .demo-container {
        display: flex;
        flex-direction: column;
        min-height: 100vh;
        background: #0d0e14;
        color: #a9b1d6;
        font-family: 'Monaspace Argon', 'SF Mono', Monaco, monospace;
        position: relative;
        overflow: hidden;
      }

      .demo-container::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background-image:
          linear-gradient(rgba(122, 162, 247, 0.03) 1px, transparent 1px),
          linear-gradient(90deg, rgba(122, 162, 247, 0.03) 1px, transparent 1px);
        background-size: 48px 48px;
        mask-image: radial-gradient(ellipse 80% 60% at 50% 30%, black 20%, transparent 70%);
        -webkit-mask-image: radial-gradient(ellipse 80% 60% at 50% 30%, black 20%, transparent 70%);
        pointer-events: none;
      }

      .demo-container::after {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        right: -50%;
        bottom: -50%;
        background: radial-gradient(
          circle at 50% 0%,
          rgba(122, 162, 247, 0.08) 0%,
          transparent 50%
        );
        animation: pulse 8s ease-in-out infinite;
        pointer-events: none;
      }

      @keyframes pulse {
        0%, 100% {
          opacity: 0.5;
          transform: scale(1);
        }
        50% {
          opacity: 0.8;
          transform: scale(1.05);
        }
      }

      .demo-header {
        position: relative;
        z-index: 1;
        text-align: center;
        padding: 3rem 1rem 1.5rem;
      }

      .demo-header h1 {
        margin: 0;
        font-family: 'Monaspace Neon', 'SF Mono', Monaco, monospace;
        font-size: 3rem;
        font-weight: 700;
        letter-spacing: -0.02em;
        background: linear-gradient(135deg, #7aa2f7 0%, #bb9af7 50%, #7dcfff 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
      }

      .demo-subtitle {
        margin: 0.75rem 0 0;
        color: #565f89;
        font-size: 1.125rem;
        font-weight: 400;
        letter-spacing: 0.01em;
      }

      .terminal-wrapper {
        position: relative;
        z-index: 1;
        flex: 1;
        display: flex;
        justify-content: center;
        align-items: flex-start;
        padding: 1rem 1.5rem 2rem;
      }

      .terminal-window {
        position: relative;
        width: 100%;
        max-width: 960px;
        background: #1a1b26;
        border-radius: 12px;
        box-shadow:
          0 0 0 1px rgba(59, 66, 97, 0.6),
          0 4px 16px rgba(0, 0, 0, 0.3),
          0 16px 48px rgba(0, 0, 0, 0.4),
          0 0 80px rgba(122, 162, 247, 0.12),
          0 0 120px rgba(187, 154, 247, 0.06);
        overflow: hidden;
        transition: box-shadow 0.3s ease;
      }

      .terminal-window:hover {
        box-shadow:
          0 0 0 1px rgba(59, 66, 97, 0.8),
          0 4px 16px rgba(0, 0, 0, 0.3),
          0 16px 48px rgba(0, 0, 0, 0.4),
          0 0 100px rgba(122, 162, 247, 0.18),
          0 0 160px rgba(187, 154, 247, 0.08);
      }

      .terminal-titlebar {
        display: flex;
        align-items: center;
        padding: 12px 16px;
        background: #16161e;
        border-bottom: 1px solid #2a2d3d;
      }

      .terminal-buttons {
        display: flex;
        gap: 8px;
      }

      .terminal-btn {
        width: 12px;
        height: 12px;
        border-radius: 50%;
      }

      .terminal-btn.close {
        background: #f7768e;
      }

      .terminal-btn.minimize {
        background: #e0af68;
      }

      .terminal-btn.maximize {
        background: #9ece6a;
      }

      .terminal-title {
        flex: 1;
        text-align: center;
        font-family: 'Monaspace Neon', monospace;
        font-size: 0.8125rem;
        color: #565f89;
        font-weight: 500;
      }

      .terminal-spacer {
        width: 52px;
      }

      #terminal {
        height: 480px;
        padding: 0;
      }

      /* Ensure xterm fills the container */
      #terminal .xterm {
        padding: 8px;
      }

      #terminal .xterm-viewport {
        background-color: #1a1b26 !important;
      }

      .demo-footer {
        position: relative;
        z-index: 1;
        text-align: center;
        padding: 1.5rem;
        color: #565f89;
        font-size: 0.875rem;
      }

      .demo-footer code {
        font-family: 'Monaspace Neon', monospace;
        background: #1a1b26;
        padding: 0.25rem 0.5rem;
        border-radius: 6px;
        color: #bb9af7;
        border: 1px solid #2a2d3d;
      }

      .demo-footer a {
        color: #7aa2f7;
        text-decoration: none;
        transition: color 0.15s ease;
      }

      .demo-footer a:hover {
        color: #89b4fa;
      }

      @media (max-width: 768px) {
        .demo-header h1 {
          font-size: 2.25rem;
        }

        .demo-subtitle {
          font-size: 1rem;
        }

        .terminal-wrapper {
          padding: 1rem;
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
