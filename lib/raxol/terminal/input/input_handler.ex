defmodule Raxol.Terminal.Input.InputHandler do
  @moduledoc """
  Handles input processing for the terminal emulator, including:
  - Mouse events (clicks, movement, scrolling)
  - Special key handling
  - Input mode switching
  - Input buffering
  - Extended key combinations
  - Tab completion
  """

  alias Raxol.Terminal.Input.InputBuffer
  alias Raxol.Terminal.Input.SpecialKeys
  alias Raxol.Terminal.Input.Types

  @type mouse_button :: 0 | 1 | 2 | 3 | 4
  @type mouse_event_type :: :press | :release | :move | :scroll
  @type mouse_event ::
          {mouse_event_type(), mouse_button(), non_neg_integer(),
           non_neg_integer()}
  @type special_key ::
          :up
          | :down
          | :left
          | :right
          | :home
          | :end
          | :page_up
          | :page_down
          | :insert
          | :delete
          | :escape
          | :tab
          | :enter
          | :backspace
  @type input_mode :: :normal | :insert | :replace | :command
  @type completion_callback :: (String.t() -> list(String.t()))
  @type t :: %__MODULE__{
          mode: input_mode(),
          history_index: integer() | nil,
          input_history: [String.t()],
          buffer: Types.input_buffer(),
          prompt: String.t() | nil,
          completion_context: map() | nil,
          last_event_time: integer() | nil,
          clipboard_content: String.t() | nil,
          clipboard_history: [String.t()],
          mouse_enabled: boolean(),
          mouse_buttons: MapSet.t(mouse_button()),
          mouse_position: {non_neg_integer(), non_neg_integer()},
          modifier_state: SpecialKeys.modifier_state(),
          input_queue: list(String.t()),
          processing_escape: boolean(),
          completion_callback: completion_callback() | nil,
          completion_options: list(String.t()),
          completion_index: non_neg_integer()
        }

  defstruct [
    :mode,
    :history_index,
    :input_history,
    :buffer,
    :prompt,
    :completion_context,
    :last_event_time,
    :clipboard_content,
    :clipboard_history,
    :mouse_enabled,
    :mouse_buttons,
    :mouse_position,
    :modifier_state,
    :input_queue,
    :processing_escape,
    :completion_callback,
    :completion_options,
    :completion_index
  ]

  @doc """
  Creates a new input handler with default values.
  """
  def new do
    %__MODULE__{
      mode: :normal,
      history_index: nil,
      input_history: [],
      buffer: InputBuffer.new(),
      prompt: nil,
      completion_context: nil,
      last_event_time: nil,
      clipboard_content: nil,
      clipboard_history: [],
      mouse_enabled: false,
      mouse_buttons: MapSet.new(),
      mouse_position: {0, 0},
      modifier_state: SpecialKeys.new_state(),
      input_queue: [],
      processing_escape: false,
      completion_callback: nil,
      completion_options: [],
      completion_index: 0
    }
  end

  @doc """
  Processes a keyboard input event.
  """
  def process_keyboard(%__MODULE__{} = handler, input) when is_binary(input) do
    if handler.processing_escape do
      handle_escape_sequence(handler, input)
    else
      case input do
        "\e" ->
          %{handler | processing_escape: true}

        _ ->
          process_normal_input(handler, input)
      end
    end
  end

  @doc """
  Processes a special key event.
  """
  def process_special_key(%__MODULE__{} = handler, key) when is_atom(key) do
    special_key_sequence = get_special_key_sequence(key)
    process_keyboard(handler, special_key_sequence)
  end

  @doc """
  Updates the modifier state for a key.
  """
  def update_modifier(%__MODULE__{} = handler, key, pressed)
      when is_binary(key) and is_boolean(pressed) do
    %{
      handler
      | modifier_state:
          SpecialKeys.update_state(handler.modifier_state, key, pressed)
    }
  end

  @doc """
  Processes a key with the current modifier state.
  """
  def process_key_with_modifiers(%__MODULE__{} = handler, key)
      when is_binary(key) do
    sequence = SpecialKeys.to_escape_sequence(handler.modifier_state, key)
    process_keyboard(handler, sequence)
  end

  @doc """
  Processes a mouse event.
  """
  def process_mouse(%__MODULE__{} = handler, {event_type, button, x, y}) do
    if handler.mouse_enabled do
      mouse_sequence = encode_mouse_event(event_type, button, x, y)

      %{
        handler
        | buffer: InputBuffer.append(handler.buffer, mouse_sequence),
          mouse_buttons:
            update_mouse_buttons(handler.mouse_buttons, event_type, button),
          mouse_position: {x, y}
      }
    else
      handler
    end
  end

  @doc """
  Enables or disables mouse event handling.
  """
  def set_mouse_enabled(%__MODULE__{} = handler, enabled)
      when is_boolean(enabled) do
    %{handler | mouse_enabled: enabled}
  end

  @doc """
  Sets the input mode.
  """
  def set_mode(%__MODULE__{} = handler, mode) when is_atom(mode) do
    %{handler | mode: mode}
  end

  @doc """
  Gets the current input mode.
  """
  def get_mode(%__MODULE__{} = handler) do
    handler.mode
  end

  @doc """
  Adds the current buffer contents to the input history.
  Resets the history navigation index and clears the buffer.
  """
  def add_to_history(
        %__MODULE__{buffer: buffer, input_history: history} = handler
      ) do
    current_content = InputBuffer.get_contents(buffer)
    # Don't add empty strings or duplicates of the last entry
    allow_add =
      current_content != "" and
        (history == [] or hd(history) != current_content)

    if allow_add do
      %{
        handler
        | input_history: [current_content | history],
          # Reset history index
          history_index: nil,
          # Clear the buffer
          buffer: InputBuffer.clear(buffer)
      }
    else
      # Still clear buffer even if not adding (e.g., empty input)
      %{handler | buffer: InputBuffer.clear(buffer)}
    end
  end

  @doc """
  Retrieves a specific input from history by its index (0 is most recent).
  Sets the history_index to track navigation.
  """
  def get_history_entry(
        %__MODULE__{input_history: history, buffer: current_buffer} = handler,
        index
      )
      when is_integer(index) and index >= 0 and index < length(history) do
    entry = Enum.at(history, index)
    new_buffer = InputBuffer.set_contents(current_buffer, entry)

    %{
      handler
      | buffer: new_buffer,
        history_index: index
    }
  end

  # Ignore invalid index
  def get_history_entry(handler, _index), do: handler

  @doc """
  Moves to the next history entry (newer / Down Arrow).
  """
  def next_history_entry(
        %__MODULE__{
          history_index: index,
          input_history: history,
          buffer: current_buffer
        } = handler
      ) do
    # Check if not already at newest entry (index must be non-nil and > 0)
    if is_integer(index) and index > 0 do
      new_index = index - 1
      new_input = Enum.at(history, new_index)
      new_buffer = InputBuffer.set_contents(current_buffer, new_input)

      new_buffer_after_cursor =
        InputBuffer.move_cursor_to_end_of_line(new_buffer)

      {%{handler | history_index: new_index, buffer: new_buffer_after_cursor},
       new_input}
    else
      # Already at newest entry (index 0) or not navigating
      {handler, InputBuffer.get_contents(handler.buffer)}
    end
  end

  @doc """
  Moves to the previous history entry (older / Up Arrow).
  If not currently navigating history, it starts from the most recent entry (index 0).
  """
  def previous_history_entry(
        %__MODULE__{
          history_index: index,
          input_history: history,
          buffer: current_buffer
        } = handler
      ) do
    # Handle the first press of 'Up Arrow' when index is nil
    current_index = if is_nil(index), do: -1, else: index

    # Check if there's an older entry available
    if length(history) > 0 and current_index < length(history) - 1 do
      new_index = current_index + 1
      new_input = Enum.at(history, new_index)
      new_buffer = InputBuffer.set_contents(current_buffer, new_input)

      new_buffer_after_cursor =
        InputBuffer.move_cursor_to_end_of_line(new_buffer)

      {%{handler | history_index: new_index, buffer: new_buffer_after_cursor},
       new_input}
    else
      # Already at oldest entry
      {handler, InputBuffer.get_contents(handler.buffer)}
    end
  end

  @doc """
  Clears the input buffer.
  """
  def clear_buffer(%__MODULE__{} = handler) do
    %{handler | buffer: InputBuffer.clear(handler.buffer)}
  end

  @doc """
  Gets the contents of the internal input buffer.
  """
  def get_buffer_contents(%__MODULE__{buffer: buffer}) do
    InputBuffer.get_contents(buffer)
  end

  @doc """
  Checks if the buffer is empty.
  """
  def buffer_empty?(%__MODULE__{} = handler) do
    InputBuffer.empty?(handler.buffer)
  end

  @doc """
  Sets a completion callback function for tab completion.
  """
  def set_completion_callback(%__MODULE__{} = handler, callback)
      when is_function(callback, 1) do
    %{handler | completion_callback: callback}
  end

  @doc """
  Processes tab completion.
  """
  def handle_tab(%__MODULE__{} = handler) do
    if handler.completion_callback do
      current_input = InputBuffer.get_contents(handler.buffer)

      # Get completion options
      completion_options = handler.completion_callback.(current_input)

      if length(completion_options) > 0 do
        # If we have a single option, complete it
        if length(completion_options) == 1 do
          %{
            handler
            | buffer:
                InputBuffer.set_contents(
                  handler.buffer,
                  Enum.at(completion_options, 0)
                ),
              completion_options: [],
              completion_index: 0
          }
        else
          # If we have multiple options, cycle through them
          new_index =
            rem(handler.completion_index + 1, length(completion_options))

          %{
            handler
            | buffer:
                InputBuffer.set_contents(
                  handler.buffer,
                  Enum.at(completion_options, new_index)
                ),
              completion_options: completion_options,
              completion_index: new_index
          }
        end
      else
        handler
      end
    else
      handler
    end
  end

  # Private functions

  defp handle_escape_sequence(%__MODULE__{} = handler, input) do
    case input do
      # End of escape sequence
      <<c>> when c >= ?@ and c <= ?~ ->
        %{
          handler
          | buffer: InputBuffer.append(handler.buffer, "\e" <> input),
            processing_escape: false
        }

      # More escape sequence data
      _ ->
        %{handler | buffer: InputBuffer.append(handler.buffer, input)}
    end
  end

  defp process_normal_input(%__MODULE__{} = handler, input) do
    case input do
      "\r" ->
        handler
        |> add_to_history()
        |> clear_buffer()

      "\b" ->
        %{handler | buffer: InputBuffer.backspace(handler.buffer)}

      "\t" ->
        handle_tab(handler)

      _ ->
        %{handler | buffer: InputBuffer.append(handler.buffer, input)}
    end
  end

  defp get_special_key_sequence(key) do
    case key do
      :up -> "\e[A"
      :down -> "\e[B"
      :left -> "\e[D"
      :right -> "\e[C"
      :home -> "\e[H"
      :end -> "\e[F"
      :page_up -> "\e[5~"
      :page_down -> "\e[6~"
      :insert -> "\e[2~"
      :delete -> "\e[3~"
      # Note: Some terminals use OP, OQ, OR, OS for F1-F4
      :f1 -> "\eOP"
      :f2 -> "\eOQ"
      :f3 -> "\eOR"
      :f4 -> "\eOS"
      :f5 -> "\e[15~"
      :f6 -> "\e[17~"
      :f7 -> "\e[18~"
      :f8 -> "\e[19~"
      :f9 -> "\e[20~"
      :f10 -> "\e[21~"
      :f11 -> "\e[23~"
      :f12 -> "\e[24~"
      :tab -> "\t"
      :enter -> "\r"
      :backspace -> "\b"
      :escape -> "\e"
      _ -> ""
    end
  end

  # Encodes mouse event according to XTerm specification (SGR format preferred)
  # Reference: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Extended-coordinates
  # Format: CSI < Cb ; Cx ; Cy M (press) or m (release)
  defp encode_mouse_event(event_type, button, x, y) do
    # SGR format uses different button codes and adds modifier info
    # Basic button code: 0=Left, 1=Middle, 2=Right
    # Scroll wheel: 64=Up, 65=Down
    # Modifiers: Shift=4, Meta=8, Ctrl=16
    # TODO: Incorporate modifier state from handler.modifier_state

    base_code =
      case {event_type, button} do
        {:press, 0} -> 0
        {:press, 1} -> 1
        {:press, 2} -> 2
        # Release uses code 3 in basic encoding, but SGR is different
        {:release, _} -> 3
        # Placeholder - SGR doesn't use button code 3 for release
        # Scroll Up
        {:scroll, 4} -> 64
        # Scroll Down
        {:scroll, 5} -> 65
        # Code for mouse move / drag
        _ -> 35
      end

    # TODO: Add modifier calculation: base_code + shift_val + meta_val + ctrl_val

    # Coordinates are 1-based for SGR
    final_x = x + 1
    final_y = y + 1

    # Determine final character M (press) or m (release)
    final_char =
      case event_type do
        :press -> "M"
        :release -> "m"
        # Scrolls are typically treated as presses in SGR
        :scroll -> "M"
        # Motion events are typically treated as presses
        :move -> "M"
      end

    "\e[<#{base_code};#{final_x};#{final_y}#{final_char}"
  end

  defp update_mouse_buttons(buttons, event_type, button) do
    case event_type do
      :press -> MapSet.put(buttons, button)
      :release -> MapSet.delete(buttons, button)
      _ -> buttons
    end
  end
end
