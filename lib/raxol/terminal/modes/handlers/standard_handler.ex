defmodule Raxol.Terminal.Modes.Handlers.StandardHandler do
  @moduledoc """
  Handles standard mode operations and their side effects.
  Manages standard terminal modes like insert mode and line feed mode.
  """

  require Raxol.Core.Runtime.Log
  require Logger

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Modes.Types.ModeTypes

  @doc """
  Handles a standard mode change and applies its effects to the emulator.
  """
  @spec handle_mode_change(atom(), ModeTypes.mode_value(), Emulator.t()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def handle_mode_change(mode_name, value, emulator) do
    case find_mode_definition(mode_name) do
      %{category: :standard} = mode_def ->
        apply_mode_effects(mode_def, value, emulator)

      _ ->
        {:error, :invalid_mode}
    end
  end

  @doc """
  Handles a standard mode change (alias for handle_mode_change/3 for compatibility).
  """
  @spec handle_mode(Emulator.t(), atom(), ModeTypes.mode_value()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def handle_mode(emulator, mode_name, value) do
    handle_mode_change(mode_name, value, emulator)
  end

  # Private Functions

  defp find_mode_definition(mode_name) do
    # Search standard modes first to handle duplicates correctly
    standard_modes = ModeTypes.get_modes_by_category(:standard)

    # Search in order of preference for standard handler
    standard_modes
    |> Enum.find(&(&1.name == mode_name))
  end

  defp apply_mode_effects(mode_def, value, emulator) do
    case mode_def.name do
      :irm ->
        handle_insert_mode(value, emulator)

      :lnm ->
        handle_line_feed_mode(value, emulator)

      :deccolm_132 ->
        handle_column_width_mode_wide(value, emulator)

      :deccolm_80 ->
        handle_column_width_mode_normal(value, emulator)

      _ ->
        {:error, :unsupported_mode}
    end
  end

  defp handle_insert_mode(true, emulator) do
    require Logger
    Logger.debug("StandardHandler.handle_insert_mode/2 called with value: true")
    # Insert Mode (IRM)
    # When enabled, new text is inserted at the cursor position
    {:ok,
     %{emulator | mode_manager: %{emulator.mode_manager | insert_mode: true}}}
  end

  defp handle_insert_mode(false, emulator) do
    require Logger

    Logger.debug(
      "StandardHandler.handle_insert_mode/2 called with value: false"
    )

    # Replace Mode (default)
    # When disabled, new text overwrites existing text
    {:ok,
     %{emulator | mode_manager: %{emulator.mode_manager | insert_mode: false}}}
  end

  defp handle_line_feed_mode(true, emulator) do
    # Line Feed Mode (LNM)
    # When enabled, line feed also performs carriage return
    {:ok,
     %{emulator | mode_manager: %{emulator.mode_manager | line_feed_mode: true}}}
  end

  defp handle_line_feed_mode(false, emulator) do
    # New Line Mode (default)
    # When disabled, line feed only moves down one line
    {:ok,
     %{
       emulator
       | mode_manager: %{emulator.mode_manager | line_feed_mode: false}
     }}
  end

  defp handle_column_width_mode_wide(value, emulator) do
    handle_column_width_mode(value, emulator, :wide)
  end

  defp handle_column_width_mode_normal(value, emulator) do
    handle_column_width_mode(value, emulator, :normal)
  end

  defp handle_column_width_mode(value, emulator, width_mode) do
    target_width = calculate_target_width(width_mode, value)
    new_column_mode = calculate_column_width_mode(width_mode, value)

    emulator = resize_emulator_buffers(emulator, target_width)
    emulator = update_column_width_mode(emulator, new_column_mode)
    emulator = reset_cursor_position(emulator)

    {:ok, emulator}
  end

  defp calculate_target_width(:wide, true), do: 132
  defp calculate_target_width(_, _), do: 80

  defp calculate_column_width_mode(:wide, true), do: :wide
  defp calculate_column_width_mode(_, _), do: :normal

  defp resize_emulator_buffers(emulator, target_width) do
    main_buffer = resize_buffer(emulator.main_screen_buffer, target_width)

    alt_buffer =
      if emulator.alternate_screen_buffer do
        resize_buffer(emulator.alternate_screen_buffer, target_width)
      else
        nil
      end

    %{
      emulator
      | main_screen_buffer: main_buffer,
        alternate_screen_buffer: alt_buffer
    }
  end

  defp resize_buffer(buffer, new_width) do
    # When changing column width, the screen should be cleared (VT100 behavior)
    # Create a new empty buffer with the new width
    %{
      buffer
      | width: new_width,
        cells: create_empty_cells(buffer.height, new_width),
        # Reset cursor to top-left
        cursor_position: {0, 0},
        # Reset scroll position
        scroll_position: 0
    }
  end

  defp create_empty_cells(height, width) do
    for _row <- 1..height do
      for _col <- 1..width do
        %Raxol.Terminal.Cell{
          char: " ",
          style: %Raxol.Terminal.ANSI.TextFormatting{},
          dirty: false,
          wide_placeholder: false,
          sixel: false
        }
      end
    end
  end

  defp update_column_width_mode(emulator, new_mode) do
    %{
      emulator
      | mode_manager: %{emulator.mode_manager | column_width_mode: new_mode}
    }
  end

  defp reset_cursor_position(emulator) do
    # Reset cursor to home position (0, 0) when changing column width
    # This follows VT100 behavior
    Raxol.Terminal.Operations.CursorOperations.set_cursor_position(
      emulator,
      0,
      0
    )
  end
end
