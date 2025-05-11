defmodule Raxol.Terminal.Input.Manager do
  @moduledoc """
  Manages input handling for the terminal emulator, including:
  - Keyboard input processing
  - Mouse event handling
  - Input buffering
  - Input history
  - Input modes
  - Special key handling
  - Modifier state management
  """

  alias Raxol.Terminal.Input.InputBuffer
  alias Raxol.Terminal.Input.SpecialKeys
  alias Raxol.Terminal.Input.Types

  @type mouse_button :: 0 | 1 | 2 | 3 | 4
  @type mouse_event_type :: :press | :release | :move | :scroll
  @type mouse_event :: {mouse_event_type(), mouse_button(), non_neg_integer(), non_neg_integer()}
  @type special_key :: :up | :down | :left | :right | :home | :end | :page_up | :page_down |
                      :insert | :delete | :escape | :tab | :enter | :backspace |
                      :f1 | :f2 | :f3 | :f4 | :f5 | :f6 | :f7 | :f8 | :f9 | :f10 | :f11 | :f12
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
  Creates a new input manager with default values.
  """
  @spec new() :: t()
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
  @spec process_keyboard(t(), String.t()) :: t()
  def process_keyboard(%__MODULE__{} = manager, input) when is_binary(input) do
    if manager.processing_escape do
      handle_escape_sequence(manager, input)
    else
      case input do
        "\e" -> %{manager | processing_escape: true}
        _ -> process_normal_input(manager, input)
      end
    end
  end

  @doc """
  Processes a special key event.
  """
  @spec process_special_key(t(), special_key()) :: t()
  def process_special_key(%__MODULE__{} = manager, key) when is_atom(key) do
    special_key_sequence = get_special_key_sequence(key)
    process_keyboard(manager, special_key_sequence)
  end

  @doc """
  Updates the modifier state for a key.
  """
  @spec update_modifier(t(), String.t(), boolean()) :: t()
  def update_modifier(%__MODULE__{} = manager, key, pressed)
      when is_binary(key) and is_boolean(pressed) do
    %{
      manager
      | modifier_state: SpecialKeys.update_state(manager.modifier_state, key, pressed)
    }
  end

  @doc """
  Processes a key with the current modifier state.
  """
  @spec process_key_with_modifiers(t(), String.t()) :: t()
  def process_key_with_modifiers(%__MODULE__{} = manager, key) when is_binary(key) do
    sequence = SpecialKeys.to_escape_sequence(manager.modifier_state, key)
    process_keyboard(manager, sequence)
  end

  @doc """
  Processes a mouse event.
  """
  @spec process_mouse(t(), mouse_event()) :: t()
  def process_mouse(%__MODULE__{} = manager, {event_type, button, x, y}) do
    if manager.mouse_enabled do
      mouse_sequence = encode_mouse_event(event_type, button, x, y)

      %{
        manager
        | buffer: InputBuffer.append(manager.buffer, mouse_sequence),
          mouse_buttons: update_mouse_buttons(manager.mouse_buttons, event_type, button),
          mouse_position: {x, y}
      }
    else
      manager
    end
  end

  @doc """
  Enables or disables mouse event handling.
  """
  @spec set_mouse_enabled(t(), boolean()) :: t()
  def set_mouse_enabled(%__MODULE__{} = manager, enabled) when is_boolean(enabled) do
    %{manager | mouse_enabled: enabled}
  end

  @doc """
  Sets the input mode.
  """
  @spec set_mode(t(), input_mode()) :: t()
  def set_mode(%__MODULE__{} = manager, mode) when is_atom(mode) do
    %{manager | mode: mode}
  end

  @doc """
  Gets the current input mode.
  """
  @spec get_mode(t()) :: input_mode()
  def get_mode(%__MODULE__{} = manager) do
    manager.mode
  end

  @doc """
  Adds the current buffer contents to the input history.
  Resets the history navigation index and clears the buffer.
  """
  @spec add_to_history(t()) :: t()
  def add_to_history(%__MODULE__{buffer: buffer, input_history: history} = manager) do
    if buffer != "" do
      %{
        manager
        | input_history: [buffer | history],
          history_index: nil,
          buffer: InputBuffer.new()
      }
    else
      manager
    end
  end

  @doc """
  Gets the current buffer contents.
  """
  @spec get_buffer_contents(t()) :: String.t()
  def get_buffer_contents(%__MODULE__{buffer: buffer}) do
    InputBuffer.get_contents(buffer)
  end

  # Private functions

  defp handle_escape_sequence(%__MODULE__{} = manager, input) do
    case input do
      # End of escape sequence
      <<c>> when c >= ?@ and c <= ?~ ->
        %{
          manager
          | buffer: InputBuffer.append(manager.buffer, "\e" <> input),
            processing_escape: false
        }

      # More escape sequence data
      _ ->
        %{manager | buffer: InputBuffer.append(manager.buffer, input)}
    end
  end

  defp process_normal_input(%__MODULE__{} = manager, input) do
    case input do
      "\r" ->
        manager
        |> add_to_history()

      "\b" ->
        %{manager | buffer: InputBuffer.backspace(manager.buffer)}

      "\t" ->
        handle_tab(manager)

      _ ->
        %{manager | buffer: InputBuffer.append(manager.buffer, input)}
    end
  end

  defp handle_tab(%__MODULE__{} = manager) do
    if manager.completion_callback do
      current_input = get_buffer_contents(manager)
      completions = manager.completion_callback.(current_input)

      if completions != [] do
        %{
          manager
          | completion_options: completions,
            completion_index: 0,
            buffer: InputBuffer.set_contents(manager.buffer, hd(completions))
        }
      else
        manager
      end
    else
      # Basic tab completion: insert spaces
      tab_width = 4
      spaces = String.duplicate(" ", tab_width)
      %{manager | buffer: InputBuffer.append(manager.buffer, spaces)}
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

  defp encode_mouse_event(event_type, button, x, y) do
    base_code =
      case {event_type, button} do
        {:press, 0} -> 0
        {:press, 1} -> 1
        {:press, 2} -> 2
        {:release, _} -> 3
        {:scroll, 4} -> 64
        {:scroll, 5} -> 65
        _ -> 35
      end

    final_x = x + 1
    final_y = y + 1

    final_char =
      case event_type do
        :press -> "M"
        :release -> "m"
        :scroll -> "M"
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
