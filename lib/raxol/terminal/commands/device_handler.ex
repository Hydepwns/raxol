defmodule Raxol.Terminal.Commands.DeviceHandler do
  @moduledoc """
  @deprecated "Use Raxol.Terminal.Commands.UnifiedCommandHandler instead"

  This module has been consolidated into the unified command handling system.
  For new code, use:

      # Instead of DeviceHandler.handle_n(emulator, params)
      UnifiedCommandHandler.handle_csi(emulator, "n", params)
      
      # Instead of DeviceHandler.handle_c(emulator, params, intermediates)
      UnifiedCommandHandler.handle_csi(emulator, "c", params)
  """

  alias Raxol.Terminal.Commands.UnifiedCommandHandler
  require Raxol.Core.Runtime.Log

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_n(emulator, params) do
    IO.puts(
      :stderr,
      "Warning: DeviceHandler.handle_n/2 is deprecated. Use UnifiedCommandHandler instead."
    )

    UnifiedCommandHandler.handle_csi(emulator, "n", params || [])
  end

  @deprecated "Use UnifiedCommandHandler.handle_csi/3 instead"
  def handle_c(emulator, params, intermediates_buffer \\ "") do
    IO.puts(
      :stderr,
      "Warning: DeviceHandler.handle_c/3 is deprecated. Use UnifiedCommandHandler instead."
    )

    # Create command params that include intermediates information
    cmd_params = %{
      type: :csi,
      command: "c",
      params: params || [],
      intermediates: intermediates_buffer || "",
      private_markers: ""
    }

    UnifiedCommandHandler.handle_command(emulator, cmd_params)
  end

  # Keep the old private functions for any code that might call them directly
  # (though this is unlikely)
  def generate_dsr_response(code, _emulator) do
    IO.puts(
      :stderr,
      "Warning: DeviceHandler.generate_dsr_response/2 is deprecated."
    )

    case code do
      6 ->
        # This would need cursor position - simplified version
        # Default to 1;1
        "\e[1;1R"

      5 ->
        "\e[0n"

      _ ->
        nil
    end
  end

  def generate_da_response(intermediates_buffer) do
    IO.puts(
      :stderr,
      "Warning: DeviceHandler.generate_da_response/1 is deprecated."
    )

    case intermediates_buffer do
      # Secondary DA
      ">" -> "\e[>0;279;0c"
      # Primary DA
      _ -> "\e[?6c"
    end
  end
end
