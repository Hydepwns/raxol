defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc """
  Main entry point for executing terminal commands.

  This module handles the execution of parsed CSI, OSC, and DCS sequences,
  delegating to specialized modules for specific functionality.
  It receives emulator state and sequence details, and returns the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.Modes
  alias Raxol.Terminal.Commands.Screen
  alias Raxol.Terminal.Cursor.Movement
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Cursor.Style
  alias Raxol.Terminal.TextFormatting
  alias Raxol.Terminal.ANSI.TextFormatting

  require Logger
  require Raxol.Terminal.TextFormatting

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  CSI sequences begin with the escape character followed by '[' and are used
  for cursor movement, screen editing, and setting display attributes.

  ## Parameters

  * `emulator` - The current emulator state
  * `params_buffer` - The parameter portion of the CSI sequence
  * `intermediates_buffer` - The intermediate bytes portion of the CSI sequence
  * `final_byte` - The final byte that determines the specific command

  ## Returns

  * Updated emulator state
  """
  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    # Parse the raw param string buffer into a list of integers/nil
    params = Parser.parse_params(params_buffer)
    # Use intermediates_buffer directly
    intermediates = intermediates_buffer

    case {final_byte, intermediates} do
      # SGR - Select Graphic Rendition
      {?m, ""} ->
        # Params can be empty (CSI m), which defaults to [0]
        sgr_params = if params == [], do: [0], else: params
        handle_sgr(emulator, sgr_params)

      # --- Scrolling ---
      # SU - Scroll Up
      {?S, ""} ->
        # Default to 1
        count = Parser.get_param(params, 1)
        Screen.scroll_up(emulator, count)

      # SD - Scroll Down
      {?T, ""} ->
        # Default to 1
        count = Parser.get_param(params, 1)
        Screen.scroll_down(emulator, count)

      # --- Scrolling Region ---
      # DECSTBM - Set Top and Bottom Margins
      {?r, ""} ->
        handle_set_scroll_region(emulator, params)

      # --- DEC Private Mode Set/Reset ---
      # DECSET - Set Mode
      {?h, "?"} ->
        Modes.handle_dec_private_mode(emulator, params, :set)

      {?h, ""} ->
        Modes.handle_ansi_mode(emulator, params, :set)

      # DECRST - Reset Mode
      {?l, "?"} ->
        Modes.handle_dec_private_mode(emulator, params, :reset)

      {?l, ""} ->
        Modes.handle_ansi_mode(emulator, params, :reset)

      # --- Cursor Movement ---
      # CUU - Cursor Up
      {?A, ""} ->
        count = Parser.get_param(params, 1)
        %{emulator | cursor: Movement.move_up(emulator.cursor, count)}

      # CUD - Cursor Down
      {?B, ""} ->
        count = Parser.get_param(params, 1)
        %{emulator | cursor: Movement.move_down(emulator.cursor, count)}

      # CUF - Cursor Forward
      {?C, ""} ->
        count = Parser.get_param(params, 1)
        %{emulator | cursor: Movement.move_right(emulator.cursor, count)}

      # CUB - Cursor Back
      {?D, ""} ->
        count = Parser.get_param(params, 1)
        %{emulator | cursor: Movement.move_left(emulator.cursor, count)}

      # CUP - Cursor Position
      {?H, ""} ->
        handle_cursor_position(emulator, params)

      # HVP - Horizontal and Vertical Position (same as CUP)
      {?f, ""} ->
        handle_cursor_position(emulator, params)

      # CNL - Cursor Next Line
      {?E, ""} ->
        count = Parser.get_param(params, 1)
        cursor = emulator.cursor
        # Move to beginning of line, then down
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}}
        cursor = Movement.move_down(cursor, count)
        %{emulator | cursor: cursor}

      # CPL - Cursor Previous Line
      {?F, ""} ->
        count = Parser.get_param(params, 1)
        cursor = emulator.cursor
        # Move to beginning of line, then up
        cursor = %{cursor | position: {0, elem(cursor.position, 1)}}
        cursor = Movement.move_up(cursor, count)
        %{emulator | cursor: cursor}

      # CHA - Cursor Horizontal Absolute
      {?G, ""} ->
        col = Parser.get_param(params, 1)
        {_, row} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col, row)}

      # VPA - Vertical Position Absolute
      {?d, ""} ->
        row = Parser.get_param(params, 1)
        {col, _} = emulator.cursor.position
        %{emulator | cursor: Manager.move_to(emulator.cursor, col, row)}

      # --- Editing ---
      # ED - Erase in Display (clear screen)
      {?J, ""} ->
        n = Parser.get_param(params, 1, 0)
        Screen.clear_screen(emulator, n)

      # EL - Erase in Line (clear line)
      {?K, ""} ->
        n = Parser.get_param(params, 1, 0)
        Screen.clear_line(emulator, n)

      # IL - Insert Line
      {?L, ""} ->
        n = Parser.get_param(params, 1)
        Screen.insert_lines(emulator, n)

      # DL - Delete Line
      {?M, ""} ->
        n = Parser.get_param(params, 1)
        Screen.delete_lines(emulator, n)

      # --- Cursor Visibility ---
      # DECTCEM - Text Cursor Enable Mode
      {?q, " "} ->
        n = Parser.get_param(params, 1)
        handle_cursor_style(emulator, n)

      # --- Device Status Reports ---
      # DSR - Device Status Report
      {?n, ""} ->
        n = Parser.get_param(params, 1)
        handle_device_status_report(emulator, n)

      # --- Default case ---
      _ ->
        Logger.debug(
          "Unhandled CSI sequence: final=#{final_byte}, " <>
          "intermediates=#{inspect(intermediates)}, params=#{inspect(params)}"
        )
        emulator
    end
  end

  # --- Helper Functions ---

  defp handle_sgr(emulator, params) do
    # Process each SGR parameter
    Enum.reduce(params, emulator, fn param, acc ->
      case param do
        # Reset all attributes
        0 ->
          %{acc | style: TextFormatting.reset_style()}

        # Bold/increased intensity
        1 ->
          %{acc | style: TextFormatting.set_style(acc.style, :bold, true)}

        # Faint/decreased intensity
        2 ->
          %{acc | style: TextFormatting.set_style(acc.style, :faint, true)}

        # Italic
        3 ->
          %{acc | style: TextFormatting.set_style(acc.style, :italic, true)}

        # Underline
        4 ->
          %{acc | style: TextFormatting.set_style(acc.style, :underline, true)}

        # Blink
        5 ->
          %{acc | style: TextFormatting.set_style(acc.style, :blink, true)}

        # Rapid blink (not widely supported)
        6 ->
          %{acc | style: TextFormatting.set_style(acc.style, :rapid_blink, true)}

        # Reverse video
        7 ->
          %{acc | style: TextFormatting.set_style(acc.style, :inverse, true)}

        # Conceal (not widely supported)
        8 ->
          %{acc | style: TextFormatting.set_style(acc.style, :conceal, true)}

        # Crossed-out
        9 ->
          %{acc | style: TextFormatting.set_style(acc.style, :strikethrough, true)}

        # Primary (default) font
        10 ->
          %{acc | style: TextFormatting.set_style(acc.style, :font, 0)}

        # Alternative font (1-9)
        n when n in 11..19 ->
          font_idx = n - 10
          %{acc | style: TextFormatting.set_style(acc.style, :font, font_idx)}

        # Fraktur (rarely used)
        20 ->
          %{acc | style: TextFormatting.set_style(acc.style, :fraktur, true)}

        # Double underline or not bold
        21 ->
          %{acc | style: TextFormatting.set_style(acc.style, :double_underline, true)}

        # Normal intensity (not bold, not faint)
        22 ->
          style =
            acc.style
            |> TextFormatting.set_style(:bold, false)
            |> TextFormatting.set_style(:faint, false)

          %{acc | style: style}

        # Not italic, not fraktur
        23 ->
          style =
            acc.style
            |> TextFormatting.set_style(:italic, false)
            |> TextFormatting.set_style(:fraktur, false)

          %{acc | style: style}

        # Not underlined
        24 ->
          style =
            acc.style
            |> TextFormatting.set_style(:underline, false)
            |> TextFormatting.set_style(:double_underline, false)

          %{acc | style: style}

        # Not blinking
        25 ->
          style =
            acc.style
            |> TextFormatting.set_style(:blink, false)
            |> TextFormatting.set_style(:rapid_blink, false)

          %{acc | style: style}

        # Reserved
        26 ->
          acc

        # Not inverse
        27 ->
          %{acc | style: TextFormatting.set_style(acc.style, :inverse, false)}

        # Not concealed
        28 ->
          %{acc | style: TextFormatting.set_style(acc.style, :conceal, false)}

        # Not crossed out
        29 ->
          %{acc | style: TextFormatting.set_style(acc.style, :strikethrough, false)}

        # Set foreground color (black through white)
        n when n in 30..37 ->
          color_index = n - 30
          %{acc | style: TextFormatting.set_style(acc.style, :fg_color, color_index)}

        # Set foreground color to default
        39 ->
          %{acc | style: TextFormatting.set_style(acc.style, :fg_color, :default)}

        # Set background color (black through white)
        n when n in 40..47 ->
          color_index = n - 40
          %{acc | style: TextFormatting.set_style(acc.style, :bg_color, color_index)}

        # Set background color to default
        49 ->
          %{acc | style: TextFormatting.set_style(acc.style, :bg_color, :default)}

        # Set bright foreground color (bright black through bright white)
        n when n in 90..97 ->
          color_index = n - 90 + 8 # Bright colors start at index 8
          %{acc | style: TextFormatting.set_style(acc.style, :fg_color, color_index)}

        # Set bright background color (bright black through bright white)
        n when n in 100..107 ->
          color_index = n - 100 + 8 # Bright colors start at index 8
          %{acc | style: TextFormatting.set_style(acc.style, :bg_color, color_index)}

        # 256 color and true color handling would be delegated to TextFormatting as well
        # This is a simplified example

        # Unknown SGR parameter
        _ ->
          Logger.debug("Unknown SGR parameter: #{param}")
          acc
      end
    end)
  end

  defp handle_cursor_style(emulator, style_param) do
    cursor_style =
      case style_param do
        # Block cursor
        1 -> :block
        # Underline cursor
        3 -> :underline
        # Vertical bar cursor
        5 -> :bar
        # Default to block cursor for unknown values
        _ -> :block
      end

    new_cursor = Style.set_style(emulator.cursor, cursor_style)
    %{emulator | cursor: new_cursor}
  end

  defp handle_device_status_report(emulator, report_type) do
    case report_type do
      # Status Report
      5 ->
        # For this refactoring, we'll just log that we received the request
        # In a real implementation, this would send a response back
        Logger.debug("Received Device Status Report request")
        emulator

      # Cursor Position Report
      6 ->
        # For this refactoring, we'll just log that we received the request
        # In a real implementation, this would send a response back
        {x, y} = emulator.cursor.position
        Logger.debug("Received Cursor Position Report request, position: #{x+1};#{y+1}")
        emulator

      # Unknown report type
      _ ->
        Logger.debug("Unknown Device Status Report type: #{report_type}")
        emulator
    end
  end

  defp handle_cursor_position(emulator, params) do
    # Handle CUP / HVP parameters
    [row, col] =
      case params do
        [] -> [1, 1]  # Default to (1,1) if no params
        [r] -> [r, 1] # Default column to 1 if only row specified
        [r, c] -> [r, c]
        [r, c | _] -> [r, c] # Ignore any additional parameters
      end

    # Convert to 0-based for internal representation
    # and handle home position inside margins if origin mode is relative
    cursor = Manager.move_to_origin_aware(emulator.cursor, col, row, emulator.scroll_region)
    %{emulator | cursor: cursor}
  end

  defp handle_set_scroll_region(emulator, params) do
    active_buffer = Emulator.get_active_buffer(emulator)
    height = emulator.height || 24  # Default to 24 if height is not set

    [top, bottom] =
      case params do
        # Handle CSI r -> default (1, height)
        [] -> [1, height]
        # Should not happen with map defaults, but safe
        [nil] -> [1, height]
        [t] -> [t, height]
        [nil, b] -> [1, b]
        # Handle CSI top ; bottom r
        [t, b] -> [t, b]
        # Handle more than 2 params - take the first two
        [t, b | _] -> [t, b]
      end

    # Ensure top < bottom and within screen bounds (1 to height)
    # Clamp values and ensure top < bottom.
    # Terminals often reset region if top >= bottom.
    clamped_top = max(1, min(top, height))
    clamped_bottom = max(1, min(bottom, height))

    if clamped_top >= clamped_bottom do
      Logger.debug(
        "DECSTBM: Invalid region (#{top}, #{bottom}), resetting to full screen."
      )

      # Reset scroll region and move cursor home
      cursor_after_move = Manager.move_to(emulator.cursor, 1, 1)
      %{emulator | scroll_region: nil, cursor: cursor_after_move}
    else
      # Store region as 0-based {top, bottom} (inclusive)
      Logger.debug(
        "DECSTBM: Setting scroll region to {#{clamped_top - 1}, #{clamped_bottom - 1}} (0-based)"
      )

      # Set the scroll region but leave the cursor position unchanged.
      %{emulator | scroll_region: {clamped_top - 1, clamped_bottom - 1}}
    end
  end
end
