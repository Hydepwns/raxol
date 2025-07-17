defmodule Raxol.Terminal.Commands.CSIHandlers.DeviceHandlers do
  @moduledoc """
  Handlers for device-related CSI commands.
  """

  alias Raxol.Terminal.Commands.CSIHandlers.Device

  @doc """
  Handles device status with integer parameter.
  """
  def handle_device_status(emulator, param) when is_integer(param) do
    case param do
      5 -> handle_device_status_report(emulator, 5)
      6 -> handle_device_status_report(emulator, 6)
      _ -> emulator
    end
  end

  @doc """
  Handles device status with list parameters.
  """
  def handle_device_status(emulator, params) when is_list(params) do
    case params do
      [?6, ?n] -> handle_device_status_report(emulator, 6)
      [?6, ?R] -> handle_cursor_position_report(emulator)
      [param] when is_integer(param) -> handle_device_status(emulator, param)
      _ -> emulator
    end
  end

  @doc """
  Handles device status report with status code.
  """
  def handle_device_status_report(emulator, status_code) do
    case Device.handle_command(
           emulator,
           [status_code],
           "",
           ?n
         ) do
      {:ok, updated_emulator} -> updated_emulator
      result -> result
    end
  end

  @doc """
  Handles device status report with default status code.
  """
  def handle_device_status_report(emulator) do
    # Default to status code 6 (cursor position report)
    handle_device_status_report(emulator, 6)
  end

  @doc """
  Handles cursor position report.
  """
  def handle_cursor_position_report(emulator) do
    # Handle cursor position report sequence [?6, ?R]
    case Device.handle_command(
           emulator,
           [6],
           "",
           ?n
         ) do
      {:ok, updated_emulator} ->
        %{updated_emulator | cursor_position_reported: true}

      result ->
        %{result | cursor_position_reported: true}
    end
  end
end
