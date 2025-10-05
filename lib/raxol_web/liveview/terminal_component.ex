defmodule RaxolWeb.LiveView.TerminalComponent do
  @moduledoc """
  A Phoenix LiveView component for rendering terminal buffers in web browsers.

  This component provides high-performance terminal rendering with character-perfect
  monospace grid alignment, virtual DOM diffing, and built-in theme support.

  ## Features

  - 60fps rendering capability with smart caching
  - Virtual DOM-style diffing to minimize DOM updates
  - Character-perfect 1ch monospace grid alignment
  - 7 built-in themes (synthwave84, nord, dracula, monokai, gruvbox, solarized, tokyo_night)
  - Keyboard and mouse event handling
  - Accessible (ARIA attributes, screen reader support)
  - CRT mode with scanline effects
  - High contrast mode for accessibility

  ## Basic Usage

      <.live_component
        module={RaxolWeb.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
      />

  ## Full Example

      <.live_component
        module={RaxolWeb.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={:synthwave84}
        width={80}
        height={24}
        crt_mode={false}
        high_contrast={false}
        aria_label="Interactive terminal interface"
        on_keypress="handle_key"
        on_cell_click="handle_cell_click"
      />

      # In your LiveView
      def handle_event("handle_key", %{"key" => key}, socket) do
        # Process keyboard input
        {:noreply, socket}
      end

      def handle_event("handle_cell_click", %{"row" => row, "col" => col}, socket) do
        # Process cell click
        {:noreply, socket}
      end

  ## Buffer Format

  The component expects buffers in this format:

      %{
        lines: [
          %{
            cells: [
              %{char: "H", style: %{fg_color: :green, bold: true}},
              %{char: "i", style: %{}}
            ]
          }
        ],
        width: 80,
        height: 24
      }

  ## Styles

  Each cell's style map supports:

  - `:fg_color` - Foreground color (`:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`)
  - `:bg_color` - Background color (same values as fg_color)
  - `:bold` - Bold text (boolean)
  - `:italic` - Italic text (boolean)
  - `:underline` - Underlined text (boolean)
  - `:reverse` - Reverse video (boolean)

  ## Themes

  Built-in themes:
  - `:synthwave84` - Retro synthwave colors (default)
  - `:nord` - Nordic-inspired theme
  - `:dracula` - Popular dark theme
  - `:monokai` - Classic editor theme
  - `:gruvbox` - Retro groove theme
  - `:solarized_dark` - Solarized dark variant
  - `:tokyo_night` - Modern dark theme

  You can also provide a custom theme map:

      theme: %{
        background: "#1a1a1a",
        foreground: "#ffffff",
        cursor: "#00ff00",
        selection: "#333333",
        colors: %{
          black: "#000000",
          red: "#ff0000",
          # ... etc
        }
      }
  """

  use Phoenix.LiveComponent
  alias RaxolWeb.{Renderer, Themes}

  @doc """
  Initializes the component with a new renderer instance.

  Called once when the component is first mounted to the page.
  Sets up an empty renderer and nil theme CSS which will be
  populated on first update.
  """
  @impl true
  def mount(socket) do
    renderer = Renderer.new()

    {:ok,
     socket
     |> assign(:renderer, renderer)
     |> assign(:theme_css, nil)}
  end

  @doc """
  Updates the component state with new assigns from the parent LiveView.

  ## Assigns

  Required:
  - `:id` - Unique identifier for this component instance

  Optional:
  - `:buffer` - Terminal buffer to render (creates blank if not provided)
  - `:theme` - Theme atom or custom theme map (default: `:synthwave84`)
  - `:width` - Terminal width in characters (default: 80)
  - `:height` - Terminal height in characters (default: 24)
  - `:crt_mode` - Enable CRT scanline effects (default: false)
  - `:high_contrast` - Enable high contrast mode (default: false)
  - `:aria_label` - ARIA label for accessibility (default: "Interactive terminal")
  - `:on_keypress` - Event name for keyboard events (optional)
  - `:on_cell_click` - Event name for cell click events (optional)

  ## Performance

  - Only regenerates theme CSS when theme changes
  - Uses renderer's virtual DOM diffing for efficient updates
  - Caches common character/style combinations
  """
  @impl true
  def update(assigns, socket) do
    # Extract configuration
    theme = Map.get(assigns, :theme, :synthwave84)
    width = Map.get(assigns, :width, 80)
    height = Map.get(assigns, :height, 24)
    crt_mode = Map.get(assigns, :crt_mode, false)
    high_contrast = Map.get(assigns, :high_contrast, false)
    aria_label = Map.get(assigns, :aria_label, "Interactive terminal")

    # Get or validate buffer
    buffer = Map.get(assigns, :buffer, create_blank_buffer(width, height))

    # Render buffer to HTML
    {html, new_renderer} = Renderer.render(socket.assigns.renderer, buffer)

    # Generate theme CSS if theme changed
    theme_css =
      if theme != socket.assigns[:current_theme] do
        theme_data =
          if is_atom(theme) do
            Themes.get(theme) || Themes.get(:synthwave84)
          else
            theme
          end

        Themes.to_css(theme_data, ".raxol-terminal-#{assigns.id}")
      else
        socket.assigns[:theme_css]
      end

    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:buffer, buffer)
     |> assign(:terminal_html, html)
     |> assign(:renderer, new_renderer)
     |> assign(:theme, theme)
     |> assign(:current_theme, theme)
     |> assign(:theme_css, theme_css)
     |> assign(:width, width)
     |> assign(:height, height)
     |> assign(:crt_mode, crt_mode)
     |> assign(:high_contrast, high_contrast)
     |> assign(:aria_label, aria_label)
     |> assign(:on_keypress, Map.get(assigns, :on_keypress))
     |> assign(:on_cell_click, Map.get(assigns, :on_cell_click))}
  end

  @doc """
  Renders the terminal component HTML.

  Outputs a wrapper div with:
  - Scoped theme CSS injected as <style> tag
  - Base CSS for terminal grid layout
  - CRT mode and high contrast class modifiers
  - ARIA attributes for accessibility
  - Keyboard and mouse event handlers
  - Rendered terminal HTML from buffer

  The rendered HTML uses character-perfect 1ch grid alignment
  with monospace fonts for pixel-perfect terminal display.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"raxol-wrapper-#{@id}"}
      class={[
        "raxol-terminal-wrapper",
        "raxol-terminal-#{@id}",
        @crt_mode && "raxol-crt-mode",
        @high_contrast && "raxol-high-contrast"
      ]}
      role="application"
      aria-label={@aria_label}
      tabindex="0"
      phx-window-keydown={@on_keypress}
      phx-target={@myself}
    >
      <!-- Inject theme CSS -->
      <%= if @theme_css do %>
        <style>
          <%= Phoenix.HTML.raw(@theme_css) %>
        </style>
      <% end %>

      <!-- Base CSS for terminal rendering -->
      <style>
        .raxol-terminal-<%= @id %> {
          font-family: 'Monaspace Argon', 'JetBrains Mono', 'Fira Code', 'Cascadia Code', 'Consolas', monospace;
          font-size: 14px;
          line-height: 1.4;
          padding: 1rem;
          overflow: hidden;
          width: fit-content;
        }

        .raxol-terminal-<%= @id %> .raxol-line {
          display: block;
          white-space: pre;
          height: 1.4em;
        }

        .raxol-terminal-<%= @id %> .raxol-cell {
          display: inline;
          width: 1ch;
        }

        /* CRT Mode Effects */
        .raxol-terminal-<%= @id %>.raxol-crt-mode::before {
          content: " ";
          display: block;
          position: absolute;
          top: 0;
          left: 0;
          bottom: 0;
          right: 0;
          background: linear-gradient(
            rgba(18, 16, 16, 0) 50%,
            rgba(0, 0, 0, 0.25) 50%
          );
          background-size: 100% 4px;
          z-index: 2;
          pointer-events: none;
        }

        .raxol-terminal-<%= @id %>.raxol-crt-mode {
          animation: flicker 0.15s infinite;
        }

        @keyframes flicker {
          0% { opacity: 0.97; }
          50% { opacity: 1; }
          100% { opacity: 0.97; }
        }

        /* High Contrast Mode */
        .raxol-terminal-<%= @id %>.raxol-high-contrast {
          filter: contrast(1.3) brightness(1.1);
        }

        /* Selection */
        .raxol-terminal-<%= @id %> ::selection {
          background: rgba(255, 255, 255, 0.2);
        }
      </style>

      <!-- Terminal Content -->
      <%= Phoenix.HTML.raw(@terminal_html) %>
    </div>
    """
  end

  @doc """
  Handles terminal events (keyboard and cell clicks).

  ## Events

  ### "keypress"
  When `:on_keypress` assign is set, sends a message to the parent
  LiveView in the format `{:terminal_keypress, component_id, key}`.

  ### "cell_click"
  When `:on_cell_click` assign is set, sends a message to the parent
  LiveView in the format `{:terminal_cell_click, component_id, row, col}`.

  The parent LiveView should implement handlers for these messages to
  process user interactions with the terminal.
  """
  @impl true
  def handle_event("keypress", %{"key" => key}, socket) do
    if socket.assigns.on_keypress do
      send(self(), {:terminal_keypress, socket.assigns.id, key})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cell_click", %{"row" => row, "col" => col}, socket) do
    if socket.assigns.on_cell_click do
      send(self(), {:terminal_cell_click, socket.assigns.id, row, col})
    end

    {:noreply, socket}
  end

  # Helpers

  @doc false
  @spec create_blank_buffer(integer(), integer()) :: map()
  defp create_blank_buffer(width, height) do
    lines =
      for _ <- 1..height do
        cells =
          for _ <- 1..width do
            %{
              char: " ",
              style: %{
                bold: false,
                italic: false,
                underline: false,
                reverse: false,
                fg_color: nil,
                bg_color: nil
              }
            }
          end

        %{cells: cells}
      end

    %{lines: lines, width: width, height: height}
  end
end
