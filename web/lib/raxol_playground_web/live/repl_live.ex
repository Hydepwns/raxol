defmodule RaxolPlaygroundWeb.ReplLive do
  @moduledoc """
  Landing page encouraging users to try the real terminal playground.
  """

  use RaxolPlaygroundWeb, :live_view

  import RaxolPlaygroundWeb.PlaygroundComponents

  alias RaxolPlaygroundWeb.Playground.Helpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="atmosphere" aria-hidden="true">
      <div class="pearl-bg"></div>
      <div class="dark-overlay"></div>
    </div>

    <div class="relative min-h-screen flex items-center justify-center" style="z-index: 2;">
      <main class="max-w-2xl mx-auto px-8 py-16 text-center">
        <h1 class="font-mono font-bold tracking-wide mb-4" style="font-size: clamp(1.5rem, 1.25rem + 1vw, 2.5rem); color: #ffcd9c;">
          Try the Real Terminal
        </h1>
        <p class="font-mono mb-12 body-text">
          The best way to experience Raxol is in an actual terminal.
          <%= Helpers.widget_count() %> interactive widget demos, all running natively.
        </p>

        <div class="space-y-3 mb-10 text-left">
          <.copyable_command
            id="repl-ssh"
            command={Helpers.ssh_command()}
            comment="no install needed"
            color="#ffcd9c"
          />
          <.copyable_command
            id="repl-playground"
            command="mix raxol.playground"
            comment={"all #{Helpers.widget_count()} widgets"}
            color="#58a1c6"
          />
          <.copyable_command
            id="repl-new"
            command="mix raxol.new my_app --template dashboard"
            comment="new project"
            color="#58a1c6"
          />
        </div>

        <div class="flex justify-center gap-4">
          <a href="/gallery" class="btn-primary">Browse Gallery</a>
          <a href="/playground" class="btn-secondary">Open Playground</a>
        </div>
      </main>
    </div>
    """
  end
end
