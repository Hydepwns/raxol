defmodule RaxolPlaygroundWeb.LandingLive do
  @moduledoc """
  Landing page for raxol.io. Dark-native, monospace-first, Xochi-sibling aesthetic.
  """

  use RaxolPlaygroundWeb, :live_view

  require Logger

  alias Raxol.Playground.Catalog
  alias RaxolPlaygroundWeb.Playground.{DemoLifecycle, Helpers}

  import RaxolPlaygroundWeb.PlaygroundComponents

  # Disabled: demo embed crashes LiveView in dev. Investigate rendering pipeline.
  @demo_name nil

  @raxol_version (case :application.get_key(:raxol, :vsn) do
                    {:ok, vsn} ->
                      vsn |> to_string() |> String.split(".") |> Enum.take(2) |> Enum.join(".")

                    _ ->
                      "2.4"
                  end)

  @counter_code_html String.trim_leading(~S"""
                     <span style="color:#ffcd9c">defmodule</span> <span style="color:#58a1c6">Counter</span> <span style="color:#ffcd9c">do</span>
                       <span style="color:#ffcd9c">use</span> <span style="color:#58a1c6">Raxol.Core.Runtime.Application</span>

                       <span style="color:#a89a80">@impl true</span>
                       <span style="color:#ffcd9c">def</span> <span style="color:#58a1c6">init</span>(<span style="color:#e8e4dc">_ctx</span>), <span style="color:#e58476">do:</span> <span style="color:#e8e4dc">%{</span><span style="color:#e58476">count:</span> <span style="color:#e8e4dc">0}</span>

                       <span style="color:#a89a80">@impl true</span>
                       <span style="color:#ffcd9c">def</span> <span style="color:#58a1c6">update</span>(<span style="color:#e58476">:increment</span>, <span style="color:#e8e4dc">model</span>), <span style="color:#e58476">do:</span> <span style="color:#e8e4dc">{%{model |</span> <span style="color:#e58476">count:</span> <span style="color:#e8e4dc">model.count + 1}, []}</span>
                       <span style="color:#ffcd9c">def</span> <span style="color:#58a1c6">update</span>(<span style="color:#e58476">:decrement</span>, <span style="color:#e8e4dc">model</span>), <span style="color:#e58476">do:</span> <span style="color:#e8e4dc">{%{model |</span> <span style="color:#e58476">count:</span> <span style="color:#e8e4dc">model.count - 1}, []}</span>
                       <span style="color:#ffcd9c">def</span> <span style="color:#58a1c6">update</span>(<span style="color:#e8e4dc">_</span>, <span style="color:#e8e4dc">model</span>), <span style="color:#e58476">do:</span> <span style="color:#e8e4dc">{model, []}</span>

                       <span style="color:#a89a80">@impl true</span>
                       <span style="color:#ffcd9c">def</span> <span style="color:#58a1c6">view</span>(<span style="color:#e8e4dc">model</span>) <span style="color:#ffcd9c">do</span>
                         <span style="color:#58a1c6">column</span> <span style="color:#e58476">style:</span> <span style="color:#e8e4dc">%{</span><span style="color:#e58476">padding:</span> <span style="color:#e8e4dc">1,</span> <span style="color:#e58476">gap:</span> <span style="color:#e8e4dc">1}</span> <span style="color:#ffcd9c">do</span>
                           <span style="color:#e8e4dc">[</span>
                             <span style="color:#58a1c6">text</span>(<span style="color:#a89a80">"Count: &#35;{model.count}"</span>, <span style="color:#e58476">style:</span> <span style="color:#e8e4dc">[</span><span style="color:#e58476">:bold</span><span style="color:#e8e4dc">]</span>),
                             <span style="color:#58a1c6">row</span> <span style="color:#e58476">style:</span> <span style="color:#e8e4dc">%{</span><span style="color:#e58476">gap:</span> <span style="color:#e8e4dc">1}</span> <span style="color:#ffcd9c">do</span>
                               <span style="color:#e8e4dc">[</span><span style="color:#58a1c6">button</span>(<span style="color:#a89a80">"+"</span>, <span style="color:#e58476">on_click:</span> <span style="color:#e58476">:increment</span>), <span style="color:#58a1c6">button</span>(<span style="color:#a89a80">"-"</span>, <span style="color:#e58476">on_click:</span> <span style="color:#e58476">:decrement</span>)<span style="color:#e8e4dc">]</span>
                             <span style="color:#ffcd9c">end</span>
                           <span style="color:#e8e4dc">]</span>
                         <span style="color:#ffcd9c">end</span>
                       <span style="color:#ffcd9c">end</span>
                     <span style="color:#ffcd9c">end</span>
                     """)

  @impl true
  def mount(_params, _session, socket) do
    demo_component = Catalog.get_component(@demo_name)

    socket =
      socket
      |> assign(
        page_title: "Raxol",
        counter_code: @counter_code_html,
        raxol_version: @raxol_version,
        mobile_menu_open: false,
        terminal_html: "",
        lifecycle_pid: nil,
        topic: nil,
        demo_error: nil,
        demo_timer: nil,
        demo_component: demo_component
      )
      |> then(fn s ->
        if demo_component do
          DemoLifecycle.start_demo(s, demo_component,
            timeout_ms: :timer.minutes(5),
            topic_prefix: "landing"
          )
        else
          s
        end
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_info({:render_update, html}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  def handle_info({:render_update, html, _animation_css}, socket) do
    {:noreply, assign(socket, :terminal_html, html)}
  end

  def handle_info(:demo_timeout, socket) do
    # Silently restart the demo for landing page (loops forever)
    socket = DemoLifecycle.stop_demo(socket)
    demo_component = socket.assigns.demo_component

    socket =
      socket
      |> assign(terminal_html: "", demo_error: nil)
      |> then(fn s ->
        if demo_component do
          DemoLifecycle.start_demo(s, demo_component,
            timeout_ms: :timer.minutes(5),
            topic_prefix: "landing"
          )
        else
          s
        end
      end)

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, socket) do
    if pid == socket.assigns[:lifecycle_pid] do
      {:noreply, assign(socket, lifecycle_pid: nil, demo_error: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    _ = DemoLifecycle.stop_demo(socket)
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="atmosphere" aria-hidden="true">
      <div class="pearl-bg"></div>
      <div class="dark-overlay"></div>
      <div class="orb orb-1"></div>
      <div class="orb orb-2"></div>
      <div class="orb orb-3"></div>
    </div>

    <div class="relative min-h-screen" style="z-index: 2;">
      <.nav_bar mobile_menu_open={@mobile_menu_open} />
      <main>
        <.hero_section raxol_version={@raxol_version} terminal_html={@terminal_html} />
        <hr class="section-divider" aria-hidden="true" />
        <.surfaces_section />
        <hr class="section-divider" aria-hidden="true" />
        <.code_example_section counter_code={@counter_code} />
        <hr class="section-divider" aria-hidden="true" />
        <.features_section />
        <hr class="section-divider" aria-hidden="true" />
        <.comparison_section />
        <hr class="section-divider" aria-hidden="true" />
        <.packages_section />
        <hr class="section-divider" aria-hidden="true" />
        <.try_section />
      </main>
      <.footer_section />
    </div>
    """
  end

  # ===========================================================================
  # Navigation
  # ===========================================================================

  attr(:mobile_menu_open, :boolean, required: true)

  defp nav_bar(assigns) do
    ~H"""
    <nav class="sticky top-0 z-50 surface-bar">
      <div class="max-w-5xl mx-auto px-6 py-3 flex items-center justify-between">
        <a href="/" class="font-mono text-lg font-bold text-axol-coral" style="letter-spacing: 0.05em;">
          raxol
        </a>
        <div class="hidden md:flex items-center gap-6 text-sm font-mono" style="letter-spacing: 0.05em;">
          <a href="/playground" class="nav-link">Playground</a>
          <a href="/gallery" class="nav-link">Gallery</a>
          <a href="/demos" class="nav-link">Demos</a>
          <a href="https://hexdocs.pm/raxol" class="nav-link">Docs</a>
          <a href="/skill.md" class="nav-link">Skill</a>
          <a href="https://github.com/DROOdotFOO/raxol" class="nav-link">GitHub</a>
        </div>
        <button phx-click="toggle_mobile_menu" class="md:hidden p-1 text-pearl-50">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <%= if @mobile_menu_open do %>
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            <% else %>
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
            <% end %>
          </svg>
        </button>
      </div>
      <%= if @mobile_menu_open do %>
        <div class="md:hidden px-6 py-4 flex flex-col gap-4 text-sm font-mono border-t border-subtle text-pearl-50">
          <a href="/playground">Playground</a>
          <a href="/gallery">Gallery</a>
          <a href="/demos">Demos</a>
          <a href="https://hexdocs.pm/raxol">Docs</a>
          <a href="/skill.md">Skill</a>
          <a href="https://github.com/DROOdotFOO/raxol">GitHub</a>
        </div>
      <% end %>
    </nav>
    """
  end

  # ===========================================================================
  # Hero
  # ===========================================================================

  attr(:raxol_version, :string, required: true)
  attr(:terminal_html, :string, required: true)

  defp hero_section(assigns) do
    ~H"""
    <section class="landing-section px-6 pt-24 pb-20 md:pt-32 md:pb-28 max-w-4xl mx-auto text-center" aria-labelledby="hero-title">
      <div class="mb-10">
        <span class="badge">Multi-surface runtime</span>
      </div>

      <h1 id="hero-title" class="font-mono font-bold tracking-wide mb-6" style="font-size: clamp(3rem, 2.5rem + 3vw, 5rem); color: #ffcd9c; line-height: 1.1;">
        raxol
      </h1>

      <p class="font-mono mb-4" style="font-size: clamp(1rem, 0.9rem + 0.5vw, 1.25rem); color: rgba(232, 228, 220, 0.7); line-height: 1.5; letter-spacing: 0.01em;">
        One app. Terminal, browser, SSH, or agent.
      </p>

      <p class="body-text-dim mb-10 max-w-2xl mx-auto">
        Write a TEA module. It renders everywhere. Crash isolation, hot reload,
        AI agents, and distributed swarm -- all from OTP.
      </p>

      <%!-- Live terminal embed --%>
      <%= if @terminal_html != "" do %>
        <div class="terminal-chrome mb-10 mx-auto text-left" style="max-width: 42rem;">
          <div class="terminal-chrome-bar">
            <div class="terminal-chrome-dot terminal-chrome-dot--red" aria-hidden="true"></div>
            <div class="terminal-chrome-dot terminal-chrome-dot--yellow" aria-hidden="true"></div>
            <div class="terminal-chrome-dot terminal-chrome-dot--green" aria-hidden="true"></div>
            <span class="terminal-chrome-title">raxol -- sparkline demo (live)</span>
            <span class="ml-auto font-mono" style="font-size: 0.6rem; color: rgba(88, 161, 198, 0.5); letter-spacing: 0.1em; text-transform: uppercase;">live</span>
          </div>
          <div
            id="landing-terminal"
            phx-hook="RaxolTerminal"
            class="raxol-terminal p-4 overflow-hidden"
            style="background: #241b2f; min-height: 10rem; max-height: 16rem;"
            data-theme="synthwave84"
            tabindex="-1"
            role="img"
            aria-label="Live Raxol sparkline demo rendering in real-time"
          ><%= Phoenix.HTML.raw(@terminal_html) %></div>
        </div>
      <% end %>

      <%!-- SSH command hero --%>
      <div class="mb-10">
        <div class="ssh-hero" id="ssh-copy" phx-hook="CopyToClipboard" data-copy={Helpers.ssh_command()}>
          <span class="prompt">$ </span><%= Helpers.ssh_command() %><span class="cursor-blink" style="color: #ffcd9c;">_</span>
        </div>
        <p class="label-text mt-3">
          Zero install. Click to copy.
        </p>
      </div>

      <div class="flex items-center justify-center gap-4 flex-wrap">
        <a href="/playground" class="btn-primary">
          Open Playground
        </a>
        <a href="/skill.md" class="btn-sky">
          Agent Skill
        </a>
        <a href="https://github.com/DROOdotFOO/raxol" class="btn-secondary">
          GitHub
        </a>
      </div>

      <div class="mt-10">
        <code class="font-mono detail-text text-pearl-40 bg-inset border border-subtle" style="padding: 0.5rem 1rem; border-radius: 4px;"><%= raw("{:raxol, \"~> #{@raxol_version}\"}") %></code>
      </div>
    </section>
    """
  end

  # ===========================================================================
  # Surfaces
  # ===========================================================================

  defp surfaces_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="surfaces-title">
      <h2 id="surfaces-title" class="heading-2xl mb-3">
        One codebase, six surfaces
      </h2>
      <p class="body-text mb-10">
        Write your app once. Raxol projects it to every target.
      </p>

      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <.surface_card icon=">" name="Terminal" detail="Native termbox2 NIF" />
        <.surface_card icon="~" name="Browser" detail="Phoenix LiveView bridge" />
        <.surface_card icon="$" name="SSH" detail="Each connection supervised" />
        <.surface_card icon="@" name="MCP" detail="Agent tool derivation" />
        <.surface_card icon="#" name="Telegram" detail="Per-chat sessions" />
        <.surface_card icon="!" name="Watch" detail="APNS/FCM push" />
      </div>
    </section>
    """
  end

  attr(:icon, :string, required: true)
  attr(:name, :string, required: true)
  attr(:detail, :string, required: true)

  defp surface_card(assigns) do
    ~H"""
    <div class="panel panel--glow p-5 transition-all duration-200">
      <div class="font-mono font-bold mb-2 text-sky" style="font-size: clamp(1rem, 0.9rem + 0.5vw, 1.15rem);">
        <span class="text-pearl-30"><%= @icon %></span> <%= @name %>
      </div>
      <p class="detail-text">
        <%= @detail %>
      </p>
    </div>
    """
  end

  # ===========================================================================
  # Code Example
  # ===========================================================================

  attr(:counter_code, :string, required: true)

  defp code_example_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-4xl mx-auto" aria-labelledby="code-title">
      <h2 id="code-title" class="heading-2xl mb-3">
        Hello World
      </h2>
      <p class="body-text mb-8">
        Every Raxol app follows The Elm Architecture:
        <span class="text-axol-coral">init</span>,
        <span class="text-axol-coral">update</span>,
        <span class="text-axol-coral">view</span>.
        Here's a counter in 20 lines.
      </p>

      <div class="terminal-chrome mb-8">
        <div class="terminal-chrome-bar">
          <div class="terminal-chrome-dot terminal-chrome-dot--red"></div>
          <div class="terminal-chrome-dot terminal-chrome-dot--yellow"></div>
          <div class="terminal-chrome-dot terminal-chrome-dot--green"></div>
          <span class="terminal-chrome-title">counter.exs</span>
        </div>
        <div class="terminal-chrome-body">
          <pre style="overflow-x: auto; font-size: 0.85rem; line-height: 1.7;"><code><%= Phoenix.HTML.raw(@counter_code) %></code></pre>
        </div>
      </div>

      <p class="body-text-dim mb-6">
        That counter works in a terminal. The same module renders in Phoenix LiveView.
        The same module serves over SSH. One codebase, three targets.
      </p>

      <div class="terminal-chrome" style="padding: 0;">
        <div class="terminal-chrome-body" style="padding: 0.75rem 1.25rem;">
          <span class="text-pearl-40">$</span>
          <span class="text-sky" style="margin-left: 0.5rem;">mix run examples/getting_started/counter.exs</span>
        </div>
      </div>
    </section>
    """
  end

  # ===========================================================================
  # Features
  # ===========================================================================

  defp features_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="features-title">
      <h2 id="features-title" class="heading-2xl mb-3">
        What's in the box
      </h2>
      <p class="body-text mb-10">
        Every capability comes from OTP, not a library.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
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
          title="Agent Payments"
          description="x402 micropayments, Xochi cross-chain settlement, stealth addresses. Agents that can pay."
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
          title={"#{RaxolPlaygroundWeb.Playground.Helpers.widget_count()} Widgets"}
          description="Buttons, tables, trees, charts, sparklines. Flexbox + CSS Grid layout."
        />
      </div>
    </section>
    """
  end

  attr(:title, :string, required: true)
  attr(:description, :string, required: true)

  defp feature_card(assigns) do
    ~H"""
    <div class="panel panel--glow feature-card p-6">
      <h3 class="name-coral mb-2">
        <%= @title %>
      </h3>
      <p class="detail-text" style="line-height: 1.7;">
        <%= @description %>
      </p>
    </div>
    """
  end

  # ===========================================================================
  # Comparison
  # ===========================================================================

  defp comparison_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="comparison-title">
      <h2 id="comparison-title" class="heading-2xl mb-3">
        Why OTP
      </h2>
      <p class="body-text mb-8">
        These capabilities come from the BEAM VM, not application code.
      </p>

      <div class="overflow-x-auto -mx-6 px-6">
        <table class="w-full font-mono" style="font-size: clamp(0.7rem, 0.65rem + 0.25vw, 0.75rem);">
          <thead>
            <tr class="border-b border-subtle">
              <th class="text-left py-3 pr-4 label-text-dim" style="font-weight: 500;">Capability</th>
              <th class="py-3 px-3 text-axol-coral" style="font-weight: 600;">Raxol</th>
              <th class="py-3 px-3" style="color: rgba(232, 228, 220, 0.3); font-weight: 500;">Ratatui</th>
              <th class="py-3 px-3" style="color: rgba(232, 228, 220, 0.3); font-weight: 500;">Bubble Tea</th>
              <th class="py-3 px-3" style="color: rgba(232, 228, 220, 0.3); font-weight: 500;">Textual</th>
              <th class="py-3 px-3" style="color: rgba(232, 228, 220, 0.3); font-weight: 500;">Ink</th>
            </tr>
          </thead>
          <tbody>
            <.comparison_row capability="Crash isolation per component" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
            <.comparison_row capability="Hot code reload (no restart)" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
            <.comparison_row capability="Same app in terminal + browser" raxol="yes" ratatui="--" bubbletea="--" textual="partial" ink="--" />
            <.comparison_row capability="Built-in SSH serving" raxol="yes" ratatui="--" bubbletea="via lib" textual="--" ink="--" />
            <.comparison_row capability="AI agent runtime" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
            <.comparison_row capability="Distributed clustering (CRDTs)" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
            <.comparison_row capability="Time-travel debugging" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
            <.comparison_row capability="Agent payments" raxol="yes" ratatui="--" bubbletea="--" textual="--" ink="--" />
          </tbody>
        </table>
      </div>

      <p class="detail-text text-pearl-35 mt-8" style="line-height: 1.7; max-width: 50ch;">
        Ratatui and Bubble Tea have excellent rendering and large ecosystems.
        Raxol's advantage is structural: crash isolation, hot reload, distribution,
        and SSH come from OTP, not application code.
      </p>
    </section>
    """
  end

  attr(:capability, :string, required: true)
  attr(:raxol, :string, required: true)
  attr(:ratatui, :string, required: true)
  attr(:bubbletea, :string, required: true)
  attr(:textual, :string, required: true)
  attr(:ink, :string, required: true)

  defp comparison_row(assigns) do
    ~H"""
    <tr class="border-b border-subtle-faint">
      <td class="py-3 pr-4 text-pearl-60"><%= @capability %></td>
      <td class={"py-3 px-3 text-center #{comparison_class(@raxol)}"}><%= @raxol %></td>
      <td class={"py-3 px-3 text-center #{comparison_class(@ratatui)}"}><%= @ratatui %></td>
      <td class={"py-3 px-3 text-center #{comparison_class(@bubbletea)}"}><%= @bubbletea %></td>
      <td class={"py-3 px-3 text-center #{comparison_class(@textual)}"}><%= @textual %></td>
      <td class={"py-3 px-3 text-center #{comparison_class(@ink)}"}><%= @ink %></td>
    </tr>
    """
  end

  defp comparison_class("yes"), do: "comparison-cell--yes"
  defp comparison_class("partial"), do: "comparison-cell--partial"
  defp comparison_class(_), do: "comparison-cell--no"

  # ===========================================================================
  # Packages
  # ===========================================================================

  defp packages_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="packages-title">
      <h2 id="packages-title" class="heading-2xl mb-3">
        Pick what you need
      </h2>
      <p class="body-text mb-10">
        Use the full framework, or just the parts that matter for your use case.
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <.package_card
          name="raxol"
          dep={~s({:raxol, "~> 2.4"})}
          description="Full framework: TEA runtime, rendering, widgets, layout, effects"
          accent={true}
        />
        <.package_card
          name="raxol_agent"
          dep={~s({:raxol_agent, "~> 2.4"})}
          description="AI agents with teams, strategies, LLM streaming, shell commands"
        />
        <.package_card
          name="raxol_mcp"
          dep={~s({:raxol_mcp, "~> 2.4"})}
          description="MCP server, tool auto-derivation from widgets, test harness"
        />
        <.package_card
          name="raxol_payments"
          dep={~s({:raxol_payments, "~> 0.1"})}
          description="Agent commerce: x402, MPP, Xochi cross-chain, spending controls"
        />
        <.package_card
          name="raxol_liveview"
          dep={~s({:raxol_liveview, "~> 2.4"})}
          description="Render TEA apps in Phoenix LiveView via TerminalBridge"
        />
        <.package_card
          name="raxol_sensor"
          dep={~s({:raxol_sensor, "~> 2.4"})}
          description="Sensor fusion engine. Zero dependencies."
        />
        <.package_card
          name="raxol_terminal"
          dep={~s({:raxol_terminal, "~> 2.4"})}
          description="VT100/ANSI emulation, screen buffer, termbox2 NIF"
        />
        <.package_card
          name="raxol_core"
          dep={~s({:raxol_core, "~> 2.4"})}
          description="Behaviours, events, config, accessibility, plugin infra"
        />
        <.package_card
          name="raxol_plugin"
          dep={~s({:raxol_plugin, "~> 2.4"})}
          description="Plugin SDK: use macro, API facade, generator, testing utils"
        />
      </div>
    </section>
    """
  end

  attr(:name, :string, required: true)
  attr(:dep, :string, required: true)
  attr(:description, :string, required: true)
  attr(:accent, :boolean, default: false)

  defp package_card(assigns) do
    ~H"""
    <div class="panel panel--glow p-5">
      <h3 class="name-sky-sm mb-1" style={"color: #{if @accent, do: "#ffcd9c", else: "#58a1c6"};"}>
        <%= @name %>
      </h3>
      <code class="caption-text"><%= @dep %></code>
      <p class="detail-text mt-2">
        <%= @description %>
      </p>
    </div>
    """
  end

  # ===========================================================================
  # Try It
  # ===========================================================================

  defp try_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-4xl mx-auto" aria-labelledby="try-title">
      <h2 id="try-title" class="heading-2xl mb-10">
        Try it
      </h2>

      <div class="space-y-3 mb-10">
        <.copyable_command
          id="copy-ssh"
          command={Helpers.ssh_command()}
          comment="zero install"
          color="#ffcd9c"
        />
        <.copyable_command
          id="copy-playground"
          command="mix raxol.playground"
          comment={"#{Helpers.widget_count()} demos, #{Helpers.category_count()} categories"}
          color="#58a1c6"
        />
        <.copyable_command
          id="copy-demo"
          command="mix run examples/demo.exs"
          comment="BEAM dashboard"
          color="#58a1c6"
        />
      </div>

      <div class="flex flex-wrap gap-2 mb-10" role="list" aria-label="Widget categories">
        <span :for={cat <- ~w(input display feedback navigation overlay layout visualization effects)} class="category-tag" role="listitem">
          <%= cat %>
        </span>
      </div>

      <div class="flex gap-4 flex-wrap">
        <a href="/playground" class="btn-primary">
          Open Playground
        </a>
        <a href="/gallery" class="btn-secondary">
          Browse Gallery
        </a>
      </div>
    </section>
    """
  end

  # ===========================================================================
  # Footer
  # ===========================================================================

  defp footer_section(assigns) do
    ~H"""
    <footer class="landing-section px-6 py-16 border-t border-subtle">
      <div class="max-w-4xl mx-auto">
        <div class="flex flex-wrap gap-6 font-mono mb-10" style="font-size: clamp(0.7rem, 0.65rem + 0.25vw, 0.75rem); letter-spacing: 0.05em;">
          <a href="https://github.com/DROOdotFOO/raxol" class="footer-link">GitHub</a>
          <a href="https://hex.pm/packages/raxol" class="footer-link">Hex.pm</a>
          <a href="https://hexdocs.pm/raxol" class="footer-link">Docs</a>
          <a href="/playground" class="footer-link">Playground</a>
          <a href="/skill.md" class="footer-link">Skill</a>
        </div>

        <blockquote class="mb-10 pl-4 font-mono detail-text text-pearl-35" style="border-left: 2px solid rgba(168, 154, 128, 0.2); line-height: 1.7; max-width: 55ch; font-style: italic;">
          Raxol started as two converging ideas: a terminal for AGI, where AI agents
          interact with a real terminal emulator the same way humans do;
          and an interface for the cockpit of a Gundam Wing Suit, where fault isolation,
          real-time responsiveness, and sensor fusion are survival-critical.
        </blockquote>

        <div class="flex items-center justify-between font-mono caption-text" style="letter-spacing: 0.05em;">
          <span>Elixir on OTP</span>
          <span>Made by <a href="https://axol.io" class="axol-link">axol.io</a></span>
        </div>
      </div>
    </footer>
    """
  end
end
