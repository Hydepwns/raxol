defmodule RaxolPlaygroundWeb.LandingLive do
  @moduledoc """
  Landing page for raxol.io. Static content -- no GenServer state.
  """

  use RaxolPlaygroundWeb, :live_view

  @package_test_counts %{
    main: 3695,
    core: 765,
    terminal: 1874,
    agent: 131,
    sensor: 55
  }
  @total_tests (
                 total = @package_test_counts |> Map.values() |> Enum.sum()

                 total
                 |> Integer.to_string()
                 |> String.replace(~r/(\d)(?=(\d{3})+$)/, "\\1,")
               )

  @raxol_version (case :application.get_key(:raxol, :vsn) do
                    {:ok, vsn} ->
                      vsn
                      |> to_string()
                      |> String.split(".")
                      |> Enum.take(2)
                      |> Enum.join(".")

                    _ ->
                      "2.3"
                  end)

  @counter_code_html String.trim_leading(~S"""
                     <span style="color:#bb9af7">defmodule</span> <span style="color:#7aa2f7">Counter</span> <span style="color:#bb9af7">do</span>
                       <span style="color:#bb9af7">use</span> <span style="color:#7aa2f7">Raxol.Core.Runtime.Application</span>

                       <span style="color:#9ece6a">@impl true</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">init</span>(<span style="color:#a9b1d6">_ctx</span>), <span style="color:#7dcfff">do:</span> <span style="color:#a9b1d6">%{</span><span style="color:#7dcfff">count:</span> <span style="color:#a9b1d6">0}</span>

                       <span style="color:#9ece6a">@impl true</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">update</span>(<span style="color:#7dcfff">:increment</span>, <span style="color:#a9b1d6">model</span>), <span style="color:#7dcfff">do:</span> <span style="color:#a9b1d6">{%{model |</span> <span style="color:#7dcfff">count:</span> <span style="color:#a9b1d6">model.count + 1}, []}</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">update</span>(<span style="color:#7dcfff">:decrement</span>, <span style="color:#a9b1d6">model</span>), <span style="color:#7dcfff">do:</span> <span style="color:#a9b1d6">{%{model |</span> <span style="color:#7dcfff">count:</span> <span style="color:#a9b1d6">model.count - 1}, []}</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">update</span>(<span style="color:#a9b1d6">_</span>, <span style="color:#a9b1d6">model</span>), <span style="color:#7dcfff">do:</span> <span style="color:#a9b1d6">{model, []}</span>

                       <span style="color:#9ece6a">@impl true</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">view</span>(<span style="color:#a9b1d6">model</span>) <span style="color:#bb9af7">do</span>
                         <span style="color:#7aa2f7">column</span> <span style="color:#7dcfff">style:</span> <span style="color:#a9b1d6">%{</span><span style="color:#7dcfff">padding:</span> <span style="color:#a9b1d6">1,</span> <span style="color:#7dcfff">gap:</span> <span style="color:#a9b1d6">1}</span> <span style="color:#bb9af7">do</span>
                           <span style="color:#a9b1d6">[</span>
                             <span style="color:#7aa2f7">text</span>(<span style="color:#9ece6a">"Count: &#35;{model.count}"</span>, <span style="color:#7dcfff">style:</span> <span style="color:#a9b1d6">[</span><span style="color:#7dcfff">:bold</span><span style="color:#a9b1d6">]</span>),
                             <span style="color:#7aa2f7">row</span> <span style="color:#7dcfff">style:</span> <span style="color:#a9b1d6">%{</span><span style="color:#7dcfff">gap:</span> <span style="color:#a9b1d6">1}</span> <span style="color:#bb9af7">do</span>
                               <span style="color:#a9b1d6">[</span><span style="color:#7aa2f7">button</span>(<span style="color:#9ece6a">"Increment"</span>, <span style="color:#7dcfff">on_click:</span> <span style="color:#7dcfff">:increment</span>), <span style="color:#7aa2f7">button</span>(<span style="color:#9ece6a">"Decrement"</span>, <span style="color:#7dcfff">on_click:</span> <span style="color:#7dcfff">:decrement</span>)<span style="color:#a9b1d6">]</span>
                             <span style="color:#bb9af7">end</span>
                           <span style="color:#a9b1d6">]</span>
                         <span style="color:#bb9af7">end</span>
                       <span style="color:#bb9af7">end</span>

                       <span style="color:#9ece6a">@impl true</span>
                       <span style="color:#bb9af7">def</span> <span style="color:#7aa2f7">subscribe</span>(<span style="color:#a9b1d6">_model</span>), <span style="color:#7dcfff">do:</span> <span style="color:#a9b1d6">[]</span>
                     <span style="color:#bb9af7">end</span>
                     """)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Raxol",
       counter_code: @counter_code_html,
       raxol_version: @raxol_version,
       total_tests: @total_tests,
       mobile_menu_open: false
     )}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply,
     assign(socket, :mobile_menu_open, !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100">
      <.nav_bar mobile_menu_open={@mobile_menu_open} />
      <.hero_section raxol_version={@raxol_version} />
      <.comparison_section />
      <.code_example_section counter_code={@counter_code} />
      <.features_section />
      <.performance_section />
      <.packages_section />
      <.playground_section />
      <.footer_section total_tests={@total_tests} />
    </div>
    """
  end

  # ===========================================================================
  # Sections
  # ===========================================================================

  attr :mobile_menu_open, :boolean, required: true

  defp nav_bar(assigns) do
    ~H"""
    <nav class="sticky top-0 z-50 bg-gray-950/80 backdrop-blur-sm border-b border-gray-800/50">
      <div class="max-w-5xl mx-auto px-6 py-3 flex items-center justify-between">
        <a href="/" class="text-lg font-bold text-blue-400">
          raxol
        </a>
        <!-- Desktop links -->
        <div class="hidden md:flex items-center gap-6 text-sm text-gray-400">
          <a href="/playground" class="hover:text-gray-200 transition-colors">Playground</a>
          <a href="/gallery" class="hover:text-gray-200 transition-colors">Gallery</a>
          <a href="/demos" class="hover:text-gray-200 transition-colors">Demos</a>
          <a href="https://hexdocs.pm/raxol" class="hover:text-gray-200 transition-colors">Docs</a>
          <a href="https://github.com/Hydepwns/raxol" class="hover:text-gray-200 transition-colors">GitHub</a>
        </div>
        <!-- Mobile hamburger -->
        <button phx-click="toggle_mobile_menu" class="md:hidden text-gray-400 hover:text-gray-200 p-1">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <%= if @mobile_menu_open do %>
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            <% else %>
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
            <% end %>
          </svg>
        </button>
      </div>
      <!-- Mobile menu -->
      <%= if @mobile_menu_open do %>
        <div class="md:hidden border-t border-gray-800/50 px-6 py-4 flex flex-col gap-4 text-sm text-gray-400">
          <a href="/playground" class="hover:text-gray-200 transition-colors">Playground</a>
          <a href="/gallery" class="hover:text-gray-200 transition-colors">Gallery</a>
          <a href="/demos" class="hover:text-gray-200 transition-colors">Demos</a>
          <a href="https://hexdocs.pm/raxol" class="hover:text-gray-200 transition-colors">Docs</a>
          <a href="https://github.com/Hydepwns/raxol" class="hover:text-gray-200 transition-colors">GitHub</a>
        </div>
      <% end %>
    </nav>
    """
  end

  attr :raxol_version, :string, required: true

  defp hero_section(assigns) do
    ~H"""
    <section class="px-6 py-24 md:py-32 max-w-4xl mx-auto text-center">
      <a
        href="https://github.com/Hydepwns/raxol"
        class="inline-block px-4 py-1.5 mb-8 text-sm font-medium text-purple-300 bg-purple-900/40 border border-purple-700/50 rounded-full hover:bg-purple-900/60 transition-colors"
      >
        Terminal built for your Gundam
      </a>

      <h1 class="text-6xl md:text-7xl font-extrabold tracking-tight mb-6 text-blue-400">
        raxol
      </h1>

      <p class="text-xl md:text-2xl text-gray-300 font-medium mb-4">
        OTP-native terminal framework for Elixir
      </p>

      <pre class="bg-gray-900 border border-gray-800 rounded-lg inline-block px-6 py-3 mb-10 font-mono text-sm text-gray-300"><code><%= raw("{:raxol, \"~> #{@raxol_version}\"}") %></code></pre>

      <div class="flex items-center justify-center gap-4">
        <a
          href="/playground"
          class="px-6 py-3 text-sm font-semibold text-white rounded-lg bg-blue-600 hover:bg-blue-500 transition-colors"
        >
          Try Playground
        </a>
        <a
          href="https://github.com/Hydepwns/raxol"
          class="px-6 py-3 text-sm font-semibold text-gray-300 rounded-lg border border-gray-700 hover:border-gray-500 hover:text-white transition-colors"
        >
          GitHub
        </a>
      </div>
    </section>
    """
  end

  defp comparison_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-5xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-4">Why OTP</h2>
      <p class="text-gray-400 mb-8 max-w-3xl">
        Every capability below comes from the BEAM VM, not a library.
      </p>

      <div class="overflow-x-auto -mx-6 px-6">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-800">
              <th class="text-left py-3 pr-4 text-gray-400 font-medium">Capability</th>
              <th class="py-3 px-3 text-gray-100 font-semibold">Raxol</th>
              <th class="py-3 px-3 text-gray-500 font-medium">Ratatui</th>
              <th class="py-3 px-3 text-gray-500 font-medium">Bubble Tea</th>
              <th class="py-3 px-3 text-gray-500 font-medium">Textual</th>
              <th class="py-3 px-3 text-gray-500 font-medium">Ink</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-800/50">
            <.comparison_row
              capability="Crash isolation per component"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="--"
              ink="--"
            />
            <.comparison_row
              capability="Hot code reload (no restart)"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="--"
              ink="--"
            />
            <.comparison_row
              capability="Same app in terminal + browser"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="partial"
              ink="--"
            />
            <.comparison_row
              capability="Built-in SSH serving"
              raxol="yes"
              ratatui="--"
              bubbletea="via lib"
              textual="--"
              ink="--"
            />
            <.comparison_row
              capability="AI agent runtime"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="--"
              ink="--"
            />
            <.comparison_row
              capability="Distributed clustering (CRDTs)"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="--"
              ink="--"
            />
            <.comparison_row
              capability="Time-travel debugging"
              raxol="yes"
              ratatui="--"
              bubbletea="--"
              textual="--"
              ink="--"
            />
          </tbody>
        </table>
      </div>

      <p class="text-gray-500 text-sm mt-8 max-w-3xl">
        Ratatui and Bubble Tea have excellent rendering and large ecosystems.
        Raxol's advantage is structural: crash isolation, hot reload, distribution,
        and SSH come from OTP, not application code.
      </p>
    </section>
    """
  end

  attr :capability, :string, required: true
  attr :raxol, :string, required: true
  attr :ratatui, :string, required: true
  attr :bubbletea, :string, required: true
  attr :textual, :string, required: true
  attr :ink, :string, required: true

  defp comparison_row(assigns) do
    ~H"""
    <tr>
      <td class="py-3 pr-4 text-gray-300"><%= @capability %></td>
      <td class="py-3 px-3 text-center text-green-400 font-medium"><%= @raxol %></td>
      <td class="py-3 px-3 text-center text-gray-600"><%= @ratatui %></td>
      <td class="py-3 px-3 text-center text-gray-600"><%= @bubbletea %></td>
      <td class="py-3 px-3 text-center text-gray-600"><%= @textual %></td>
      <td class="py-3 px-3 text-center text-gray-600"><%= @ink %></td>
    </tr>
    """
  end

  attr :counter_code, :string, required: true

  defp code_example_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-4xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-4">Hello World</h2>
      <p class="text-gray-400 mb-8 max-w-3xl">
        Every Raxol app follows The Elm Architecture:
        <code class="text-gray-300 font-mono text-sm">init</code>,
        <code class="text-gray-300 font-mono text-sm">update</code>,
        <code class="text-gray-300 font-mono text-sm">view</code>.
        Here's a counter in 20 lines.
      </p>

      <!-- Terminal window chrome -->
      <div class="rounded-lg overflow-clip border border-gray-800 mb-6">
        <div class="bg-gray-800 px-4 py-2.5 flex items-center gap-2">
          <div class="w-3 h-3 bg-red-500 rounded-full"></div>
          <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
          <div class="w-3 h-3 bg-green-500 rounded-full"></div>
          <span class="text-gray-500 text-sm ml-3">counter.exs</span>
        </div>
        <pre class="bg-gray-900 px-5 py-4 overflow-x-auto text-sm leading-relaxed font-mono"><code><%= Phoenix.HTML.raw(@counter_code) %></code></pre>
      </div>

      <p class="text-gray-400 mb-6">
        That counter works in a terminal. The same module renders in Phoenix LiveView.
        The same module serves over SSH. One codebase, three targets.
        See the full example with keyboard handling:
      </p>

      <div class="bg-gray-900 border border-gray-800 rounded-lg px-5 py-3 font-mono text-sm text-green-400">
        $ mix run examples/getting_started/counter.exs
      </div>
    </section>
    """
  end

  defp features_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-5xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-8">What's in the box</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <.feature_card
          title="Crash Isolation"
          description="Wrap any widget in process_component/2. It crashes, it restarts. Your UI keeps running."
        />
        <.feature_card
          title="Hot Code Reload"
          description="Change your view/1 function, save. The running app updates. No restart."
        />
        <.feature_card
          title="AI Agent Runtime"
          description="Agents are TEA apps where input comes from LLMs. Supervised, crash-isolated, streaming."
        />
        <.feature_card
          title="SSH Serving"
          description="Raxol.SSH.serve(MyApp, port: 2222). Each connection gets its own supervised process."
        />
        <.feature_card
          title="LiveView Bridge"
          description="Same TEA app renders to terminal and Phoenix LiveView. One codebase."
        />
        <.feature_card
          title="Distributed Swarm"
          description="CRDTs, node monitoring, elections. Discovery via gossip, DNS, or Tailscale."
        />
        <.feature_card
          title="Time-Travel Debug"
          description="Snapshot every update/2 cycle. Step back, forward, jump, restore."
        />
        <.feature_card
          title="29 Widgets"
          description="Buttons, tables, trees, charts, sparklines. Flexbox + CSS Grid layout."
        />
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true

  defp feature_card(assigns) do
    ~H"""
    <div class="bg-gray-900 border border-gray-800 rounded-lg p-6">
      <h3 class="text-lg font-semibold text-gray-100 mb-2"><%= @title %></h3>
      <p class="text-gray-400 text-sm leading-relaxed"><%= @description %></p>
    </div>
    """
  end

  defp performance_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-4xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-4">Performance</h2>
      <p class="text-gray-400 mb-8">
        On Apple M1 Pro (Elixir 1.19 / OTP 27). 13% of the 60fps budget.
      </p>

      <div class="overflow-x-auto">
        <table class="w-full max-w-lg text-sm">
          <thead>
            <tr class="border-b border-gray-800">
              <th class="text-left py-3 pr-4 text-gray-400 font-medium">What</th>
              <th class="text-right py-3 text-gray-400 font-medium">Time</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-800/50">
            <tr>
              <td class="py-3 pr-4 text-gray-300">Full frame (create + fill + diff)</td>
              <td class="py-3 text-right text-gray-100 font-mono">2.1 ms</td>
            </tr>
            <tr>
              <td class="py-3 pr-4 text-gray-300">Tree diff (100 nodes)</td>
              <td class="py-3 text-right text-gray-100 font-mono">4 \u03BCs</td>
            </tr>
            <tr>
              <td class="py-3 pr-4 text-gray-300">Cell write</td>
              <td class="py-3 text-right text-gray-100 font-mono">0.97 \u03BCs</td>
            </tr>
            <tr>
              <td class="py-3 pr-4 text-gray-300">ANSI parse</td>
              <td class="py-3 text-right text-gray-100 font-mono">38 \u03BCs</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp packages_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-5xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-4">Standalone Packages</h2>
      <p class="text-gray-400 mb-8">
        Use the full framework, or pick just the parts you need.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <.package_card
          name="raxol_core"
          description="Behaviours, events, config, accessibility, plugins."
          tests="765 tests"
        />
        <.package_card
          name="raxol_terminal"
          description="VT100/ANSI emulation, screen buffer, termbox2 NIF."
          tests="1,874 tests"
        />
        <.package_card
          name="raxol_agent"
          description="AI agent framework. Supervised agents with LLM streaming."
          tests="131 tests"
        />
        <.package_card
          name="raxol_sensor"
          description="Sensor fusion. Zero dependencies."
          tests="55 tests"
        />
      </div>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :description, :string, required: true
  attr :tests, :string, required: true

  defp package_card(assigns) do
    ~H"""
    <div class="bg-gray-900 border border-gray-800 rounded-lg p-6">
      <h3 class="text-base font-mono font-semibold text-gray-100 mb-2"><%= @name %></h3>
      <p class="text-gray-400 text-sm mb-3"><%= @description %></p>
      <span class="text-xs text-gray-500"><%= @tests %></span>
    </div>
    """
  end

  defp playground_section(assigns) do
    ~H"""
    <section class="px-6 py-20 max-w-4xl mx-auto">
      <h2 class="text-3xl font-bold text-gray-100 mb-8">Try It</h2>

      <div class="space-y-3 mb-8">
        <div class="bg-gray-900 border border-gray-800 rounded-lg px-5 py-3 font-mono text-sm">
          <span class="text-gray-500">$</span>
          <span class="text-green-400 ml-2">mix raxol.playground</span>
          <span class="text-gray-600 ml-4"># 29 demos across 8 categories</span>
        </div>
        <div class="bg-gray-900 border border-gray-800 rounded-lg px-5 py-3 font-mono text-sm">
          <span class="text-gray-500">$</span>
          <span class="text-green-400 ml-2">ssh -p 2222 playground@raxol.io</span>
          <span class="text-gray-600 ml-4"># same thing, over SSH</span>
        </div>
        <div class="bg-gray-900 border border-gray-800 rounded-lg px-5 py-3 font-mono text-sm">
          <span class="text-gray-500">$</span>
          <span class="text-green-400 ml-2">mix run examples/demo.exs</span>
          <span class="text-gray-600 ml-4"># flagship BEAM dashboard</span>
        </div>
      </div>

      <div class="flex flex-wrap gap-2 mb-10">
        <span :for={
          cat <- ~w(input display feedback navigation overlay layout visualization effects)
        } class="px-3 py-1 text-xs font-medium text-gray-400 bg-gray-900 border border-gray-800 rounded-full">
          <%= cat %>
        </span>
      </div>

      <a
        href="/playground"
        class="inline-block px-6 py-3 text-sm font-semibold text-white rounded-lg bg-blue-600 hover:bg-blue-500 transition-colors"
      >
        Open Playground
      </a>
    </section>
    """
  end

  attr :total_tests, :string, required: true

  defp footer_section(assigns) do
    ~H"""
    <footer class="px-6 py-16 border-t border-gray-800">
      <div class="max-w-4xl mx-auto">
        <div class="flex flex-wrap gap-6 text-sm text-gray-400 mb-10">
          <a href="https://github.com/Hydepwns/raxol" class="hover:text-gray-200 transition-colors">GitHub</a>
          <a href="https://hex.pm/packages/raxol" class="hover:text-gray-200 transition-colors">Hex.pm</a>
          <a href="https://hexdocs.pm/raxol" class="hover:text-gray-200 transition-colors">Docs</a>
          <a href="/playground" class="hover:text-gray-200 transition-colors">Playground</a>
        </div>

        <blockquote class="border-l-2 border-gray-700 pl-4 text-gray-500 text-sm italic mb-8 max-w-2xl">
          Raxol started as two converging ideas: a terminal for AGI, where AI agents
          interact with a real terminal emulator the same way humans do;
          and an interface for the cockpit of a Gundam Wing Suit, where fault isolation,
          real-time, responsiveness, and sensor fusion are survival-critical.
        </blockquote>

        <div class="flex items-center justify-between text-sm text-gray-600">
          <span><%= @total_tests %> tests across 5 packages</span>
          <span>Made by <a href="https://axol.io" class="text-gray-500 hover:text-gray-300 transition-colors">axol.io</a></span>
        </div>
      </div>
    </footer>
    """
  end
end
