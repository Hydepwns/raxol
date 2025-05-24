defmodule Raxol.Terminal.Emulator.Input do
  @moduledoc """
  Handles input processing for the terminal emulator.
  Provides functions for key event handling, command history, and input parsing.
  """

  require Logger

  alias Raxol.Terminal.{
    ScreenBuffer,
    Input,
    Emulator
  }

  @doc """
  Processes a key event.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec process_key_event(Emulator.t(), map()) ::
          {:ok, Emulator.t(), list()} | {:error, String.t()}
  def process_key_event(%Emulator{} = emulator, event) when is_map(event) do
    # Store the last key event
    emulator = %{emulator | last_key_event: event}

    # Process the event based on its type
    case event.type do
      :key ->
        process_key_press(emulator, event)

      :mouse ->
        process_mouse_event(emulator, event)

      _ ->
        {:error, "Unsupported event type: #{inspect(event.type)}"}
    end
  end

  def process_key_event(%Emulator{} = _emulator, invalid_event) do
    {:error, "Invalid event: #{inspect(invalid_event)}"}
  end

  @doc """
  Processes a key press event.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec process_key_press(Emulator.t(), map()) ::
          {:ok, Emulator.t(), list()} | {:error, String.t()}
  def process_key_press(%Emulator{} = emulator, event) do
    # Update command buffer if in command mode
    case update_command_buffer(emulator, event) do
      {:ok, updated_emulator} ->
        # Generate appropriate commands based on the key
        commands = generate_key_commands(updated_emulator, event)
        {:ok, updated_emulator, commands}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Processes a mouse event.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec process_mouse_event(Emulator.t(), map()) ::
          {:ok, Emulator.t(), list()} | {:error, String.t()}
  def process_mouse_event(%Emulator{} = emulator, event) do
    # Generate appropriate commands based on the mouse event
    commands = generate_mouse_commands(emulator, event)
    {:ok, emulator, commands}
  end

  @doc """
  Updates the command history with a new command.
  Returns {:ok, updated_emulator}.
  """
  @spec add_to_history(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def add_to_history(%Emulator{} = emulator, command) when is_binary(command) do
    # Add command to history, respecting the maximum history size
    history = [command | emulator.command_history]
    history = Enum.take(history, emulator.max_command_history)
    {:ok, %{emulator | command_history: history}}
  end

  def add_to_history(%Emulator{} = _emulator, invalid_command) do
    {:error, "Invalid command: #{inspect(invalid_command)}"}
  end

  @doc """
  Clears the command history.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_history(Emulator.t()) :: {:ok, Emulator.t()}
  def clear_history(%Emulator{} = emulator) do
    {:ok, %{emulator | command_history: []}}
  end

  @doc """
  Gets the command history.
  Returns the list of commands in history.
  """
  @spec get_history(Emulator.t()) :: list()
  def get_history(%Emulator{} = emulator) do
    emulator.command_history
  end

  @doc """
  Gets the current command buffer.
  Returns the current command buffer.
  """
  @spec get_command_buffer(Emulator.t()) :: String.t()
  def get_command_buffer(%Emulator{} = emulator) do
    emulator.current_command_buffer
  end

  @doc """
  Sets the command buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec set_command_buffer(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def set_command_buffer(%Emulator{} = emulator, buffer)
      when is_binary(buffer) do
    {:ok, %{emulator | current_command_buffer: buffer}}
  end

  def set_command_buffer(%Emulator{} = _emulator, invalid_buffer) do
    {:error, "Invalid command buffer: #{inspect(invalid_buffer)}"}
  end

  @doc """
  Clears the command buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_command_buffer(Emulator.t()) :: {:ok, Emulator.t()}
  def clear_command_buffer(%Emulator{} = emulator) do
    {:ok, %{emulator | current_command_buffer: ""}}
  end

  # Private helper functions

  defp update_command_buffer(%Emulator{} = emulator, %{key: key}) do
    case key do
      :enter ->
        # Add command to history and clear buffer
        {:ok, emulator} =
          add_to_history(emulator, emulator.current_command_buffer)

        clear_command_buffer(emulator)

      :backspace ->
        # Remove last character from buffer
        buffer = String.slice(emulator.current_command_buffer, 0..-2)
        set_command_buffer(emulator, buffer)

      char when is_binary(char) ->
        # Add character to buffer
        buffer = emulator.current_command_buffer <> char
        set_command_buffer(emulator, buffer)

      _ ->
        {:ok, emulator}
    end
  end

  defp generate_key_commands(%Emulator{} = _emulator, %{key: key}) do
    case key do
      :enter -> ["\r\n"]
      :backspace -> ["\b"]
      :tab -> ["\t"]
      :escape -> ["\e"]
      char when is_binary(char) -> [char]
      _ -> []
    end
  end

  defp generate_mouse_commands(%Emulator{} = _emulator, %{
         type: :mouse,
         button: button,
         x: x,
         y: y
       }) do
    # Generate appropriate mouse event sequence based on button and coordinates
    # This is a simplified version - actual implementation would be more complex
    case button do
      :left -> ["\e[M#{y + 32}#{x + 32}"]
      :right -> ["\e[M#{y + 32}#{x + 32}"]
      :middle -> ["\e[M#{y + 32}#{x + 32}"]
      _ -> []
    end
  end
end
