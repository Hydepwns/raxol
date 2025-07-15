defmodule Raxol.Terminal.Input.InputHandler do
  @moduledoc """
  Handles input processing for the terminal emulator.

  This module manages keyboard input, mouse events, input history,
  and modifier key states.
  """

  defstruct buffer: "",
            mode: :normal,
            mouse_enabled: false,
            mouse_buttons: MapSet.new(),
            mouse_position: {0, 0},
            input_history: [],
            history_index: nil,
            modifier_state: %{
              ctrl: false,
              alt: false,
              shift: false,
              meta: false
            }

  @type t :: %__MODULE__{}

  @doc """
  Creates a new input handler with default values.
  """
  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @doc """
  Processes regular keyboard input.
  """
  @spec process_keyboard(t(), String.t()) :: t()
  def process_keyboard(%__MODULE__{} = handler, key) when is_binary(key) do
    %{handler | buffer: handler.buffer <> key}
  end

  @doc """
  Processes special keys like arrow keys, function keys, etc.
  """
  @spec process_special_key(t(), atom()) :: t()
  def process_special_key(%__MODULE__{} = handler, key) do
    sequence = Raxol.Terminal.Input.SpecialKeys.atom_to_escape_sequence(key)
    %{handler | buffer: sequence}
  end

  @doc """
  Updates modifier key state.
  """
  @spec update_modifier(t(), String.t(), boolean()) :: t()
  def update_modifier(%__MODULE__{} = handler, modifier, state) do
    modifier_key =
      case modifier do
        "Control" -> :ctrl
        "Alt" -> :alt
        "Shift" -> :shift
        "Meta" -> :meta
        _ -> :ctrl
      end

    modifier_state = Map.put(handler.modifier_state, modifier_key, state)
    %{handler | modifier_state: modifier_state}
  end

  @doc """
  Processes key with current modifier state.
  """
  @spec process_key_with_modifiers(t(), String.t()) :: t()
  def process_key_with_modifiers(%__MODULE__{} = handler, key) do
    sequence =
      Raxol.Terminal.Input.SpecialKeys.key_with_modifiers_to_escape_sequence(
        handler.modifier_state,
        key
      )

    %{handler | buffer: sequence}
  end

  @doc """
  Processes mouse events.
  """
  @spec process_mouse(t(), tuple()) :: t()
  def process_mouse(%__MODULE__{} = handler, {action, button, x, y}) do
    if handler.mouse_enabled do
      action_code =
        case action do
          :press -> "M"
          :release -> "m"
          :drag -> "M"
          _ -> ""
        end

      sequence = "\e[<#{button};#{x + 1};#{y + 1}#{action_code}"

      mouse_buttons =
        case action do
          :press -> MapSet.put(handler.mouse_buttons, button)
          :release -> MapSet.delete(handler.mouse_buttons, button)
          _ -> handler.mouse_buttons
        end

      %{
        handler
        | buffer: sequence,
          mouse_position: {x, y},
          mouse_buttons: mouse_buttons
      }
    else
      handler
    end
  end

  @doc """
  Sets mouse enabled state.
  """
  @spec set_mouse_enabled(t(), boolean()) :: t()
  def set_mouse_enabled(%__MODULE__{} = handler, enabled) do
    %{handler | mouse_enabled: enabled}
  end

  @doc """
  Sets input mode.
  """
  @spec set_mode(t(), atom()) :: t()
  def set_mode(%__MODULE__{} = handler, mode) do
    %{handler | mode: mode}
  end

  @doc """
  Gets current input mode.
  """
  @spec get_mode(t()) :: atom()
  def get_mode(%__MODULE__{} = handler) do
    handler.mode
  end

  @doc """
  Adds current buffer to history if not empty.
  """
  @spec add_to_history(t()) :: t()
  def add_to_history(%__MODULE__{} = handler) do
    if handler.buffer != "" do
      history = [handler.buffer | handler.input_history]
      %{handler | input_history: history, history_index: nil, buffer: ""}
    else
      handler
    end
  end

  @doc """
  Gets history entry at specified index.
  """
  @spec get_history_entry(t(), integer()) :: t()
  def get_history_entry(%__MODULE__{} = handler, index) do
    if index >= 0 and index < length(handler.input_history) do
      entry = Enum.at(handler.input_history, index)
      %{handler | buffer: entry, history_index: index}
    else
      handler
    end
  end

  @doc """
  Moves to next (newer) history entry.
  """
  @spec next_history_entry(t()) :: {t(), String.t()}
  def next_history_entry(%__MODULE__{} = handler) do
    if handler.history_index == nil or handler.input_history == [] do
      {handler, handler.buffer}
    else
      new_index = max(handler.history_index - 1, 0)
      entry = Enum.at(handler.input_history, new_index)
      new_handler = %{handler | buffer: entry, history_index: new_index}
      {new_handler, entry}
    end
  end

  @doc """
  Moves to previous (older) history entry.
  """
  @spec previous_history_entry(t()) :: {t(), String.t()}
  def previous_history_entry(%__MODULE__{} = handler) do
    if handler.history_index == nil and length(handler.input_history) > 0 do
      entry = hd(handler.input_history)
      new_handler = %{handler | buffer: entry, history_index: 0}
      {new_handler, entry}
    else
      if handler.history_index != nil and
           handler.history_index < length(handler.input_history) - 1 do
        new_index = handler.history_index + 1
        entry = Enum.at(handler.input_history, new_index)
        new_handler = %{handler | buffer: entry, history_index: new_index}
        {new_handler, entry}
      else
        {handler, handler.buffer}
      end
    end
  end

  @doc """
  Clears the input buffer.
  """
  @spec clear_buffer(t()) :: t()
  def clear_buffer(%__MODULE__{} = handler) do
    %{handler | buffer: ""}
  end

  @doc """
  Checks if buffer is empty.
  """
  @spec buffer_empty?(t()) :: boolean()
  def buffer_empty?(%__MODULE__{} = handler) do
    handler.buffer == ""
  end

  @doc """
  Gets buffer contents.
  """
  @spec get_buffer_contents(t()) :: String.t()
  def get_buffer_contents(%__MODULE__{} = handler) do
    handler.buffer
  end

  @doc """
  Handles printable character input for the terminal emulator.
  """
  @spec handle_printable_character(any(), integer(), map(), atom() | nil) ::
          {any(), any()}
  def handle_printable_character(emulator, char_codepoint, params, single_shift) do
    IO.puts(
      "DEBUG: InputHandler - Processing codepoint: #{inspect(char_codepoint)} (#{List.to_string([char_codepoint])})"
    )

    # Use the CharacterProcessor to handle the printable character
    # This will write the character to the buffer and update cursor position
    updated_emulator =
      Raxol.Terminal.Input.CharacterProcessor.process_printable_character(
        emulator,
        char_codepoint
      )

    {updated_emulator, nil}
  end
end
