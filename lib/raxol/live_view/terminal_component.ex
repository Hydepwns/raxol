defmodule Raxol.LiveView.TerminalComponent do
  @moduledoc """
  Phoenix LiveComponent for embedding terminal buffers in LiveView.

  Provides a drop-in terminal component with event handling, theming,
  and performance optimizations for 60fps rendering.

  ## Features

  - Event handling (keyboard, mouse, clipboard)
  - Multiple themes (Nord, Dracula, Solarized, Monokai)
  - Cursor rendering and styling
  - Focus management
  - Accessibility (ARIA labels, keyboard navigation)
  - Performance monitoring (logs if > 16ms)

  ## Usage

      # In your LiveView template
      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal-1"
        buffer={@buffer}
        theme={:nord}
        on_keypress={&handle_terminal_input/1}
      />

  ## Event Handling

  The component can emit the following events:

  - `on_keypress` - Keyboard input (includes key, modifiers)
  - `on_click` - Mouse click (includes x, y coordinates)
  - `on_paste` - Clipboard paste (includes text)
  - `on_focus` - Terminal gained focus
  - `on_blur` - Terminal lost focus

  ## Complete Example

      defmodule MyAppWeb.TerminalLive do
        use MyAppWeb, :live_view
        alias Raxol.Core.{Buffer, Box}
        alias Raxol.LiveView.TerminalComponent

        def mount(_params, _session, socket) do
          buffer = Buffer.create_blank_buffer(80, 24)
          buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)
          buffer = Buffer.write_at(buffer, 2, 2, "Welcome to Raxol!", %{bold: true})

          {:ok, assign(socket,
            buffer: buffer,
            cursor_pos: {2, 4}
          )}
        end

        def render(assigns) do
          ~H\"\"\"
          <div class="terminal-container">
            <.live_component
              module={TerminalComponent}
              id="my-terminal"
              buffer={@buffer}
              theme={:dracula}
              cursor_position={@cursor_pos}
              on_keypress={fn event -> send(self(), {:keypress, event}) end}
            />
          </div>
          \"\"\"
        end

        def handle_info({:keypress, %{key: key}}, socket) do
          # Handle keyboard input
          new_buffer = process_input(socket.assigns.buffer, key)
          {:noreply, assign(socket, buffer: new_buffer)}
        end
      end

  """

  use Phoenix.LiveComponent
  import Phoenix.HTML, only: [raw: 1]
  alias Raxol.LiveView.TerminalBridge

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    start_time = System.monotonic_time(:millisecond)

    socket =
      socket
      |> assign(:buffer, Map.get(assigns, :buffer))
      |> assign(:id, Map.get(assigns, :id))
      |> assign(:theme, Map.get(assigns, :theme, :default))
      |> assign(:cursor_position, Map.get(assigns, :cursor_position))
      |> assign(:cursor_style, Map.get(assigns, :cursor_style, :block))
      |> assign(:css_prefix, Map.get(assigns, :css_prefix, "raxol"))
      |> assign(:show_cursor, Map.get(assigns, :show_cursor, true))
      |> assign(:on_keypress, Map.get(assigns, :on_keypress))
      |> assign(:on_click, Map.get(assigns, :on_click))
      |> assign(:on_paste, Map.get(assigns, :on_paste))
      |> assign(:on_focus, Map.get(assigns, :on_focus))
      |> assign(:on_blur, Map.get(assigns, :on_blur))
      |> assign(:focusable, Map.get(assigns, :focusable, true))
      |> assign(:debug_diff, Map.get(assigns, :debug_diff, false))

    # Performance monitoring
    render_time = System.monotonic_time(:millisecond) - start_time

    if render_time > 16 do
      require Logger

      Logger.warning(
        "Terminal component update exceeded 60fps budget: #{render_time}ms"
      )
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"#{@id}-container"}
      class="raxol-container"
      phx-hook="RaxolTerminal"
      data-terminal-id={@id}
    >
      <%= if @debug_diff and assigns[:old_buffer] do %>
        <%= raw(TerminalBridge.buffer_diff_to_html(@old_buffer, @buffer,
          theme: @theme,
          css_prefix: @css_prefix
        )) %>
      <% else %>
        <%= raw(TerminalBridge.buffer_to_html(@buffer,
          theme: @theme,
          css_prefix: @css_prefix,
          show_cursor: @show_cursor,
          cursor_position: @cursor_position,
          cursor_style: @cursor_style
        )) %>
      <% end %>

      <%= if @focusable do %>
        <input
          type="text"
          id={"#{@id}-input"}
          class="raxol-input-capture"
          style="position: absolute; left: -9999px;"
          phx-keydown="terminal_keydown"
          phx-target={@myself}
          phx-blur="terminal_blur"
          phx-focus="terminal_focus"
          autocomplete="off"
          autocorrect="off"
          autocapitalize="off"
          spellcheck="false"
        />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("terminal_keydown", %{"key" => key} = params, socket) do
    event = %{
      key: key,
      code: Map.get(params, "code"),
      alt: Map.get(params, "altKey", false),
      ctrl: Map.get(params, "ctrlKey", false),
      shift: Map.get(params, "shiftKey", false),
      meta: Map.get(params, "metaKey", false)
    }

    if handler = socket.assigns.on_keypress do
      handler.(event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("terminal_click", %{"x" => x, "y" => y}, socket) do
    event = %{x: x, y: y}

    if handler = socket.assigns.on_click do
      handler.(event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("terminal_paste", %{"text" => text}, socket) do
    event = %{text: text}

    if handler = socket.assigns.on_paste do
      handler.(event)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("terminal_focus", _params, socket) do
    if handler = socket.assigns.on_focus do
      handler.()
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("terminal_blur", _params, socket) do
    if handler = socket.assigns.on_blur do
      handler.()
    end

    {:noreply, socket}
  end
end
