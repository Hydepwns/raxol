defmodule Raxol.Terminal.Input do
  @moduledoc """
  Terminal input handling module.
  
  This module handles the processing of keyboard and mouse input events for the terminal,
  including:
  - Keyboard event processing
  - Mouse event processing
  - Special key handling
  - Input mode management
  - Input buffering
  - Event filtering
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
    buffer: String.t(),
    mode: :normal | :insert | :visual | :command,
    modifiers: list(atom()),
    mouse_enabled: boolean(),
    bracketed_paste: boolean(),
    input_history: list(String.t()),
    history_index: non_neg_integer(),
    history_limit: non_neg_integer()
  }

  defstruct [
    :buffer,
    :mode,
    :modifiers,
    :mouse_enabled,
    :bracketed_paste,
    :input_history,
    :history_index,
    :history_limit
  ]

  @doc """
  Creates a new input handler.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input.mode
      :normal
      iex> input.buffer
      ""
  """
  def new do
    %__MODULE__{
      buffer: "",
      mode: :normal,
      modifiers: [],
      mouse_enabled: false,
      bracketed_paste: false,
      input_history: [],
      history_index: 0,
      history_limit: 100
    }
  end

  @doc """
  Processes a keyboard event.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "a")
      iex> input.buffer
      "a"
  """
  def process_keyboard(%__MODULE__{} = input, key) do
    cond do
      is_special_key?(key) ->
        process_special_key(input, key)
      
      input.bracketed_paste ->
        %{input | buffer: input.buffer <> key}
      
      true ->
        process_normal_key(input, key)
    end
  end

  @doc """
  Processes a mouse event.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.process_mouse(input, :left, :press, 10, 5)
      iex> input.buffer
      "\e[M 0;10;5"
  """
  def process_mouse(%__MODULE__{} = input, button, action, x, y) do
    if input.mouse_enabled do
      event = encode_mouse_event(button, action, x, y)
      %{input | buffer: input.buffer <> event}
    else
      input
    end
  end

  @doc """
  Sets the input mode.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.set_mode(input, :insert)
      iex> input.mode
      :insert
  """
  def set_mode(%__MODULE__{} = input, mode) do
    %{input | mode: mode}
  end

  @doc """
  Enables or disables mouse input.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.set_mouse_enabled(input, true)
      iex> input.mouse_enabled
      true
  """
  def set_mouse_enabled(%__MODULE__{} = input, enabled) do
    %{input | mouse_enabled: enabled}
  end

  @doc """
  Enables or disables bracketed paste mode.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.set_bracketed_paste(input, true)
      iex> input.bracketed_paste
      true
  """
  def set_bracketed_paste(%__MODULE__{} = input, enabled) do
    %{input | bracketed_paste: enabled}
  end

  @doc """
  Adds a modifier to the current input state.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.add_modifier(input, :ctrl)
      iex> input.modifiers
      [:ctrl]
  """
  def add_modifier(%__MODULE__{} = input, modifier) do
    %{input | modifiers: [modifier | input.modifiers]}
  end

  @doc """
  Removes a modifier from the current input state.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.add_modifier(input, :ctrl)
      iex> input = Input.remove_modifier(input, :ctrl)
      iex> input.modifiers
      []
  """
  def remove_modifier(%__MODULE__{} = input, modifier) do
    %{input | modifiers: List.delete(input.modifiers, modifier)}
  end

  @doc """
  Clears all modifiers from the current input state.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.add_modifier(input, :ctrl)
      iex> input = Input.add_modifier(input, :shift)
      iex> input = Input.clear_modifiers(input)
      iex> input.modifiers
      []
  """
  def clear_modifiers(%__MODULE__{} = input) do
    %{input | modifiers: []}
  end

  @doc """
  Adds input to the history.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.add_to_history(input, "command")
      iex> length(input.input_history)
      1
  """
  def add_to_history(%__MODULE__{} = input, command) do
    new_history = [command | input.input_history]
    |> Enum.take(input.history_limit)
    
    %{input |
      input_history: new_history,
      history_index: 0
    }
  end

  @doc """
  Retrieves a command from the history.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.add_to_history(input, "command1")
      iex> input = Input.add_to_history(input, "command2")
      iex> input = Input.get_from_history(input, 1)
      "command1"
  """
  def get_from_history(%__MODULE__{} = input, index) do
    case Enum.at(input.input_history, index) do
      nil -> ""
      command -> command
    end
  end

  @doc """
  Clears the input buffer.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "a")
      iex> input = Input.clear_buffer(input)
      iex> input.buffer
      ""
  """
  def clear_buffer(%__MODULE__{} = input) do
    %{input | buffer: ""}
  end

  @doc """
  Gets the current input buffer.
  
  ## Examples
  
      iex> input = Input.new()
      iex> input = Input.process_keyboard(input, "a")
      iex> Input.get_buffer(input)
      "a"
  """
  def get_buffer(%__MODULE__{} = input) do
    input.buffer
  end

  # Private functions

  defp is_special_key?(key) do
    String.starts_with?(key, "\e[") or
    String.starts_with?(key, "\eO") or
    key in ["\r", "\t", "\b", "\x7F"]
  end

  defp process_special_key(input, key) do
    case key do
      "\r" -> %{input | buffer: input.buffer <> "\n"}
      "\t" -> %{input | buffer: input.buffer <> "  "}
      "\b" -> backspace(input)
      "\x7F" -> backspace(input)
      key when String.starts_with?(key, "\e[") ->
        process_escape_sequence(input, key)
      key when String.starts_with?(key, "\eO") ->
        process_escape_sequence(input, key)
      _ -> input
    end
  end

  defp process_normal_key(input, key) do
    case input.mode do
      :normal -> process_normal_mode(input, key)
      :insert -> %{input | buffer: input.buffer <> key}
      :visual -> process_visual_mode(input, key)
      :command -> %{input | buffer: input.buffer <> key}
    end
  end

  defp process_normal_mode(input, key) do
    case key do
      "i" -> set_mode(input, :insert)
      "v" -> set_mode(input, :visual)
      ":" -> set_mode(input, :command)
      _ -> input
    end
  end

  defp process_visual_mode(input, key) do
    case key do
      "\e" -> set_mode(input, :normal)
      _ -> input
    end
  end

  defp process_escape_sequence(input, sequence) do
    case sequence do
      "\e[A" -> %{input | buffer: input.buffer <> "\e[A"} # Up arrow
      "\e[B" -> %{input | buffer: input.buffer <> "\e[B"} # Down arrow
      "\e[C" -> %{input | buffer: input.buffer <> "\e[C"} # Right arrow
      "\e[D" -> %{input | buffer: input.buffer <> "\e[D"} # Left arrow
      "\e[H" -> %{input | buffer: input.buffer <> "\e[H"} # Home
      "\e[F" -> %{input | buffer: input.buffer <> "\e[F"} # End
      "\e[3~" -> %{input | buffer: input.buffer <> "\e[3~"} # Delete
      "\e[5~" -> %{input | buffer: input.buffer <> "\e[5~"} # Page Up
      "\e[6~" -> %{input | buffer: input.buffer <> "\e[6~"} # Page Down
      "\e[Z" -> %{input | buffer: input.buffer <> "\e[Z"} # Shift+Tab
      _ -> input
    end
  end

  defp backspace(input) do
    case String.length(input.buffer) do
      0 -> input
      len -> %{input | buffer: String.slice(input.buffer, 0, len - 1)}
    end
  end

  defp encode_mouse_event(button, action, x, y) do
    button_code = case {button, action} do
      {:left, :press} -> 0
      {:left, :release} -> 3
      {:middle, :press} -> 1
      {:middle, :release} -> 4
      {:right, :press} -> 2
      {:right, :release} -> 5
      _ -> 0
    end
    
    "\e[M#{button_code};#{x};#{y}"
  end
end