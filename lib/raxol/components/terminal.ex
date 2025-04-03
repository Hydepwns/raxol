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
  alias Raxol.Components.Base
  alias Raxol.Components.Terminal.ANSI

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
  def init(opts \\ []) do
    rows = Keyword.get(opts, :rows, 24)
    cols = Keyword.get(opts, :cols, 80)
    prompt = Keyword.get(opts, :prompt, "$ ")
    
    %{
      buffer: [prompt],
      cursor: {String.length(prompt), 0},
      dimensions: {cols, rows},
      mode: :normal,
      history: [],
      history_index: 0,
      scroll_offset: 0,
      style: Base.base_style([
        padding: [1, 1],
        border: :rounded,
        background: :black,
        color: :white
      ]),
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
    %{state |
      buffer: new_ansi_state.buffer,
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
  def render(state) do
    # Render the visible portion of the buffer
    visible_lines = Enum.slice(state.buffer, state.scroll_offset, elem(state.dimensions, 1))
    
    # Create terminal content
    content = Enum.join(visible_lines, "\n")
    
    # Apply terminal style
    Style.render(state.style, %{
      type: :terminal,
      attrs: %{
        content: content,
        cursor: state.cursor,
        dimensions: state.dimensions
      }
    })
  end

  # Private functions

  defp handle_normal_mode(%Event{key: :i}, state) do
    %{state | mode: :insert}
  end

  defp handle_normal_mode(%Event{key: :colon}, state) do
    %{state | mode: :command}
  end

  defp handle_normal_mode(%Event{key: :up}, state) do
    if state.history_index < length(state.history) do
      %{state | history_index: state.history_index + 1}
    else
      state
    end
  end

  defp handle_normal_mode(%Event{key: :down}, state) do
    if state.history_index > 0 do
      %{state | history_index: state.history_index - 1}
    else
      state
    end
  end

  defp handle_normal_mode(_event, state), do: state

  defp handle_insert_mode(%Event{key: key}, state) when is_binary(key) do
    # Process the input through ANSI to handle any escape sequences
    new_ansi_state = ANSI.process(key, state.ansi_state)
    
    %{state |
      buffer: new_ansi_state.buffer,
      cursor: new_ansi_state.cursor,
      style: Map.merge(state.style, new_ansi_state.style),
      ansi_state: new_ansi_state
    }
  end

  defp handle_insert_mode(%Event{key: :escape}, state) do
    %{state | mode: :normal}
  end

  defp handle_insert_mode(_event, state), do: state

  defp handle_command_mode(%Event{key: :enter}, state) do
    # Execute command and reset mode
    %{state | mode: :normal}
  end

  defp handle_command_mode(%Event{key: :escape}, state) do
    %{state | mode: :normal}
  end

  defp handle_command_mode(_event, state), do: state
end 