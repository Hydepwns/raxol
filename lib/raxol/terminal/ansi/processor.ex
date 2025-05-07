defmodule Raxol.Terminal.ANSI.Processor do
  @moduledoc """
  ANSI sequence processor module.

  This module processes ANSI escape sequences for terminal control, including:
  - Cursor movement
  - Text formatting
  - Screen manipulation
  - Terminal state changes
  - Bracketed paste mode
  - Focus reporting
  """

  use GenServer
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.ANSI.Sequences.{Cursor, Colors}
  alias Raxol.Terminal.ANSI.{TextFormatting, CharacterSets}
  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.ANSI.ScreenModes, as: ANSIScreenModes
  # alias Raxol.Terminal.Emulator
  # alias Raxol.Terminal.Commands.History
  # alias Raxol.Terminal.Commands.Modes, as: CmdModes
  # alias Raxol.Terminal.ScreenModes

  require Logger

  # ANSI sequence types
  @type sequence_type :: :csi | :osc | :sos | :pm | :apc | :esc | :text

  # ANSI sequence structure
  @type sequence :: %{
          type: sequence_type(),
          command: String.t(),
          params: list(String.t()),
          intermediate: String.t(),
          final: String.t(),
          text: String.t()
        }

  @doc """
  Process a parsed ANSI sequence and return the updated emulator state.
  This is a direct interface for processing sequences without using the GenServer.

  ## Parameters

  * `sequence` - The parsed ANSI sequence (result from Parser.parse_sequence/1)
  * `emulator` - The current emulator state

  ## Returns

  Updated emulator state

  ## Examples

      iex> sequence = Raxol.Terminal.ANSI.Parser.parse_sequence("\e[31m")
      iex> new_state = Raxol.Terminal.ANSI.Processor.process(sequence, emulator)
  """
  def process(sequence, emulator) do
    case sequence do
      {:cursor_up, n} ->
        Cursor.move_cursor_up(emulator, n)

      {:cursor_down, n} ->
        Cursor.move_cursor_down(emulator, n)

      {:cursor_forward, n} ->
        Cursor.move_cursor_forward(emulator, n)

      {:cursor_backward, n} ->
        Cursor.move_cursor_backward(emulator, n)

      {:cursor_move, row, col} ->
        Cursor.move_cursor(emulator, row, col)

      {:clear_screen, n} ->
        Screen.clear_screen(emulator, n)

      {:clear_line, n} ->
        Screen.clear_line(emulator, n)

      {:insert_line, n} ->
        Screen.insert_lines(emulator, n)

      {:delete_line, n} ->
        Screen.delete_lines(emulator, n)

      {:text_attributes, attrs} ->
        handle_text_attributes(attrs, emulator)

      {:charset, gset_num, charset} ->
        new_charset_state =
          CharacterSets.switch_charset(
            emulator.charset_state,
            gset_num,
            charset
          )

        %{emulator | charset_state: new_charset_state}

      {:unknown, _sequence} ->
        # Return the emulator unchanged for unknown sequences
        emulator

      _ ->
        # Default case for any unhandled sequence type
        emulator
    end
  end

  defp handle_text_attributes(attrs, emulator) do
    # Use emulator.style as the initial accumulator
    initial_style = emulator.style

    new_style =
      Enum.reduce(attrs, initial_style, fn
        # Use apply_attribute with :reset atom
        :reset, _acc ->
          # Reset by creating a new default style
          TextFormatting.new()

        {:foreground_basic, color_code}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_foreground_basic(acc, color_code)

        {:background_basic, color_code}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_background_basic(acc, color_code)

        {:foreground_256, index}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_foreground_256(acc, index)

        {:background_256, index}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_background_256(acc, index)

        {:foreground_true, r, g, b}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_foreground_true(acc, r, g, b)

        {:background_true, r, g, b}, acc ->
          # Colors functions take style struct, not emulator
          Colors.set_background_true(acc, r, g, b)

        attribute, acc when is_atom(attribute) ->
          # Use correct function name
          TextFormatting.apply_attribute(acc, attribute)

        # Ignore unknown attribute types
        _, acc ->
          acc
      end)

    # Update the emulator with the new style
    %{emulator | style: new_style}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_opts) do
    {:ok,
     %{
       buffer_manager: nil,
       current_sequence: nil,
       sequence_buffer: "",
       current_style: TextFormatting.new(),
       terminal_state: %{
         cursor_position: {0, 0},
         attributes: %{},
         modes: %{
           bracketed_paste: false,
           focus_reporting: false,
           cursor_visible: true
         }
       }
     }}
  end

  @doc """
  Processes an ANSI sequence.

  ## Examples

      iex> {:ok, processor} = Processor.start_link([])
      iex> {:ok, buffer_manager} = Manager.new(80, 24)
      iex> :ok = Processor.set_buffer_manager(processor, buffer_manager)
      iex> {:ok, _} = Processor.process_sequence(processor, "\e[31m")
      :ok
  """
  def process_sequence(processor, sequence) do
    GenServer.call(processor, {:process_sequence, sequence})
  end

  @doc """
  Sets the buffer manager for the processor.

  ## Examples

      iex> {:ok, processor} = Processor.start_link([])
      iex> {:ok, buffer_manager} = Manager.new(80, 24)
      iex> :ok = Processor.set_buffer_manager(processor, buffer_manager)
      :ok
  """
  def set_buffer_manager(processor, buffer_manager) do
    GenServer.call(processor, {:set_buffer_manager, buffer_manager})
  end

  @doc """
  Gets the current buffer manager.

  ## Examples

      iex> {:ok, processor} = Processor.start_link([])
      iex> {:ok, buffer_manager} = Manager.new(80, 24)
      iex> :ok = Processor.set_buffer_manager(processor, buffer_manager)
      iex> Processor.get_buffer_manager(processor)
      {:ok, ^buffer_manager}
  """
  def get_buffer_manager(processor) do
    GenServer.call(processor, :get_buffer_manager)
  end

  # Server callbacks

  def handle_call({:process_sequence, sequence}, _from, state) do
    parsed_sequence = parse_sequence(sequence)

    case handle_sequence(parsed_sequence, state) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      new_state -> {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call({:set_buffer_manager, buffer_manager}, _from, state) do
    {:reply, :ok, %{state | buffer_manager: buffer_manager}}
  end

  def handle_call(:get_buffer_manager, _from, state) do
    {:reply, {:ok, state.buffer_manager}, state}
  end

  # Private functions

  defp parse_sequence(sequence) do
    cond do
      # CSI sequence: \e[<params><intermediate><final>
      Regex.match?(~r/^\e\[/, sequence) ->
        case Regex.run(~r/^\e\[([\d;]*)([\x20-\x2F]*)([\x30-\x7E])/, sequence) do
          [_, params, intermediate, final] ->
            %{
              type: :csi,
              command: final,
              params: String.split(params, ";", trim: true),
              intermediate: intermediate,
              final: final,
              text: ""
            }

          _ ->
            %{type: :text, text: sequence}
        end

      # OSC sequence: \e]<params><text><bell>
      Regex.match?(~r/^\e\]/, sequence) ->
        case Regex.run(~r/^\e\]([\d;]*)([^\a]*)\a/, sequence) do
          [_, params, text] ->
            %{
              type: :osc,
              command: "",
              params: String.split(params, ";", trim: true),
              intermediate: "",
              final: "",
              text: text
            }

          _ ->
            %{type: :text, text: sequence}
        end

      # ESC sequence: \e<command>
      Regex.match?(~r/^\e[^\[\]]/, sequence) ->
        case Regex.run(~r/^\e([\x30-\x7E])/, sequence) do
          [_, command] ->
            %{
              type: :esc,
              command: command,
              params: [],
              intermediate: "",
              final: "",
              text: ""
            }

          _ ->
            %{type: :text, text: sequence}
        end

      # Plain text
      true ->
        %{type: :text, text: sequence}
    end
  end

  defp handle_sequence(sequence, state) do
    case sequence.type do
      :csi -> handle_csi_sequence(sequence, state)
      :osc -> handle_osc_sequence(sequence, state)
      :esc -> handle_esc_sequence(sequence, state)
      :text -> handle_text_sequence(sequence, state)
    end
  end

  defp handle_csi_sequence(sequence, state) do
    case sequence.command do
      "A" -> handle_cursor_up(sequence, state)
      "B" -> handle_cursor_down(sequence, state)
      "C" -> handle_cursor_forward(sequence, state)
      "D" -> handle_cursor_backward(sequence, state)
      "H" -> handle_cursor_position(sequence, state)
      "J" -> handle_erase_display(sequence, state)
      "K" -> handle_erase_line(sequence, state)
      "m" -> handle_text_attributes(sequence, state)
      "?25" -> handle_cursor_visibility(sequence, state)
      "?2004" -> handle_bracketed_paste(sequence, state)
      "?1004" -> handle_focus_reporting(sequence, state)
      _ -> state
    end
  end

  defp handle_osc_sequence(_sequence, state) do
    {:ok, state}
  end

  defp handle_esc_sequence(_sequence, state) do
    {:ok, state}
  end

  defp handle_text_sequence(_sequence, state) do
    {:ok, state}
  end

  # CSI sequence handlers

  defp handle_cursor_up(sequence, state) do
    # Parse the number of rows to move up
    count = parse_param(sequence.params, 1)

    # Update cursor position
    {x, y} = state.buffer_manager.cursor_position
    new_y = max(0, y - count)

    # Update state using helper function
    new_state = update_cursor_position(state, {x, new_y})
    {:ok, new_state}
  end

  defp handle_cursor_down(sequence, state) do
    # Parse the number of rows to move down
    count = parse_param(sequence.params, 1)

    # Update cursor position
    {x, y} = state.buffer_manager.cursor_position
    height = ScreenBuffer.get_height(state.buffer_manager.active_buffer)
    new_y = min(height - 1, y + count)

    # Update state using helper function
    new_state = update_cursor_position(state, {x, new_y})
    {:ok, new_state}
  end

  defp handle_cursor_forward(sequence, state) do
    # Parse the number of columns to move forward
    count = parse_param(sequence.params, 1)

    # Update cursor position
    {x, y} = state.buffer_manager.cursor_position
    width = ScreenBuffer.get_width(state.buffer_manager.active_buffer)
    new_x = min(width - 1, x + count)

    # Update state using helper function
    new_state = update_cursor_position(state, {new_x, y})
    {:ok, new_state}
  end

  defp handle_cursor_backward(sequence, state) do
    # Parse the number of columns to move backward
    count = parse_param(sequence.params, 1)

    # Update cursor position
    {x, y} = state.buffer_manager.cursor_position
    new_x = max(0, x - count)

    # Update state using helper function
    new_state = update_cursor_position(state, {new_x, y})
    {:ok, new_state}
  end

  defp handle_cursor_position(sequence, state) do
    # Parse the target position
    [row, col] = parse_params(sequence.params, [1, 1])

    # Convert to 0-based coordinates
    x = col - 1
    y = row - 1

    # Update state using helper function
    new_state = update_cursor_position(state, {x, y})
    {:ok, new_state}
  end

  defp handle_erase_display(sequence, state) do
    # Parse the erase mode
    mode = parse_param(sequence.params, 0)

    # Update the buffer based on the erase mode
    new_buffer_manager =
      case mode do
        0 ->
          BufferManager.erase_from_cursor_to_end(state.buffer_manager, state.current_style)

        1 ->
          BufferManager.erase_from_beginning_to_cursor(state.buffer_manager, state.current_style)

        2 ->
          BufferManager.clear_visible_display(state.buffer_manager, state.current_style)

        3 ->
          BufferManager.clear_entire_display_with_scrollback(
            state.buffer_manager,
            state.current_style
          )

        _ ->
          state.buffer_manager
      end

    new_state = %{state | buffer_manager: new_buffer_manager}
    {:ok, new_state}
  end

  defp handle_erase_line(sequence, state) do
    # Parse the erase mode
    mode = parse_param(sequence.params, 0)

    # Update the buffer based on the erase mode
    new_buffer_manager =
      case mode do
        0 ->
          BufferManager.erase_from_cursor_to_end_of_line(state.buffer_manager, state.current_style)

        1 ->
          BufferManager.erase_from_beginning_of_line_to_cursor(
            state.buffer_manager,
            state.current_style
          )

        2 ->
          BufferManager.clear_current_line(state.buffer_manager, state.current_style)

        _ ->
          state.buffer_manager
      end

    new_state = %{state | buffer_manager: new_buffer_manager}
    {:ok, new_state}
  end

  defp handle_cursor_visibility(sequence, state) do
    # Parse the visibility mode
    mode = parse_param(sequence.params, 1)

    # Update cursor visibility in terminal state
    new_state = %{
      state
      | terminal_state: %{
          state.terminal_state
          | modes: %{state.terminal_state.modes | cursor_visible: mode == 1}
        }
    }

    {:ok, new_state}
  end

  defp handle_bracketed_paste(sequence, state) do
    # Parse the bracketed paste mode
    mode = parse_param(sequence.params, 1)

    # Update bracketed paste mode in terminal state
    new_state = %{
      state
      | terminal_state: %{
          state.terminal_state
          | modes: %{state.terminal_state.modes | bracketed_paste: mode == 1}
        }
    }

    {:ok, new_state}
  end

  defp handle_focus_reporting(sequence, state) do
    # Parse the focus reporting mode
    mode = parse_param(sequence.params, 1)

    # Update focus reporting mode in terminal state
    new_state = %{
      state
      | terminal_state: %{
          state.terminal_state
          | modes: %{state.terminal_state.modes | focus_reporting: mode == 1}
        }
    }

    {:ok, new_state}
  end

  # Helper functions

  defp update_cursor_position(state, {x, y}) do
    # Update the buffer manager's cursor position
    new_buffer_manager =
      BufferManager.set_cursor_position(state.buffer_manager, x, y)

    # Update the terminal state
    %{
      state
      | buffer_manager: new_buffer_manager,
        terminal_state: %{state.terminal_state | cursor_position: {x, y}}
    }
  end

  defp parse_param(params, default) do
    case params do
      [param | _] ->
        case Integer.parse(param) do
          {value, _} -> value
          :error -> default
        end

      _ ->
        default
    end
  end

  defp parse_params(params, defaults) do
    params
    |> Enum.zip(defaults)
    |> Enum.map(fn {param, default} ->
      case Integer.parse(param) do
        {value, _} -> value
        :error -> default
      end
    end)
  end

  # Add this clause to handle SGR sequences
  defp handle_sequence({:text_attributes, attrs}, state) do
    # Update the style stored in the GenServer state
    # Iterate through attributes and apply them individually
    new_style = Enum.reduce(attrs, state.current_style, fn attr, current_style ->
      # Use apply_attribute/2 instead of apply_attributes/2
      TextFormatting.apply_attribute(current_style, attr)
    end)
    %{state | current_style: new_style}
  end
end
