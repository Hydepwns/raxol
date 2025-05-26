defmodule Raxol.Terminal.Commands.BufferHandlers do
  @moduledoc """
  Handles buffer manipulation related CSI commands.

  This module contains handlers for buffer operations like insert/delete lines,
  insert/delete characters, and erase operations. Each function takes the current
  emulator state and parsed parameters, returning the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Commands.{Scrolling, Editor}
  require Raxol.Core.Runtime.Log

  @doc """
  Helper function to get active buffer, cursor position, and default style.
  Returns a tuple of {active_buffer, cursor_pos, default_style}.
  """
  @spec get_buffer_state(Emulator.t()) ::
          {ScreenBuffer.t(), {integer(), integer()},
           Raxol.Terminal.ANSI.TextFormatting.text_style()}
  def get_buffer_state(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)
    cursor_pos = emulator.cursor
    # Use a blank style for new/empty cells
    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()
    {active_buffer, cursor_pos, blank_style}
  end

  @doc """
  Helper function to perform a buffer operation and update the emulator.
  Takes the emulator, a function that performs the buffer operation,
  and any additional arguments needed by the operation function.
  """
  @spec with_buffer_operation(
          Emulator.t(),
          (ScreenBuffer.t(), any() -> ScreenBuffer.t()),
          any()
        ) :: Emulator.t()
  def with_buffer_operation(emulator, operation_fn, operation_args) do
    active_buffer = Emulator.get_active_buffer(emulator)
    new_buffer = operation_fn.(active_buffer, operation_args)
    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Insert Line (IL - 'L')"
  @spec handle_L(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_L(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)

    {active_buffer, {_, current_row}, default_style} =
      get_buffer_state(emulator)

    new_buffer =
      Editor.insert_lines(active_buffer, current_row, count, default_style)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Delete Line (DL - 'M')"
  @spec handle_M(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_M(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)

    {active_buffer, {_, current_row}, default_style} =
      get_buffer_state(emulator)

    new_buffer =
      Editor.delete_lines(active_buffer, current_row, count, default_style)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Delete Character (DCH - 'P')"
  @spec handle_P(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_P(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)

    {active_buffer, {current_col, current_row}, default_style} =
      get_buffer_state(emulator)

    new_buffer =
      Editor.delete_chars(
        active_buffer,
        current_row,
        current_col,
        count,
        default_style
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Insert Character (ICH - '@')"
  @spec handle_at(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_at(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)

    {active_buffer, {current_col, current_row}, default_style} =
      get_buffer_state(emulator)

    new_buffer =
      Editor.insert_chars(
        active_buffer,
        current_row,
        current_col,
        count,
        default_style
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Erase Character (ECH - 'X')"
  @spec handle_X(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_X(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)

    {active_buffer, {current_col, current_row}, default_style} =
      get_buffer_state(emulator)

    new_buffer =
      Editor.erase_chars(
        active_buffer,
        current_row,
        current_col,
        count,
        default_style
      )

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Scroll Up (SU - 'S')"
  @spec handle_S(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_S(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    scroll_region = emulator.scroll_region
    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()

    new_buffer =
      Scrolling.scroll_up(active_buffer, count, scroll_region, blank_style)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc "Handles Scroll Down (SD - 'T')"
  @spec handle_T(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_T(emulator, params) do
    count = get_valid_non_neg_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    scroll_region = emulator.scroll_region
    blank_style = Raxol.Terminal.ANSI.TextFormatting.new()

    new_buffer =
      Scrolling.scroll_down(active_buffer, count, scroll_region, blank_style)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  # --- Parameter Validation Helpers ---

  @spec get_valid_param(
          list(integer() | nil),
          non_neg_integer(),
          integer(),
          integer(),
          integer()
        ) :: integer()
  defp get_valid_param(params, index, default, min, max) do
    param = Enum.at(params, index, default)
    case param do
      value when is_integer(value) and value >= min and value <= max ->
        value
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context("BufferHandlers: Invalid parameter value: #{inspect(param)}", %{})
        default
    end
  end

  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp get_valid_non_neg_param(params, index, default) do
    get_valid_param(params, index, default, 0, 9999)
  end
end
