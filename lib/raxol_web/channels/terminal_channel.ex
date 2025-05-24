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
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Input
  require Logger

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
      scrollback_limit =
        Application.get_env(:raxol, :terminal, [])
        |> Keyword.get(:scrollback_lines, 1000)

      emulator = Emulator.new(80, 24, scrollback: scrollback_limit)
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

    {emulator, _output} = Raxol.Terminal.Emulator.process_input(state.emulator, data)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}
    socket = assign(socket, :terminal_state, new_state)

    # Revert: Push the rendered output again
    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    cursor_visible = Raxol.Terminal.Emulator.get_cursor_visible(emulator)

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

    emulator = Raxol.Terminal.Emulator.resize(state.emulator, width, height)
    renderer = %{state.renderer | screen_buffer: emulator.main_screen_buffer}

    new_state = %{state | emulator: emulator, renderer: renderer}

    socket = assign(socket, :terminal_state, new_state)

    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    cursor_visible = Raxol.Terminal.Emulator.get_cursor_visible(emulator)

    reply = {:reply, :ok, socket}

    _push_result =
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
      html: Renderer.render(renderer),
      scrollback_size: scrollback_size
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
  def handle_in("set_scrollback_limit", %{"limit" => limit}, socket) do
    state = socket.assigns.terminal_state
    limit = if is_integer(limit), do: limit, else: String.to_integer("#{limit}")
    emulator = %{state.emulator | scrollback_limit: limit}
    new_state = %{state | emulator: emulator}
    socket = assign(socket, :terminal_state, new_state)
    {:reply, :ok, socket}
  end

  @impl true
  def terminate(_reason, _socket) do
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

  # Pushes rendered output and cursor state to the client
  defp push_output(socket, state) do
    buffer = state.emulator.main_screen_buffer
    current_theme = Map.get(state.renderer, :theme, %{})

    html_content =
      Renderer.render(%Renderer{screen_buffer: buffer, theme: current_theme})

    payload = %{
      html: html_content,
      cursor: %{
        x: Raxol.Terminal.Emulator.get_cursor_position(state.emulator) |> elem(0),
        y: Raxol.Terminal.Emulator.get_cursor_position(state.emulator) |> elem(1),
        visible: Raxol.Terminal.Emulator.get_cursor_visible(state.emulator)
      }
    }

    # Only use Task.start_link outside of test environment
    if Mix.env() == :test do
      push(socket, "output", payload)
    else
      # Use Task.start_link for async push in dev/prod
      Task.start_link(fn -> push(socket, "output", payload) end)
    end
  end
end
