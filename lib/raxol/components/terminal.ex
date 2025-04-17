defmodule Raxol.Components.Terminal do
  @moduledoc """
  A terminal component for Raxol that provides terminal emulation capabilities.

  This component handles:
  - Terminal output buffer
  - Cursor management
  - ANSI escape code processing
  - Input handling
  - Terminal state management
  """

  use Raxol.Component
  alias Raxol.Components.Terminal.ANSI
  # alias Raxol.Style # Unused
  # alias Raxol.Terminal.Buffer # Unused
  # import Raxol.View.Components
  # import Raxol.View.Layout

  @type terminal_state :: %{
          buffer: [String.t()],
          cursor: {integer(), integer()},
          dimensions: {integer(), integer()},
          mode: :normal | :insert | :command,
          history: [String.t()],
          history_index: integer(),
          scroll_offset: integer(),
          style: map(),
          ansi_state: ANSI.ansi_state()
        }

  @doc """
  Initializes a new terminal component.

  ## Options

  * `:rows` - Number of rows (default: 24)
  * `:cols` - Number of columns (default: 80)
  * `:prompt` - Command prompt string (default: "$ ")
  * `:style` - Terminal style options
  """
  @impl Raxol.Component
  def init(opts) when is_map(opts) do
    rows = Map.get(opts, :rows, 24)
    cols = Map.get(opts, :cols, 80)
    prompt = Map.get(opts, :prompt, "$ ")

    %{
      buffer: [prompt],
      buffer_content: prompt,
      cursor: {String.length(prompt), 0},
      width: cols,
      height: rows,
      mode: :normal,
      history: [],
      history_index: 0,
      scroll_offset: 0,
      style:
        Map.merge(
          %{
            padding: [1, 1],
            border: :rounded,
            background: :black,
            color: :white
          },
          Map.get(opts, :style, %{})
        ),
      ansi_state: %{
        cursor: {String.length(prompt), 0},
        style: %{},
        screen: %{},
        buffer: [prompt]
      }
    }
  end

  @doc """
  Handles terminal events.
  """
  @impl Raxol.Component
  def handle_event(%Event{type: :key} = event, state) do
    case state.mode do
      :normal -> handle_normal_mode(event, state)
      :insert -> handle_insert_mode(event, state)
      :command -> handle_command_mode(event, state)
    end
  end

  def handle_event(%Event{type: :output, data: output}, state) do
    # Process ANSI codes in the output
    new_ansi_state = ANSI.process(output, state.ansi_state)

    # Update terminal state based on ANSI processing
    %{
      state
      | buffer: new_ansi_state.buffer,
        cursor: new_ansi_state.cursor,
        style: Map.merge(state.style, new_ansi_state.style),
        ansi_state: new_ansi_state
    }
  end

  def handle_event(%Event{type: :resize} = event, state) do
    {cols, rows} = event.data
    %{state | dimensions: {cols, rows}}
  end

  def handle_event(_event, state), do: state

  @doc """
  Renders the terminal component.
  """
  @impl true
  def render(state) do
    # Generate the DSL map structure for the terminal
    dsl_result = %{
      # Special type handled by Runtime
      type: :terminal,
      # Pass raw content
      content: state.buffer_content,
      dimensions: {state.width, state.height},
      cursor: state.cursor,
      # Pass base style
      style: state.style
    }

    # Convert to Element struct
    Raxol.View.to_element(dsl_result)
  end

  # Private functions

  defp handle_normal_mode(%Event{type: :key, data: %{key: :i}}, state) do
    {%{state | mode: :insert}, []}
  end

  defp handle_normal_mode(%Event{type: :key, data: %{key: :colon}}, state) do
    {%{state | mode: :command, command_buffer: ":"}, []}
  end

  defp handle_normal_mode(%Event{type: :key, data: %{key: :up}}, state) do
    {update(:move_cursor_up, state), []}
  end

  defp handle_normal_mode(%Event{type: :key, data: %{key: :down}}, state) do
    {update(:move_cursor_down, state), []}
  end

  defp handle_normal_mode(_event, state), do: state

  defp handle_insert_mode(%Event{type: :key, data: %{key: key}}, state)
       when is_binary(key) do
    {update(:insert_char, state, key), []}
  end

  defp handle_insert_mode(%Event{type: :key, data: %{key: :escape}}, state) do
    {%{state | mode: :normal}, []}
  end

  defp handle_insert_mode(_event, state), do: state

  defp handle_command_mode(%Event{type: :key, data: %{key: :enter}}, state) do
    {update(:execute_command, state), []}
  end

  defp handle_command_mode(%Event{type: :key, data: %{key: :escape}}, state) do
    {%{state | mode: :normal, command_buffer: ""}, []}
  end

  defp handle_command_mode(_event, state), do: state

  def update(:insert_char, state, char) do
    %{state | buffer: state.buffer <> char}
  end

  @impl true
  def update(:move_cursor_up, state) do
    if state.history_index < length(state.history) do
      %{state | history_index: state.history_index + 1}
    else
      state
    end
  end

  def update(:move_cursor_down, state) do
    if state.history_index > 0 do
      %{state | history_index: state.history_index - 1}
    else
      state
    end
  end

  def update(:execute_command, state) do
    # Execute command and reset mode
    %{state | mode: :normal}
  end

  # Public API
end
