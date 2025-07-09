defmodule Raxol.Terminal.Commands.CSIHandlers.Device do
  @moduledoc """
  Handlers for device-related CSI commands.
  """

  alias Raxol.Terminal.Emulator

  def handle_command(emulator, params, intermediates_buffer, byte) do
    case byte do
      # Device Attributes
      ?c -> handle_da(emulator, params, intermediates_buffer)
      # Device Status Report
      ?n -> handle_dsr(emulator, params)
      # Save Cursor
      ?s -> handle_decsc(emulator, params)
      # Restore Cursor
      ?u -> handle_decrc(emulator, params)
      # Window Manipulation
      ?t -> handle_xtwinops(emulator, params)
      _ -> {:ok, emulator}
    end
  end

  @doc """
  Handle Device Attributes (DA) command.
  Responds with terminal capabilities.
  """
  def handle_da(emulator, _params, intermediates_buffer) do
    case intermediates_buffer do
      "?" ->
        # Respond with VT100 capabilities
        # ESC [ ? 1 ; 2 c
        # 1 = VT100
        # 2 = Advanced Video Option
        {:ok, emulator}

      _ ->
        # Public DA - respond with standard capabilities
        updated_emulator = Emulator.write_to_output(emulator, ~c"\e[?62;1;6;9;15;22;29c")
        {:ok, updated_emulator}
    end
  end

  @doc """
  Handle Device Status Report (DSR) command.
  Responds with cursor position or device status.
  """
  def handle_dsr(emulator, params) do
    case params do
      [5] ->
        # Report device status
        # ESC [ 0 n (ready, no malfunctions)
        updated_emulator = Emulator.write_to_output(emulator, "\e[0n")
        {:ok, updated_emulator}

      [6] ->
        # Report cursor position
        # ESC [ row ; col R
        {x, y} = Emulator.get_cursor_position(emulator)
        updated_emulator = Emulator.write_to_output(emulator, "\e[#{y + 1};#{x + 1}R")
        {:ok, updated_emulator}

      _ ->
        {:ok, emulator}
    end
  end

  @doc """
  Handle Save Cursor (DECSC) command.
  Saves cursor position and attributes.
  """
  def handle_decsc(emulator, _params) do
    saved_cursor = %{
      position: Emulator.get_cursor_position(emulator),
      style: emulator.style,
      attributes: emulator.cursor.attributes
    }

    {:ok, %{emulator | saved_cursor: saved_cursor}}
  end

  @doc """
  Handle Restore Cursor (DECRC) command.
  Restores cursor position and attributes.
  """
  def handle_decrc(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        {:ok, emulator}

      saved ->
        emulator =
          Emulator.move_cursor_to(
            emulator,
            saved.position,
            emulator.width,
            emulator.height
          )

        {:ok,
         %{
           emulator
           | style: saved.style,
             cursor: %{emulator.cursor | attributes: saved.attributes}
         }}
    end
  end

  @doc """
  Handle Window Manipulation (XTWINOPS) command.
  Handles window size and state changes.
  """
  def handle_xtwinops(emulator, params) do
    case params do
      [3, _x, _y] ->
        # Report window size
        # ESC [ 3 ; height ; width t
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[3;#{emulator.window.x};#{emulator.window.y}t"
        )

        {:ok, updated_emulator}

      [4, height, width] ->
        # Resize window
        Emulator.resize(emulator, width, height)
        {:ok, emulator}

      [5, 0] ->
        # Report window state
        # ESC [ 5 ; 0 t (normal)
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[5;#{state}t")
        {:ok, updated_emulator}

      [5, 1] ->
        # Report window state
        # ESC [ 5 ; 1 t (iconified)
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[5;#{state}t")
        {:ok, updated_emulator}

      [5, 2] ->
        # Report window state
        # ESC [ 5 ; 2 t (maximized)
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[5;#{state}t")
        {:ok, updated_emulator}

      [9, 0] ->
        # Restore window
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[9;#{state}t")
        {:ok, updated_emulator}

      [9, 1] ->
        # Maximize window
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[9;#{state}t")
        {:ok, %{updated_emulator | window: %{updated_emulator.window | maximized: true}}}

      [10] ->
        # Unmaximize window
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[10;#{state}t")
        {:ok, %{updated_emulator | window: %{updated_emulator.window | maximized: false}}}

      [11] ->
        # Report window state
        state = if emulator.window.maximized, do: 1, else: 0
        updated_emulator = Emulator.write_to_output(emulator, "\e[11;#{state}t")
        {:ok, updated_emulator}

      [13] ->
        # Report window position
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[13;#{emulator.window.x};#{emulator.window.y}t"
        )
        {:ok, updated_emulator}

      [14] ->
        # Report window size in pixels
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[14;#{emulator.window.height};#{emulator.window.width}t"
        )
        {:ok, updated_emulator}

      [15] ->
        # Report screen size in pixels
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[15;#{emulator.window.height};#{emulator.window.width}t"
        )
        {:ok, updated_emulator}

      [16] ->
        # Report character cell size in pixels
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[16;#{emulator.window.cell_height};#{emulator.window.cell_width}t"
        )
        {:ok, updated_emulator}

      [18] ->
        # Report screen size in characters
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[18;#{emulator.height};#{emulator.width}t"
        )
        {:ok, updated_emulator}

      [19] ->
        # Report screen size in characters
        updated_emulator = Emulator.write_to_output(
          emulator,
          "\e[19;#{emulator.height};#{emulator.width}t"
        )
        {:ok, updated_emulator}

      [20] ->
        # Report icon label
        updated_emulator = Emulator.write_to_output(emulator, "\e[20;#{emulator.window.title}t")
        {:ok, updated_emulator}

      [21] ->
        # Report window title
        updated_emulator = Emulator.write_to_output(emulator, "\e[21;#{emulator.window.title}t")
        {:ok, updated_emulator}

      _ ->
        {:ok, emulator}
    end
  end
end
