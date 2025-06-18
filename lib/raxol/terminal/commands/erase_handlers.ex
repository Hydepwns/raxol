defmodule Raxol.Terminal.Commands.EraseHandlers do
  @moduledoc '''
  Handles erase related CSI commands.

  This module contains handlers for erase operations like ED (Erase in Display)
  and EL (Erase in Line). Each function takes the current emulator state and
  parsed parameters, returning the updated emulator state.
  '''

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Eraser
  require Raxol.Core.Runtime.Log

  @doc '''
  Helper function to get active buffer, cursor position, and default style.
  Returns a tuple of {active_buffer, cursor_pos, default_style}.
  '''
  @spec get_buffer_state(Emulator.t()) ::
          {ScreenBuffer.t(), {integer(), integer()},
           Raxol.Terminal.ANSI.TextFormatting.text_style()}
  def get_buffer_state(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)

    cursor_pos =
      if is_map(emulator.cursor) and Map.has_key?(emulator.cursor, :position),
        do: emulator.cursor.position,
        else: {0, 0}

    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()
    {active_buffer, cursor_pos, blank_style}
  end

  @doc '''
  Helper function to handle erase operations.
  Takes the emulator, erase type, and erase parameters.
  '''
  @spec handle_erase(
          Emulator.t(),
          :screen | :line,
          integer(),
          {integer(), integer()}
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_erase(emulator, type, erase_param, {row, col}) do
    {active_buffer, _, default_style} = get_buffer_state(emulator)

    new_buffer =
      apply_erase_operation(
        active_buffer,
        type,
        erase_param,
        row,
        col,
        default_style
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  defp apply_erase_operation(
         active_buffer,
         type,
         erase_param,
         row,
         col,
         default_style
       ) do
    case {type, erase_param} do
      {:screen, 0} ->
        Eraser.clear_screen_from(active_buffer, row, col, default_style)

      {:screen, 1} ->
        Eraser.clear_screen_to(active_buffer, row, col, default_style)

      {:screen, 2} ->
        Eraser.clear_screen(active_buffer, default_style)

      {:screen, 3} ->
        clear_scrollback(active_buffer, default_style)

      {:line, 0} ->
        Eraser.clear_line_from(active_buffer, row, col, default_style)

      {:line, 1} ->
        Eraser.clear_line_to(active_buffer, row, col, default_style)

      {:line, 2} ->
        Eraser.clear_line(active_buffer, row, default_style)

      _ ->
        active_buffer
    end
  end

  @doc 'Handles Erase in Display (ED - \'J\")"
  @spec handle_j(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_j(emulator, params) do
    mode = get_valid_non_neg_param(params, 0, 0)
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    new_buffer =
      Raxol.Terminal.Buffer.Operations.erase_in_display(
        active_buffer,
        {x, y},
        mode
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc 'Handles Erase in Line (EL - \'K\")"
  @spec handle_k(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_k(emulator, params) do
    mode = get_valid_non_neg_param(params, 0, 0)
    active_buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    new_buffer =
      Raxol.Terminal.Buffer.Operations.erase_in_line(
        active_buffer,
        {x, y},
        mode
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  # Helper function to clear scrollback buffer
  @spec clear_scrollback(ScreenBuffer.t(), Cell.style()) :: ScreenBuffer.t()
  defp clear_scrollback(buffer, _default_style) do
    # Get current viewport dimensions and content
    current_width = ScreenBuffer.get_width(buffer)
    current_height = ScreenBuffer.get_height(buffer)

    current_cells =
      Enum.map(0..(current_height - 1), fn y ->
        ScreenBuffer.get_line(buffer, y) ||
          List.duplicate(Cell.new(), current_width)
      end)

    # Create a new buffer struct with the viewport content and empty scrollback
    %ScreenBuffer{
      cells: current_cells,
      width: current_width,
      height: current_height,
      # Effectively clears scrollback
      scrollback: [],
      # Preserve limit
      scrollback_limit: buffer.scrollback_limit,
      # Selections are usually cleared on such operations
      selection: nil,
      # Scroll region is also typically reset
      scroll_region: nil
    }
  end

  # --- Parameter Validation Helpers ---

  # Gets a parameter value with validation.
  # Returns the parameter value if valid, or the default value if invalid.
  @doc false
  defp get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid parameter value at index #{index}, using default #{default}",
          %{}
        )

        default
    end
  end

  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          integer()
        ) :: integer()
  defp get_valid_non_neg_param(params, index, default) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= 0 ->
        value

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid parameter value at index #{index}, using default #{default}",
          %{}
        )

        default
    end
  end
end
