defmodule Raxol.Terminal.Commands.CSIHandlers.Device do
  @moduledoc """
  Handlers for device-related CSI commands.
  """

  # NOTE: The functions handle_report_*, handle_resize_window, handle_unmaximize_window, 
  # and handle_window_action are called dynamically via apply/3 in dispatch_window_operation/3.
  # The compiler cannot detect this usage pattern and shows "unused function" warnings.
  # These warnings are expected and can be ignored - the functions ARE used at runtime.

  alias Raxol.Terminal.Emulator

  # Suppress all compiler warnings for this module
  @compile :nowarn_unused_function
  @compile :nowarn_unused_vars

  @dialyzer {:nowarn_function,
             [
               handle_report_window_size: 1,
               handle_resize_window: 3,
               handle_report_window_state: 2,
               handle_window_action: 2,
               handle_unmaximize_window: 1,
               handle_report_window_position: 1,
               handle_report_screen_size_pixels: 1,
               handle_report_cell_size: 1,
               handle_report_screen_size_chars: 1,
               handle_report_icon_label: 1,
               handle_report_window_state_0: 1,
               handle_report_window_title: 1
             ]}

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
  def handle_da(emulator, params, intermediates_buffer) do
    case {intermediates_buffer, params} do
      {">", []} ->
        # Secondary DA: CSI > c
        updated_emulator = Emulator.write_to_output(emulator, "\e[>0;0;0c")
        {:ok, updated_emulator}

      {">", [0]} ->
        # Secondary DA: CSI > 0 c
        updated_emulator = Emulator.write_to_output(emulator, "\e[>0;0;0c")
        {:ok, updated_emulator}

      {">", [_]} ->
        # Secondary DA with non-zero param - ignore
        {:ok, emulator}

      {"", []} ->
        # Primary DA: CSI c
        updated_emulator = Emulator.write_to_output(emulator, "\e[?6c")
        {:ok, updated_emulator}

      {"", [0]} ->
        # Primary DA: CSI 0 c
        updated_emulator = Emulator.write_to_output(emulator, "\e[?6c")
        {:ok, updated_emulator}

      {"", [_]} ->
        # Primary DA with non-zero param - ignore
        {:ok, emulator}

      {"?", _} ->
        # Private DA - ignore for now
        {:ok, emulator}

      _ ->
        # Default case - ignore
        {:ok, emulator}
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
        {row, col} = Emulator.get_cursor_position(emulator)

        updated_emulator =
          Emulator.write_to_output(emulator, "\e[#{row + 1};#{col + 1}R")

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
      [op | rest] -> dispatch_window_operation(emulator, op, rest)
      _ -> {:ok, emulator}
    end
  end

  @window_operations %{
    3 => {:handle_report_window_size, 0},
    4 => {:handle_resize_window, 2},
    5 => {:handle_report_window_state, 1},
    9 => {:handle_window_action, 1},
    10 => {:handle_unmaximize_window, 0},
    11 => {:handle_report_window_state_0, 0},
    13 => {:handle_report_window_position, 0},
    14 => {:handle_report_window_size_pixels, 0},
    15 => {:handle_report_screen_size_pixels, 0},
    16 => {:handle_report_cell_size, 0},
    18 => {:handle_report_screen_size_chars, 0},
    19 => {:handle_report_screen_size_chars, 0},
    20 => {:handle_report_icon_label, 0},
    21 => {:handle_report_window_title, 0}
  }

  defp dispatch_window_operation(emulator, op, rest) do
    case Map.get(@window_operations, op) do
      nil ->
        {:ok, emulator}

      {function, 0} ->
        apply(__MODULE__, function, [emulator])

      {function, 1} ->
        apply(__MODULE__, function, [emulator, List.first(rest)])

      {function, 2} ->
        apply(__MODULE__, function, [
          emulator,
          List.first(rest),
          List.last(rest)
        ])
    end
  end

  # The following functions are called dynamically via apply/3 in dispatch_window_operation
  # They are public to avoid unused function warnings

  def handle_report_window_size(emulator) do
    updated_emulator =
      Emulator.write_to_output(
        emulator,
        "\e[3;#{emulator.window.x};#{emulator.window.y}t"
      )

    {:ok, updated_emulator}
  end

  def handle_resize_window(emulator, width, height) do
    Emulator.resize(emulator, width, height)
    {:ok, emulator}
  end

  def handle_report_window_state(emulator, _state) do
    state =
      case emulator.window.maximized do
        true -> 1
        false -> 0
      end

    updated_emulator = Emulator.write_to_output(emulator, "\e[5;#{state}t")
    {:ok, updated_emulator}
  end

  def handle_window_action(emulator, 0) do
    state =
      case emulator.window.maximized do
        true -> 1
        false -> 0
      end

    updated_emulator = Emulator.write_to_output(emulator, "\e[9;#{state}t")
    {:ok, updated_emulator}
  end

  def handle_window_action(emulator, 1) do
    state =
      case emulator.window.maximized do
        true -> 1
        false -> 0
      end

    updated_emulator = Emulator.write_to_output(emulator, "\e[9;#{state}t")

    {:ok,
     %{updated_emulator | window: %{updated_emulator.window | maximized: true}}}
  end

  def handle_unmaximize_window(emulator) do
    state =
      case emulator.window.maximized do
        true -> 1
        false -> 0
      end

    updated_emulator = Emulator.write_to_output(emulator, "\e[10;#{state}t")

    {:ok,
     %{updated_emulator | window: %{updated_emulator.window | maximized: false}}}
  end

  def handle_report_window_position(emulator) do
    updated_emulator =
      Emulator.write_to_output(
        emulator,
        "\e[13;#{emulator.window.x};#{emulator.window.y}t"
      )

    {:ok, updated_emulator}
  end

  def handle_report_screen_size_pixels(emulator) do
    updated_emulator =
      Emulator.write_to_output(
        emulator,
        "\e[15;#{emulator.window.height};#{emulator.window.width}t"
      )

    {:ok, updated_emulator}
  end

  def handle_report_cell_size(emulator) do
    updated_emulator =
      Emulator.write_to_output(
        emulator,
        "\e[16;#{emulator.window.cell_height};#{emulator.window.cell_width}t"
      )

    {:ok, updated_emulator}
  end

  def handle_report_screen_size_chars(emulator) do
    updated_emulator =
      Emulator.write_to_output(
        emulator,
        "\e[18;#{emulator.height};#{emulator.width}t"
      )

    {:ok, updated_emulator}
  end

  def handle_report_icon_label(emulator) do
    updated_emulator =
      Emulator.write_to_output(emulator, "\e[20;#{emulator.window.title}t")

    {:ok, updated_emulator}
  end

  def handle_report_window_state_0(emulator),
    do: handle_report_window_state(emulator, 0)

  def handle_report_window_title(emulator) do
    updated_emulator =
      Emulator.write_to_output(emulator, "\e[21;#{emulator.window.title}t")

    {:ok, updated_emulator}
  end
end
