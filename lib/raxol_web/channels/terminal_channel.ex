defmodule RaxolWeb.TerminalChannel do
  @moduledoc """
  WebSocket channel for real-time terminal communication.

  This channel handles:
  - Terminal session initialization
  - Real-time input/output
  - Terminal resizing
  - Session management
  - Error handling
  """

  use RaxolWeb, :channel
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.Input
  require Raxol.Core.Runtime.Log
  require Logger
  import Raxol.Guards

  @type t :: %__MODULE__{
          emulator: Emulator.t(),
          input: Input.t(),
          renderer: Renderer.t(),
          session_id: String.t(),
          user_id: String.t(),
          scrollback_limit: non_neg_integer()
        }

  defstruct [
    :emulator,
    :input,
    :renderer,
    :session_id,
    :user_id,
    :scrollback_limit
  ]

  # Use dependency injection for the emulator module
  @emulator_module Application.get_env(:raxol, :terminal_emulator_module, Raxol.Terminal.Emulator)
  @renderer_module Application.get_env(:raxol, :terminal_renderer_module, Raxol.Terminal.Renderer)

  @impl Phoenix.Channel
  @dialyzer {:nowarn_function, join: 3}
  def join("terminal:" <> session_id, _params, socket) do
    # Only allow if session_id is a valid UUID
    if valid_uuid?(session_id) do
      # Get scrollback limit from config or use default
      scrollback_limit =
        Application.get_env(:raxol, :terminal, %{})[:scrollback_lines] || 1000

      # Create new emulator instance
      emulator = @emulator_module.new(80, 24, scrollback: scrollback_limit)
      input = Input.new()
      renderer = @renderer_module.new(emulator.main_screen_buffer)

      state = %__MODULE__{
        emulator: emulator,
        input: input,
        renderer: renderer,
        session_id: session_id,
        user_id: socket.assigns.user_id,
        scrollback_limit: scrollback_limit
      }

      {:ok, assign(socket, :terminal_state, state)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl Phoenix.Channel
  def handle_in("input", %{"data" => data}, socket) do
    state = socket.assigns.terminal_state

    # Process input through emulator
    {emulator, output} = @emulator_module.process_input(state.emulator, data)

    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    # Get cursor position and visibility
    {cursor_x, cursor_y} = @emulator_module.get_cursor_position(emulator)
    cursor_visible = @emulator_module.get_cursor_visible(emulator)

    # Broadcast output to client (send html, not data)
    broadcast!(socket, "output", %{
      html: @renderer_module.render(renderer),
      cursor: %{
        x: cursor_x,
        y: cursor_y,
        visible: cursor_visible
      }
    })

    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    state = socket.assigns.terminal_state

    # Resize emulator
    emulator = @emulator_module.resize(state.emulator, width, height)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}

    socket = assign(socket, :terminal_state, new_state)

    # Get cursor position and visibility
    {cursor_x, cursor_y} = @emulator_module.get_cursor_position(emulator)
    cursor_visible = @emulator_module.get_cursor_visible(emulator)

    # Broadcast resize event to client
    broadcast!(socket, "resize", %{
      width: width,
      height: height,
      cursor: %{
        x: cursor_x,
        y: cursor_y,
        visible: cursor_visible
      }
    })

    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def handle_in("scroll", %{"offset" => offset}, socket) do
    state = socket.assigns.terminal_state
    emulator = state.emulator

    new_emulator =
      cond do
        offset < 0 ->
          Raxol.Terminal.Commands.Screen.scroll_up(emulator, abs(offset))

        offset > 0 ->
          Raxol.Terminal.Commands.Screen.scroll_down(emulator, abs(offset))

        true ->
          emulator
      end

    renderer = %{
      state.renderer
      | screen_buffer: new_emulator.main_screen_buffer
    }

    new_state = %{state | emulator: new_emulator, renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    # Optionally, include scrollback size for UI
    scrollback_size = length(new_emulator.scrollback_buffer || [])

    push(socket, "output", %{
      html: @renderer_module.render(renderer),
      scrollback_size: scrollback_size
    })

    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def handle_in("theme", %{"theme" => theme}, socket) do
    state = socket.assigns.terminal_state
    renderer = @renderer_module.set_theme(state.renderer, theme)

    new_state = %{state | renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    push(socket, "output", %{
      html: @renderer_module.render(renderer)
    })

    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def handle_in("set_scrollback_limit", %{"limit" => limit}, socket) do
    state = socket.assigns.terminal_state
    limit = if integer?(limit), do: limit, else: String.to_integer("#{limit}")
    emulator = %{state.emulator | scrollback_limit: limit}
    new_state = %{state | emulator: emulator}
    socket = assign(socket, :terminal_state, new_state)
    {:reply, :ok, socket}
  end

  @impl Phoenix.Channel
  def terminate(_reason, _socket) do
    :ok
  end

  defp valid_uuid?(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
