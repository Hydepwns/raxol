defmodule RaxolPlaygroundWeb.ReplLive do
  @moduledoc """
  Landing page encouraging users to try the real terminal playground.
  Replaces the simulated REPL with links to `mix raxol.playground` and SSH.
  """

  use RaxolPlaygroundWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100 flex items-center justify-center">
      <div class="max-w-2xl mx-auto px-8 py-16 text-center">
        <h1 class="text-4xl font-bold mb-4">Try the Real Terminal</h1>
        <p class="text-xl text-gray-400 mb-12">
          The best way to experience Raxol is in an actual terminal.
          <%= RaxolPlaygroundWeb.Playground.Helpers.widget_count() %> interactive widget demos, all running natively.
        </p>

        <div class="bg-gray-800 rounded-lg p-8 font-mono text-left mb-8">
          <div class="text-gray-400 mb-4"># Local -- browse all <%= RaxolPlaygroundWeb.Playground.Helpers.widget_count() %> widgets</div>
          <div class="text-green-400 text-lg mb-6">$ mix raxol.playground</div>

          <div class="text-gray-400 mb-4"># Remote -- try it right now, no install needed</div>
          <div class="text-green-400 text-lg mb-6">$ <%= RaxolPlaygroundWeb.Playground.Helpers.ssh_command() %></div>

          <div class="text-gray-400 mb-4"># Or add Raxol to a new project</div>
          <div class="text-green-400 text-lg">$ mix raxol.new my_app --template dashboard</div>
        </div>

        <div class="flex justify-center space-x-4">
          <a href="/gallery" class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Browse Gallery
          </a>
          <a href="/playground" class="px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors">
            Open Playground
          </a>
        </div>
      </div>
    </div>
    """
  end
end
