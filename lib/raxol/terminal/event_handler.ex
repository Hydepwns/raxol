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
  @spec handle_mouse_event(Emulator.t(), map()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
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
  @spec handle_keyboard_event(Emulator.t(), map()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
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
  @spec handle_focus_event(Emulator.t(), atom()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
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
    # Always handle selection for left button regardless of mouse reporting mode
    emulator =
      if button == :left do
        handle_mouse_selection_start(emulator, x, y)
      else
        emulator
      end

    case Emulator.get_mode_manager(emulator).mouse_report_mode do
      :none ->
        {:ok, emulator}

      :x10 ->
        process_mouse_button_event(emulator, :press, button, x, y)

      :cell_motion ->
        process_mouse_any_event(emulator, :press, button, x, y)

      :sgr ->
        process_mouse_any_event(emulator, :press, button, x, y)

      _ ->
        {:ok, emulator}
    end
  end

  defp handle_mouse_release(emulator, button, x, y) do
    # Handle selection end for left button
    emulator =
      if button == :left do
        handle_mouse_selection_end(emulator)
      else
        emulator
      end

    case Emulator.get_mode_manager(emulator).mouse_report_mode do
      :none ->
        {:ok, emulator}

      :x10 ->
        # X10 mode only reports press events, not releases
        {:ok, emulator}

      :cell_motion ->
        process_mouse_any_event(emulator, :release, button, x, y)

      :sgr ->
        process_mouse_any_event(emulator, :release, button, x, y)

      _ ->
        {:ok, emulator}
    end
  end

  defp handle_mouse_move(emulator, x, y) do
    # Handle selection drag if active
    emulator =
      if emulator.selection_manager && emulator.selection_manager.active do
        handle_mouse_selection_drag(emulator, x, y)
      else
        emulator
      end

    case Emulator.get_mode_manager(emulator).mouse_report_mode do
      :none ->
        {:ok, emulator}

      :x10 ->
        # X10 mode doesn't report move events
        {:ok, emulator}

      :cell_motion ->
        process_mouse_move_event(emulator, x, y)

      :sgr ->
        process_mouse_move_event(emulator, x, y)

      _ ->
        {:ok, emulator}
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
    # Convert pixel coordinates to cell coordinates
    # For now, assume direct mapping - this could be enhanced based on font metrics
    {x, y}
  end

  defp generate_mouse_command(type, button, x, y) do
    # Generate standard mouse command sequence
    # Format: ESC [ M <button> <x+32> <y+32>
    button_code = encode_mouse_button(button, type)
    <<27, "[M", button_code, x + 32, y + 32>>
  end

  defp generate_mouse_any_command(type, button, x, y) do
    # For "any event" mode, use SGR format which is more reliable
    # Format: ESC [ < <button> ; <x> ; <y> <M or m>
    button_code = encode_sgr_button(button, type)
    suffix = if type == :press, do: "M", else: "m"
    "\e[<#{button_code};#{x};#{y}#{suffix}"
  end

  defp generate_mouse_move_command(x, y) do
    # Mouse move events typically use button code 32 (motion)
    <<27, "[M", 32, x + 32, y + 32>>
  end

  # Mouse button encoding for standard format
  defp encode_mouse_button(button, type) do
    base_code =
      case button do
        :left -> 0
        :middle -> 1
        :right -> 2
        _ -> 0
      end

    # Add press/release flag (release = base + 3)
    case type do
      :press -> base_code
      # Standard release code
      :release -> 3
      _ -> base_code
    end
  end

  # Mouse button encoding for SGR format
  defp encode_sgr_button(button, _type) do
    case button do
      :left -> 0
      :middle -> 1
      :right -> 2
      _ -> 0
    end
  end

  defp generate_normal_key_command(_key, _modifiers) do
    ""
  end

  # Mouse selection handling functions

  defp handle_mouse_selection_start(emulator, x, y) do
    alias Raxol.Terminal.Selection.Manager

    # Initialize selection manager if not present
    selection_manager = emulator.selection_manager || Manager.new()

    # Convert screen coordinates to terminal coordinates
    {term_x, term_y} = convert_to_terminal_coordinates(emulator, x, y)

    # Start new selection
    updated_selection_manager =
      Manager.start_selection(selection_manager, {term_x, term_y})

    %{emulator | selection_manager: updated_selection_manager}
  end

  defp handle_mouse_selection_drag(emulator, x, y) do
    alias Raxol.Terminal.Selection.Manager

    if emulator.selection_manager && emulator.selection_manager.active do
      # Convert screen coordinates to terminal coordinates
      {term_x, term_y} = convert_to_terminal_coordinates(emulator, x, y)

      # Update selection end position
      updated_selection_manager =
        Manager.update_selection(emulator.selection_manager, {term_x, term_y})

      %{emulator | selection_manager: updated_selection_manager}
    else
      emulator
    end
  end

  defp handle_mouse_selection_end(emulator) do
    # Selection remains active until explicitly cleared
    # This allows for copy operations after selection is made
    emulator
  end

  defp generate_application_key_command(_key, _modifiers) do
    ""
  end
end
