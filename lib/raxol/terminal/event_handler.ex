defmodule Raxol.Terminal.EventHandler do
  @moduledoc """
  Handles various terminal events including mouse, keyboard, and focus events.
  This module is responsible for processing and responding to user interactions.
  """

  alias Raxol.Terminal.Emulator
  require Raxol.Core.Runtime.Log

  @doc """
  Processes a mouse event.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec handle_mouse_event(Emulator.t(), map()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def handle_mouse_event(emulator, %{type: :mouse_press} = event) do
    handle_mouse_press(emulator, event.button, event.x, event.y)
  end

  def handle_mouse_event(emulator, %{type: :mouse_release} = event) do
    handle_mouse_release(emulator, event.button, event.x, event.y)
  end

  def handle_mouse_event(emulator, %{type: :mouse_move} = event) do
    handle_mouse_move(emulator, event.x, event.y)
  end

  def handle_mouse_event(_emulator, invalid_event) do
    {:error, "Invalid mouse event: #{inspect(invalid_event)}"}
  end

  @doc """
  Processes a keyboard event.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec handle_keyboard_event(Emulator.t(), map()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def handle_keyboard_event(emulator, %{type: :key_press} = event) do
    handle_key_press(emulator, event.key, event.modifiers)
  end

  def handle_keyboard_event(emulator, %{type: :key_release} = event) do
    handle_key_release(emulator, event.key, event.modifiers)
  end

  def handle_keyboard_event(_emulator, invalid_event) do
    {:error, "Invalid keyboard event: #{inspect(invalid_event)}"}
  end

  @doc """
  Processes a focus event.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec handle_focus_event(Emulator.t(), atom()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def handle_focus_event(emulator, :focus_gain) do
    handle_focus_gain(emulator)
  end

  def handle_focus_event(emulator, :focus_loss) do
    handle_focus_loss(emulator)
  end

  def handle_focus_event(_emulator, invalid_event) do
    {:error, "Invalid focus event: #{inspect(invalid_event)}"}
  end

  # Private Functions

  defp handle_mouse_press(emulator, button, x, y) do
    case Emulator.get_mode_manager(emulator).mouse_mode do
      :normal ->
        {:ok, emulator}

      :button ->
        process_mouse_button_event(emulator, :press, button, x, y)

      :any ->
        process_mouse_any_event(emulator, :press, button, x, y)
    end
  end

  defp handle_mouse_release(emulator, button, x, y) do
    case Emulator.get_mode_manager(emulator).mouse_mode do
      :normal ->
        {:ok, emulator}

      :button ->
        process_mouse_button_event(emulator, :release, button, x, y)

      :any ->
        process_mouse_any_event(emulator, :release, button, x, y)
    end
  end

  defp handle_mouse_move(emulator, x, y) do
    case Emulator.get_mode_manager(emulator).mouse_mode do
      :normal ->
        {:ok, emulator}

      :button ->
        process_mouse_move_event(emulator, x, y)

      :any ->
        process_mouse_move_event(emulator, x, y)
    end
  end

  defp handle_key_press(emulator, key, modifiers) do
    case Emulator.get_mode_manager(emulator).keyboard_mode do
      :normal ->
        process_normal_key_press(emulator, key, modifiers)

      :application ->
        process_application_key_press(emulator, key, modifiers)
    end
  end

  defp handle_key_release(emulator, key, modifiers) do
    case Emulator.get_mode_manager(emulator).keyboard_mode do
      :normal ->
        process_normal_key_release(emulator, key, modifiers)

      :application ->
        process_application_key_release(emulator, key, modifiers)
    end
  end

  defp handle_focus_gain(emulator) do
    # Restore cursor visibility and other focus-related states
    emulator = Emulator.set_cursor_visibility(emulator, true)
    {:ok, emulator}
  end

  defp handle_focus_loss(emulator) do
    # Save cursor visibility and other focus-related states
    emulator = Emulator.set_cursor_visibility(emulator, false)
    {:ok, emulator}
  end

  # Mouse Event Processing

  defp process_mouse_button_event(emulator, type, button, x, y) do
    # Convert mouse coordinates to terminal coordinates
    {term_x, term_y} = convert_to_terminal_coordinates(emulator, x, y)

    # Generate appropriate command based on event type
    command = generate_mouse_command(type, button, term_x, term_y)

    # Process the command
    case Emulator.process_input(emulator, command) do
      {updated_emulator, _} -> {:ok, updated_emulator}
      error -> error
    end
  end

  defp process_mouse_any_event(emulator, type, button, x, y) do
    # Similar to button events but with different command generation
    {term_x, term_y} = convert_to_terminal_coordinates(emulator, x, y)
    command = generate_mouse_any_command(type, button, term_x, term_y)

    case Emulator.process_input(emulator, command) do
      {updated_emulator, _} -> {:ok, updated_emulator}
      error -> error
    end
  end

  defp process_mouse_move_event(emulator, x, y) do
    {term_x, term_y} = convert_to_terminal_coordinates(emulator, x, y)
    command = generate_mouse_move_command(term_x, term_y)

    case Emulator.process_input(emulator, command) do
      {updated_emulator, _} -> {:ok, updated_emulator}
      error -> error
    end
  end

  # Keyboard Event Processing

  defp process_normal_key_press(emulator, key, modifiers) do
    command = generate_normal_key_command(key, modifiers)

    case Emulator.process_input(emulator, command) do
      {updated_emulator, _} -> {:ok, updated_emulator}
      error -> error
    end
  end

  defp process_application_key_press(emulator, key, modifiers) do
    command = generate_application_key_command(key, modifiers)

    case Emulator.process_input(emulator, command) do
      {updated_emulator, _} -> {:ok, updated_emulator}
      error -> error
    end
  end

  defp process_normal_key_release(emulator, _key, _modifiers) do
    {:ok, emulator}
  end

  defp process_application_key_release(emulator, _key, _modifiers) do
    {:ok, emulator}
  end

  # Helper Functions

  defp convert_to_terminal_coordinates(_emulator, x, y) do
    {x, y}
  end

  defp generate_mouse_command(_type, _button, _x, _y) do
    ""
  end

  defp generate_mouse_any_command(_type, _button, _x, _y) do
    ""
  end

  defp generate_mouse_move_command(_x, _y) do
    ""
  end

  defp generate_normal_key_command(_key, _modifiers) do
    ""
  end

  defp generate_application_key_command(_key, _modifiers) do
    ""
  end
end
