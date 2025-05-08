defmodule Raxol.Terminal.Buffer.Eraser do
  @moduledoc """
  Handles erasing parts of the Raxol.Terminal.ScreenBuffer.
  Includes functions for erasing lines, screen regions, and characters.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Writer
  alias Raxol.Terminal.ANSI.TextFormatting
  require Logger

  @doc """
  Clears a rectangular region of the buffer by replacing cells with blank cells
  using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_region(
          ScreenBuffer.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def clear_region(
        %ScreenBuffer{} = buffer,
        top,
        left,
        bottom,
        right,
        default_style
      ) do
    # Clamp coordinates to buffer dimensions
    clamped_top = max(0, min(top, buffer.height - 1))
    clamped_left = max(0, min(left, buffer.width - 1))
    clamped_bottom = max(0, min(bottom, buffer.height - 1))
    clamped_right = max(0, min(right, buffer.width - 1))

    Logger.debug(
      "[Eraser.clear_region] Called with: top=#{top}, left=#{left}, bottom=#{bottom}, right=#{right}"
    )

    Logger.debug(
      "[Eraser.clear_region] Clamped to: top=#{clamped_top}, left=#{clamped_left}, bottom=#{clamped_bottom}, right=#{clamped_right}"
    )

    Logger.debug(
      "[Eraser.clear_region] Buffer dimensions: width=#{buffer.width}, height=#{buffer.height}"
    )

    if clamped_top > clamped_bottom or clamped_left > clamped_right do
      Logger.debug(
        "[Eraser.clear_region] Invalid region (clamped_top > clamped_bottom or clamped_left > clamped_right), no-op."
      )

      # No-op if region is invalid
      buffer
    else
      # REMOVED condition: Log the exact clamped values for EVERY call that reaches here
      Logger.debug(
        "[Eraser.clear_region PARAMS] top_arg: #{top}, left_arg: #{left}, bottom_arg: #{bottom}, right_arg: #{right} --- clamped_top: #{clamped_top}, clamped_left: #{clamped_left}, clamped_bottom: #{clamped_bottom}, clamped_right: #{clamped_right}"
      )

      blank_cell = %Cell{char: " ", style: default_style, dirty: true}
      region_width = clamped_right - clamped_left + 1
      blank_row_segment = List.duplicate(blank_cell, region_width)

      new_cells =
        buffer.cells
        |> Enum.with_index()
        |> Enum.map(fn {line, row_idx} ->
          condition_result =
            row_idx >= clamped_top and row_idx <= clamped_bottom

          # ADDED: Log row_idx and condition_result if we are in the call for LINE 2
          # Check if this is the call originating from clear_line(2)
          if top == 2 and bottom == 2 and left == 0 do
            Logger.debug(
              "[Eraser.clear_region CALL FOR LINE 2] row_idx: #{row_idx}, condition_eval: (top=#{clamped_top}, bot=#{clamped_bottom}), condition_result: #{condition_result}"
            )
          end

          if condition_result do
            # This row is in the vertical range, modify the horizontal segment
            Logger.debug("[Eraser.clear_region] Processing row_idx: #{row_idx}")

            # Log the captured values of clamped_left and clamped_right for this iteration
            Logger.debug(
              "[Eraser.clear_region] Inside map for row #{row_idx}: effective_left=#{clamped_left}, effective_right=#{clamped_right}"
            )

            prefix_cells = Enum.take(line, clamped_left)

            # The segment to be replaced is from clamped_left to clamped_right inclusive
            # The suffix starts after clamped_right
            suffix_cells = Enum.drop(line, clamped_right + 1)

            # Detailed logging for chars
            original_line_chars_map = Enum.map(line, & &1.char)
            prefix_chars_map = Enum.map(prefix_cells, & &1.char)
            suffix_chars_map = Enum.map(suffix_cells, & &1.char)
            blank_segment_chars_map = Enum.map(blank_row_segment, & &1.char)

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - Original line chars: #{inspect(original_line_chars_map)}"
            )

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - Splitting at left: #{clamped_left}, right_plus_1_for_drop: #{clamped_right + 1}"
            )

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - Prefix chars: #{inspect(prefix_chars_map)} (count: #{length(prefix_cells)})"
            )

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - Suffix chars: #{inspect(suffix_chars_map)} (count: #{length(suffix_cells)})"
            )

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - Blank segment to insert: #{inspect(blank_segment_chars_map)} (count: #{length(blank_row_segment)})"
            )

            new_line_cells = prefix_cells ++ blank_row_segment ++ suffix_cells
            new_line_chars_map = Enum.map(new_line_cells, & &1.char)

            Logger.debug(
              "[Eraser.clear_region] row_idx: #{row_idx} - New line chars: #{inspect(new_line_chars_map)}"
            )

            new_line_cells
          else
            # Return unchanged line
            line
          end
        end)

      %{buffer | cells: new_cells}
    end
  end

  @doc """
  Clears from the given position to the end of the line using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_line_from(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def clear_line_from(%ScreenBuffer{} = buffer, row, col, default_style) do
    # Ensure row is valid
    if row >= 0 and row < buffer.height do
      clear_region(buffer, row, col, row, buffer.width - 1, default_style)
    else
      buffer
    end
  end

  @doc """
  Clears from the beginning of the line to the given position using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_line_to(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def clear_line_to(%ScreenBuffer{} = buffer, row, col, default_style) do
    # Ensure row is valid
    if row >= 0 and row < buffer.height do
      clear_region(buffer, row, 0, row, col, default_style)
    else
      buffer
    end
  end

  @doc """
  Clears the entire line using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_line(ScreenBuffer.t(), integer(), TextFormatting.text_style()) ::
          ScreenBuffer.t()
  def clear_line(%ScreenBuffer{} = buffer, row, default_style) do
    Logger.debug(
      "[Eraser.clear_line] CALLED with row: #{row}, buffer_height: #{buffer.height}"
    )

    # Ensure row is valid
    if row >= 0 and row < buffer.height do
      Logger.debug(
        "[Eraser.clear_line] Condition TRUE, calling clear_region for row: #{row}"
      )

      clear_region(buffer, row, 0, row, buffer.width - 1, default_style)
    else
      Logger.debug(
        "[Eraser.clear_line] Condition FALSE for row: #{row}, returning original buffer"
      )

      buffer
    end
  end

  @doc """
  Clears the screen from the given position down using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_screen_from(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def clear_screen_from(%ScreenBuffer{} = buffer, row, col, default_style) do
    # Clamp coordinates
    eff_row = max(0, min(row, buffer.height - 1))
    eff_col = max(0, min(col, buffer.width - 1))

    # Clear remainder of the current line
    buffer_step1 = clear_line_from(buffer, eff_row, eff_col, default_style)

    # Clear lines below, if any
    if eff_row < buffer.height - 1 do
      clear_region(
        buffer_step1,
        eff_row + 1,
        0,
        buffer.height - 1,
        buffer.width - 1,
        default_style
      )
    else
      buffer_step1
    end
  end

  @doc """
  Clears the screen from the beginning up to the given position using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_screen_to(
          ScreenBuffer.t(),
          integer(),
          integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def clear_screen_to(%ScreenBuffer{} = buffer, row, col, default_style) do
    # Clamp coordinates
    eff_row = max(0, min(row, buffer.height - 1))
    eff_col = max(0, min(col, buffer.width - 1))

    # Clear the current line up to the cursor
    buffer_step1 = clear_line_to(buffer, eff_row, eff_col, default_style)

    Logger.debug(
      "[clear_screen_to] After clear_line_to, buffer_step1.width: #{buffer_step1.width}, eff_row: #{eff_row}"
    )

    # Clear lines above, if any
    if eff_row > 0 do
      arg_top = 0
      arg_left = 0
      arg_bottom = eff_row - 1
      # Assuming width is correct here
      arg_right = buffer_step1.width - 1

      Logger.debug(
        "[clear_screen_to] PRE-CALL clear_region for lines ABOVE: top=#{arg_top}, left=#{arg_left}, bottom=#{arg_bottom}, right=#{arg_right}, eff_row_val=#{eff_row}, buf_width_val=#{buffer_step1.width}"
      )

      # Use explicit vars
      clear_region(
        buffer_step1,
        arg_top,
        arg_left,
        arg_bottom,
        arg_right,
        default_style
      )
    else
      buffer_step1
    end
  end

  @doc """
  Clears the entire screen (main buffer grid) using the provided default_style.
  Returns the updated buffer state.
  """
  @spec clear_screen(ScreenBuffer.t(), TextFormatting.text_style()) ::
          ScreenBuffer.t()
  def clear_screen(%ScreenBuffer{} = buffer, default_style) do
    clear_region(
      buffer,
      0,
      0,
      buffer.height - 1,
      buffer.width - 1,
      default_style
    )
  end

  @doc """
  Erases parts of the current line based on cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  Requires cursor state {col, row}.
  Delegates to specific clear_line_* functions.
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          :to_end | :to_beginning | :all,
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def erase_in_line(%ScreenBuffer{} = buffer, {col, row}, type, default_style) do
    case type do
      :to_end ->
        clear_line_from(buffer, row, col, default_style)

      :to_beginning ->
        clear_line_to(buffer, row, col, default_style)

      :all ->
        clear_line(buffer, row, default_style)

      _ ->
        # Should not happen if called correctly from CSI handler
        buffer
    end
  end

  @doc """
  Erases parts of the display based on cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  Requires cursor state {col, row}.
  Delegates to specific clear_screen_* functions.
  Does not handle type 3 (scrollback) - that should be handled by the Emulator.
  """
  @spec erase_in_display(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          :to_end | :to_beginning | :all,
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def erase_in_display(
        %ScreenBuffer{} = buffer,
        {col, row},
        type,
        default_style
      ) do
    case type do
      :to_end ->
        clear_screen_from(buffer, row, col, default_style)

      :to_beginning ->
        clear_screen_to(buffer, row, col, default_style)

      :all ->
        clear_screen(buffer, default_style)

      _ ->
        # Ignore other types (like :scrollback which is handled elsewhere)
        buffer
    end
  end
end
