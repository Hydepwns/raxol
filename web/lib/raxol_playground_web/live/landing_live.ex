defmodule RaxolPlaygroundWeb.LandingLive do
  @moduledoc """
  Landing page for raxol.io. Five-section narrative:
  hook (SSH + live demo) -> proof (code) -> features -> packages -> CTA.
  """

  use RaxolPlaygroundWeb, :live_view

  require Logger

  alias Raxol.Playground.Catalog
  alias RaxolPlaygroundWeb.Playground.{DemoLifecycle, Helpers}

  import RaxolPlaygroundWeb.PlaygroundComponents

  @demo_name "Button"

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
        terminal_html: false,
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
    {:noreply,
     socket
     |> assign(:terminal_html, true)
     |> push_event("terminal_html", %{html: html})}
  end

  def handle_info({:render_update, html, _animation_css}, socket) do
    {:noreply,
     socket
     |> assign(:terminal_html, true)
     |> push_event("terminal_html", %{html: html})}
  end

  def handle_info(:demo_timeout, socket) do
    socket = DemoLifecycle.stop_demo(socket)
    demo_component = socket.assigns.demo_component

    socket =
      socket
      |> assign(terminal_html: false, demo_error: nil)
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

  # ===========================================================================
  # Render -- 5 sections: hook, code, features, packages, CTA
  # ===========================================================================

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
        <.code_example_section counter_code={@counter_code} />
        <hr class="section-divider" aria-hidden="true" />
        <.features_section />
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
    <nav class="sticky top-0 z-50 surface-bar" aria-label="Main navigation">
      <div class="max-w-5xl mx-auto px-6 py-3 flex items-center justify-between">
        <a href="/" class="font-mono text-lg font-bold text-axol-coral" style="letter-spacing: 0.05em;">
          raxol
        </a>
        <div class="hidden md:flex items-center gap-6 text-sm font-mono" style="letter-spacing: 0.05em;">
          <a href="/playground" class="nav-link">Playground</a>
          <a href="/gallery" class="nav-link">Gallery</a>
          <a href="https://hexdocs.pm/raxol" class="nav-link">Docs</a>
          <a href="/skill.md" class="nav-link">Skill</a>
          <a href="https://github.com/DROOdotFOO/raxol" class="nav-link">GitHub</a>
        </div>
        <button phx-click="toggle_mobile_menu" class="md:hidden p-1 text-pearl-50" aria-label="Toggle menu">
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
          <a href="https://hexdocs.pm/raxol">Docs</a>
          <a href="/skill.md">Skill</a>
          <a href="https://github.com/DROOdotFOO/raxol">GitHub</a>
        </div>
      <% end %>
    </nav>
    """
  end

  # ===========================================================================
  # 1. Hook: SSH + live demo + CTAs
  # ===========================================================================

  attr(:raxol_version, :string, required: true)
  attr(:terminal_html, :boolean, required: true)

  defp hero_section(assigns) do
    ~H"""
    <section class="landing-section px-6 pt-24 pb-20 md:pt-32 md:pb-24 max-w-4xl mx-auto text-center" aria-labelledby="hero-title">
      <h1 id="hero-title" class="font-mono font-bold tracking-wide mb-6" style="font-size: clamp(3rem, 2.5rem + 3vw, 5rem); color: #ffcd9c; line-height: 1.1;">
        raxol
      </h1>

      <p class="font-mono mb-4" style="font-size: clamp(1rem, 0.9rem + 0.5vw, 1.25rem); color: rgba(232, 228, 220, 0.7); line-height: 1.5; letter-spacing: 0.01em;">
        One app. Terminal, browser, SSH, or agent.
      </p>

      <p class="body-text-dim mb-10 max-w-2xl mx-auto">
        Write a TEA module in Elixir. It renders everywhere -- crash isolation,
        hot reload, AI agents, and distributed swarm from OTP.
      </p>

      <%!-- Live terminal embed (HTML injected by RaxolTerminal hook) --%>
      <%= if @terminal_html do %>
        <div class="terminal-chrome mb-10 mx-auto text-left" style="max-width: 42rem;">
          <div class="terminal-chrome-bar">
            <div class="terminal-chrome-dot terminal-chrome-dot--red" aria-hidden="true"></div>
            <div class="terminal-chrome-dot terminal-chrome-dot--yellow" aria-hidden="true"></div>
            <div class="terminal-chrome-dot terminal-chrome-dot--green" aria-hidden="true"></div>
            <span class="terminal-chrome-title">raxol</span>
          </div>
          <div
            id="landing-terminal"
            phx-hook="RaxolTerminal"
            class="raxol-terminal p-4 overflow-hidden"
            style="background: #241b2f; min-height: 10rem; max-height: 16rem;"
            data-theme="synthwave84"
            tabindex="-1"
            role="img"
            aria-label="Raxol demo"
          ></div>
        </div>
      <% end %>

      <div class="mb-10">
        <div class="ssh-hero" id="ssh-copy" phx-hook="CopyToClipboard" data-copy={Helpers.ssh_command()}>
          <span class="prompt">$ </span><%= Helpers.ssh_command() %><span class="cursor-blink text-axol-coral">_</span>
        </div>
        <p class="label-text mt-3">Zero install. Click to copy.</p>
      </div>

      <div class="flex items-center justify-center gap-4 flex-wrap">
        <a href="/playground" class="btn-primary">Open Playground</a>
        <a href="/skill.md" class="btn-sky">Agent Skill</a>
        <a href="https://github.com/DROOdotFOO/raxol" class="btn-secondary">GitHub</a>
      </div>

      <div class="mt-10">
        <code class="font-mono detail-text text-pearl-40 bg-inset border border-subtle" style="padding: 0.5rem 1rem; border-radius: 4px;"><%= raw("{:raxol, \"~> #{@raxol_version}\"}") %></code>
      </div>
    </section>
    """
  end

  # ===========================================================================
  # 2. Proof: code example
  # ===========================================================================

  attr(:counter_code, :string, required: true)

  defp code_example_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-4xl mx-auto" aria-labelledby="code-title">
      <h2 id="code-title" class="heading-2xl mb-3">Hello World</h2>
      <p class="body-text mb-8">
        Every Raxol app follows The Elm Architecture:
        <span class="text-axol-coral">init</span>,
        <span class="text-axol-coral">update</span>,
        <span class="text-axol-coral">view</span>.
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

      <p class="body-text-dim">
        That counter works in a terminal, Phoenix LiveView, and over SSH. One codebase.
      </p>
    </section>
    """
  end

  # ===========================================================================
  # 3. Features
  # ===========================================================================

  defp features_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="features-title">
      <h2 id="features-title" class="heading-2xl mb-10">What OTP gives you</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <.feature_card title="Crash Isolation" description="Components crash and restart independently. Your UI keeps running." />
        <.feature_card title="Hot Code Reload" description="Change view/1, save. The running app updates without restart." />
        <.feature_card title="AI Agent Runtime" description="Agents are TEA apps with LLM input. Supervised, crash-isolated, streaming." />
        <.feature_card title="SSH Serving" description="Each SSH connection gets its own supervised process. One line to enable." />
        <.feature_card title="Agent Payments" description="x402 micropayments, Xochi cross-chain, stealth addresses. Autonomous commerce." />
        <.feature_card title="Distributed Swarm" description="CRDTs, elections, discovery via gossip, DNS, or Tailscale." />
        <.feature_card title="Time-Travel Debug" description="Snapshot every update/2 cycle. Step back, forward, jump, restore." />
        <.feature_card title="MCP Tools" description="Widgets auto-derive MCP tools. Agents interact with real UI programmatically." />
      </div>
    </section>
    """
  end

  attr(:title, :string, required: true)
  attr(:description, :string, required: true)

  defp feature_card(assigns) do
    ~H"""
    <div class="panel panel--glow feature-card p-6">
      <h3 class="name-coral mb-2"><%= @title %></h3>
      <p class="detail-text" style="line-height: 1.7;"><%= @description %></p>
    </div>
    """
  end

  # ===========================================================================
  # 4. Packages
  # ===========================================================================

  defp packages_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-5xl mx-auto" aria-labelledby="packages-title">
      <h2 id="packages-title" class="heading-2xl mb-3">Pick what you need</h2>
      <p class="body-text mb-10">Full framework or just the parts that matter.</p>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <.package_card name="raxol" dep={~s({:raxol, "~> 2.4"})} description="Full framework: TEA runtime, rendering, widgets, effects" accent={true} />
        <.package_card name="raxol_agent" dep={~s({:raxol_agent, "~> 2.4"})} description="AI agents, teams, strategies, LLM streaming" />
        <.package_card name="raxol_mcp" dep={~s({:raxol_mcp, "~> 2.4"})} description="MCP server, tool derivation from widgets" />
        <.package_card name="raxol_payments" dep={~s({:raxol_payments, "~> 0.1"})} description="x402, MPP, Xochi cross-chain, spending controls" />
        <.package_card name="raxol_liveview" dep={~s({:raxol_liveview, "~> 2.4"})} description="Render TEA apps in Phoenix LiveView" />
        <.package_card name="raxol_sensor" dep={~s({:raxol_sensor, "~> 2.4"})} description="Sensor fusion. Zero dependencies." />
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
      <p class="detail-text mt-2"><%= @description %></p>
    </div>
    """
  end

  # ===========================================================================
  # 5. CTA
  # ===========================================================================

  defp try_section(assigns) do
    ~H"""
    <section class="landing-section px-6 py-20 max-w-4xl mx-auto" aria-labelledby="try-title">
      <h2 id="try-title" class="heading-2xl mb-10">Try it</h2>

      <div class="space-y-3 mb-10">
        <.copyable_command id="copy-ssh" command={Helpers.ssh_command()} comment="zero install" color="#ffcd9c" />
        <.copyable_command id="copy-playground" command="mix raxol.playground" comment="interactive demos" color="#58a1c6" />
        <.copyable_command id="copy-demo" command="mix run examples/demo.exs" comment="BEAM dashboard" color="#58a1c6" />
      </div>

      <div class="flex gap-4 flex-wrap">
        <a href="/playground" class="btn-primary">Open Playground</a>
        <a href="/gallery" class="btn-secondary">Browse Gallery</a>
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

        <div class="flex items-center justify-between font-mono caption-text" style="letter-spacing: 0.05em;">
          <span>Elixir on OTP</span>
          <span>Made by <a href="https://axol.io" class="axol-link">axol.io</a></span>
        </div>
      </div>
    </footer>
    """
  end
end
