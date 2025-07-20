defmodule Raxol.Terminal.Commands.DeviceHandlers do
  @moduledoc """
  Handles device status and attribute related CSI commands.

  This module contains handlers for device status reports (DSR) and device
  attributes (DA). Each function takes the current emulator state and parsed
  parameters, returning the updated emulator state.
  """

  alias Raxol.Terminal.{Emulator, OutputManager}
  require Raxol.Core.Runtime.Log

  @spec handle_n(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_n(emulator, params) do
    code =
      case params do
        [] -> 5
        [0] -> 5
        [val | _] -> val
      end

    response = generate_dsr_response(code, emulator)

    if response do
      {:ok, OutputManager.write(emulator, response)}
    else
      {:error, :unknown_dsr_code, emulator}
    end
  end

  @spec handle_c(Emulator.t(), list(integer()), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_c(emulator, _params, intermediates_buffer) do
    response = generate_da_response(intermediates_buffer)

    if response do
      {:ok, OutputManager.write(emulator, response)}
    else
      {:error, :invalid_da_response, emulator}
    end
  end

  @spec generate_dsr_response(non_neg_integer(), Emulator.t()) ::
          String.t() | nil
  defp generate_dsr_response(code, emulator) do
    case code do
      # Report cursor position (CPR)
      6 ->
        {row, col} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
        # Convert to 1-based for response
        "\e[#{row + 1};#{col + 1}R"

      # Report device status (DSR)
      5 ->
        # Device ready
        "\e[0n"

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown DSR code: #{code}",
          %{}
        )

        nil
    end
  end

  @spec generate_da_response(String.t()) :: String.t()
  defp generate_da_response(intermediates_buffer) do
    case intermediates_buffer do
      # Secondary DA: VT220
      ">" -> "\e[>0;1;0c"
      # Primary DA: VT220
      _ -> "\e[?1;2c"
    end
  end
end
