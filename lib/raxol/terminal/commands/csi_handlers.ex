defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handles the execution logic for specific CSI commands.

  Functions in this module are typically called by `Raxol.Terminal.Commands.Executor`
  after parameters have been parsed. Each function takes the current emulator
  state and the parsed parameters, returning the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Commands.{Scrolling, Editor}
  alias Raxol.Terminal.Buffer.LineEditor
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.Buffer.Writer
  alias Raxol.Terminal.ANSI.SGRHandler
  alias Raxol.Terminal.Buffer.State # Import State for get_scroll_region_boundaries
  alias Raxol.Terminal.Buffer.Operations # Import Operations for replace_region_content
  require Logger

  @doc "Handles Select Graphic Rendition (SGR - 'm')"
  @spec handle_m(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_m(emulator, params) do
    Logger.debug("[SGR Handler] Input Style: #{inspect(emulator.style)}, Params: #{inspect(params)}")
    # Process parameters statefully to handle multi-param codes (38, 48)
    new_style = SGRHandler.apply_sgr_params(params, emulator.style)
    Logger.debug("[SGR Handler] Output Style: #{inspect(new_style)}")
    # Update emulator state with the new style
    %{emulator | style: new_style}
  end

  @doc "Handles Cursor Position (CUP - 'H')"
  @spec handle_H(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_H(emulator, params) do
    # Params: [row, col], default to 1,1
    # FIX: Use 0-based indices for get_param
    row = Parser.get_param(params, 0, 1)
    col = Parser.get_param(params, 1, 1)
    # Convert to 0-based index for cursor manager
    new_cursor = CursorManager.move_to(emulator.cursor, col - 1, row - 1)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Set Top and Bottom Margins (DECSTBM - 'r')"
  @spec handle_r(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_r(emulator, params) do
    # Params: [top, bottom], default to 1, screen_height
    # Parameters are 1-based, get_param expects 0-based index
    top = Parser.get_param(params, 0, 1)
    # Get height from active buffer
    height = ScreenBuffer.get_height(Emulator.get_active_buffer(emulator))
    bottom = Parser.get_param(params, 1, height)

    # Validate: top < bottom and within screen bounds
    if top >= 1 and top < bottom and bottom <= height do
      # Store 0-based region
      %{emulator | scroll_region: {top - 1, bottom - 1}}
    else
      # Invalid or missing parameters reset to full screen
      %{emulator | scroll_region: nil}
    end
  end

  @doc """
  Handles Set Mode (SM - `h`) or Reset Mode (RM - `l`).

  Dispatches to `ModeManager` to handle both standard ANSI modes and
  DEC private modes (prefixed with `?`).
  """
  @spec handle_h_or_l(Emulator.t(), list(integer() | nil), String.t(), char()) :: Emulator.t()
  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    action = if final_byte == ?h, do: :set, else: :reset
    apply_mode_func = if action == :set, do: &ModeManager.set_mode/2, else: &ModeManager.reset_mode/2

    # Check for DEC Private Mode marker ('?')
    if intermediates_buffer == "?" do
      # DEC Private Mode (e.g., CSI ? Pn h/l)
      param = Parser.get_param(params, 0, nil)

      cond do
        is_nil(param) ->
          Logger.warning("Missing parameter for DEC private mode h/l.")
          emulator
        mode_atom = ModeManager.lookup_private(param) ->
          Logger.debug("[CSI] #{action} DEC Private Mode ##{param} (#{mode_atom})")
          apply_mode_func.(emulator, [mode_atom]) # Pass mode as a list
        true ->
          Logger.warning("Unknown DEC private mode code: #{param}")
          emulator
      end
    else
      # Standard ANSI Mode (e.g., CSI Pn h/l)
      mode_atoms = Enum.map(params, &ModeManager.lookup_standard/1)
                   |> Enum.reject(&is_nil/1)

      if Enum.empty?(mode_atoms) do
        Logger.warning("No valid standard mode codes found in params: #{inspect(params)}")
        emulator
      else
        Logger.debug("[CSI] #{action} Standard Modes: #{inspect(mode_atoms)}")
        apply_mode_func.(emulator, mode_atoms)
      end
    end
  end

  @doc "Handles Erase in Display (ED - 'J')"
  @spec handle_J(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_J(emulator, params) do
    erase_param = Parser.get_param(params, 0, 0)
    cursor_pos = emulator.cursor.position # {col, row}
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style # Get default style

    current_row = elem(cursor_pos, 1)
    current_col = elem(cursor_pos, 0)

    Logger.debug(
      "[CSIHandlers.handle_J] PRE-CALL Eraser: active_buffer.width=#{active_buffer.width}, active_buffer.height=#{active_buffer.height}, row=#{current_row}, col=#{current_col}, erase_param=#{erase_param}"
    )

    new_buffer =
      case erase_param do
        0 -> # Erase from cursor to end of screen
          Eraser.clear_screen_from(active_buffer, current_row, current_col, default_style)

        1 -> # Erase from beginning of screen to cursor
          Eraser.clear_screen_to(active_buffer, current_row, current_col, default_style)

        2 -> # Erase entire screen
          Eraser.clear_screen(active_buffer, default_style)

        3 -> # Erase scrollback
          # TODO: Implement scrollback clearing
          active_buffer

        _ ->
          active_buffer
      end

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Erase in Line (EL - 'K')"
  @spec handle_K(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_K(emulator, params) do
    erase_param = Parser.get_param(params, 0, 0)
    cursor_pos = Emulator.get_cursor_position(emulator)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style # Get default style

    new_buffer =
      case erase_param do
        0 -> # Erase from cursor to end of line
          Eraser.clear_line_from(active_buffer, elem(cursor_pos, 1), elem(cursor_pos, 0), default_style)

        1 -> # Erase from beginning of line to cursor
          Eraser.clear_line_to(active_buffer, elem(cursor_pos, 1), elem(cursor_pos, 0), default_style)

        2 -> # Erase entire line
          Eraser.clear_line(active_buffer, elem(cursor_pos, 1), default_style)

        _ ->
          active_buffer
      end

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Cursor Up (CUU - 'A')"
  @spec handle_A(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_A(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    new_cursor = CursorManager.move_up(emulator.cursor, count)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Down (CUD - 'B')"
  @spec handle_B(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_B(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    # Need terminal height to constrain movement
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    {current_col, current_row} = emulator.cursor.position
    new_row = min(current_row + count, height - 1) # Calculate new row, clamp to bounds
    new_cursor = CursorManager.move_to(emulator.cursor, current_col, new_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Forward (CUF - 'C')"
  @spec handle_C(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_C(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    # Need terminal width to constrain movement
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    {current_col, current_row} = emulator.cursor.position
    new_col = min(current_col + count, width - 1) # Calculate new col, clamp to bounds
    new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Backward (CUB - 'D')"
  @spec handle_D(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_D(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    # Calculate new col, clamp to bounds
    {current_col, current_row} = emulator.cursor.position
    new_col = max(current_col - count, 0)
    new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Next Line (CNL - 'E')"
  @spec handle_E(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_E(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    # Move down N lines to column 0
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    {_current_col, current_row} = emulator.cursor.position
    new_row = min(current_row + count, height - 1) # Calculate new row, clamp to bounds
    new_cursor = CursorManager.move_to(emulator.cursor, 0, new_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Previous Line (CPL - 'F')"
  @spec handle_F(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_F(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    # Move up N lines to column 0
    {_current_col, current_row} = emulator.cursor.position
    new_row = max(current_row - count, 0) # Calculate new row, clamp to bounds
    new_cursor = CursorManager.move_to(emulator.cursor, 0, new_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Cursor Horizontal Absolute (CHA - 'G')"
  @spec handle_G(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_G(emulator, params) do
    col = Parser.get_param(params, 0, 1)
    # Move to column N (1-based) on the current row
    active_buffer = Emulator.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    {_current_col, current_row} = emulator.cursor.position
    new_col = min(max(col - 1, 0), width - 1) # Calculate new col (0-based), clamp
    new_cursor = CursorManager.move_to(emulator.cursor, new_col, current_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Vertical Line Position Absolute (VPA - 'd')"
  @spec handle_d(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_d(emulator, params) do
    row = Parser.get_param(params, 0, 1)
    # Move to row N (1-based) on the current column
    active_buffer = Emulator.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    {current_col, _current_row} = emulator.cursor.position
    new_row = min(max(row - 1, 0), height - 1) # Calculate new row (0-based), clamp
    new_cursor = CursorManager.move_to(emulator.cursor, current_col, new_row)
    %{emulator | cursor: new_cursor}
  end

  @doc "Handles Insert Lines (IL - 'L')"
  @spec handle_L(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_L(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    cursor_row = elem(Emulator.get_cursor_position(emulator), 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style
    buffer_width = ScreenBuffer.get_width(active_buffer)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    # Get effective scroll region
    {scroll_top, scroll_bottom} =
      case emulator.scroll_region do
        nil -> {0, buffer_height - 1} # Full buffer if nil
        {top, bottom} -> {top, bottom}
      end

    # Only perform insertion if cursor is within the scroll region
    if cursor_row >= scroll_top and cursor_row <= scroll_bottom do
      # Calculate how many lines are available to shift down
      lines_in_region = scroll_bottom - scroll_top + 1

      # Get all lines before modification
      buffer_cells = active_buffer.cells

      # Split buffer into three parts: lines above scroll region, lines in scroll region, lines below scroll region
      lines_above_region = Enum.slice(buffer_cells, 0, scroll_top)
      lines_in_scroll_region = Enum.slice(buffer_cells, scroll_top, lines_in_region)
      lines_below_region = Enum.slice(buffer_cells, scroll_bottom + 1, buffer_height - scroll_bottom - 1)

      # Split the scroll region at cursor position
      cursor_offset_in_region = cursor_row - scroll_top
      {lines_above_cursor, lines_at_and_below_cursor} = Enum.split(lines_in_scroll_region, cursor_offset_in_region)

      # Create blank lines to insert
      blank_line = List.duplicate(%Cell{char: " ", style: default_style}, buffer_width)
      blank_lines = List.duplicate(blank_line, count)

      # Number of lines to keep from below cursor (may discard some if insertion would push past region bottom)
      lines_to_keep = max(0, lines_in_region - cursor_offset_in_region - count)
      kept_lines = Enum.take(lines_at_and_below_cursor, lines_to_keep)

      # Combine all parts
      new_region_content = lines_above_cursor ++ blank_lines ++ kept_lines

      # Make sure we don't exceed the scroll region height
      new_region_content = Enum.take(new_region_content, lines_in_region)

      # Create the new buffer cells
      new_buffer_cells = lines_above_region ++ new_region_content ++ lines_below_region

      # Update the buffer
      Emulator.update_active_buffer(emulator, %{active_buffer | cells: new_buffer_cells})
    else
      # Cursor is outside scroll region, do nothing
      emulator
    end
  end

  @doc "Handles Delete Lines (DL - 'M')"
  @spec handle_M(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_M(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    cursor_row = elem(Emulator.get_cursor_position(emulator), 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style
    buffer_width = ScreenBuffer.get_width(active_buffer)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    # Get effective scroll region
    {scroll_top, scroll_bottom} =
      case emulator.scroll_region do
        nil -> {0, buffer_height - 1} # Full buffer if nil
        {top, bottom} -> {top, bottom}
      end

    # Only perform deletion if cursor is within the scroll region
    if cursor_row >= scroll_top and cursor_row <= scroll_bottom do
      # Calculate lines in the scroll region
      lines_in_region = scroll_bottom - scroll_top + 1

      # Get all lines before modification
      buffer_cells = active_buffer.cells

      # Split buffer into three parts: lines above scroll region, lines in scroll region, lines below scroll region
      lines_above_region = Enum.slice(buffer_cells, 0, scroll_top)
      lines_in_scroll_region = Enum.slice(buffer_cells, scroll_top, lines_in_region)
      lines_below_region = Enum.slice(buffer_cells, scroll_bottom + 1, buffer_height - scroll_bottom - 1)

      # Split the scroll region at cursor position
      cursor_offset_in_region = cursor_row - scroll_top
      {lines_above_cursor, lines_at_and_below_cursor} = Enum.split(lines_in_scroll_region, cursor_offset_in_region)

      # Skip the deleted lines and keep the rest
      remaining_lines = Enum.drop(lines_at_and_below_cursor, min(count, length(lines_at_and_below_cursor)))

      # Create blank lines to add at the bottom of the scroll region
      blank_line = List.duplicate(%Cell{char: " ", style: default_style}, buffer_width)
      num_blank_lines = min(count, lines_in_region - cursor_offset_in_region)
      blank_lines = List.duplicate(blank_line, num_blank_lines)

      # Combine all parts within the scroll region
      new_region_content = lines_above_cursor ++ remaining_lines ++ blank_lines

      # Make sure we don't exceed the scroll region height
      new_region_content = Enum.take(new_region_content, lines_in_region)

      # Create the new buffer cells
      new_buffer_cells = lines_above_region ++ new_region_content ++ lines_below_region

      # Update the buffer
      Emulator.update_active_buffer(emulator, %{active_buffer | cells: new_buffer_cells})
    else
      # Cursor is outside scroll region, do nothing
      emulator
    end
  end

  @doc "Handles Delete Characters (DCH - 'P')"
  @spec handle_P(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_P(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    {current_col, current_row} = Emulator.get_cursor_position(emulator)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style # Get default style

    # Note: ScreenBuffer.delete_characters/4 needed update
    new_buffer = CharEditor.delete_characters(active_buffer, current_row, current_col, count, default_style)
    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Insert Character (ICH - '@')"
  @spec handle_at(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_at(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    {col, row} = Emulator.get_cursor_position(emulator)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style # Use current style for inserted spaces

    # Pass row and col in the correct order
    new_buffer = CharEditor.insert_characters(active_buffer, row, col, count, default_style)

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Scroll Up (SU - 'S')"
  @spec handle_S(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_S(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    # ScreenBuffer.scroll_up returns {new_buffer, scrolled_lines}
    # We only need the new_buffer to update the emulator state
    {new_buffer, _scrolled_lines} = ScreenBuffer.scroll_up(active_buffer, count, emulator.scroll_region)
    Emulator.update_active_buffer(emulator, new_buffer) # Use helper
  end

  @doc "Handles Scroll Down (SD - 'T')"
  @spec handle_T(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_T(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    active_buffer = Emulator.get_active_buffer(emulator)
    # ScreenBuffer.scroll_down expects lines to insert from scrollback
    # This requires coordination with Buffer.Manager, which CSIHandlers doesn't have direct access to.
    # For now, just pass empty list for lines_to_insert.
    # TODO: Refactor scrolling logic - maybe move to Emulator or Buffer.Manager?
    new_buffer = ScreenBuffer.scroll_down(active_buffer, count, emulator.scroll_region)
    Emulator.update_active_buffer(emulator, new_buffer) # Use helper
  end

  @doc "Handles Erase Character (ECH - 'X')"
  @spec handle_X(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_X(emulator, params) do
    count = Parser.get_param(params, 0, 1)
    {current_col, current_row} = Emulator.get_cursor_position(emulator)
    active_buffer = Emulator.get_active_buffer(emulator)
    default_style = emulator.style # Get default style

    # Erase Characters (ECH) - write N spaces starting at cursor
    blank_char = " "
    new_buffer =
      Enum.reduce(0..(count - 1), active_buffer, fn i, buf ->
        # Use the Writer module, passing the default style
        Raxol.Terminal.Buffer.Writer.write_char(buf, current_row, current_col + i, blank_char, default_style)
      end)

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @doc "Handles Send Device Attributes (DA - 'c')"
  @spec handle_c(Emulator.t(), list(integer() | nil), String.t()) :: Emulator.t()
  def handle_c(emulator, params, intermediates_buffer) do
    # Determine if it's Primary or Secondary DA based on intermediate
    is_secondary_da = (intermediates_buffer == ">")
    param = Parser.get_param(params, 0, 0)

    # Only respond if param is 0
    if param == 0 do
      response =
        if is_secondary_da do
          # Secondary DA (> 0 c) Response
          "\e[>0;0;0c" # Placeholder version/cartridge
        else
          # Primary DA (0 c) Response
          "\e[?6c" # VT102 ID
        end
      %{emulator | output_buffer: emulator.output_buffer <> response}
    else
      # Ignore non-zero parameters for DA
      emulator
    end
  end

  @doc "Handles Device Status Report (DSR - 'n')"
  @spec handle_n(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_n(emulator, params) do
    param = Parser.get_param(params, 0, 0)
    Logger.debug("Handling DSR (n) with param: #{param}")
    response = case param do
      # Status report: Respond OK
      5 -> "\e[0n"
      # Cursor position report
      6 ->
        # Get 1-based row/col using direct access
        {col, row} = emulator.cursor.position
        "\e[#{row + 1};#{col + 1}R"
      # Unknown DSR request
      _ ->
        Logger.warning("Unknown DSR request: #{param}")
        ""
    end

    if response != "" do
      Logger.debug("DSR response: #{inspect(response)}")
      %{emulator | output_buffer: emulator.output_buffer <> response}
    else
      emulator
    end
  end

  @doc "Handles Set cursor style (DECSCUSR - 'q' with space intermediate)"
  @spec handle_q_deccusr(Emulator.t(), list(integer() | nil)) :: Emulator.t()
  def handle_q_deccusr(emulator, params) do
    param = Parser.get_param(params, 0, 1) # Default to 1 (blinking block)
    Logger.debug("Handling DECSCUSR ( q) with param: #{param}")
    new_style = case param do
      # Explicitly set blinking block for 0, 1, or default/invalid
      0 -> :blinking_block # User-specified default
      1 -> :blinking_block # User-specified default
      2 -> :steady_block
      3 -> :blinking_underline
      4 -> :steady_underline
      5 -> :blinking_bar
      6 -> :steady_bar
      # Catch-all for other values (including missing param which defaults to 1,
      # or invalid params like 999). Explicitly set blinking block.
      _ ->
        Logger.warning("Unknown DECSCUSR param: #{param}, defaulting to blinking block")
        :blinking_block # Default to blinking block for unknown params
    end
    %{emulator | cursor_style: new_style}
  end

  # --- SGR Processing Helper (Moved from Executor) ---

  # Recursive helper to process SGR parameters
  @spec process_sgr_params(list(integer() | nil), TextFormatting.style_t()) :: TextFormatting.style_t()
  # Base case: Empty list means all params processed, return the final style
  # Reset (0) is handled within the recursive step.
  defp process_sgr_params([], style), do: style

  defp process_sgr_params([param | rest_params], style) do
    # Treat nil parameter as 0 (reset)
    actual_param = param || 0
    # Logger.debug("[process_sgr_params] Processing param: #{inspect(param)} -> #{actual_param}, Style IN: #{inspect(style)}")

    # Use actual_param for the case statement
    next_style =
      case actual_param do
        # --- Basic Attributes & Resets ---
        0 -> TextFormatting.new() # Reset all attributes
        1 -> TextFormatting.apply_attribute(style, :bold) # Bold
        2 -> TextFormatting.apply_attribute(style, :faint) # Faint
        3 -> TextFormatting.apply_attribute(style, :italic)
        4 -> TextFormatting.apply_attribute(style, :underline)
        5 -> TextFormatting.apply_attribute(style, :blink) # Slow blink
        6 -> TextFormatting.apply_attribute(style, :blink) # Fast blink (treat same as slow)
        7 -> TextFormatting.apply_attribute(style, :reverse)
        8 -> TextFormatting.apply_attribute(style, :conceal)
        9 -> TextFormatting.apply_attribute(style, :strikethrough)
        # 10-19 Font selection (ignored for now)
        20 -> TextFormatting.apply_attribute(style, :fraktur)
        21 -> TextFormatting.apply_attribute(style, :double_underline)
        22 -> TextFormatting.apply_attribute(style, :normal_intensity) # Not bold, not faint
        23 -> TextFormatting.apply_attribute(style, :no_italic_fraktur) # Not italic, not fraktur
        # Correctly reset single/double underline
        24 -> TextFormatting.apply_attribute(style, :no_underline)
        25 -> TextFormatting.apply_attribute(style, :no_blink)
        # Add missing reset codes
        27 -> TextFormatting.apply_attribute(style, :no_reverse)
        28 -> TextFormatting.apply_attribute(style, :reveal) # Not concealed
        29 -> TextFormatting.apply_attribute(style, :no_strikethrough)

        # --- Basic Foreground Colors (30-37) & Default (39) ---
        param when param >= 30 and param <= 37 ->
          color = index_to_basic_color(param - 30)
          TextFormatting.set_foreground(style, color)
        39 ->
          TextFormatting.apply_attribute(style, :default_fg)

        # --- Basic Background Colors (40-47) & Default (49) ---
        param when param >= 40 and param <= 47 ->
          color = index_to_basic_color(param - 40)
          TextFormatting.set_background(style, color)
        49 ->
          TextFormatting.apply_attribute(style, :default_bg)

        # --- Bright Foreground Colors (90-97) ---
        # Also apply bold attribute for bright colors
        param when param >= 90 and param <= 97 ->
          color = index_to_basic_color(param - 90)
          style |> TextFormatting.set_foreground(color) |> TextFormatting.apply_attribute(:bold)

        # --- Bright Background Colors (100-107) ---
        param when param >= 100 and param <= 107 ->
          color = index_to_basic_color(param - 100)
          style |> TextFormatting.set_background(color)

        # --- Extended Colors (38, 48) --- Need stateful handling within this function
        # TODO: Re-implement stateful parsing for 38/48 here if needed
        # Currently, this recursive version won't handle multi-param codes like 38;2;r;g;b correctly
        # It will process 38, then try to process 2, then r, etc. individually.

        # Fallback for unknown/ignored SGR codes
        unknown ->
          Logger.debug("Ignoring unknown SGR parameter: #{unknown}")
          style
      end
    # Logger.debug("[process_sgr_params] Style OUT: #{inspect(next_style)}")

    # Recursively process remaining parameters
    process_sgr_params(rest_params, next_style)
  end

  # Helper to map basic color indices (0-7) to atoms
  defp index_to_basic_color(index) do
    [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    |> Enum.at(index)
  end

end
