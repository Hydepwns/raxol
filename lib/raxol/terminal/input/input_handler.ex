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
  """
  def add_to_history(%__MODULE__{} = handler) do
    if InputBuffer.empty?(handler.buffer) do
      handler
    else
      %{
        handler
        | input_history: [
            InputBuffer.get_contents(handler.buffer) | handler.input_history
          ],
          history_index: 0
      }
    end
  end

  @doc """
  Retrieves a previous input from history.
  """
  def get_history_entry(%__MODULE__{} = handler, index) do
    if index < length(handler.input_history) do
      entry = Enum.at(handler.input_history, index)
      %{handler | buffer: InputBuffer.set_contents(handler.buffer, entry)}
    else
      handler
    end
  end

  @doc """
  Moves to the next history entry.
  """
  def next_history_entry(%__MODULE__{} = handler) do
    if handler.history_index < length(handler.input_history) - 1 do
      new_index = handler.history_index + 1
      entry = Enum.at(handler.input_history, new_index)

      %{
        handler
        | buffer: InputBuffer.set_contents(handler.buffer, entry),
          history_index: new_index
      }
    else
      handler
    end
  end

  @doc """
  Moves to the previous history entry.
  """
  def previous_history_entry(%__MODULE__{} = handler) do
    if handler.history_index > 0 do
      new_index = handler.history_index - 1
      entry = Enum.at(handler.input_history, new_index)

      %{
        handler
        | buffer: InputBuffer.set_contents(handler.buffer, entry),
          history_index: new_index
      }
    else
      handler
    end
  end

  @doc """
  Clears the input buffer.
  """
  def clear_buffer(%__MODULE__{} = handler) do
    %{handler | buffer: InputBuffer.clear(handler.buffer)}
  end

  @doc """
  Gets the current buffer contents.
  """
  def get_buffer_contents(%__MODULE__{} = handler) do
    InputBuffer.get_contents(handler.buffer)
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
      :right -> "\e[C"
      :left -> "\e[D"
      :home -> "\e[H"
      :end -> "\e[F"
      :page_up -> "\e[5~"
      :page_down -> "\e[6~"
      :insert -> "\e[2~"
      :delete -> "\e[3~"
      :escape -> "\e"
      :tab -> "\t"
      :enter -> "\r"
      :backspace -> "\b"
      _ -> ""
    end
  end

  defp encode_mouse_event(event_type, button, x, y) do
    # Convert to 1-based coordinates for terminal
    x = x + 1
    y = y + 1

    # Encode the event type and button
    event_code =
      case {event_type, button} do
        {:press, 0} -> 0
        {:press, 1} -> 1
        {:press, 2} -> 2
        {:release, _} -> 3
        {:move, _} -> 35
        # Scroll up
        {:scroll, 4} -> 64
        # Scroll down
        {:scroll, 5} -> 65
        _ -> 0
      end

    # Encode the coordinates
    # Format: \e[M<event_code><x><y>
    # where x and y are ASCII characters with 32 added to make them printable
    "\e[M#{<<event_code + 32>>}#{<<x + 32>>}#{<<y + 32>>}"
  end

  defp update_mouse_buttons(buttons, event_type, button) do
    case event_type do
      :press -> MapSet.put(buttons, button)
      :release -> MapSet.delete(buttons, button)
      _ -> buttons
    end
  end
end
