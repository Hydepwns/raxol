defmodule Raxol.Terminal.Device.Status do
  @moduledoc '''
  Handles device status reporting and attributes for the terminal emulator.
  '''

  @doc '''
  Handles Device Attributes (DA) requests.
  '''
  def handle_device_attributes(emulator, params, intermediates) do
    case {params, intermediates} do
      # Primary DA (0)
      {[0], []} ->
        # Report as VT100 with advanced features
        # Format: ESC [ ? 1 ; 2 c
        # 1 = VT100 with advanced features
        # 2 = Color support
        response = "\x1b[?1;2c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      # Secondary DA (>)
      {[0], [?>]} ->
        # Report as VT220
        # Format: ESC [ > 0 ; 95 ; 0 c
        # 0 = VT220
        # 95 = Firmware version
        # 0 = No additional options
        response = "\x1b[>0;95;0c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      # Unknown DA request
      _ ->
        {:ok, emulator}
    end
  end

  @doc '''
  Handles Device Status Report (DSR) requests.
  '''
  def handle_status_report(emulator, params) do
    case params do
      # Report cursor position
      [6] ->
        # Get current cursor position (0-based)
        {col, row} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
        # Convert to 1-based for response
        response = "\x1b[#{row + 1};#{col + 1}R"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      # Unknown status request
      _ ->
        {:ok, emulator}
    end
  end
end
