defmodule Raxol.Terminal.Commands.CSIHandlers.Screen do
  @moduledoc """
  Handles screen-related CSI commands.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Emulator.Struct, as: Emulator
  alias Raxol.Terminal.Commands.CSIHandlers.SGRHandler
  alias Raxol.Terminal.{Buffer.Operations, ScreenBuffer}

  @command_handlers %{
    ?A => {:handle_cuu, "Cursor Up"},
    ?B => {:handle_cud, "Cursor Down"},
    ?C => {:handle_cuf, "Cursor Forward"},
    ?D => {:handle_cub, "Cursor Backward"},
    ?E => {:handle_cnl, "Cursor Next Line"},
    ?F => {:handle_cpl, "Cursor Previous Line"},
    ?G => {:handle_cha, "Cursor Horizontal Absolute"},
    ?H => {:handle_cup, "Cursor Position"},
    ?I => {:handle_cht, "Cursor Horizontal Tab"},
    ?J => {:handle_ed, "Erase Display"},
    ?K => {:handle_el, "Erase Line"},
    ?L => {:handle_il, "Insert Line"},
    ?M => {:handle_dl, "Delete Line"},
    ?P => {:handle_dch, "Delete Character"},
    ?S => {:handle_su, "Scroll Up"},
    ?T => {:handle_sd, "Scroll Down"},
    ?X => {:handle_ech, "Erase Character"},
    ?Z => {:handle_cbt, "Cursor Backward Tab"},
    ?` => {:handle_hpa, "Horizontal Position Absolute"},
    ?a => {:handle_hpr, "Horizontal Position Relative"},
    ?d => {:handle_vpa, "Vertical Position Absolute"},
    ?e => {:handle_vpr, "Vertical Position Relative"},
    ?f => {:handle_hvp, "Horizontal and Vertical Position"},
    ?g => {:handle_tbc, "Tab Clear"},
    ?h => {:handle_sm, "Set Mode"},
    ?l => {:handle_rm, "Reset Mode"},
    ?m => {&SGRHandler.handle/2, "Select Graphic Rendition"},
    ?n => {:handle_dsr, "Device Status Report"},
    ?r => {:handle_decstbm, "Set Top and Bottom Margins"},
    ?s => {:handle_scp, "Save Cursor Position"},
    ?u => {:handle_rcp, "Restore Cursor Position"},
    ?@ => {:handle_ich, "Insert Character"}
  }

  def handle_command(emulator, params, byte) do
    case Map.get(@command_handlers, byte) do
      {handler, _description} when atom?(handler) ->
        apply(__MODULE__, handler, [emulator, params])

      {fun, _description} when function?(fun) ->
        fun.(emulator, params)

      nil ->
        {:ok, emulator}
    end
  end

  @doc """
  Handle Cursor Up (CUU) command.
  Moves cursor up by specified number of lines.
  """
  def handle_cuu(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)
    {top, _bottom} = get_scroll_region(emulator)

    new_y =
      if y - lines < top do
        top
      else
        y - lines
      end

    {:ok, Emulator.move_cursor(emulator, x, new_y)}
  end

  @doc """
  Handle Cursor Down (CUD) command.
  Moves cursor down by specified number of lines.
  """
  def handle_cud(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)
    {_top, bottom} = get_scroll_region(emulator)

    new_y =
      if y + lines > bottom do
        bottom
      else
        y + lines
      end

    {:ok, Emulator.move_cursor(emulator, x, new_y)}
  end

  @doc """
  Handle Cursor Forward (CUF) command.
  Moves cursor forward by specified number of columns.
  """
  def handle_cuf(emulator, params) do
    cols = Enum.at(params, 0, 1)
    move_cursor_horizontally(emulator, cols, :relative)
  end

  @doc """
  Handle Cursor Backward (CUB) command.
  Moves cursor backward by specified number of columns.
  """
  def handle_cub(emulator, params) do
    cols = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    new_x =
      if x - cols < 0 do
        0
      else
        x - cols
      end

    {:ok, Emulator.move_cursor(emulator, new_x, y)}
  end

  @doc """
  Handle Cursor Next Line (CNL) command.
  Moves cursor to the beginning of the next line.
  """
  def handle_cnl(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {_top, bottom} = get_scroll_region(emulator)

    new_y =
      if y + lines > bottom do
        bottom
      else
        y + lines
      end

    {:ok, Emulator.move_cursor(emulator, 0, new_y)}
  end

  @doc """
  Handle Cursor Previous Line (CPL) command.
  Moves cursor to the beginning of the previous line.
  """
  def handle_cpl(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {top, _bottom} = get_scroll_region(emulator)

    new_y =
      if y - lines < top do
        top
      else
        y - lines
      end

    {:ok, Emulator.move_cursor(emulator, 0, new_y)}
  end

  @doc """
  Handle Cursor Horizontal Absolute (CHA) command.
  Moves cursor to specified horizontal position.
  """
  def handle_cha(emulator, params) do
    x = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)

    {:ok, Emulator.move_cursor(emulator, x, y)}
  end

  @doc """
  Handle Cursor Position (CUP) command.
  Moves cursor to specified position.
  """
  def handle_cup(emulator, params) do
    x = Enum.at(params, 0, 1)
    y = Enum.at(params, 1, 1)

    {:ok, Emulator.move_cursor(emulator, x, y)}
  end

  @doc """
  Handle Cursor Horizontal Tab (CHT) command.
  Moves cursor to the next horizontal tab stop.
  """
  def handle_cht(emulator, params) do
    cols = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    new_x =
      if x + cols > emulator.width - 1 do
        emulator.width - 1
      else
        x + cols
      end

    {:ok, Emulator.move_cursor(emulator, new_x, y)}
  end

  @doc """
  Handle Erase Display (ED) command.
  Erases the screen from the cursor to the end of the screen.
  """
  def handle_ed(emulator, _params) do
    {x, y} = Emulator.get_cursor_position(emulator)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.erase_display(buffer, x, y, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Erase Line (EL) command.
  Erases the line from the cursor to the end of the line.
  """
  def handle_el(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.erase_line(buffer, lines, y, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Insert Line (IL) command.
  Inserts blank lines at cursor position.
  """
  def handle_il(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.insert_lines(buffer, lines, y, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Delete Line (DL) command.
  Deletes lines at cursor position.
  """
  def handle_dl(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {_x, y} = Emulator.get_cursor_position(emulator)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.delete_lines(buffer, lines, y, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Delete Character (DCH) command.
  Deletes characters at cursor position.
  """
  def handle_dch(emulator, params) do
    chars = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    buffer = Emulator.get_active_buffer(emulator)
    new_buffer = Raxol.Terminal.ScreenBuffer.delete_chars(buffer, x, y, chars)
    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Insert Character (ICH) command.
  Inserts blank characters at cursor position.
  """
  def handle_ich(emulator, params) do
    chars = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    buffer = Emulator.get_active_buffer(emulator)
    new_buffer = Raxol.Terminal.ScreenBuffer.insert_chars(buffer, x, y, chars)
    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Scroll Up (SU) command.
  Scrolls screen up within scroll region.
  """
  def handle_su(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.scroll_up(buffer, lines, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Scroll Down (SD) command.
  Scrolls screen down within scroll region.
  """
  def handle_sd(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {top, bottom} = get_scroll_region(emulator)

    buffer = Emulator.get_active_buffer(emulator)

    new_buffer =
      Raxol.Terminal.ScreenBuffer.scroll_down(buffer, lines, top, bottom)

    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Erase Character (ECH) command.
  Erases characters at cursor position.
  """
  def handle_ech(emulator, params) do
    chars = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    buffer = Emulator.get_active_buffer(emulator)
    new_buffer = Raxol.Terminal.ScreenBuffer.erase_chars(buffer, x, y, chars)
    {:ok, Emulator.update_active_buffer(emulator, new_buffer)}
  end

  @doc """
  Handle Cursor Backward Tab (CBT) command.
  Moves cursor to the previous tab stop.
  """
  def handle_cbt(emulator, _params) do
    {x, y} = Emulator.get_cursor_position(emulator)
    tab_stops = emulator.tab_stops

    new_x =
      if x > 0 do
        x - 1
      else
        emulator.width - 1
      end

    if MapSet.member?(tab_stops, {new_x, y}) do
      {:ok, Emulator.move_cursor(emulator, new_x, y)}
    else
      {:ok, emulator}
    end
  end

  @doc """
  Handle Horizontal Position Absolute (HPA) command.
  Moves cursor to specified horizontal position.
  """
  def handle_hpa(emulator, params) do
    handle_cha(emulator, params)
  end

  @doc """
  Handle Horizontal Position Relative (HPR) command.
  Moves cursor horizontally by specified number of columns.
  """
  def handle_hpr(emulator, params) do
    cols = Enum.at(params, 0, 1)
    move_cursor_horizontally(emulator, cols, :relative)
  end

  @doc """
  Handle Vertical Position Absolute (VPA) command.
  Moves cursor to specified vertical position.
  """
  def handle_vpa(emulator, params) do
    y = Enum.at(params, 0, 1)
    {x, _y} = Emulator.get_cursor_position(emulator)

    {:ok, Emulator.move_cursor(emulator, x, y)}
  end

  @doc """
  Handle Vertical Position Relative (VPR) command.
  Moves cursor vertically by specified number of lines.
  """
  def handle_vpr(emulator, params) do
    lines = Enum.at(params, 0, 1)
    {x, y} = Emulator.get_cursor_position(emulator)

    new_y =
      if y + lines > emulator.height - 1 do
        emulator.height - 1
      else
        y + lines
      end

    {:ok, Emulator.move_cursor(emulator, x, new_y)}
  end

  @doc """
  Handle Horizontal and Vertical Position (HVP) command.
  Moves cursor to specified position.
  """
  def handle_hvp(emulator, params) do
    handle_cup(emulator, params)
  end

  @doc """
  Handle Tab Clear (TBC) command.
  Clears tab stops.
  """
  def handle_tbc(emulator, params) do
    case params do
      [0] ->
        # Clear tab stop at current position
        {:ok,
         %{
           emulator
           | tab_stops:
               MapSet.delete(
                 emulator.tab_stops,
                 Emulator.get_cursor_position(emulator)
               )
         }}

      [3] ->
        # Clear all tab stops
        {:ok, %{emulator | tab_stops: MapSet.new()}}

      _ ->
        {:ok, emulator}
    end
  end

  # Private helper function to get scroll region
  defp get_scroll_region(emulator) do
    case emulator.scroll_region do
      {top, bottom} -> {top, bottom}
      nil -> {0, emulator.height - 1}
    end
  end

  defp move_cursor_horizontally(emulator, cols, :relative) do
    {x, y} = Emulator.get_cursor_position(emulator)

    new_x =
      if x + cols > emulator.width - 1 do
        emulator.width - 1
      else
        x + cols
      end

    {:ok, Emulator.move_cursor(emulator, new_x, y)}
  end

  @doc """
  Handles the IND (Index) sequence - moves cursor down one line, scrolling if needed.
  """
  def handle_ind(emulator) do
    buffer = emulator.main_screen_buffer
    cursor = buffer.cursor

    if cursor.y >= buffer.height - 1 do
      # Use ScreenBuffer.scroll_down since we have a ScreenBuffer struct
      new_buffer = ScreenBuffer.scroll_down(buffer, 1)
      %{emulator | main_screen_buffer: new_buffer}
    else
      new_cursor = %{cursor | y: cursor.y + 1}
      new_buffer = %{buffer | cursor: new_cursor}
      %{emulator | main_screen_buffer: new_buffer}
    end
  end

  @doc """
  Handles the NEL (Next Line) sequence - moves cursor to start of next line, scrolling if needed.
  """
  def handle_nel(emulator) do
    buffer = emulator.main_screen_buffer
    cursor = buffer.cursor

    if cursor.y >= buffer.height - 1 do
      # Use ScreenBuffer.scroll_down since we have a ScreenBuffer struct
      new_buffer = ScreenBuffer.scroll_down(buffer, 1)
      new_cursor = %{new_buffer.cursor | x: 0}
      %{emulator | main_screen_buffer: %{new_buffer | cursor: new_cursor}}
    else
      new_cursor = %{cursor | x: 0, y: cursor.y + 1}
      new_buffer = %{buffer | cursor: new_cursor}
      %{emulator | main_screen_buffer: new_buffer}
    end
  end

  @doc """
  Handles the RI (Reverse Index) sequence - moves cursor up one line, scrolling if needed.
  """
  def handle_ri(emulator) do
    buffer = emulator.main_screen_buffer
    cursor = buffer.cursor

    if cursor.y <= 0 do
      # Use ScreenBuffer.scroll_up since we have a ScreenBuffer struct
      new_buffer = ScreenBuffer.scroll_up(buffer, 1)
      %{emulator | main_screen_buffer: new_buffer}
    else
      new_cursor = %{cursor | y: cursor.y - 1}
      new_buffer = %{buffer | cursor: new_cursor}
      %{emulator | main_screen_buffer: new_buffer}
    end
  end
end
