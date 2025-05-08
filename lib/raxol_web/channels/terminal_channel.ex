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
  alias Raxol.Terminal.{Emulator, Renderer, Input, ScreenBuffer}
  # alias Phoenix.Channel # Unused
  # alias Raxol.Terminal.Input.InputHandler # Unused (commented out call)
  # alias Phoenix.Socket # Unused
  # require Logger # <-- Removed

  @type t :: %__MODULE__{
          emulator: Emulator.t(),
          input: Input.t(),
          renderer: Renderer.t(),
          session_id: String.t(),
          user_id: String.t()
        }

  defstruct [:emulator, :input, :renderer, :session_id, :user_id]

  @impl true
  @dialyzer {:nowarn_function, join: 3}
  def join("terminal:" <> session_id, _params, socket) do
    if authorized?(socket) do
      emulator = Emulator.new(80, 24)
      input = Input.new()
      renderer = Renderer.new(emulator.main_screen_buffer)

      state = %__MODULE__{
        emulator: emulator,
        input: input,
        renderer: renderer,
        session_id: session_id,
        user_id: socket.assigns.user_id
      }

      {:ok, assign(socket, :terminal_state, state)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("input", %{"data" => data}, socket) do
    state = socket.assigns.terminal_state

    {emulator, _output} = Emulator.process_input(state.emulator, data)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    # Revert: Push the rendered output again
    {cursor_x, cursor_y} = Emulator.get_cursor_position(emulator)
    cursor_visible = Emulator.get_cursor_visible(emulator)

    push(socket, "output", %{
      html: Renderer.render(renderer),
      cursor: %{
        x: cursor_x,
        y: cursor_y,
        visible: cursor_visible
      }
    })

    {:reply, :ok, socket}
  end

  @impl true
  @dialyzer {:nowarn_function, handle_in: 3}
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    state = socket.assigns.terminal_state

    emulator = Emulator.resize(state.emulator, width, height)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}

    socket = assign(socket, :terminal_state, new_state)

    {cursor_x, cursor_y} = Emulator.get_cursor_position(emulator)
    cursor_visible = Emulator.get_cursor_visible(emulator)

    reply = {:reply, :ok, socket}

    push_result =
      push(socket, "output", %{
        html: Renderer.render(renderer),
        cursor: %{
          x: cursor_x,
          y: cursor_y,
          visible: cursor_visible
        }
      })

    reply
  end

  @impl true
  def handle_in("scroll", %{"offset" => _offset}, socket) do
    state = socket.assigns.terminal_state

    push(socket, "output", %{
      html: Renderer.render(state.renderer)
    })

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("theme", %{"theme" => theme}, socket) do
    state = socket.assigns.terminal_state
    renderer = Renderer.set_theme(state.renderer, theme)

    new_state = %{state | renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    push(socket, "output", %{
      html: Renderer.render(renderer)
    })

    {:reply, :ok, socket}
  end

  @impl true
  def terminate(reason, socket) do
    :ok
  end

  # Private functions

  defp authorized?(_socket) do
    # Implement authorization logic
    true
  end

  # Unused function
  # defp process_events(events, emulator, renderer) do
  #   Enum.reduce(events, {emulator, renderer}, fn event, {emu, ren} ->
  #     case event do
  #       {:text, text} ->
  #         {Emulator.process_input(emu, text), ren}
  #       {:control, :enter} ->
  #         {Emulator.process_input(emu, "\n"), ren}
  #       {:control, :backspace} ->
  #         {Emulator.process_input(emu, "\b"), ren}
  #       {:control, :tab} ->
  #         {Emulator.process_input(emu, "\t"), ren}
  #       {:escape, sequence} ->
  #         {Emulator.process_escape_sequence(emu, sequence), ren}
  #       {:mouse, event} ->
  #         {Emulator.process_mouse(emu, event), ren}
  #       _ ->
  #         {emu, ren}
  #     end
  #   end)
  # end

  # Keep the commented out original resize handler
  # @impl true
  # def handle_in(\"resize\", %{\"width\" => width, \"height\" => height}, socket) do
  # ... (rest of original handler)
  # end
end
