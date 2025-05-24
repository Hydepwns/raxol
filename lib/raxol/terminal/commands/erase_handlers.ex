defmodule Raxol.Terminal.Commands.EraseHandlers do
  @moduledoc """
  Handles erase related CSI commands.

  This module contains handlers for erase operations like ED (Erase in Display)
  and EL (Erase in Line). Each function takes the current emulator state and
  parsed parameters, returning the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Eraser
  require Logger

  @doc """
  Helper function to get active buffer, cursor position, and default style.
  Returns a tuple of {active_buffer, cursor_pos, default_style}.
  """
  @spec get_buffer_state(Emulator.t()) ::
          {ScreenBuffer.t(), {integer(), integer()},
           Raxol.Terminal.ANSI.TextFormatting.text_style()}
  def get_buffer_state(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)
    cursor_pos = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()
    {active_buffer, cursor_pos, blank_style}
  end

  @doc """
  Helper function to handle erase operations.
  Takes the emulator, erase type, and erase parameters.
  """
  @spec handle_erase(
          Emulator.t(),
          :screen | :line,
          integer(),
          {integer(), integer()}
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_erase(emulator, type, erase_param, {row, col}) do
    {active_buffer, _, default_style} = get_buffer_state(emulator)

    new_buffer =
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

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Erase in Display (ED - 'J')"
  @spec handle_J(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_J(emulator, params) do
    erase_param = get_valid_param(params, 0, 0, 0, 3)
    {_, cursor_pos, _} = get_buffer_state(emulator)
    handle_erase(emulator, :screen, erase_param, cursor_pos)
  end

  @doc "Handles Erase in Line (EL - 'K')"
  @spec handle_K(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_K(emulator, params) do
    erase_param = get_valid_param(params, 0, 0, 0, 2)
    {_, cursor_pos, _} = get_buffer_state(emulator)
    handle_erase(emulator, :line, erase_param, cursor_pos)
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

  @doc """
  Gets a parameter value with validation.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_param(
          list(integer() | nil),
          non_neg_integer(),
          integer(),
          integer(),
          integer()
        ) :: integer()
  defp get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value

      _ ->
        Logger.warning(
          "Invalid parameter value at index #{index}, using default #{default}",
          []
        )

        default
    end
  end

  @doc """
  Gets a parameter value with validation for boolean values (0 or 1).
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_bool_param(list(integer() | nil), non_neg_integer(), 0..1) ::
          0..1
  defp get_valid_bool_param(params, index, default) do
    get_valid_param(params, index, default, 0, 1)
  end
end
