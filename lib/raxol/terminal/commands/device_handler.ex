defmodule Raxol.Terminal.Commands.DeviceHandler do
  @moduledoc """
  Handles device-specific terminal commands like Device Attributes (DA) and Device Status Report (DSR).
  This module delegates to UnifiedCommandHandler for actual implementation.
  """

  alias Raxol.Terminal.Commands.CommandServer

  @doc """
  Handles Device Attributes (DA) request - CSI c command.

  Primary DA (CSI 0 c or CSI c): Reports terminal capabilities
  Secondary DA (CSI > 0 c): Reports terminal version and features
  """
  def handle_c(emulator, params, intermediates \\ "") do
    UnifiedCommandHandler.handle_csi(emulator, "c", params, intermediates)
  end

  @doc """
  Handles Device Status Report (DSR) request - CSI n command.

  CSI 5 n: Device Status Report - reports "OK" status
  CSI 6 n: Cursor Position Report - reports current cursor position
  """
  def handle_n(emulator, params) do
    case UnifiedCommandHandler.handle_csi(emulator, "n", params, "") do
      {:ok, updated_emulator} -> {:ok, updated_emulator}
      {:error, _reason, updated_emulator} -> {:ok, updated_emulator}
      result -> result
    end
  end
end
