defmodule Raxol.Terminal.Commands.CSIHandlers.Basic do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Operations.CursorOperations
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  require Logger

  # Replace the single handle_command function with multiple pattern-matched functions
  def handle_command(emulator, params, ?m), do: handle_sgr(emulator, params)
  def handle_command(emulator, params, ?H), do: handle_cup(emulator, params)
  def handle_command(emulator, params, ?r), do: handle_decstbm(emulator, params)
  def handle_command(emulator, params, ?J), do: handle_ed(emulator, params)
  def handle_command(emulator, params, ?K), do: handle_el(emulator, params)
  def handle_command(emulator, params, ?l), do: handle_rm(emulator, params)
  def handle_command(emulator, params, ?h), do: handle_sm(emulator, params)
  def handle_command(emulator, params, ?s), do: handle_decsc(emulator, params)
  def handle_command(emulator, params, ?u), do: handle_decrc(emulator, params)
  def handle_command(emulator, params, ?n), do: handle_dsr(emulator, params)
  def handle_command(emulator, params, ?c), do: handle_da(emulator, params)

  def handle_command(emulator, params, ?q),
    do: handle_decscusr(emulator, params)

  def handle_command(emulator, params, ?p), do: handle_decstr(emulator, params)
  def handle_command(emulator, params, ?t), do: handle_decslrm(emulator, params)
  def handle_command(emulator, _params, _byte), do: {:ok, emulator}

  def handle_sgr(emulator, params) do
    require Logger
    Logger.debug("handle_sgr called with params=#{inspect(params)}")

    # Convert params to string format for the SGR processor
    params_string = Enum.join(params, ";")

    # Use the correct SGR processor
    updated_style =
      Raxol.Terminal.ANSI.SGRProcessor.handle_sgr(params_string, emulator.style)

    Logger.debug("handle_sgr: updated_style -> #{inspect(updated_style)}")

    {:ok, %{emulator | style: updated_style}}
  end


  @doc """
  Handles Cursor Position (CUP) command.
  Moves cursor to the specified position.
  """
  @spec handle_cup(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cup(emulator, params) do
    row = Enum.at(params, 0, 1)
    col = Enum.at(params, 1, 1)

    # Convert to 0-based coordinates
    row_0 = row - 1
    col_0 = col - 1

    # Clamp to screen bounds
    row_clamped = max(0, min(row_0, emulator.height - 1))
    col_clamped = max(0, min(col_0, emulator.width - 1))

    # Set cursor position - CursorManager.set_position returns :ok
    CursorManager.set_position(emulator.cursor, {row_clamped, col_clamped})

    {:ok, emulator}
  end

  def handle_decstbm(emulator, params) do
    require Logger

    Logger.debug(
      "handle_decstbm called with params=#{inspect(params)}, emulator.height=#{emulator.height}"
    )

    case parse_scroll_region(params, emulator.height) do
      {:ok, region} -> {:ok, %{emulator | scroll_region: region}}
      :error -> {:ok, emulator}
    end
  end

  defp parse_scroll_region([], _height), do: {:ok, nil}

  defp parse_scroll_region([1, bottom], height) when bottom == height,
    do: {:ok, nil}

  defp parse_scroll_region([top, bottom], height)
       when top >= 1 and bottom <= height and top < bottom do
    {:ok, {top - 1, bottom - 1}}
  end

  defp parse_scroll_region([top], height) when top >= 1 and top < height do
    {:ok, {top - 1, height - 1}}
  end

  defp parse_scroll_region(_, _), do: :error

  @doc """
  Handles Erase Display (ED) command.
  Clears parts of the screen based on the mode.
  """
  @spec handle_ed(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_ed(emulator, params) do
    mode = Enum.at(params, 0, 0)
    clear_screen_by_mode(emulator, mode)
  end

  defp clear_screen_by_mode(emulator, mode) do
    {row, col} = CursorOperations.get_cursor_position(emulator)
    buffer = Emulator.get_screen_buffer(emulator)

    case mode do
      # From cursor to end of screen
      0 ->
        updated_buffer = Eraser.clear_screen_from(buffer, row, col)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      # From start of screen to cursor
      1 ->
        updated_buffer = Eraser.clear_screen_to(buffer, row, col)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      # Entire screen
      2 ->
        updated_buffer = Eraser.clear_screen(buffer)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      # Clear scrollback buffer (mode 3)
      3 ->
        updated_buffer = Eraser.clear_scrollback(buffer)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      _ ->
        {:ok, emulator}
    end
  end

  @doc """
  Handles Erase Line (EL) command.
  Clears parts of the current line based on the mode.
  """
  @spec handle_el(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_el(emulator, params) do
    mode = Enum.at(params, 0, 0)
    clear_line_by_mode(emulator, mode)
  end

  defp clear_line_by_mode(emulator, mode) do
    {row, col} = CursorOperations.get_cursor_position(emulator)
    buffer = Emulator.get_screen_buffer(emulator)

    case mode do
      # From cursor to end of line
      0 ->
        updated_buffer = Eraser.clear_line_from(buffer, row, col)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      # From start of line to cursor
      1 ->
        updated_buffer = Eraser.clear_line_to(buffer, row, col)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      # Entire line
      2 ->
        updated_buffer = Eraser.clear_line(buffer, row)
        {:ok, Emulator.update_active_buffer(emulator, updated_buffer)}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_rm(emulator, params) do
    case params do
      [?? | rest] -> handle_private_rm(emulator, rest)
      _ -> handle_standard_rm(emulator, params)
    end
  end

  def handle_sm(emulator, params) do
    case params do
      [?? | rest] -> handle_private_sm(emulator, rest)
      _ -> handle_standard_sm(emulator, params)
    end
  end

  def handle_decsc(emulator, _params) do
    # Save cursor position to cursor manager's saved fields
    cursor = emulator.cursor
    updated_cursor = %{cursor | 
      saved_row: cursor.row,
      saved_col: cursor.col
    }
    {:ok, %{emulator | cursor: updated_cursor}}
  end

  def handle_decrc(emulator, _params) do
    cursor = emulator.cursor
    case {cursor.saved_row, cursor.saved_col} do
      {nil, _} ->
        {:ok, emulator}
      {_, nil} ->
        {:ok, emulator}
      {saved_row, saved_col} ->
        # Restore cursor position from saved fields
        updated_cursor = %{cursor | 
          row: saved_row,
          col: saved_col
        }
        {:ok, %{emulator | cursor: updated_cursor}}
    end
  end

  def handle_dsr(emulator, params) do
    case params do
      [5] ->
        # Report device status - ready, no malfunctions
        output = "\e[0n"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      [6] ->
        # Report cursor position
        {x, y} = Emulator.get_cursor_position(emulator)
        output = "\e[#{y + 1};#{x + 1}R"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_da(emulator, params) do
    case params do
      [0] ->
        # Report device attributes
        output = "\e[?1;2c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      [1] ->
        # Report device attributes with more details
        output = "\e[?62;1;6;9;15;22;29c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> output}}

      _ ->
        {:ok, emulator}
    end
  end

  def handle_decscusr(emulator, params) do
    case params do
      [0] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}

      [1] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}

      [2] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :steady_block}}}

      [3] ->
        {:ok,
         %{emulator | cursor: %{emulator.cursor | style: :blink_underline}}}

      [4] ->
        {:ok,
         %{emulator | cursor: %{emulator.cursor | style: :steady_underline}}}

      [5] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_bar}}}

      [6] ->
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :steady_bar}}}

      [param] when is_integer(param) ->
        # Invalid style code - keep current style
        {:ok, emulator}

      _ ->
        # Invalid parameter type - default to blink_block
        {:ok, %{emulator | cursor: %{emulator.cursor | style: :blink_block}}}
    end
  end

  def handle_decstr(emulator, _params) do
    {:ok,
     %{
       emulator
       | style: %{},
         cursor: %{emulator.cursor | style: :block},
         scroll_region: nil,
         insert_mode: false,
         newline_mode: false,
         tab_stops: MapSet.new()
     }}
  end

  def handle_decslrm(emulator, params) do
    left = Enum.at(params, 0, 1)
    right = Enum.at(params, 1, emulator.width)

    if left >= 1 and right <= emulator.width and left < right do
      {:ok, %{emulator | horizontal_margins: {left - 1, right - 1}}}
    else
      {:ok, emulator}
    end
  end

  @private_rm_mappings %{
    1 => {:cursor_keys, :normal},
    2 => {:ansi_mode, false},
    3 => {:column_mode, false},
    4 => {:smooth_scroll, false},
    5 => {:reverse_video, false},
    6 => {:origin_mode, false},
    7 => {:wrap_mode, false},
    8 => {:auto_repeat, false},
    9 => {:interlacing, false},
    12 => {:cursor_blink, false},
    25 => {:cursor_visible, false},
    47 => {:alternate_screen, false}
  }

  @private_sm_mappings %{
    1 => {:cursor_keys, :application},
    2 => {:ansi_mode, true},
    3 => {:column_mode, true},
    4 => {:smooth_scroll, true},
    5 => {:reverse_video, true},
    6 => {:origin_mode, true},
    7 => {:wrap_mode, true},
    8 => {:auto_repeat, true},
    9 => {:interlacing, true},
    12 => {:cursor_blink, true},
    25 => {:cursor_visible, true},
    47 => {:alternate_screen, true}
  }

  defp handle_private_rm(emulator, params) do
    case params do
      [param] when is_integer(param) ->
        case Map.get(@private_rm_mappings, param) do
          {field, value} -> {:ok, %{emulator | field => value}}
          nil -> {:ok, emulator}
        end

      _ ->
        {:ok, emulator}
    end
  end

  defp handle_private_sm(emulator, params) do
    case params do
      [param] when is_integer(param) ->
        case Map.get(@private_sm_mappings, param) do
          {field, value} -> {:ok, %{emulator | field => value}}
          nil -> {:ok, emulator}
        end

      _ ->
        {:ok, emulator}
    end
  end

  defp handle_standard_rm(emulator, params) do
    case params do
      [4] -> 
        # Reset insert mode (IRM)
        mode_manager = Raxol.Terminal.ModeManager.set_mode(emulator.mode_manager, [:irm], false)
        {:ok, %{emulator | mode_manager: mode_manager}}
      _ ->
        {:ok, emulator}
    end
  end

  defp handle_standard_sm(emulator, params) do
    case params do
      [4] -> 
        # Set insert mode (IRM)
        mode_manager = Raxol.Terminal.ModeManager.set_mode(emulator.mode_manager, [:irm], true)
        {:ok, %{emulator | mode_manager: mode_manager}}
      _ ->
        {:ok, emulator}
    end
  end
end
