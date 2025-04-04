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
  alias Raxol.Terminal.{Emulator, Input, Renderer}
  alias Phoenix.Socket

  @type t :: %__MODULE__{
    emulator: Emulator.t(),
    input: Input.t(),
    renderer: Renderer.t(),
    session_id: String.t(),
    user_id: String.t()
  }

  defstruct [:emulator, :input, :renderer, :session_id, :user_id]

  @impl true
  def join("terminal:" <> session_id, _params, socket) do
    if authorized?(socket) do
      emulator = Emulator.new(80, 24)
      input = Input.new()
      renderer = Renderer.new(emulator: emulator)
      
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
    {events, input} = Input.process_input(state.input, data)
    
    {emulator, renderer} = process_events(events, state.emulator, state.renderer)
    
    new_state = %{state | 
      emulator: emulator,
      input: input,
      renderer: renderer
    }
    
    socket = assign(socket, :terminal_state, new_state)
    
    {:reply, :ok, push(socket, "output", %{
      html: Renderer.render_with_css(renderer),
      cursor: %{
        x: emulator.cursor_x,
        y: emulator.cursor_y,
        visible: emulator.cursor_visible
      }
    })}
  end

  @impl true
  def handle_in("resize", %{"width" => width, "height" => height}, socket) do
    state = socket.assigns.terminal_state
    emulator = Emulator.resize(state.emulator, width, height)
    renderer = Renderer.set_dimensions(state.renderer, width, height)
    
    new_state = %{state | 
      emulator: emulator,
      renderer: renderer
    }
    
    socket = assign(socket, :terminal_state, new_state)
    
    {:reply, :ok, push(socket, "output", %{
      html: Renderer.render_with_css(renderer),
      cursor: %{
        x: emulator.cursor_x,
        y: emulator.cursor_y,
        visible: emulator.cursor_visible
      }
    })}
  end

  @impl true
  def handle_in("scroll", %{"offset" => offset}, socket) do
    state = socket.assigns.terminal_state
    renderer = Renderer.set_scroll_offset(state.renderer, offset)
    
    new_state = %{state | renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)
    
    {:reply, :ok, push(socket, "output", %{
      html: Renderer.render_with_css(renderer)
    })}
  end

  @impl true
  def handle_in("theme", %{"theme" => theme}, socket) do
    state = socket.assigns.terminal_state
    renderer = Renderer.set_theme(state.renderer, theme)
    
    new_state = %{state | renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)
    
    {:reply, :ok, push(socket, "output", %{
      html: Renderer.render_with_css(renderer)
    })}
  end

  @impl true
  def terminate(reason, socket) do
    state = socket.assigns.terminal_state
    # Clean up terminal session
    :ok
  end

  # Private functions

  defp authorized?(socket) do
    # Implement authorization logic
    true
  end

  defp process_events(events, emulator, renderer) do
    Enum.reduce(events, {emulator, renderer}, fn event, {emu, ren} ->
      case event do
        {:text, text} ->
          {Emulator.write(emu, text), ren}
        {:control, :enter} ->
          {Emulator.write(emu, "\n"), ren}
        {:control, :backspace} ->
          {Emulator.write(emu, "\b"), ren}
        {:control, :tab} ->
          {Emulator.write(emu, "\t"), ren}
        {:escape, sequence} ->
          {Emulator.process_escape(emu, sequence), ren}
        {:mouse, event} ->
          {Emulator.process_mouse(emu, event), ren}
        _ ->
          {emu, ren}
      end
    end)
  end
end 